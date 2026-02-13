# HARDCODED TO AWS
# A dynamicStorage parameter type would be very helpful for this

aws s3 cp ${resource_label}/merge.sh ${BUCKET_URI}/${dcs_output_directory}/${USER}/${workflow_name}/${job_number}/merge.sh
aws s3 cp --recursive Results ${BUCKET_URI}/${dcs_output_directory}/${USER}/${workflow_name}/${job_number}/Results
aws s3 cp --recursive TempData ${BUCKET_URI}/${dcs_output_directory}/${USER}/${workflow_name}/${job_number}/TempData
