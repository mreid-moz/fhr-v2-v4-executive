if [ -z "$(which java)" ]; then
  sudo apt-get install --yes openjdk-7-jdk
fi

sudo apt-get install --yes python-snappy

javac split.java
SPLIT=split
mkdir -p $SPLIT/

if [ -z "$LO" ]; then
  LO=0
fi

if [ -z "$HI" ]; then
  HI=999
fi
for i in $(seq $LO $HI); do
  f=$(printf "part-m-%05d.deflate" $i)
  echo "Processing $f"
  time aws s3 cp s3://mozillametricsfhrsamples/tmp/exec-2015-10-26/$f ./
  time printf "\x1f\x8b\x08\x00\x00\x00\x00\x00" | cat - $f | gzip -dc | java split
  rm -v $f
  size=$(du -s --bytes $SPLIT/ | cut -f 1)
  if [ "30000000000" -lt "$size" ]; then
    echo "Compressing data after accumulating $size bytes..."
    for tbc in $(find $SPLIT/ -type f); do
      python -m snappy -c $tbc $tbc.$i.snap
      rm -v $tbc
    done
    time aws s3 sync $SPLIT/ s3://net-mozaws-prod-us-west-2-pipeline-analysis/mreid/bug1175583/fast_split/
    rm -v $SPLIT/*
  fi
done

# upload the last ones.
for tbc in $(find $SPLIT/ -type f); do
  python -m snappy -c $tbc $tbc.$HI.snap
  rm -v $tbc
done
time aws s3 sync $SPLIT/ s3://net-mozaws-prod-us-west-2-pipeline-analysis/mreid/bug1175583/fast_split/
rm -v $SPLIT/*
