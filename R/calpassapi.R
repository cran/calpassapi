## library(devtools)
## library(roxygen2)
## setwd('calpassapi')
## document()
## devtools::build()
## setwd('..')
## install('calpassapi')

# Notes: on httr # https://earlconf.com/2017/downloads/sanfrancisco/presentations/earl2017_-_api_interface_with_r_-_jeremy_morris.pdf

##' Create interSegmentKey's from students' first names, last names, genders, and birthdates
##'
##' @title Create interSegmentKey's for students
##' @param first_name a character vector of students' first names.
##' @param last_name a character vector of students' last names.
##' @param gender a character vector of students' genders.  The first character will be used (uppercase'd automatically), and should take on values \code{'M'}, \code{'F'}, or \code{'X'} (use \code{'X'} for unknown or did not disclosed).
##' @param birthdate a character or numeric vector of birthdates of the form \code{'yyyymmdd'}.
##' @return a vector of interSegmentKey's
##' @examples
##' ## single
##' calpass_create_isk(first_name='Jane', last_name='Doe'
##'  , gender='F', birthdate=20001231)
##' ## data frame
##' \dontrun{
##' firstname <- c('Tom', 'Jane', 'Jo')
##' lastname <- c('Ng', 'Doe', 'Smith')
##' gender <- c('Male', 'Female', 'X')
##' birthdate <- c(2001231, 19990101, 19981111)
##' df <- data.frame(firstname, lastname
##'   , gender, birthdate, stringsAsFactors=FALSE)
##' library(dplyr)
##' df %>%
##'   mutate(isk=calpass_create_isk(first_name=firstname
##'     , last_name=lastname
##'     , gender=gender
##'     , birthdate
##'   ))
##' }
##' @author Vinh Nguyen
##' @export
##' @importFrom digest digest
##' @importFrom stringr str_pad
calpass_create_isk <- function(first_name, last_name, gender, birthdate) {
  # Check data
  stopifnot(is.character(first_name)
          , is.character(last_name)
          , is.character(gender)
          , length(first_name)==length(last_name)
          , length(first_name)==length(gender)
          , length(first_name)==length(birthdate)
          , all(toupper(substring(gender, 1, 1)) %in% c('M', 'F', 'X', NA))
          , all(nchar(birthdate) == 8 | is.na(birthdate))
            )
  if (any(is.na(first_name))) warning("first_name contains NA.")
  if (any(is.na(last_name))) warning("last_name contains NA.")
  if (any(is.na(gender))) warning("gender contains NA.")
  if (any(is.na(birthdate))) warning("birthdate contains NA.")
  
  # Construct string
  x <- paste0(toupper(str_pad(substring(ifelse(is.na(first_name), '', first_name), 1, 3), 3, 'right'))
            , toupper(str_pad(substring(ifelse(is.na(last_name), '', last_name), 1, 3), 3, 'right'))
            , toupper(str_pad(substring(ifelse(is.na(gender), 'X', gender), 1, 1), 1, 'right'))
            , str_pad(substring(birthdate, 1, 8), 8, 'right')
              )
  # Convert to UTF-16LE and convert into  a hash
  #toupper(as.character(sha512(iconv("DANLAMM19440606", to='UTF-16LE', toRaw=TRUE)[[1]]))) ## using openssl package
  #toupper(digest(iconv("DANLAMM19440606", to='UTF-16LE', toRaw=TRUE)[[1]], algo='sha512', serialize=FALSE)) # using digest package
  sapply(iconv(x, to='UTF-16LE', toRaw=TRUE), function(rawobj) toupper(digest(rawobj, algo='sha512', serialize=FALSE)))
}

