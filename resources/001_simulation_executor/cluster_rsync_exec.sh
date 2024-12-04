#!/bin/bash
cd $(dirname $0)

source inputs.sh
source workflow-libs.sh

# Prepare for metering
mkdir ${resource_jobdir}/usage
mkdir ${resource_jobdir}/usage_completed

echo '#!/bin/bash' > cancel.sh
chmod +x cancel.sh

create_case(){
    # The merge tasks syncs the results from an S3 bucket. To simplify the path to the
    # results in the S3 bucket ww use the resource job dir
    case_dir=${resource_jobdir}/worker_${case_index}
    mkdir -p ${case_dir}

    echo "    Writing job script"
    cp batch_header.sh  ${case_dir}/run_case.sh

    if [[ ${jobschedulertype} == "SLURM" ]]; then 
        echo "#SBATCH -o ${case_dir}/logs_${case_index}.out" >> ${case_dir}/run_case.sh
        echo "#SBATCH -e ${case_dir}/logs_${case_index}.out" >> ${case_dir}/run_case.sh
    elif [[ ${jobschedulertype} == "PBS" ]]; then
        echo "#PBS -o ${case_dir}/logs_${case_index}.out" >> ${case_dir}/run_case.sh
        echo "#PBS -e ${case_dir}/logs_${case_index}.out" >> ${case_dir}/run_case.sh
    fi
    
    # Main script
    echo "mkdir -p ${case_dir}" >> ${case_dir}/run_case.sh
    echo "cd ${case_dir}" >> ${case_dir}/run_case.sh
    
    # FIXME: This is needed because run directory is not shared between controller and compute nodes
    #echo "rsync -avzq ${resource_privateIp}:${case_dir}/ ."  >> ${case_dir}/run_case.sh

    # Main script
    echo >> ${case_dir}/run_case.sh
    cat inputs.sh >> ${case_dir}/run_case.sh
    cat dcs_environment/${dcs_version}.sh >> ${case_dir}/run_case.sh
    echo "export case_index=${case_index}" >> ${case_dir}/run_case.sh
    echo "export dcs_model_file=${dcs_model_file}" >> ${case_dir}/run_case.sh
    echo >> ${case_dir}/run_case.sh

    cat ${dcs_analysis_type}.sh >> ${case_dir}/run_case.sh
    cat activate_monitoring.sh >> ${case_dir}/run_case.sh
    cat run_dcs.sh >> ${case_dir}/run_case.sh
    cat plot_monitoring.sh >> ${case_dir}/run_case.sh
    cat load_bucket_credentials_ssh.sh >> ${case_dir}/run_case.sh
    cat transfer_outputs.sh >> ${case_dir}/run_case.sh

}

cat_slurm_logs() {
    for f in  $(find ${resource_jobdir} -name logs_*.out); do
	    echo; echo "Contents of ${f}:"
	    cat ${f}
    done
	      
}


echo; echo; echo "STARTING INPUT DATA TRANSFER"
source load_bucket_credentials_ssh.sh
source transfer_inputs.sh

if [[ ${dcs_dry_run} == "true" ]]; then
    echo "RUNNING THE WORKFLOW IN DRY RUN MODE"
    unset monitoring_conda_dir monitoring_conda_env
    echo > activate_monitoring.sh
    echo > plot_monitoring.sh
    echo > activate_monitoring.sh
    mv dry_run.sh run_dcs.sh
else
    rm dry_run.sh
fi

# If no conda environment is specified for the CPU and Mem python monitoring utility
# the workflow assumes monitoring is disabled
if [ -z "${monitoring_conda_dir}" ] || [ -z "${monitoring_conda_env}" ]; then
    echo "CPU and Memory monitoring are disabled"
    echo > activate_monitoring.sh
    echo > plot_monitoring.sh
else
    echo; echo; echo "INSTALLING PYTHON DEPENDENCIES FOR CPU AND MEMORY MONITORING"
    create_conda_env_from_yaml ${monitoring_conda_dir} ${monitoring_conda_env} ./cpu_and_memory_usage_requirements.yaml
fi

echo; echo; echo "CREATING JOB SCRIPTS"
for case_index in $(seq 1 ${dcs_concurrency}); do
    echo; echo "  Case ${case_index}"
    create_case
done

echo; echo; echo "SUBMITTING JOB SCRIPTS"
for case_index in $(seq 1 ${dcs_concurrency}); do
    case_dir=${resource_jobdir}/worker_${case_index}
    echo; echo "  Case ${case_index}"
    cp ${resource_jobdir}/${dcs_model_file} ${case_dir}

    submit_job_sh=${case_dir}/run_case.sh
    echo "  Job script ${submit_job_sh}"

    if [[ ${jobschedulertype} == "SLURM" ]]; then 
        job_id=$(${submit_cmd} ${submit_job_sh} | tail -1 | awk -F ' ' '{print $4}')
    elif [[ ${jobschedulertype} == "PBS" ]]; then
        job_id=$(${submit_cmd} ${submit_job_sh} | tail -1)
    fi
    
    if [ -z "${job_id}" ]; then
        echo "  ERROR: ${submit_cmd} ${submit_job_sh} failed"
        exit 1
    else
        echo "  Submitted job ${job_id}"
        echo "${cancel_cmd} ${job_id}" >> ${resource_jobdir}/${resource_label}/cancel.sh
        echo ${job_id} > ${case_dir}/job_id.submitted
    fi
done