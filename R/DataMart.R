#' Check if a file exists
#' 
#' Check whether a file of a given name exists in the Data Mart.
#' 
#' @param filename character string. Name of the file to search for
#' 
#' @return TRUE if the file exists, otherwise FALSE
#' 
#' @importFrom httr HEAD add_headers
#' @importFrom utils URLencode
#' 
#' @export
QFileExists <- function(filename) 
{
    companySecret <- get0("companySecret", ifnotfound = "")
    clientId <- gsub("[^0-9]", "", get0("clientId", ifnotfound = ""))
    res <- try(HEAD(paste0("https://app.displayr.com/api/DataMart?filename=", URLencode(filename, TRUE)), 
                    config=add_headers("X-Q-Company-Secret" = companySecret,
                                       "X-Q-Project-ID" = clientId)))
    
    if (is.null(res$status_code) || res$status_code != 200)
    {
        warning("File not found.")
        return (FALSE)
    } else 
    {
        message("File was found.")
        return (TRUE)
    }
}

#' Opens a Connection
#' 
#' Opens a connection for either reading OR writing to a file of a given name.
#' In the reading case, it opens a stream to the file in the Data Mart. 
#' In the writing case, it opens a temporary file for writing to and uploads this to the Data Mart on close.
#' Note that writing to a file which already exists will overwrite that file's contents.
#' 
#' @param filename character string. Name of file to be opened
#' @param open character string. A description of how to open the connection
#' @param blocking logical. Whether or not the connection blocks can be specified
#' @param encoding character string. The name of the encoding to be assumed.
#' @param raw logical. Whether this connection should be treated as a byte stream
#' @param method character string. See documentation for connections
#' 
#' @return A curl connection (read) or a file connection (write)
#' 
#' @importFrom curl curl new_handle handle_setheaders
#' @importFrom httr POST upload_file add_headers handle
#' @importFrom tools file_ext
#' @importFrom utils URLencode
#' 
#' @export
QFileOpen <- function(filename, open = "r", blocking = TRUE, 
                      encoding = getOption("encoding"), raw = FALSE, 
                      method = getOption("url.method", "default"))
{
    mode <- tolower(open)
    if (mode == "r" || mode == "rb") 
    {
        companySecret <- get0("companySecret", ifnotfound = "")
        clientId <- gsub("[^0-9]", "", get0("clientId", ifnotfound = ""))
        h <- new_handle()
        handle_setheaders(h,
            "X-Q-Company-Secret" = companySecret,
            "X-Q-Project-ID" = clientId
        )
        conn <- try(curl(paste0("https://app.displayr.com/api/DataMart?filename=", URLencode(filename, TRUE)),
                        open = mode,
                        handle = h), 
                    silent = TRUE)
        
        if (!inherits(conn,"connection"))
            stop("File not found.")

        
        # to allow functions to parse this 'like' a url connection
        # e.g. so readRDS will wrap this in gzcon when reading
        class(conn) <- append(class(conn), "url")
        return (conn)
    } else if (mode == "w" || mode == "wb") 
    {
        if (!exists("companySecret") || identical(companySecret, NULL))
            stop("Could not connect to Data Mart.")
        
        tmpfile <- paste0(tempfile(), ".", file_ext(filename))
        conn <- file(tmpfile, mode, blocking, encoding, raw, method)
        class(conn) = append("qpostcon", class(conn))
        
        # store attributes for later access
        attr(conn, "tmpfile") <- tmpfile
        attr(conn, "filename") <- filename

        return (conn)
    } else 
    {
        stop("Invalid mode - please use either 'r', 'rb','w' or 'wb'.")
    }
}

