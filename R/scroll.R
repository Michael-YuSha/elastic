#' Scroll search function
#'
#' @export
#' @name scroll
#' 
#' @param scroll_id (character) For \code{scroll}, a single scroll id; for 
#' \code{scroll_clear}, one or more scroll id's
#' @param scroll (character) Specify how long a consistent view of the index 
#' should be maintained for scrolled search, e.g., "30s", "1m". 
#' See \code{\link{units-time}}.
#' @param raw (logical) If \code{FALSE} (default), data is parsed to list. 
#' If \code{TRUE}, then raw JSON.
#' @param asdf (logical) If \code{TRUE}, use \code{\link[jsonlite]{fromJSON}} 
#' to parse JSON directly to a data.frame. If \code{FALSE} (Default), list 
#' output is given.
#' @param stream_opts (list) A list of options passed to 
#' \code{\link[jsonlite]{stream_out}} - Except that you can't pass \code{x} as 
#' that's the data that's streamed out, and pass a file path instead of a 
#' connection to \code{con}. \code{pagesize} param doesn't do much as 
#' that's more or less controlled by paging with ES.
#' @param all (logical) If \code{TRUE} (default) then all search contexts 
#' cleared.  If \code{FALSE}, scroll id's must be passed to \code{scroll_id}
#' @param ... Curl args passed on to \code{\link[httr]{POST}}
#' 
#' @seealso \code{\link{Search}}
#' @references 
#' \url{https://www.elastic.co/guide/en/elasticsearch/reference/current/search-request-scroll.html}
#' 
#' @details Scores will be zero for all documents that are returned from a 
#' scroll request. Dems da rules.
#' 
#' @section Clear scroll:
#' Search context are automatically removed when the scroll timeout has 
#' been exceeded.  Keeping scrolls open has a cost, so scrolls should be 
#' explicitly cleared as soon  as the scroll is not being used anymore 
#' using \code{scroll_clear}
#' 
#' @section Sliced scrolling:
#' See the example in this man file.
#' 
#' @examples \dontrun{
#' # Get a scroll_id
#' res <- Search(index = 'shakespeare', q="a*", scroll="1m")
#' res$`_scroll_id`
#' 
#' # Setting search_type=scan turns off sorting of results, is faster
#' res <- Search(index = 'shakespeare', q="a*", scroll="1m", 
#'   search_type = "scan")
#' res$`_scroll_id`
#' 
#' # Pass scroll_id to scroll function
#' scroll(scroll_id = res$`_scroll_id`)
#' 
#' # Get all results - one approach is to use a while loop
#' res <- Search(index = 'shakespeare', q="a*", scroll="5m", 
#'   search_type = "scan")
#' out <- list()
#' hits <- 1
#' while(hits != 0){
#'   res <- scroll(scroll_id = res$`_scroll_id`)
#'   hits <- length(res$hits$hits)
#'   if(hits > 0)
#'     out <- c(out, res$hits$hits)
#' }
#' length(out)
#' out[[1]]
#' 
#' # clear scroll
#' ## individual scroll id
#' res <- Search(index = 'shakespeare', q="a*", scroll="5m", 
#'   search_type = "scan")
#' scroll_clear(scroll_id = res$`_scroll_id`)
#' 
#' ## many scroll ids
#' res1 <- Search(index = 'shakespeare', q="c*", scroll="5m", 
#'   search_type = "scan")
#' res2 <- Search(index = 'shakespeare', q="d*", scroll="5m", 
#'   search_type = "scan")
#' nodes_stats(metric = "indices")$nodes[[1]]$indices$search$open_contexts
#' scroll_clear(scroll_id = c(res1$`_scroll_id`, res2$`_scroll_id`))
#' nodes_stats(metric = "indices")$nodes[[1]]$indices$search$open_contexts
#' 
#' ## all scroll ids
#' res1 <- Search(index = 'shakespeare', q="f*", scroll="1m", 
#'   search_type = "scan")
#' res2 <- Search(index = 'shakespeare', q="g*", scroll="1m", 
#'   search_type = "scan")
#' res3 <- Search(index = 'shakespeare', q="k*", scroll="1m", 
#'   search_type = "scan")
#' scroll_clear(all = TRUE)
#' 
#' ## sliced scrolling
#' body1 <- '{
#'   "slice": {
#'     "id": 0, 
#'     "max": 2 
#'   },
#'   "query": {
#'     "match" : {
#'       "text_entry" : "a*"
#'     }
#'   }
#' }'
#' 
#' body2 <- '{
#'   "slice": {
#'     "id": 1, 
#'     "max": 2 
#'   },
#'   "query": {
#'     "match" : {
#'       "text_entry" : "a*"
#'     }
#'   }
#' }'
#' 
#' res1 <- Search(index = 'shakespeare', scroll="1m", body = body1)
#' res2 <- Search(index = 'shakespeare', scroll="1m", body = body2)
#' scroll(scroll_id = res1$`_scroll_id`)
#' scroll(scroll_id = res2$`_scroll_id`)
#' 
#' out1 <- list()
#' hits <- 1
#' while(hits != 0){
#'   tmp1 <- scroll(scroll_id = res1$`_scroll_id`)
#'   hits <- length(tmp1$hits$hits)
#'   if(hits > 0)
#'     out1 <- c(out1, tmp1$hits$hits)
#' }
#' 
#' out2 <- list()
#' hits <- 1
#' while(hits != 0){
#'   tmp2 <- scroll(scroll_id = res2$`_scroll_id`)
#'   hits <- length(tmp2$hits$hits)
#'   if(hits > 0)
#'     out2 <- c(out2, tmp2$hits$hits)
#' }
#'
#' c(
#'  lapply(out1, "[[", "_source"),
#'  lapply(out2, "[[", "_source")
#' )
#' 
#' 
#' # using jsonlite::stream_out
#' connect()
#' res <- Search(scroll = "1m")
#' file <- tempfile()
#' scroll(
#'   scroll_id = res$`_scroll_id`, 
#'   stream_opts = list(file = file)
#' )
#' jsonlite::stream_in(file(file))
#' unlink(file)
#' 
#' ## stream_out and while loop
#' connect()
#' (file <- tempfile())
#' res <- Search(index = "shakespeare", scroll = "5m", 
#'   size = 1000, stream_opts = list(file = file))
#' while(!inherits(res, "warning")) {
#'   res <- tryCatch(scroll(
#'     scroll_id = res$`_scroll_id`, 
#'     scroll = "5m",
#'     stream_opts = list(file = file)
#'   ), warning = function(w) w)
#' }
#' NROW(df <- jsonlite::stream_in(file(file)))
#' head(df)
#' }
scroll <- function(scroll_id, scroll = "1m", raw = FALSE, asdf = FALSE, 
                   stream_opts = list(), ...) {
  
  scroll_POST(
    path = "_search/scroll", 
    args = list(scroll = scroll), 
    body = scroll_id, 
    raw = raw, 
    asdf = asdf, 
    stream_opts = stream_opts, ...)
}

#' @export
#' @rdname scroll
scroll_clear <- function(scroll_id = NULL, all = FALSE, ...) {
  if (all) {
    path <- "_search/scroll/_all" 
    body <- NULL
  } else {
    if (is.null(scroll_id)) stop("if all=FALSE scroll_id must not be NULL", 
                                 call. = FALSE)
    path <- "_search/scroll"
    body <- list(scroll_id = scroll_id)
  }
  scroll_DELETE(path, body = body, ...)
}
