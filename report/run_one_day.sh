#!/bin/bash

## install dependencies
sudo apt-get install --yes python-snappy
if [ ! -f "/mnt/work/heka/share/heka/lua_modules/snappy.so" ]; then
    cp util/snappy.so /mnt/work/heka/share/heka/lua_modules/
fi

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
FHR_INPUT=input_$DAY_NODASH.tsv
for f in $(find $FHR_DEST/ -name "*.snap"); do
  python -m snappy -d $f >> $FHR_INPUT
  rm -v $f
done

split -d -n l/10 $FHR_INPUT

echo "Cleaning up input for $DAY_NODASH"
rm -v $FHR_INPUT

time ./hindsight_cli ./hindsight_convert.cfg 7

cp output/hindsight.cp ./hindsight_fhr_${DAY_NODASH}.cp
cp output/hindsight.tsv ./hindsight_fhr_${DAY_NODASH}.tsv
rm -rfv output/

echo "Cleaning up split input for $DAY_NODASH"
rm -v x0[0-9]

## Symlink the .data files so both operate on the same state.
if [ ! -h "run_exec/analysis/firefox_executive_daily.data" ]; then
  echo "creating symlinks"
  ln -vs $(pwd)/run_convert/analysis/firefox_executive_daily.data $(pwd)/run_exec/analysis/firefox_executive_daily.data
  ln -vs $(pwd)/run_convert/analysis/firefox_executive_weekly.data $(pwd)/run_exec/analysis/firefox_executive_weekly.data
  ln -vs $(pwd)/run_convert/analysis/firefox_executive_monthly.data $(pwd)/run_exec/analysis/firefox_executive_monthly.data
fi

## Decide if we're runnning v2 or v3
if [ -z "$UT_VERSION" ]; then
    if [ "$DAY_NODASH" -lt "20151028" ]; then
        UT_VERSION=2
    else
        UT_VERSION=3
    fi
    echo "UT_VERSION was unset, guessing '$UT_VERSION' based on date."
else
    echo "Using UT_VERSION=${UT_VERSION} as specified"
fi

UT_SOURCE=net-mozaws-prod-us-west-2-pipeline-data
UT_EXEC_PREFIX="telemetry-executive-summary-${UT_VERSION}"

## Add in the Unified Telemetry data too.
sed -r "s/__TARGET__/$DAY_NODASH/" schema_template.${UT_VERSION}.json > schema.json

export PATH=$PATH:/mnt/work/heka/bin
S3LIST=ut_files${DAY_NODASH}.txt
heka-s3list -bucket $UT_SOURCE -bucket-prefix "$UT_EXEC_PREFIX" -schema schema.json > $S3LIST
time heka-s3cat -bucket $UT_SOURCE -format heka -stdin < $S3LIST | ./hindsight_cli ./hindsight_exec.cfg 7

## Back up analysis state
## Back up current csv

cp output/hindsight.cp ./hindsight_ut_${DAY_NODASH}.cp
cp output/hindsight.tsv ./hindsight_ut_${DAY_NODASH}.tsv
## Clean up output files
rm -rfv output/

#for n in $(seq 102 -1 15); do
#    T=$(date -d "$n days ago" +%Y%m%d)
#    echo "Processing $T"
#    time bash run_one_day.sh $T 2>&1 | tee run_${T}.log
#done
