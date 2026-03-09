
pw buckets cp merge.sh ${dcs_bucket_uri}/${dcs_output_directory}/${USER}/${PW_WORKFLOW_NAME}/${PW_JOB_NUMBER}/merge.sh > bucket_upload.log 2>&1
echo >> bucket_upload.log 
pw buckets cp -r Results ${dcs_bucket_uri}/${dcs_output_directory}/${USER}/${PW_WORKFLOW_NAME}/${PW_JOB_NUMBER}/Results >> bucket_upload.log 2>&1
echo >> bucket_upload.log
pw buckets cp -r TempData ${dcs_bucket_uri}/${dcs_output_directory}/${USER}/${PW_WORKFLOW_NAME}/${PW_JOB_NUMBER}/TempData >> bucket_upload.log 2>&1