#' Closes a QFileOpen connection
#' 
#' This is an overload for close.connection which writes the file contents 
#' of a connection opened using QFileOpen to the Data Mart.
#' 
#' @param con connection object of class 'qpostconn'. Connection opened with QFileOpen
#' @param ... arguments passed to or from other methods.
#' 
#' @importFrom httr POST add_headers upload_file
#' @importFrom mime guess_type
#' @importFrom utils URLencode
#' 
#' @return NULL invisibly. Called for the purpose of uploading data
#' and assumed to succeed if no errors are thrown.
#' 
#' @export
close.qpostcon = function(con, ...) 
{
    close.connection(con, ...)
    filename <- attr(con, "filename")
    tmpfile <- attr(con, "tmpfile")
    on.exit(if(file.exists(tmpfile)) file.remove(tmpfile))

    companySecret <- get0("companySecret", ifnotfound = "")
    clientId <- gsub("[^0-9]", "", get0("clientId", ifnotfound = ""))
    res <- try(POST(paste0("https://app.displayr.com/api/DataMart?filename=", URLencode(filename, TRUE)),
                config = add_headers("Content-Type" = guess_type(filename),
                                     "X-Q-Company-Secret" = companySecret,
                                     "X-Q-Project-ID" = clientId),
                encode = "raw",
                body = upload_file(tmpfile)))
    
    if (inherits(res, "try-error") || res$status_code != 200)
    {
        msg <- "Could not write to data mart." 
        if (inherits(res, "response"))
            msg <- paste0(msg, " Http status: ", res$status_code)
        stop(msg)
    }
    else 
    {
        message("File was written successfully.")
    }
    
    invisible()
}

#' Loads an object
#' 
#' Loads an *.rds file from the data mart and converts this to an R object.
#' 
#' @param filename character string. Name of the file to be opened from the Data Mart
#' 
#' @return An R object
#' 
#' @importFrom httr GET add_headers write_disk
#' @importFrom tools file_ext
#' @importFrom utils URLencode
#' 
#' @export
QLoadData <- function(filename) 
{
    if (file_ext(filename) != "rds") 
        stop("Can only load data from *.rds objects.")
    
    tmpfile <- tempfile()
    companySecret <- get0("companySecret", ifnotfound = "")
    clientId <- gsub("[^0-9]", "", get0("clientId", ifnotfound = ""))
    req <- try(GET(paste0("https://app.displayr.com/api/DataMart?filename=", URLencode(filename, TRUE)),
               config=add_headers("X-Q-Company-Secret" = companySecret,
                                  "X-Q-Project-ID" = clientId),
               write_disk(tmpfile, overwrite = TRUE)))
    
    if (inherits(req, "try-error") || req$status_code != 200)
        stop("File not found.")

    if (file.exists(tmpfile)) 
    {
        obj <- readRDS(tmpfile) 
        file.remove(tmpfile)
        return (obj)
    }
    stop("Could not read from file.")
}

#' Save an object
#' 
#' Saves an object to the Data Mart as an *.rds file of the given name.
#' If the name is given an extension, this must be '.rds'. If there is no
#' extension specified, this defaults to '.rds'.
#' 
#' @param object object. The object to be uploaded
#' @param filename character string. Name of the file to be written to
#' 
#' @importFrom httr POST add_headers upload_file
#' @importFrom tools file_ext
#' @importFrom utils URLencode
#' 
#' @return NULL invisibly. Called for the purpose of uploading data
#' and assumed to succeed if no errors are thrown.
#' 
#' @export 
QSaveData <- function(object, filename)
{
    if (file_ext(filename) == "") 
        filename <- append(filename, ".rds")
    
    if (file_ext(filename) != "rds")
        stop("File must be of type *.rds")
    
    tmpfile <- tempfile()
    saveRDS(object, tmpfile)
    on.exit(if(file.exists(tmpfile)) file.remove(tmpfile))
    
    companySecret <- get0("companySecret", ifnotfound = "")
    clientId <- gsub("[^0-9]", "", get0("clientId", ifnotfound = ""))
    res <- try(POST(paste0("https://app.displayr.com/api/DataMart?filename=", URLencode(filename, TRUE)), 
                config = add_headers("Content-Type" = "application/x-gzip", # default is gzip for saveRDS
                                     "X-Q-Company-Secret" = companySecret,
                                     "X-Q-Project-ID" = clientId),
                encode = "raw",
                body = upload_file(tmpfile)))
    
    if (inherits(res, "try-error") || res$status_code != 200)
    {
        msg <- "Could not write to data mart." 
        if (inherits(res, "response"))
            msg <- paste0(msg, " Http status: ", res$status_code)
        stop(msg)
    }
    
    msg <- paste("Object uploaded to Data Mart To re-import object use:",
                  "   > library(flipAPI)",
           paste0("   > QLoadData('", filename, "')"),
           sep = "\n")
    message(msg)
    invisible()
}
