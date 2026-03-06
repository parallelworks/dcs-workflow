
# Copy path/to/worker_<i> to bucket
set -x
pw buckets cp -r ${PWD} ${dcs_bucket_uri}/${dcs_output_directory}/${USER}/${PW_WORKFLOW_NAME}/${PW_JOB_NUMBER}/$(basename ${PWD}) > bucket_upload.log 2>&1


