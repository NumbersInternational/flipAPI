companySecret <- get0("companySecret", ifnotfound = Sys.getenv("companySecret"))
assign("companySecret", companySecret, envir = .GlobalEnv)
clientId <- "123456" # This could be anything - we are just using this for metadata
assign("clientId", clientId, envir = .GlobalEnv)
region <- "master"
assign("region", region, envir = .GlobalEnv)
