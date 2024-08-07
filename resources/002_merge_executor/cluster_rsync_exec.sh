#!/bin/bash
cd $(dirname $0)

source inputs.sh
source workflow-libs.sh

# Make sure controller has ssh access to the metering node
host=${metering_user}@${metering_ip}
if ssh -q -o BatchMode=yes -o ConnectTimeout=5 -J usercontainer ${host} "echo 2>&1"; then
    echo "SSH connection to ${host} is successful."
else
    echo "SSH connection to ${host} failed. Exiting."
    exit 1  # Exit the script with a non-zero status
fi

if [[ ${dcs_dry_run} == "true" ]]; then
    echo "RUNNING THE WORKFLOW IN DRY RUN MODE"
    mv dry_run.sh run_dcs.sh 
else
    rm dry_run.sh
fi

echo; echo; echo "MERGING RESULTS"
pwd
echo "    Writing job script"
cp batch_header.sh merge.sh

if [[ ${jobschedulertype} == "SLURM" ]]; then 
    echo "#SBATCH -o ${PWD}/${case_dir}/logs_merge.out" >> merge.sh
    echo "#SBATCH -e ${PWD}/${case_dir}/logs_merge.out" >> merge.sh
elif [[ ${jobschedulertype} == "PBS" ]]; then
    echo "#PBS -o ${PWD}/${case_dir}/logs_merge.out" >> merge.sh
    echo "#PBS -e ${PWD}/${case_dir}/logs_merge.out" >> merge.sh
fi
    
# FIXME: This is needed because run directory is not shared between controller and compute nodes
#echo "rsync -avzq ${resource_privateIp}:${PWD}/ ."  >> merge.sh


# Main script
cat inputs.sh >> merge.sh
cat dcs_environment/${dcs_version}.sh >> merge.sh
cat load_bucket_credentials_ssh.sh >> merge.sh
cat transfer_inputs.sh >> merge.sh
cat ${dcs_analysis_type}.sh >> merge.sh
cat run_dcs.sh >> merge.sh
cat load_bucket_credentials_ssh.sh >> merge.sh
cat clean_job_directory.sh >> merge.sh
cat transfer_outputs.sh >> merge.sh

# FIXME: This is needed because run directory is not shared between controller and compute nodes
#echo "rsync -avzq . ${resource_privateIp}:${PWD}/"  >> merge.sh

echo; echo; echo "SUBMITTING MERGE JOB"
submit_job_sh=./merge.sh
echo "  Job script ${submit_job_sh}"

if [[ ${jobschedulertype} == "SLURM" ]]; then 
    jobid=$(${submit_cmd} ${submit_job_sh} | tail -1 | awk -F ' ' '{print $4}')
elif [[ ${jobschedulertype} == "PBS" ]]; then
    jobid=$(${submit_cmd} ${submit_job_sh} | tail -1)
fi
    
if [ -z "${jobid}" ]; then
    echo "  ERROR: ${submit_cmd} ${submit_job_sh} failed"
    cat ${PWD}/${case_dir}/logs_merge.out
    exit 1
fi

echo ${jobid} > ${resource_jobdir}/job_id.submitted
echo "${cancel_cmd} ${jobid}" >> ${resource_jobdir}/${resource_label}/cancel.sh