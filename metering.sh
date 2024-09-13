#!/bin/bash
while true; do
    sleep 60
    ssh -A -o StrictHostKeyChecking=no ${resource_publicIp} rsync -avz ${resource_jobdir}/usage/ ${metering_user}@${metering_ip}:~/.3dcs/usage-pending
done