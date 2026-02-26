# HARDCODED TO AWS
# A dynamicStorage parameter type would be very helpful for this
unset BUCKET_URI
unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN

resource_jobdir=/home/Hanif/pw/jobs/marketplace.3dcshondajapan.latest/00041
source ${resource_jobdir}/bucket_credentials

# Loop until all variables are non-empty
while [[ -z "$BUCKET_URI" \
     || -z "$AWS_ACCESS_KEY_ID" \
     || -z "$AWS_SECRET_ACCESS_KEY" \
     || -z "$AWS_SESSION_TOKEN" ]]
do
    echo "$(date) Waiting for required environment variables to be set..."
    sleep 5
    source ${resource_jobdir}/bucket_credentials
done

# Copy path/to/worker_<i> to bucket
aws s3 cp --recursive ${PWD} ${BUCKET_URI}/${dcs_output_directory}/${USER}/${workflow_name}/${job_number}/$(basename ${PWD})
