source("~/prefix.R")

prefix <- "/user/sguha/fhr/samples/output/"
xt <- tempfile()

writeLines(c("LOCK"), "/tmp/lock")
system(sprintf("aws s3 cp /tmp/lock  s3://mozillametricsfhrsamples/lock"))

for(x in c("1pct","5pct","10pct","nightly","aurora","beta")){
    hdfs.setwd(sprintf("%s%s",prefix,x))
    z <- rhls(".")$file
    system(sprintf("aws s3 rm --recursive s3://mozillametricsfhrsamples/%s/",x))
    for(af in z){
        rhget(af,xt)
        system(sprintf("aws s3 cp %s s3://mozillametricsfhrsamples/%s/%s",xt,x,basename(af)))
    }
    cat(sprintf("Done with %s",x))
}

rhget("/user/sguha/fhr/samples/output/createdTime.txt","/tmp/")
system(sprintf("aws s3 cp /tmp/createdTime.txt s3://mozillametricsfhrsamples/"))
system(sprintf("aws s3 rm   s3://mozillametricsfhrsamples/lock"))




source("~/prefix.R")

prefix <- "/user/sguha/fhr/samples/exec/exec-2015-10-12/"
xt <- tempfile()


x="t"
Sys.setenv(HADOOP_HOME="")
hdfs.setwd(sprintf("%s%s",prefix,x))
z <- rhls(".")$file
system(sprintf("aws s3 rm --recursive s3://mozillametricsfhrsamples/execComp/"))
for(af in z){
        system(sprintf("hadoop dfs -text %s > /tmp/temp",af))
        system(sprintf("aws s3 cp %s s3://mozillametricsfhrsamples/execComp/%s","/tmp/temp",gsub(".deflate",".txt",basename(af))))
}