##' Obtain a token from CalPASS using your API credentials, which should allow access for 60 minutes.
##'
##' @title Obtain CalPASS API token
##' @param username API username.  For security reasons, the user could specify \code{cp_api_uid} in the user's \code{.Renviron} file in the user's home directory (execute \code{Sys.getenv('HOME')} in R to check path to home directory).  That way, the user does not have to hard code the username in their R script.  The function uses for the username here by default.
##' @param password API password.  The user could specify \code{cp_api_pwd} as above.
##' @param client_id parameter needed in the http body in order to obtain a token (unique to \code{username})
##' @param scope parameter needed in the http body in order to obtain a token (unique to \code{username})
##' @param auth_endpoint Authentication endpoint/url, defaults to \code{'https://oauth.calpassplus.org/connect/token'}.
##' @param verbose If \code{TRUE}, then print http exchanges (to assist with debugging).  Defaults to \code{FALSE}.
##' @return CalPASS token string
##' @author Vinh Nguyen
##' @examples
##' \dontrun{
##' cp_token <- calpass_get_token(username='my_cp_api_uid', password='my_cp_api_pwd'
##'   , client_id='my_client_id'
##'   , scope='my_scope'
##'   )
##' }
##' @export
##' @import httr
calpass_get_token <- function(username=Sys.getenv('cp_api_uid'), password=Sys.getenv('cp_api_pwd'), client_id, scope, auth_endpoint='https://oauth.calpassplus.org/connect/token',verbose=FALSE) {
  cur_time <- Sys.time()
  cp_response <- content(POST(url=auth_endpoint
                            , content_type('application/x-www-form-urlencoded') # added to header via config= param
                            , body=list(grant_type='password', username=username, password=password, client_id=client_id, scope=scope)
                            , encode='form'
                            , if (verbose) verbose() else NULL
        ))
  # cp_token <- cp_response$access_token
  # return(cp_token)
  if (is.null(cp_response$access_token)) {
    print(cp_response)
    stop('Access token not returned.  See above printout for error message.')
  }
  cp_response$expiration_time <- Sys.time() + cp_response$expires_in
  return(cp_response)
}
##' Query data from CalPASS API endpoints for a single interSegmentKey
##'
##' @title Query data from CalPASS API endpoints
##' @param interSegmentKey for \code{calpass_query}, a single interSegmentKey; for \code{calpass_query_many}, a vector of interSgementKey's.  The interSegmentKey's can be created from \link[calpassapi]{calpass_create_isk}.
##' @param token (optional) a token object created from \link[calpassapi]{calpass_get_token}.  If this is not specified, then \code{token_username}, \code{token_password}, \code{token_client_id}, and \code{token_scope} should be specified.  The credentials approach is preferred for long runs to obtain refreshed tokens (tokens currently are valid for 1 hour).
##' @param api_url defaults to \code{'https://mmap.calpassplus.org/api'}, but can be overrode if CalPASS changes the url.
##' @param endpoint the api endpoint to use; defaults to \code{'transcript'}.
##' @param verbose If \code{TRUE}, then print http exchanges (to assist with debugging).  Defaults to \code{FALSE}.
##' @param api_call_limit the number of api calls allowed per \code{limit_per_n_sec}; defaults to 150 calls per 60 seconds.
##' @param limit_per_n_sec time frame where \code{api_call_limit} is applicable to; defaults to 60 seconds.
##' @param wait indicates whether the user is willing to wait \code{limit_per_n_sec} seconds per batch if the number of unique values in \code{interSegmentKey} is greater than \code{api_call_limit}; defaults to \code{FALSE}.  The user should set to \code{TRUE} if there are more than \code{api_call_limit} number of calls to be executed.
##' @param wait indicates whether the user is willing to wait \code{limit_per_n_sec} seconds per batch if the number of unique values in \code{interSegmentKey} is greater than \code{api_call_limit}; defaults to \code{FALSE}.  The user should set to \code{TRUE} if there are more than \code{api_call_limit} number of calls to be executed.
##' @param token_username (optional, required if \code{token} is not specified) username passed to \link[calpassapi]{calpass_get_token}.
##' @param token_password (optional, required if \code{token} is not specified) password passed to \link[calpassapi]{calpass_get_token}.
##' @param token_client_id (optional, required if \code{token} is not specified) client_id passed to \link[calpassapi]{calpass_get_token}.
##' @param token_scope (optional, required if \code{token} is not specified) scope passed to \link[calpassapi]{calpass_get_token}.
##' @return a data frame with columns \code{interSegmentKey}, \code{status_code} (the http response code: 200 means student was found, 204 means student was not found, 429 means the api limit was reached and student was not processed, and anything else in the 400's correspond to http errors.)
##' @author Vinh Nguyen
##' @references \href{https://mmap.calpassplus.org/docs/index.html}{MMAP API V1}
##' @examples
##' \dontrun{
##' ## get access token
##' cp_token <- calpass_get_token(username='my_cp_api_uid', password='my_cp_api_pwd')
##'
##' ## single run
##' isk <- calpass_create_isk(first_name='Jane', last_name='Doe'
##'   , gender='F', birthdate=20001231)
##' calpass_query(interSegmentKey=isk
##'   , token=cp_token, endpoint='transcript')
##' calpass_query(interSegmentKey=isk
##'   , token=cp_token, endpoint='placement')
##'
##' ## multiple
##' firstname <- c('Tom', 'Jane', 'Jo')
##' lastname <- c('Ng', 'Doe', 'Smith')
##' gender <- c('Male', 'Female', 'X')
##' birthdate <- c(20001231, 19990101, 19981111)
##' df <- data.frame(firstname, lastname
##'   , gender, birthdate, stringsAsFactors=FALSE)
##' library(dplyr)
##' df %>%
##'   mutate(isk=calpass_create_isk(first_name=firstname
##'     , last_name=lastname
##'     , gender=gender
##'     , birthdate
##'   )) 
##' dfResults <- calpass_query_many(interSegmentKey=df$isk
##'   , token=cp_token
##'   , endpoint='transcript'
##' )
##' }
##' @export
##' @import httr
##' @importFrom jsonlite fromJSON
##' @importFrom dplyr bind_rows
calpass_query <- function(interSegmentKey, token, api_url='https://mmap.calpassplus.org/api', endpoint=c('transcript', 'placement'), verbose=FALSE) {
  if (token$expiration_time < Sys.time()) {
    stop(paste('The token has expired at', token$expiration_time))
  }
  endpoint <- match.arg(endpoint)
  cp_response <- GET(url=paste0(api_url, '/', endpoint, '/', interSegmentKey)
                   # , add_headers(c(Authorization=paste('Bearer', token))) # Old where `calpass_get_token` only returned the access token string by itself
                   , add_headers(c(Authorization=paste(token$token_type, token$access_token)))
                   , content_type('application/json')
                   , if (verbose) verbose() else NULL
                     )
  if (cp_response$status_code == 200) {
    results_list <- fromJSON(rawToChar(cp_response$content))
    results_list[sapply(results_list, is.null)] <- NA
    results_df <- data.frame(status_code=cp_response$status_code, as.data.frame(results_list), stringsAsFactors=FALSE)
  } else {
    results_df <- data.frame(status_code=cp_response$status_code, stringsAsFactors=FALSE)
  }
  return(results_df)
}

