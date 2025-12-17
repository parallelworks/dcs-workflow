#!/bin/bash
set -x
cd $(dirname $0)

echo $START_DATE
echo $END_DATE

python3 create_csv.py
python3 consolidate_csv.py

if [[ -n "$START_DATE" && "$START_DATE" != "undefined" ]]; then
    start_date_args="--start_date ${START_DATE}"
fi

if [[ -n "$END_DATE" && "$END_DATE" != "undefined" ]]; then
    end_date_args="--end_date ${END_DATE}"
fi

python3 plot_usage.py ${start_date_args} ${end_date_args}
