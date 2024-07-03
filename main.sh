#!/bin/bash
source inputs.sh

if [[ "${dcs_output_directory}" == "${dcs_model_directory}" || "${dcs_output_directory}" == "${dcs_model_directory}/"* ]]; then
    echo "Error: Output directory is a subdirectory of model directory." >&2
    exit 1
fi

# Use the resource wrapper
source /etc/profile.d/parallelworks.sh
source /etc/profile.d/parallelworks-env.sh
source /pw/.miniconda3/etc/profile.d/conda.sh

if [ -z "${workflow_utils_branch}" ]; then
    # If empty, clone the main default branch
    git clone https://github.com/parallelworks/workflow-utils.git
else
    # If not empty, clone the specified branch
    git clone -b "$workflow_utils_branch" https://github.com/parallelworks/workflow-utils.git
fi

conda activate
python3 ./workflow-utils/input_form_resource_wrapper.py 

if [ $? -ne 0 ]; then
    echo "Error: Input form resource wrapper failed. Exiting."
    exit 1
fi

# Load useful functions
source ./workflow-utils/workflow-libs.sh

# Copy useful functions
cp \
    ./workflow-utils/load_bucket_credentials_ssh.sh \
    ./workflow-utils/cpu_and_memory_usage.py \
    ./workflow-utils/cpu_and_memory_usage_requirements.yaml \
    resources/001_simulation_executor/

cp ./workflow-utils/load_bucket_credentials_ssh.sh resources/002_merge_executor/

echo; echo; echo "STARTING INPUT DATA TRANSFER"
source resources/001_simulation_executor/inputs.sh
echo '#!/bin/bash' > transfer_inputs.sh
echo "mkdir -p ${resource_jobdir}" >> transfer_inputs.sh
echo "cd ${resource_jobdir}" >> transfer_inputs.sh
cat resources/001_simulation_executor/inputs.sh >> transfer_inputs.sh
${pw_job_dir}/workflow-utils/bucket_token_generator.py --bucket_id ${dcs_bucket_id} --token_format text >> transfer_inputs.sh
cat resources/001_simulation_executor/transfer_inputs.sh >> transfer_inputs.sh
# Create metering script
cat >> transfer_inputs.sh <<HERE
echo \${dcs_model_file} > dcs_inputs.sh
echo \${fea_dir} >> dcs_inputs.sh
HERE
chmod +x transfer_inputs.sh

ssh -o StrictHostKeyChecking=no ${resource_publicIp} 'bash -s' < transfer_inputs.sh


echo; echo; echo "PREPARING AND SUBMITTING 3DCS RUN JOBS"
single_cluster_rsync_exec resources/001_simulation_executor/main.sh
return_code=$?
if [ ${return_code} -ne 0 ]; then
    ${sshcmd} ${resource_jobdir}/${resource_label}/cancel.sh
    exit 1
fi


echo; echo; echo "WAITING FOR 3DCS RUN JOBS TO COMPLETE"
source resources/001_simulation_executor/inputs.sh
export sshcmd="ssh -o StrictHostKeyChecking=no ${resource_publicIp}"

submitted_jobs=$(${sshcmd} find ${resource_jobdir} -name job_id.submitted)
if [ -z "${submitted_jobs}" ]; then
    echo "ERROR: No submitted jobs were found. Canceling workflow"
    ${sshcmd} ${resource_jobdir}/${resource_label}/cancel.sh
    exit 1
fi

echo "Submitted jobs found"
echo ${submitted_jobs}

while true; do
    date

    if [ -z "${submitted_jobs}" ]; then
        if [[ "${FAILED}" == "true" ]]; then
            echo "ERROR: Jobs [${FAILED_JOBS}] failed"
            echo "Canceling jobs"
            ${sshcmd} ${resource_jobdir}/${resource_label}/cancel.sh
            exit 1
        fi
        echo "  All jobs are completed. Please check job logs in directories [${case_dirs}] and results"
        break
    fi

    FAILED=false

    for sj in ${submitted_jobs}; do
        jobid=$(${sshcmd} cat ${sj})
              
        if [[ ${jobschedulertype} == "SLURM" ]]; then
            get_slurm_job_status
            # If job status is empty job is no longer running
            if [ -z "${job_status}" ]; then
                job_status=$($sshcmd sacct -j ${jobid}  --format=state | tail -n1)
                if [[ "${job_status}" == *"FAILED"* ]]; then
                    echo "ERROR: SLURM job [${jobid}] failed"
                    FAILED=true
                    FAILED_JOBS="${job_id}, ${FAILED_JOBS}"
                    ${sshcmd} "mv ${sj} ${sj}.failed"
                else
                    echo; echo "Job ${jobid} was completed"
                    ${sshcmd} "mv ${sj} ${sj}.completed"
                    case_dir=$(dirname ${sj} | sed "s|${PWD}/||g")
                fi
            fi

        elif [[ ${jobschedulertype} == "PBS" ]]; then
            get_pbs_job_status
            if [[ "${job_status}" == "C" || -z "${job_status}" ]]; then
                echo "Job ${jobid} was completed"
                ${sshcmd} "mv ${sj} ${sj}.completed"
                case_dir=$(dirname ${sj} | sed "s|${PWD}/||g")
            fi
        fi
        sleep 2
    done
    sleep 30
    submitted_jobs=$(${sshcmd} find ${resource_jobdir} -name job_id.submitted)
done

if ! [ -z "${FAILED_JOBS}" ]; then
    echo "ERROR: Failed jobs - ${FAILED_JOBS}. Exiting workflow"
    exit 1
fi

# FIXME: We should run a different macroScript to produce the plots and data
if [ "${dcs_concurrency}" -eq 1 ]; then
    echo "Merge job is not running because the number of workers is 1. Exiting workflow."
    exit 0
fi

echo; echo; echo "PREPARING AND SUBMITTING 3DCS MERGE JOBS"
single_cluster_rsync_exec resources/002_merge_executor/main.sh
return_code=$?
if [ ${return_code} -ne 0 ]; then
    ./cancel.sh
    exit 1
fi


echo; echo; echo "WAITING FOR 3DCS MERGE JOBS TO COMPLETE"
source resources/002_merge_executor/inputs.sh
export sshcmd="ssh -o StrictHostKeyChecking=no ${resource_publicIp}"

export jobid=$(${sshcmd} cat ${resource_jobdir}/job_id.submitted)
wait_job

echo; echo; echo "ENSURING JOBS ARE CLEANED"
./cancel.sh > /dev/null 2>&1 

exit 0