##' @describeIn calpass_query Query data from CalPASS API endpoints with a vector of interSegmentKey's.  The number of rows returned corresponds to the number of unique interSegmentKey's.
##' @export
calpass_query_many <- function(interSegmentKey, token, api_url='https://mmap.calpassplus.org/api', endpoint=c('transcript', 'placement'), verbose=FALSE, api_call_limit=3200, limit_per_n_sec=3600, wait=FALSE, token_username, token_password, token_client_id, token_scope) {
  if (length(unique(interSegmentKey)) < length(interSegmentKey)) {
    warning("interSegmentKey contains duplicates.  Will execute for unique cases only (returned rows will be the number of unique cases).")
    interSegmentKey <- unique(interSegmentKey)
  }

  n_isk <- length(interSegmentKey)

  if (n_isk > api_call_limit & wait==FALSE) {
    stop(paste0("There are ", n_isk, " unique elements in `interSegmentKey`, which is greater than `api_call_limit` (", api_call_limit, "). Set `wait` to TRUE to call API in batches of `api_call_limit`."))
  }

  n_batches <- ceiling(n_isk / api_call_limit)

  if (!missing(token)) {
    
    if (token$expiration_time < Sys.time()) {
      stop(paste('The token has expired at', token$expiration_time))
    }
    
    if(n_batches > 1 & token$expiration_time < (Sys.time() + n_batches * limit_per_n_sec * 60)) {
      stop(paste0('The token will expire during the run at ', token$expiration_time, ', and this job (with wait time) is expected to end after this time.  Suggestion: instead of specifying token, specify token_username, token_password, token_client_id, and token_scope.'))
    }
    
    use_credentials <- FALSE
    
  } else {

    if(any(missing(token_username), missing(token_password), missing(token_client_id), missing(token_scope))) {
      stop("Please specify the following: token_username, token_password, token_client_id, and token_scope.")
    }
    
    use_credentials <- TRUE
    token <- calpass_get_token(username=token_username, password=token_password, client_id=token_client_id, scope=token_scope)
  }
  
  endpoint <- match.arg(endpoint) 

  if (n_batches==1) {
    results_list_of_df <- lapply(interSegmentKey, calpass_query, token=token, api_url=api_url, endpoint=endpoint)
  } else {
    results_of_batches <- list()
    for (i in 1:n_batches) {
      if (use_credentials) {
        # Refresh token
        token <- calpass_get_token(username=token_username, password=token_password, client_id=token_client_id, scope=token_scope)
      }
      cat('Batch i =', i, 'of', n_batches, '\n')
      idx <- (api_call_limit*(i-1) + 1):pmin(api_call_limit*i, n_isk)
      cat('  Indices:', min(idx), 'to', max(idx), '\n')
      results_of_batches[[i]] <- lapply(interSegmentKey[idx], calpass_query, token=token, api_url=api_url, endpoint=endpoint)
      if (i < n_batches) {
        cat('  Waiting', limit_per_n_sec, 'seconds...\n')
        Sys.sleep(limit_per_n_sec + 1)
      }
    }
    results_list_of_df <- do.call('c', results_of_batches)
  }
  
  results_single_df <- do.call('bind_rows', results_list_of_df)
  if (any(results_single_df$status_code == 429)) warning('Status code of 429 returned for at least one API call, which means the API limit was reached.  Retry again after an hour.')
  dCp <- data.frame(interSegmentKey=interSegmentKey, results_single_df, stringsAsFactors=FALSE)
  rownames(dCp) <- NULL
  return(dCp)
}
