#' Full text search of Elasticsearch
#'
#' @export
#' @name Search
#' @template search_par
#' @template search_extra
#' @template search_egs
#' @param body Query, either a list or json.
#' @param time_scroll (character) Specify how long a consistent view of the 
#' index should be maintained for scrolled search, e.g., "30s", "1m". See 
#' [units-time]
#' @param search_path (character) The path to use for searching. Default 
#' to `_search`, but in some cases you may already have that in the base 
#' url set using [connect()], in which case you can set this 
#' to `NULL`
#' @seealso  [Search_uri()] [Search_template()] [scroll()] [count()] 
#' [validate()] [fielddata()]

Search <- function(conn, index=NULL, type=NULL, q=NULL, df=NULL, analyzer=NULL, 
  default_operator=NULL, explain=NULL, source=NULL, fields=NULL, sort=NULL, 
  track_scores=NULL, timeout=NULL, terminate_after=NULL, from=NULL, size=NULL, 
  search_type=NULL, lowercase_expanded_terms=NULL, analyze_wildcard=NULL, 
  version=NULL, lenient=NULL, body=list(), raw=FALSE, asdf=FALSE,
  track_total_hits = TRUE, time_scroll=NULL, search_path="_search",
  stream_opts=list(), ignore_unavailable = FALSE, ...) {

  is_conn(conn)
  tmp <- search_POST(conn, search_path, cl(index), cl(type),
    args = ec(list(df = df, analyzer = analyzer, 
      default_operator = default_operator, explain = as_log(explain), 
      `_source` = cl(source), fields = cl(fields), sort = cl(sort), 
      track_scores = track_scores, timeout = cn(timeout), 
      terminate_after = cn(terminate_after), from = cn(from), size = cn(size), 
      search_type = search_type, 
      lowercase_expanded_terms = lowercase_expanded_terms, 
      analyze_wildcard = analyze_wildcard, version = as_log(version), q = q, 
      ignore_unavailable = as_log(ignore_unavailable),
      scroll = time_scroll, lenient = as_log(lenient),
      track_total_hits = ck(track_total_hits))), body, raw, asdf,
    stream_opts, ...)
  if (!is.null(time_scroll)) attr(tmp, "scroll") <- time_scroll
  return(tmp)
}

search_POST <- function(conn, path, index=NULL, type=NULL, args, body, raw, 
                        asdf, stream_opts, ...) {
  if (!inherits(raw, "logical")) {
    stop("'raw' parameter must be `TRUE` or `FALSE`", call. = FALSE)
  }
  if (!inherits(asdf, "logical")) {
    stop("'asdf' parameter must be `TRUE` or `FALSE`", call. = FALSE)
  }
  
  url <- conn$make_url()
  url <- construct_url(url, path, index, type)
  url <- prune_trailing_slash(url)
  body <- check_inputs(body)
  if (!conn$ignore_version) {
    # track_total_hits introduced in ES >= 7.0
    if (conn$es_ver() < 700) args$track_total_hits <- NULL
    # in ES >= v5, lenient param droppped
    if (conn$es_ver() >= 500) args$lenient <- NULL
    # in ES >= v5, fields param changed to stored_fields
    if (conn$es_ver() >= 500) {
      if ("fields" %in% names(args)) {
        stop('"fields" parameter is deprecated in ES >= v5. Use "_source" in body\nSee also "fields" parameter in ?Search', call. = FALSE)
      }
    }
  }
  cli <- crul::HttpClient$new(url = url,
    headers = c(conn$headers, json_type()), 
    opts = c(conn$opts, ...),
    auth = crul::auth(conn$user, conn$pwd)
  )
  tt <- cli$post(query = args, body = body)
  geterror(conn, tt)
  if (conn$warn) catch_warnings(tt)
  res <- tt$parse("UTF-8")
  
  if (raw) {
    res 
  } else {
    if (length(stream_opts) != 0) {
      dat <- jsonlite::fromJSON(res, flatten = TRUE)
      stream_opts$x <- dat$hits$hits
      if (length(stream_opts$x) != 0) {
        stream_opts$con <- file(stream_opts$file, open = "ab")
        stream_opts$file <- NULL
        do.call(jsonlite::stream_out, stream_opts)
        close(stream_opts$con)
      } else {
        warning("no scroll results remain", call. = FALSE)
      }
      return(list(`_scroll_id` = dat$`_scroll_id`))
    } else {
      jsonlite::fromJSON(res, asdf, flatten = TRUE)
    }
  }
}
