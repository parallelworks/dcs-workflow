# run in bat file to get correct exit code from the software
#echo set DCS2FLMD_LICENSE_FILE="$DCS2FLMD_LICENSE_FILE" > run.bat


# Create metering script
cat >> metering.sh <<HERE
#!/bin/bash
fail_count=0
while true; do
    ssh -J ${resource_privateIp} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null ${metering_user}@${metering_ip} "date >> /home/${metering_user}/.3dcs/usage-pending/$(hostname)-${job_number}-merge"
    if [ \$? -ne 0 ]; then
        fail_count=\$((fail_count+1))
        echo "Unable to report usage to ${metering_user}@${metering_ip}."
    else
        fail_count=0
    fi

    if [ \$fail_count -gt 3 ]; then
        echo "Unable to report usage to ${metering_user}@${metering_ip}. Killing Slurm job."
        scancel ${SLURM_JOB_ID}
        exit 1
    fi

    sleep \$((RANDOM % 121 + 60))
done
HERE

chmod +x metering.sh
./metering.sh &
metering_pid=$!

# Run 3dcs
SECONDS=0
eval "${dcs_run}"  macroScript.txt
kill ${metering_pid}

# Results is own by root
sudo chmod 777 Results/ -R
echo ${SECONDS} > Results/dcs-runtime_merge.txt

