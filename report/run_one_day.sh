#!/bin/bash

## install dependencies
sudo apt-get install --yes python-snappy

## Fetch v2 data for this day
DAY_IN=$1
if [ -z "$DAY_IN" ]; then
    DAY_IN=$(date -d '1 day ago' +%Y%m%d)
fi

DAY_DASH=$(date -d "$DAY_IN" +%Y-%m-%d)
DAY_NODASH=$(date -d "$DAY_IN" +%Y%m%d)

## TODO: Fetch previous saved state?
## To clear out saved state:
## find run_convert/ -name "*.data" -exec rm -v {} \;
echo "Fetching FHR data for $DAY_DASH..."
FHR_SOURCE=s3://net-mozaws-prod-us-west-2-pipeline-analysis/mreid/bug1175583/fast_split
FHR_DEST=fhr_$DAY_NODASH

mkdir -p $FHR_DEST
aws s3 sync "$FHR_SOURCE/" $FHR_DEST/ --exclude "*" --include "${DAY_DASH}.*.snap"

## Run each data file through the exec report
for f in $(find $FHR_DEST/ -name "*.snap"); do
  python -m snappy -d $f | ./hindsight_cli ./hindsight_convert.cfg 7
  echo "TODO: rm -v $f"
done

#echo "TODO: run on UT data for $DAY_NODASH"
#exit 0
# TODO: symlink the .data files so both operate on the same state.
# ln -s run_exec/analysis/firefox_executive_daily.data run_convert/analysis/firefox_executive_daily.data
# ln -s run_exec/analysis/firefox_executive_weekly.data run_convert/analysis/firefox_executive_weekly.data
# ln -s run_exec/analysis/firefox_executive_monthly.data run_convert/analysis/firefox_executive_monthly.data
#echo "copying state from FHR run"
#cp -v run_convert/analysis/*.data run_exec/analysis/

UT_SOURCE=net-mozaws-prod-us-west-2-pipeline-data
## FIXME: use -3 for recent data
UT_EXEC_PREFIX="telemetry-executive-summary-2"
#UT_EXEC_PREFIX="telemetry-executive-summary-3"
## Add in the Unified Telemetry data too.
sed -r "s/__TARGET__/$DAY_NODASH/" schema_template.2.json > schema.json
#sed -r "s/__TARGET__/$DAY_NODASH/" schema_template.3.json > schema.json

export PATH=$PATH:/mnt/work/heka/bin
S3LIST=ut_files${DAY_NODASH}.txt
heka-s3list -bucket $UT_SOURCE -bucket-prefix "$UT_EXEC_PREFIX" -schema schema.json > $S3LIST
heka-s3cat -bucket $UT_SOURCE -format heka -stdin < $S3LIST | ./hindsight_cli ./hindsight_exec.cfg 7

## Back up analysis state
## Back up current csv

#for n in $(seq 102 -1 15); do
#    T=$(date -d "$n days ago" +%Y%m%d)
#    echo "Processing $T"
#    time bash run_one_day.sh $T 2>&1 | tee run_${T}.log
#done
