SPLIT=/mnt/work/bug1175583/hindsight/split
for i in $(seq 0 999); do
  f=$(printf "part-m-%05d.deflate" $i)
  echo "Processing $f"
  aws s3 cp s3://mozillametricsfhrsamples/tmp/exec-2015-10-26/$f ./
  time printf "\x1f\x8b\x08\x00\x00\x00\x00\x00" | cat - $f | gzip -dc | hindsight/hindsight_cli hindsight/hindsight_split.cfg 7
  rm -v $f
  rm -rvf hindsight/output
  size=$(du -s --bytes $SPLIT/ | awk '{print $1}')
  if [ "20000000000" -lt "$size" ]; then
    echo "Compressing data after accumulating $size bytes..."
    for tbc in $(find $SPLIT/ -name "fhr_exec.*.log"); do
      mv -v $tbc $tbc.$i
      gzip $tbc.$i
    done
    aws s3 sync $SPLIT/ s3://net-mozaws-prod-us-west-2-pipeline-analysis/mreid/bug1175583/
    rm -v $SPLIT/*
  fi
done
