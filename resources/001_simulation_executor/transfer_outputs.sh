# HARDCODED TO AWS
# A dynamicStorage parameter type would be very helpful for this

# Copy path/to/worker_<i> to bucket
aws s3 cp --recursive ${PWD} s3://$BUCKET_NAME/${dcs_output_directory}/${USER}/${workflow_name}/${job_number}/$(basename ${PWD})
