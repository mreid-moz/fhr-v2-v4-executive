                                        # See
                                        # https://docs.google.com/document/d/1VzQHfzfA-S_lO2wpXDFjDzSJntJCMwP03TzefIj7RrE/edit#
                                        #


library(data.table)
source("~/fhr-r-rollups/lib/search.R"         ,keep.source=FALSE)
source("~/fhr-r-rollups/lib/profileinfo.R"     ,keep.source=FALSE)
source("~/fhr-r-rollups/lib/activity.R"        ,keep.source=FALSE)
source("~/fhr-r-rollups/lib/sguha.functions.R" ,keep.source=FALSE)

isn <- function(x,r=NA) if(is.null(x) || length(x)==0)  r else x


#' @param p is a version string
#' @return the version before the dot as an integer or -1 if cannot be done
convertToVersionNumber <- function(p){
    posOfDot <- as.numeric(gregexpr("\\.",p)[[1]])
    k <- if(posOfDot>0) as.integer(substr(p,1, posOfDot-1)) else as.integer(p)
    if(is.na(k)) -1 else k
}


#' @param b the JSON object
#' @return 1 if this profile should be V4 profile and 0 otherwise
isThisProfileForFHRV4 <- function(b){
                                        # see https://mail.mozilla.org/pipermail/fhr-dev/2015-October/000638.html
    version <- convertToVersionNumber(isn(b$geckoAppInfo$platformVersion,"-1"))
    channel <- isn(b$geckoAppInfo$updateChannel,"missing")
    build   <- substr(isn(b$geckoAppInfo$appBuildID,"00000000"),1,8)
    m <- digest(b$clientId,algo="md5")

    ## I'm not at all sure about the this first condition
    if(grepl("esr",channel) && version>=42 && grepl("release", channel) && m>=42 && m<47)
        return(1)
    ## Others seem okay
    if(grepl('beta',channel) && version>=39 && build >= "20150511")
        return(1)
    if(grepl('aurora',channel) && version>=39 && build >= "20150330")
        return(1)
    if(grepl('nightly',channel) && version>=39 && build >= "20150226")
        return(1)
    if(grepl('default',channel) && version>=39)
        return(1)
    if(version>41)
        return(1)
    return(0)
}


trans <- function(a,b){
    base <- list(
        is.for.fhrv4 =  isThisProfileForFHRV4(b)
       ,clientid     = if(is.null(b$clientID)) UUIDgenerate() else b$clientID
       ,documentId   = 'missing'
       ,country      = isn(b$geo,"missing")
       ,channel      = isn(b$geckoAppInfo$updateChannel,"missing")
       ,os           = isn(b$geckoAppInfo$os,"missing"))

    dates       <- names(b$data$days)
    days        <- b$data$days
    lastBuildID <- "missing"

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

    for(i in seq_along(days)){
        theday <- days[[i]]
        thedate <- dates[[i]]
        m <- list()

                                        # Taken from
                                        # https://github.com/mozilla/fhr-r-rollups/blob/0990e71b28c190e486c8166220b20aefcb2451a1/lib/activity.R#L134
        m$usageHours <- totalActivity(theday)$activesec/3600

                                        # Searches
        m$googleSearches <- isn(ds[[ thedate ]]$google,0)
        m$bingSearches   <- isn(ds[[ thedate ]]$bing,0)
        m$yahooSearches  <- isn(ds[[ thedate ]]$yahoo,0)
        m$otherSearches  <- isn(ds[[ thedate ]]$other,0)

                                        # If missing, then the value is -1
        m$isDefaultBrowser <- isn(theday$org.mozilla.appInfo.appinfo$isDefaultBrowser,-1)

                                        # Last Build ID (last value carried forward). Note this can be
                                        # missing for every day and so this will end up being 'missing'
                                        # If all are missing then an alternative would be to replace
                                        # it with the value from geckoAppInfo.
                                        # not doing since it hasn't been asked for
        if(!is.null(theday$org.mozilla.appInfo.versions$appBuildID))
            lastBuildID <- theday$org.mozilla.appInfo.versions$appBuildID
        m$buildId <- lastBuildID

                                        # Taken from
                                        # https://hg.mozilla.org/mozilla-central/file/tip/services/healthreport/docs/dataformat.rst#l1076
                                        # if missing (and it will be for old FHR versions) replace with 0
        m$numCrashes <- isn(theday$org.mozilla.crashes.crashes$"main-crash",0)2

                                        # Taken from
                                        # https://hg.mozilla.org/mozilla-central/file/tip/services/healthreport/docs/dataformat.rst#l1076
                                        # if missing (and it will be for old FHR versions) replace with 0
        m$numPluginHangs <- isn(theday$org.mozilla.crashes.crashes$"plugin-hang",0)

        m$activityDate <- thedate

        rhcollect(a, append(base, m))
    }
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
             , reduce = 0
             , input  = sqtxt(sprintf("%s/v2",I))
             , output = O$r
             , debug  = 'count'
             , read   = FALSE
             , param  = list(isn=isn, convertToVersionNumber=convertToVersionNumber,isThisProfileForFHRV4=isThisProfileForFHRV4,trans=trans
                            ,totalActivity=totalActivity,dailySearchCounts=dailySearchCounts,get.distribution.type=get.distribution.type)
             , setup  = expression({
                 library(rjson)
                 library(uuid)
                 library(digest)
             })
             )
