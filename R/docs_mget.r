#' Get multiple documents via the multiple get API
#'
#' @export
#' @template all
#' @param conn an Elasticsearch connection object, see [connect()]
#' @param ids More than one document id, see examples.
#' @param type_id List of vectors of length 2, each with an element for
#' type and id.
#' @param index_type_id List of vectors of length 3, each with an element for
#' index, type, and id.
#' @param source (logical) If `TRUE`, return source.
#' @param fields Fields to return from the response object.
#'
#' @references
#' <https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-multi-get.html>
#'
#' @details
#'
#' You can pass in one of three combinations of parameters:
#'
#' - Pass in something for `index`, `type`, and `id`.
#'  This is the simplest, allowing retrieval from the same index, same type,
#'  and many ids.
#' - Pass in only `index` and `type_id` - this allows you to
#'  get multiple documents from the same index, but from different types.
#' - Pass in only `index_type_id` - this is so that you can get
#'  multiple documents from different indexes and different types.
#'
#' @examples \dontrun{
#' (x <- connect())
#'
#' if (!index_exists(x, 'plos')) {
#'   plosdat <- system.file("examples", "plos_data.json",
#'     package = "elastic")
#'   plosdat <- type_remover(plosdat)
#'   invisible(docs_bulk(x, plosdat))
#' }
#'
#' # same index, many ids
#' docs_mget(x, index="plos", ids=c(9,10))
#'
#' # Same index and type
#' docs_mget(x, index="plos", type="_doc", ids=c(9,10))
#'
#' tmp <- docs_mget(x, index="plos", ids=c(9, 10), raw=TRUE)
#' es_parse(tmp)
#' docs_mget(x, index="plos", ids=c(9, 10), source='title')
#' docs_mget(x, index="plos", ids=c(14, 19), source=TRUE)
#'
#' # curl options
#' docs_mget(x, index="plos", ids=1:2, callopts=list(verbose=TRUE))
#'
#' # Same index, but different types
#' if (index_exists(x, 'shakespeare')) index_delete(x, 'shakespeare')
#' shakedat <- system.file("examples", "shakespeare_data.json",
#'   package = "elastic")
#' invisible(docs_bulk(x, shakedat))
#'
#' docs_mget(x, index="shakespeare", type_id=list(c("scene",1), c("line",20)))
#' docs_mget(x, index="shakespeare", type_id=list(c("scene",1), c("line",20)),
#'   source='play_name')
#'
#' # Different indices and different types pass in separately
#' docs_mget(x, index_type_id = list(
#'   c("shakespeare", "line", 20),
#'   c("plos", "article", 1)
#'  )
#' )
#' }

docs_mget <- function(conn, index=NULL, type=NULL, ids=NULL, type_id=NULL,
  index_type_id=NULL, source=NULL, fields=NULL, raw=FALSE, callopts=list(),
  verbose=TRUE, ...) {

  is_conn(conn)
  # check_params(index, type, ids, type_id, index_type_id)
  base <- conn$make_url()

  if (!is.null(ids)) {
    if (length(ids) < 2) stop("If ids parameter is used, more than 1 id must be passed", call. = FALSE)
  }

  fields <- cw(fields)
  if (inherits(source, "logical")) source <- tolower(source)
  source <- cw(source)
  args <- ec(list(...))
  if (!is.null(fields)) args$fields <- fields
  if (!is.null(source)) args$`_source` <- source
  if (length(args) == 0) args <- NULL

  # One index, no types, one to many ids
  if (length(index) == 1 && is.null(type) && length(ids) > 1) {
    body <- jsonlite::toJSON(list("ids" = ids))
    url <- paste(base, esc(index), '_mget', sep = "/")
    cli <- conn$make_conn(url, json_type(), callopts)
    out <- cli$post(query = args, body = body, encode = "json")
  }
  # One index, one type, one to many ids
  if (length(index) == 1 && length(unique(type)) == 1 && length(ids) > 1) {
    body <- jsonlite::toJSON(list("ids" = ids))
    url <- paste(base, esc(index), esc(type), '_mget', sep = "/")
    cli <- conn$make_conn(url, json_type(), callopts)
    out <- cli$post(query = args, body = body, encode = "json")
  }
  # One index, many types, one to many ids
  else if (length(index) == 1 & length(type) > 1 | !is.null(type_id)) {
    # check for 2 elements in each element
    stopifnot(all(sapply(type_id, function(x) length(x) == 2)))
    docs <- lapply(type_id, function(x){
      list(`_type` = esc(x[[1]]), `_id` = x[[2]])
    })
    tt <- jsonlite::toJSON(list("docs" = docs))
    url <- paste(base, esc(index), '_mget', sep = "/")
    cli <- conn$make_conn(url, json_type(), callopts)
    out <- cli$post(query = args, body = tt, encode = "json")
  }
  # Many indeces, many types, one to many ids
  else if (length(index) > 1 | !is.null(index_type_id)) {
    # check for 3 elements in each element
    stopifnot(all(sapply(index_type_id, function(x) length(x) == 3)))
    docs <- lapply(index_type_id, function(x){
      list(`_index` = esc(x[[1]]), `_type` = esc(x[[2]]), `_id` = x[[3]])
    })
    tt <- jsonlite::toJSON(list("docs" = docs))
    url <- paste(base, '_mget', sep = "/")
    cli <- conn$make_conn(url, json_type(), callopts)
    out <- cli$post(query = args, body = tt, encode = "json")
  }

  if (conn$warn) catch_warnings(out)
  geterror(conn, out)
  if (verbose) message(URLdecode(out$url))
  tt <- out$parse("UTF-8")
  class(tt) <- "elastic_mget"

  if (raw) return(tt)
  es_parse(tt)
}

# check_params <- function(index, type, ids, type_id, index_type_id){
#   if (is.null(type_id) && is.null(index_type_id)) {
#     if (any(sapply(list(index, type, ids), is.null)))
#       stop("If type_id and index_type_id are NULL, you must pass in index, type, and ids", call. = FALSE)
#   } else if (!is.null(type_id) || !is.null(index_type_id)) {
#     if (!is.null(type_id)) {
#       if (is.null(index))
#         stop("If you pass in type_id, you must pass in index", call. = FALSE)
#     }
#   }
# }
