                                        # See
                                        # https://docs.google.com/document/d/1VzQHfzfA-S_lO2wpXDFjDzSJntJCMwP03TzefIj7RrE/edit#
                                        #

source("~/prefix.R")
library(data.table)
source("~/fhr-r-rollups/lib/search.R"         ,keep.source=FALSE)
source("~/fhr-r-rollups/lib/profileinfo.R"     ,keep.source=FALSE)
source("~/fhr-r-rollups/lib/activity.R"        ,keep.source=FALSE)
source("~/fhr-r-rollups/lib/sguha.functions.R" ,keep.source=FALSE)

isn <- function(x,r=NA) if(is.null(x) || length(x)==0 )  r else x
replaceNA <- function(k,r) if(is.na(k)) r else k


#' @return "out" if this datum should be V4 profile and "in" otherwise
isThisProfileForFHRV4 <- function(version, channel, build, istelemenabled,clientId){
                                        # see https://bugzilla.mozilla.org/show_bug.cgi?id=1175583#c7
    out <- "out"; notout <- "in"
    if(grepl("esr",channel) && version>=45)
        return(out)
    if(grepl("release",channel)){
        if(version>41) return(out)
        m <- as.numeric(sprintf("0x%s",digest(clientId,algo='crc32',serialize=FALSE))) %% 100
        if(version==41 && m >=42 && m < 47) return(out)
        if(version==40 && istelemenabled) return(out)
    }
    if(grepl('beta',channel) && version>=40)
        return(out)
    if(grepl('aurora',channel) && version>=40 && build >= "20150620")
        return(out)
    if(grepl('nightly',channel) && version>=41 && build >= "20150612")
        return(out)
    if(grepl('default',channel) && version>=41)
        return(out)
    if(version>41)
        return(out)
    return(notout)
}

getVersion <- function(v){
    p <- as.numeric(gregexpr("\\.", v)[[1]])
    suppressWarnings(f <- if(p>0) as.integer(substr(v,1,p-1)) else as.integer(v))
    if(is.na(f)) -1 else f
}

imputeVersionAndBuildHistory <- function(b){
    currentVersion <- isn(substr(b$geckoAppInfo$platformVersion,1,2),"missing")
    currentBuild <- isn(substr(b$geckoAppInfo$platformBuildID,1,8),"missing")
    days <- b$data$days[order(names(b$data$days))]
    nl <- structure(vector(mode='list', length=length(days)),names=names(days))
    for(l in rev(seq_along(days))){
        ## go backwards in time
        aday <- days[[l]]
        if(!is.null(aday$org.mozilla.appInfo.versions$platformBuildID))
            currentBuild <- isn(substr(aday$org.mozilla.appInfo.versions$platformBuildID,1,8),"missing")
        if(!is.null(aday$org.mozilla.appInfo.versions$platformVersion))
            currentVersion <- isn(getVersion(aday$org.mozilla.appInfo.versions$platformVersion),"missing")
        nl[[l]] <- list(b = currentBuild, v = currentVersion)
    }
    nl
}


