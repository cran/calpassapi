## ------------------------------------------------------------------------
# From CRAN (Official)
## install.packages('calpassapi')

# From github (Development)
## devtools::install_github('vinhdizzo/calpassapi')

## ---- message=FALSE, warning=FALSE---------------------------------------
library(calpassapi)
library(dplyr) # Ease in manipulations with data frames

## ---- eval=FALSE---------------------------------------------------------
#  cp_token <- calpass_get_token(username='my_cp_api_uid', password='my_cp_api_pwd', client_id='my_client_id', scope='my_scope')
#  # cp_token <- calpass_get_token(client_id='my_client_id', scope='my_scope') ## if cp_api_uid and cp_api_pwd are set in .Renviron

## ------------------------------------------------------------------------
# single
isk <- calpass_create_isk(first_name='Jane', last_name='Doe'
                 , gender='F', birthdate=20001231)
isk
# multiple
firstname <- c('Tom', 'Jane', 'Jo')
lastname <- c('Ng', 'Doe', 'Smith')
gender <- c('Male', 'Female', 'X')
birthdate <- c(20001231, 19990101, 19981111)
df <- data.frame(firstname, lastname
               , gender, birthdate, stringsAsFactors=FALSE)
df <- df %>%
  mutate(isk=calpass_create_isk(first_name=firstname
                              , last_name=lastname
                              , gender=gender
                              , birthdate
                                ))
df$isk

## ---- eval=FALSE---------------------------------------------------------
#  ## single
#  calpass_query(interSegmentKey=isk
#              , token=cp_token, endpoint='transcript')
#  ## multiple
#  dfResults <- calpass_query_many(interSegmentKey=df$isk
#                           , token=cp_token
#                           , endpoint='transcript'
#                             )
#  ## can specify credentials
#  dfResults <- calpass_query_many(interSegmentKey=df$isk
#                           , endpoint='transcript'
#                           , token_username='my_username'
#                           , token_password='my_password'
#                           , token_client_id='my_client_id'
#                           , token_scope='my_scope'
#                             )

## ---- eval=FALSE---------------------------------------------------------
#  ## batches
#  dfResults <- calpass_query_many(interSegmentKey=df$isk
#                           , token=cp_token
#                           , endpoint='transcript'
#                           , api_call_limit=2 ## batches of 2
#                           , limit_per_n_sec=10 ## every 10 seconds
#                           , wait=TRUE
#                             )

