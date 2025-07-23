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

stream_logs() {
    local max_retries=5
    local retry_delay=10
    local attempt=1

    while [ $attempt -le $max_retries ]; do
        if [ -f "COMPLETED" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - COMPLETED file detected, stopping log streaming"
            return 0
        fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Attempt $attempt of $max_retries to stream logs"
        ${sshcmd} "tail -f ${resource_jobdir}/worker_*/${log_path}"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Streaming completed successfully"
            return 0
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - SSH tail failed with exit code $exit_code. Retrying in $retry_delay seconds..."
            sleep $retry_delay
            attempt=$((attempt + 1))
        fi
    done

    if [ $attempt -gt $max_retries ]; then
        if [ -f "COMPLETED" ]; then
            echo "$(date '+%Y-%m-%d %H:%M:%S') - COMPLETED file detected, ignoring retry limit"
            return 0
        else
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to stream logs after $max_retries attempts"
            return 1
        fi
    fi
}

# Start log streaming in the background
echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting background log streaming"
stream_logs &
stream_pid=$!
echo "kill ${stream_pid}" > cancel_stream.sh

# Wait for either COMPLETED file or stream_logs to exit
while [ ! -f "COMPLETED" ]; do
    # Check if the stream_logs process is still running
    if ! ps -p $stream_pid > /dev/null; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Stream logs process (PID: $stream_pid) has exited"
        break
    fi
    sleep 10
done