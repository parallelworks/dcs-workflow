source ${monitoring_conda_dir}/etc/profile.d/conda.sh 
conda activate ${monitoring_conda_env}
monitoring_txt="case-${case_index}-${HOSTNAME}-jobid-${SLURM_JOB_ID}.txt"
python ${PW_PARENT_JOB_DIR}/scripts/cpu_and_memory_usage.py --write-usage --txt ${monitoring_txt} &
monitoring_pid=$!
echo "kill ${monitoring_pid} || true # kill monitoring" >> cancel.sh