trans <- function(a,b){
    base <- list(
        clientid        = if(is.null(b$clientID)) UUIDgenerate() else b$clientID
       ,documentId      = a
       ,country         = isn(b$geo,"missing")
       ,channel         = isn(b$geckoAppInfo$updateChannel,"missing")
       ,os              = isn(b$geckoAppInfo$os,"missing")
       ,profileCreation = isn(b$data$last$"org.mozilla.profile.age"$profileCreation,"missing"))

    days        <- b$data$days[order(names(b$data$days))]
    versionAndBuildHistory <- imputeVersionAndBuildHistory(b)

                                        # For Search Count
                                        # Function from: https://github.com/mozilla/fhr-r-rollups/blob/0990e71b28c190e486c8166220b20aefcb2451a1/lib/profileinfo.R#L135
    distrib <- get.distribution.type(b)
                                        # From https://github.com/mozilla/fhr-r-rollups/blob/57a8e2397359bbb5b642f66cc5fafb4d4ed58a07/lib/search.R#L231
    ds <- dailySearchCounts(days,
                            provider   = list(
                                google = google.searchnames(distrib)
                              , yahoo  = yahoo.searchnames(distrib)
                              , bing   = bing.searchnames(distrib)
                              , other  = NA)
                          , sap        = FALSE)

    Map(function(thedate,theday, vb){
        m <- list()
        m$inOrOut <- isThisProfileForFHRV4(version=vb$v
                                          ,channel=base$channel
                                          ,build=vb$b
                                          ,istelemenabled=isn(theday$"org.mozilla.appInfo.appinfo"$isTelemetryEnabled,FALSE)
                                        # we do not want the generated clientID because they shouldn't be here
                                          ,clientId=isn(b$clientid,"missing")
                                           )

                                        # Taken from
                                        # https://github.com/mozilla/fhr-r-rollups/blob/0990e71b28c190e486c8166220b20aefcb2451a1/lib/activity.R#L134
        m$usageHours <- totalActivity(list(theday))$activesec/3600

                                        # Searches
        m$googleSearches <- replaceNA(as.numeric(isn(ds[[ thedate ]]['google'],0)),0)
        m$bingSearches   <- replaceNA(as.numeric(isn(ds[[ thedate ]]['bing'],0)),0)
        m$yahooSearches  <- replaceNA(as.numeric(isn(ds[[ thedate ]]['yahoo'],0)),0)
        m$otherSearches  <- replaceNA(as.numeric(isn(ds[[ thedate ]]['other'],0)),0)

                                        # If missing, then the value is -1
        m$isDefaultBrowser <- isn(theday$org.mozilla.appInfo.appinfo$isDefaultBrowser,-1)

        m$buildId <- tail(vb$b,1)
        m$fxversion <- tail(vb$v,1)

                                        # Taken from
                                        # https://hg.mozilla.org/mozilla-central/file/tip/services/healthreport/docs/dataformat.rst#l1076
                                        # if missing (and it will be for old FHR versions) replace with 0
        m$numCrashes <- isn(theday$org.mozilla.crashes.crashes$"main-crash",0)

                                        # Taken from
                                        # https://hg.mozilla.org/mozilla-central/file/tip/services/healthreport/docs/dataformat.rst#l1076
                                        # if missing (and it will be for old FHR versions) replace with 0
        m$numPluginHangs <- isn(theday$org.mozilla.crashes.crashes$"plugin-hang",0)

        m$activityDate <- thedate

        rhcollect(a, append(base, m))
    }, names(days), days, versionAndBuildHistory)

}



I <- local({
    tail(data.table(rhls("/user/bcolloran/deorphaned/"))[order(modtime),]$file,1)
})
O <- local({
    f <- tail(strsplit(I,"/",perl=TRUE)[[1]],1)
    rhmkdir(sprintf("/user/sguha/fhr/samples/exec/exec-%s",f))
    list(r = sprintf("/user/sguha/fhr/samples/exec/exec-%s/r",f),
         t = sprintf("/user/sguha/fhr/samples/exec/exec-%s/t",f))
})

res <- rhwatch(map    = function(a,b) trans(a, fromJSON(b))
             , reduce = 400
             , input  = sqtxt(sprintf("%s/v2",I))
             , output = O$r
             , debug  = 'collect'
             , read   = FALSE
             , param  = list(isn=isn, replaceNA=replaceNA,getVersion=getVersion
                            ,isThisProfileForFHRV4=isThisProfileForFHRV4,trans=trans
                            ,imputeVersionAndBuildHistory=imputeVersionAndBuildHistory
                            ,totalActivity=totalActivity,dailySearchCounts=dailySearchCounts
                            ,get.distribution.type=get.distribution.type)
             , setup  = expression({
                 library(rjson)
                 library(uuid)
                 library(digest)
             })
             )

toText <- function (i, o)
{
    y <- rhwatch(map = function(a, b) {
        rhcollect(NULL, b)
    }
  , reduce = 0
  , input = i
  , output = rhfmt(type = "text", folder = o,
                   writeKey = FALSE, field.sep = "\t", stringquote = "")
  , read = FALSE)
    a <- rhls(o)$file
    rhdel(a[!grepl("part-", a)])
    rhchmod(o, "777")
    o
}

toText(O$r,O$t)
