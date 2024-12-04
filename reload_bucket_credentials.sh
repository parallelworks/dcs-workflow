#!/bin/bash
source resources/001_simulation_executor/inputs.sh
set -x
while true; do
    sleep 36000
    date
    ${pw_job_dir}/workflow-utils/bucket_token_generator.py --bucket_id ${dcs_bucket_id} --token_format text > bucket_credentials
    source bucket_credentials
    # Check if BUCKET_NAME is empty
    if ! [ -n "${BUCKET_NAME}" ]; then
        echo "ERROR: Unable to load bucket credentials!"
        exit 1
    fi
    scp bucket_credentials ${resource_publicIp}:${resource_jobdir}/bucket_credentials
done