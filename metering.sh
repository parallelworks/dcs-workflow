#!/bin/bash
mkdir -p usage
while true; do
    sleep 60
    rsync -avz --delete ${resource_publicIp}:${resource_jobdir}/usage/ usage >> metering.out 2>&1
    rsync -avz ${resource_jobdir}/usage/ ${metering_user}@${metering_ip}:~/.3dcs/usage-pending >> metering.out 2>&1
done