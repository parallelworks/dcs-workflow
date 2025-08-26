#!/bin/bash

while [ ! -f "SUBMITTED" ]; do
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Waiting for simulations to be submitted"
    sleep 10
done

# Source the inputs file
source resources/001_simulation_executor/inputs.sh

if [ ${dcs_thread} -eq 1 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Number of threads must be larger than 1 to enable estimates"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Exiting job..."
fi 

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
        if [ -f "COMPLETED" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Simulations are completed"
            exit 0
        fi
    done
}

wait_for_all_simulations_to_start

echo "$(date '+%Y-%m-%d %H:%M:%S') - All simulations are started!"
echo; echo
echo "$(date '+%Y-%m-%d %H:%M:%S') - Calculating completion time estimates"

log_files=$(${sshcmd} ls -d ${resource_jobdir}/worker_*/${log_path})
log_files=$(echo ${log_files} | tr ' ' ',')

echo "$(date '+%Y-%m-%d %H:%M:%S') - Log files:"
echo ${log_files} | tr ',' '\n'

while true; do
    echo; echo; echo "$(date '+%Y-%m-%d %H:%M:%S')"
    if [ -f "COMPLETED" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Simulations are completed"
        exit 0
    fi
    ${sshcmd} "python3 ${resource_jobdir}/001_simulation_executor/estimate_end_time.py ${log_files}"
    sleep 120
done
