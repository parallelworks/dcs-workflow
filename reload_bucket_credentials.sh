#!/bin/bash
source resources/001_simulation_executor/inputs.sh
set -x
while true; do
    sleep 36000
    date
    pw buckets get-token pw://${dcs_bucket_id} > bucket_credentials
    source bucket_credentials
    # Check if BUCKET_NAME is empty
    if ! [ -n "${BUCKET_URI}" ]; then
        echo "ERROR: Unable to load bucket credentials!"
        exit 1
    fi
    scp bucket_credentials ${resource_publicIp}:${resource_jobdir}/bucket_credentials
done