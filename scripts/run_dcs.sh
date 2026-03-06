# run in bat file to get correct exit code from the software
#echo set DCS2FLMD_LICENSE_FILE="$DCS2FLMD_LICENSE_FILE" > run.bat

# Create metering script
cat >> metering.sh <<HERE
#!/bin/bash 
while true; do
    date >> ${PW_PARENT_JOB_DIR}/usage/$(hostname)-${PW_JOB_NUMBER}
    sleep \$((RANDOM % 30 + 30))
done
HERE

chmod +x metering.sh
./metering.sh &
metering_pid=$!
echo "kill ${metering_pid} || true # Metering" >> cancel.sh

# Run 3dcs
SECONDS=0
eval "${dcs_run}"  macroScript.txt
kill ${metering_pid}
mv ${PW_PARENT_JOB_DIR}/usage/$(hostname)-${PW_JOB_NUMBER} ${PW_PARENT_JOB_DIR}/usage_completed/$(hostname)-${PW_JOB_NUMBER}

# Results is own by root
sudo chmod 777 Results/ -R
echo ${SECONDS} > Results/dcs-runtime-${case_index}.txt

