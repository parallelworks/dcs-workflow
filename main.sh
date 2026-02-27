#!/bin/bash
source inputs.sh
chmod +x cancel.sh

if [[ "${dcs_output_directory}" == "${dcs_model_directory}" || "${dcs_output_directory}" == "${dcs_model_directory}/"* ]]; then
    echo "Error: Output directory is a subdirectory of model directory." >&2
    exit 1
fi

# Check if file is provided as an argument
if ! [ -f "dcs_environment/${dcs_version}.sh" ]; then
    echo "Error: Missing file dcs_environment/${dcs_version}.sh required to load and run 3DCS. Exiting workflow."
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

# User in the metering server to report usage to
#metering_user=$(python3 ./workflow-utils/print_organization_name.py)
#if [ $? -ne 0 ]; then
#    echo "Error: Could not obtain the name of the organization of user ${PW_USER}. Exiting."
#    exit 1
#fi
#sed -i "s/__metering_user__/${metering_user}/g" inputs.sh
#sed -i "s/__metering_user__/${metering_user}/g" inputs.json

# Check balance
echo; echo "3DCS allocation balance"
python3 get_group_allocation_balance.py ${run_hours_3dcs_group} ${org_name}


if [ $? -ne 0 ]; then
    echo "Error: No 3DCS balance is available. Exiting."
    exit 1
fi

conda activate
python3 ./workflow-utils/input_form_resource_wrapper.py 

if [ $? -ne 0 ]; then
    echo "Error: Input form resource wrapper failed. Exiting."
    exit 1
fi

# Load useful functions
source resources/001_simulation_executor/inputs.sh
export sshcmd="ssh -o StrictHostKeyChecking=no ${resource_publicIp}"
source ./workflow-utils/workflow-libs.sh

# Copy useful functions
cp \
    ./workflow-utils/cpu_and_memory_usage.py \
    ./workflow-utils/cpu_and_memory_usage_requirements.yaml \
    resources/001_simulation_executor/

cp -r dcs_environment resources/001_simulation_executor/
cp -r dcs_environment resources/002_merge_executor/

echo; echo; echo "SENDING BUCKET CREDENTIALS"
pw buckets get-token pw://${dcs_bucket_id} > bucket_credentials
source bucket_credentials
# Check if BUCKET_NAME is empty
if ! [ -n "${BUCKET_URI}" ]; then
    echo "ERROR: Unable to load bucket credentials!"
    exit 1
fi
${sshcmd} "mkdir -p ${resource_jobdir}"
scp bucket_credentials ${resource_publicIp}:${resource_jobdir}/bucket_credentials

./reload_bucket_credentials.sh &> reload_bucket_credentials.log &
reload_bucket_credential_pid=$!
echo "kill ${reload_bucket_credential_pid} || true # bucket credentials" >> cancel.sh

echo; echo; echo "PREPARING AND SUBMITTING 3DCS RUN JOBS"
single_cluster_rsync_exec resources/001_simulation_executor/cluster_rsync_exec.sh
return_code=$?
if [ ${return_code} -ne 0 ]; then
    ${sshcmd} ${resource_jobdir}/${resource_label}/cancel.sh
    exit 1
fi

# Metering code for simulation_executor
./metering.sh &
simulation_executor_metering_pid=$!
echo "kill ${simulation_executor_metering_pid} || true" >> cancel.sh

# Write file to tell streaming and estimate that simulations are submitted
date > SUBMITTED

echo; echo; echo "WAITING FOR 3DCS RUN JOBS TO COMPLETE"
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
        sleep 0.5
    done
    sleep 30
    ssh_retries=10
    ssh_retry_delay=60
    while true; do
        submitted_jobs=$(${sshcmd} find ${resource_jobdir} -name job_id.submitted)
        if [[ $? -eq 0 ]]; then
            break
        fi
        ssh_retries=$((ssh_retries - 1))
        if [[ ${ssh_retries} -le 0 ]]; then
            echo "ERROR: Unable to obtain job status through SSH. Exiting workflow."
            ./cancel.sh
            exit 1
        fi
        echo "WARNING: Failed command -- ${sshcmd} find ${resource_jobdir} -name job_id.submitted"
        echo "Retrying in ${ssh_retry_delay} seconds... (${ssh_retries} retries remaining)"
        sleep ${ssh_retry_delay}
    done
done
kill ${simulation_executor_metering_pid}
# Metering
ssh -A -o StrictHostKeyChecking=no ${resource_publicIp} rsync -avz ${resource_jobdir}/usage/ ${metering_user}@${metering_ip}:~/.3dcs/usage-pending  >> metering.out 2>&1



if ! [ -z "${FAILED_JOBS}" ]; then
    echo "ERROR: Failed jobs - ${FAILED_JOBS}. Exiting workflow"
    ./cancel.sh
    exit 1
fi

# FIXME: We should run a different macroScript to produce the plots and data
if [ "${dcs_concurrency}" -eq 1 ]; then
    echo "Merge job is not running because the number of workers is 1. Exiting workflow."
    ./cancel.sh
    exit 0
fi

echo; echo; echo "PREPARING AND SUBMITTING 3DCS MERGE JOBS"
single_cluster_rsync_exec resources/002_merge_executor/cluster_rsync_exec.sh
return_code=$?
if [ ${return_code} -ne 0 ]; then
    ./cancel.sh
    exit 1
fi

# Metering code for merge_executor
./metering.sh &
merge_executor_metering_pid=$!
echo "kill ${merge_executor_metering_pid} || true" >> cancel.sh

echo; echo; echo "WAITING FOR 3DCS MERGE JOBS TO COMPLETE"
source resources/002_merge_executor/inputs.sh
export sshcmd="ssh -o StrictHostKeyChecking=no ${resource_publicIp}"

export jobid=$(${sshcmd} cat ${resource_jobdir}/job_id.submitted)
wait_job
# Metering
ssh -A -o StrictHostKeyChecking=no ${resource_publicIp} rsync -avz ${resource_jobdir}/usage/ ${metering_user}@${metering_ip}:~/.3dcs/usage-pending  >> metering.out 2>&1

echo; echo; echo "ENSURING JOBS ARE CLEANED"
./cancel.sh > /dev/null 2>&1 


date > COMPLETED

# Kill all descendant processes started by this script (background jobs, SSH connections, etc.)
_kill_descendants() {
    local pid
    for pid in $(pgrep -P "$1" 2>/dev/null); do
        _kill_descendants "$pid"
        kill "$pid" 2>/dev/null || true
    done
}
_kill_descendants $$

echo "$(date) Exiting job"
echo "exit 0" >> cancel.sh
exit 0
