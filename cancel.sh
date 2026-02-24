#!/bin/bash
if [[ -f SUBMITTED && ! -f COMPLETED ]]; then
    source ./workflow-utils/workflow-libs.sh
    cancel_jobs_by_name
done