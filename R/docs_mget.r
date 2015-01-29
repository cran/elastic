#' Get multiple documents via the multiple get API.
#'
#' @import httr
#'
#' @template all
#' @param ids More than one document id, see examples.
#' @param type_id List of vectors of length 2, each with an element for type and id.
#' @param index_type_id List of vectors of length 3, each with an element for index,
#' type, and id.
#' @param source (logical) If \code{TRUE}, return source.
#' @param fields Fields to return from the response object.
#'
#' @details There are a lot of terms you can use for Elasticsearch. See here
#'    \url{http://www.elasticsearch.org/guide/reference/query-dsl/} for the documentation.
#' @export
#' @examples \dontrun{
#' # Same index and type
#' docs_mget(index="shakespeare", type="line", ids=c(9,10))
#' tmp <- docs_mget(index="mran", type="metadata", ids=c('plyr','ggplot2'), raw=TRUE)
#' es_parse(tmp)
#' docs_mget(index="mran", type="metadata", ids=c('plyr','ggplot2'), fields='description')
#' docs_mget(index="mran", type="metadata", ids=c('plyr','ggplot2'), source=TRUE)
#'
#' library("httr")
#' docs_mget(index="twitter", type="tweet", ids=1:2, callopts=verbose())
#'
#' # Same index, but different types
#' docs_mget(index="shakespeare", type_id=list(c("scene",1), c("line",20)))
#' docs_mget(index="shakespeare", type_id=list(c("scene",1), c("line",20)), fields='play_name')
#'
#' # Different indeces and different types
#' # pass in separately
#' docs_mget(index_type_id=list(c("shakespeare","line",1), c("plos","article",1)))
#' }

docs_mget <- function(index=NULL, type=NULL, ids=NULL, type_id=NULL, index_type_id=NULL,
  source=NULL, fields=NULL, raw=FALSE, callopts=list(), verbose=TRUE, ...)
{
  conn <- es_get_auth()

  if(!is.null(ids)){
    if(length(ids) < 2) stop("If ids parameter is used, more than 1 id must be passed", call. = FALSE)
  }

  base <- paste(conn$base, ":", conn$port, sep="")
  fields <- if(is.null(fields)) { fields} else { paste(fields, collapse=",") }
  args <- ec(list(...))

  # One index, one type, one to many ids
  if(length(index)==1 && length(unique(type))==1 && length(ids) > 1){

    body <- jsonlite::toJSON(list("ids" = ids))
    url <- paste(base, index, type, '_mget', sep="/")
    out <- POST(url, body = body, encode = 'json', callopts, query = args)

  }
  # One index, many types, one to many ids
  else if(length(index)==1 & length(type)>1 | !is.null(type_id)){

    # check for 2 elements in each element
    stopifnot(all(sapply(type_id, function(x) length(x) == 2)))
    docs <- lapply(type_id, function(x){
      list(`_type` = x[[1]], `_id` = x[[2]])
    })
    docs <- lapply(docs, function(y) modifyList(y, list(`_source` = source, fields = fields)))
    tt <- jsonlite::toJSON(list("docs" = docs))
    url <- paste(base, index, '_mget', sep="/")
    out <- POST(url, body = tt, encode = 'json', callopts, query = args)

  }
  # Many indeces, many types, one to many ids
  else if(length(index)>1 | !is.null(index_type_id)){

    # check for 3 elements in each element
    stopifnot(all(sapply(index_type_id, function(x) length(x) == 3)))
    docs <- lapply(index_type_id, function(x){
      modifyList(list(`_index` = x[[1]], `_type` = x[[2]], `_id` = x[[3]]), list(fields = fields))
    })
    tt <- jsonlite::toJSON(list("docs" = docs))
    url <- paste(base, '_mget', sep="/")
    out <- POST(url, body = tt, encode = 'json', callopts, query = args)

  }

  stop_for_status(out)
  if(verbose) message(URLdecode(out$url))
  tt <- content(out, as="text")
  class(tt) <- "elastic_mget"

  if(raw){ tt } else { es_parse(tt) }
}
