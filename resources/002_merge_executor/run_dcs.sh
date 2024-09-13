# run in bat file to get correct exit code from the software
#echo set DCS2FLMD_LICENSE_FILE="$DCS2FLMD_LICENSE_FILE" > run.bat


# Create metering script
cat >> metering.sh <<HERE
#!/bin/bash
while true; do
    date >> ${resource_jobdir}/usage/$(hostname)-${job_number}-merge
    sleep \$((RANDOM % 30 + 30))
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

