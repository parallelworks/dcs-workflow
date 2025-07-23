#!/bin/bash
while [ ! -f "SUBMITTED" ]; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting for simulations to be submitted"
    sleep 10
done

# Source the inputs file
source resources/001_simulation_executor/inputs.sh

export sshcmd="ssh -o StrictHostKeyChecking=no -o ServerAliveInterval=60 -o ServerAliveCountMax=3 ${resource_publicIp}"

log_path="TempData/dcsSimuMacro_SA_log_x64_$(echo ${dcs_version} | tr '.' '_').txt"

wait_for_all_simulations_to_start() {
    while true; do
        n_running_workers=$(${sshcmd} ls -d ${resource_jobdir}/worker_*/${log_path} | wc -l)
        if [ $? -ne 0 ]; then
            n_running_workers=0
        fi
        if [ "${n_running_workers}" -lt "${dcs_concurrency}" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - ${n_running_workers}/${dcs_concurrency} simulations started"
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting for all simulations to start..."
            sleep 15
        else
            break
        fi
    done
}

wait_for_all_simulations_to_start

echo "$(date '+%Y-%m-%d %H:%M:%S') - All simulations are started!"
echo; echo
echo "$(date '+%Y-%m-%d %H:%M:%S') - Initiating streaming"

# Retry loop for tail command
max_retries=5
retry_delay=10
attempt=1

while [ $attempt -le $max_retries ]; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Attempt $attempt of $max_retries to stream logs"
    ${sshcmd} "tail -f ${resource_jobdir}/worker_*/${log_path}" 
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Streaming completed successfully"
        break
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - SSH tail failed with exit code $exit_code. Retrying in $retry_delay seconds..."
        sleep $retry_delay
        attempt=$((attempt + 1))
    fi
done

if [ $attempt -gt $max_retries ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to stream logs after $max_retries attempts"
    exit 1
fi