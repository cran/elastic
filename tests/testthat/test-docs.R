context("docs")

x <- connect(port = Sys.getenv("TEST_ES_PORT"), warn = FALSE)

## create indices first -----------------------------------
ind <- "stuff_l"
invisible(tryCatch(index_delete(x, index = ind, verbose = FALSE),
  error = function(e) e))
invisible(index_create(x, index = ind, verbose = FALSE))

test_that("docs_create works", {
  if (x$es_ver() < 600) {
    # type not provided
    expect_error(docs_create(x, index = ind, id = 1002, body = list(id = "d")),
      "'type' is required")
    # type provided
    invisible(docs_create(x, index = ind, id = 1002, type = "stuff",
      body = list(id = "12345", title = "New title")))
    a <- docs_get(x, index = ind, type = "stuff", id = 1002, verbose = FALSE)
    expect_is(a, "list")
    expect_is(a$`_source`, "list")
    expect_equal(a$`_id`, "1002")
    expect_equal(a$`_source`$id[[1]], "12345")
  } else if (x$es_ver() < 700) {
    invisible(docs_create(x, index = ind, type = ind, id = 1002,
      body = list(id = "12345", title = "New title")))
    a <- docs_get(x, index = ind, type = ind, id = 1002, verbose = FALSE)
    expect_is(a, "list")
    expect_is(a$`_source`, "list")
    expect_equal(a$`_id`, "1002")
    expect_equal(a$`_source`$id[[1]], "12345")
  } else {
    invisible(docs_create(x, index = ind, id = 1002,
      body = list(id = "12345", title = "New title")))
    a <- docs_get(x, index = ind, id = 1002, verbose = FALSE)
    expect_is(a, "list")
    expect_is(a$`_source`, "list")
    expect_equal(a$`_id`, "1002")
    expect_equal(a$`_source`$id[[1]], "12345")
  }

  # can create docs with an index that doesn't exist yet
  # should create index on the fly
  if (x$es_ver() > 700) {
    b <- docs_create(x, "bbbbbbb", list(a = 5), id = 1)
    expect_true(index_exists(x, "bbbbbbb"))
  }
  if (x$es_ver() > 600 && x$es_ver() < 700) {
    b <- docs_create(x, "bbbbbbb", type = "bbbbbbb", list(a = 5), id = 1)
    expect_true(index_exists(x, "bbbbbbb"))
  }
})

ind11 <- "stuff_ll"
test_that("docs_create works with automatically created document IDs", {
  if (x$es_ver() < 600) {
    expect_error(docs_create(x, index = ind11,
      body = list(id = "12345", title = "Some title")),
      "'type' is required")
  } else if (x$es_ver() < 700) { 
    invisible(z<-docs_create(x, index = ind11, type = ind11,
      body = list(id = "12345", title = "Some title")))
    a <- docs_get(x, index = ind11, type = ind11, id = z$`_id`, verbose = FALSE)
    expect_is(a, "list")
    expect_is(a$`_source`, "list")
    expect_equal(a$`_source`$id[[1]], "12345")
  } else {
    invisible(z<-docs_create(x, index = ind11,
      body = list(id = "12345", title = "Some title")))
    a <- docs_get(x, index = ind11, id = z$`_id`, verbose = FALSE)
    expect_is(a, "list")
    expect_is(a$`_source`, "list")
    expect_equal(a$`_source`$id[[1]], "12345")
  }
})

test_that("docs_create fails as expected", {
  if (es_version(x) < 600) {
    expect_error(docs_create(x, "adfadf"),
      "type' is required")
    expect_error(docs_create(x, "adfadf", type = "asdf"),
      "argument \"body\" is missing, with no default")
  } else {
    expect_error(docs_create(x, "adfadf"),
      "argument \"body\" is missing, with no default")
  }


  expect_error(docs_get(x),
    "argument \"index\" is missing, with no default")
  expect_error(docs_get(x, "bbbbbbb"),
    "argument \"id\" is missing, with no default")
})

## create indices first
ind2 <- "stuff_f"
invisible(tryCatch(index_delete(x, index = ind2, verbose = FALSE),
  error = function(e) e))
invisible(index_create(x, index = ind2, verbose = FALSE))

test_that("docs_get works", {
  if (x$es_ver() < 600) {
    expect_error(docs_create(x, index = ind2, id = 45, body = '{"hello": "world"}'),
      "'type' is required")
  } else if (x$es_ver() < 700 && x$es_ver() >= 600) {
    c <- docs_create(x, index = ind2, type = ind2, id = 45, body = '{"hello": "world"}')
    expect_is(c, "list")
    expect_null(c$`_source`)
    expect_null(c$found)
    expect_equal(c$`_id`, "45")
  } else {
    invisible(docs_create(x, index = ind2, id = 45, body = '{"hello": "world"}'))
    c <- docs_get(x, index = ind2, id = 45, verbose = FALSE)
    expect_is(c, "list")
    expect_is(c$`_source`, "list")
    expect_true(c$found)
    expect_equal(c$`_id`, "45")

    # If field doesn't exist no source returned
    d <- docs_get(x, "bbbbbbb", 1, fields = "b", verbose = FALSE)
    expect_null(d$`_source`)
    expect_null(d$fields)
  }
})


## create indices first
ind3 <- "stuff_t"
invisible(tryCatch(index_delete(x, index = ind3, verbose = FALSE), error = function(e) e))
invisible(index_create(x, index = ind3, verbose = FALSE))

test_that("docs_mget works", {

  invisible(docs_create(x, index = ind3, type = "holla", id = 1, body = '{"hello": "world"}'))
  invisible(docs_create(x, index = ind3, type = "holla", id = 2, body = '{"foo": "bar"}'))
  invisible(docs_create(x, index = ind3, type = "holla", id = 3, body = '{"tables": "chairs"}'))
  e <- docs_mget(x, index = ind3, type = "holla", ids = 1:3, verbose = FALSE)
  expect_is(e, "list")
  expect_named(e, "docs")
  expect_is(e$docs, "list")
  expect_true(e$docs[[1]]$found)
  expect_equal(vapply(e$docs, "[[", "", "_id"), c("1", "2", "3"))
})

test_that("docs_delete works", {

  f <- docs_delete(x, index = ind3, type = "holla", id = 3)
  expect_is(f, "list")
  if (es_version(x) < 600) {
    expect_true(f$found)
  } else {
    expect_true("_seq_no" %in% names(f))
    expect_true("_primary_term" %in% names(f))
  }
  # error if try again to delete since document is gone
  expect_error(docs_delete(x, index = ind3, type = "holla", id = 3), "Not Found")
})


## create indices first
ind4 <- "stuff_ids"
invisible(tryCatch(index_delete(x, index = ind4, verbose = FALSE), error = function(e) e))
invisible(index_create(x, index = ind4, verbose = FALSE))

ind5 <- "stuff_zzz"
invisible(tryCatch(index_delete(x, index = ind5, verbose = FALSE), error = function(e) e))
invisible(index_create(x, index = ind5, verbose = FALSE))

test_that("document ids with spaces work", {

  # create
  f <- docs_create(x, index = ind4, type = ind4, id = "hello world", body = list(a = "asdfasdf"))
  invisible(docs_create(x, index = ind4, type = ind4, id = "foo bar", body = list(a = "asdfadfadfasdfasdfsdf")))
  if (es_version(x) < 600) {
    invisible(docs_create(x, index = ind4, type = "dattype", id = "what the", body = list(a = "cars")))
  }
  expect_is(f, "list")
  expect_equal(f$`_id`, "hello world")

  # get
  g <- docs_get(x, index = ind4, type = ind4, id = "hello world", verbose = FALSE)
  expect_is(g, "list")
  expect_true(g$found)

  # mget - ids param
  h <- docs_mget(x, index = ind4, type = ind4, ids = c("hello world", "foo bar"), verbose = FALSE)
  expect_is(h, "list")
  expect_equal(length(h$docs), 2)
  expect_true(all(vapply(h$docs, "[[", logical(1), "found")))

  # mget - type_id param
  hh <- docs_mget(x, index = ind4, type_id = list(c(ind4, "hello world"), c("dattype", "what the")), verbose = FALSE)
  expect_is(hh, "list")
  expect_equal(length(hh$docs), 2)
  if (es_version(x) < 600) {
    expect_true(all(vapply(hh$docs, "[[", logical(1), "found")))
  } else {
    expect_equal(vapply(hh$docs, "[[", logical(1), "found"), c(TRUE, FALSE))
  }

  # mget - index_type_id param
  invisible(docs_create(x, index = ind5, type = ind5, id = "hello mars", body = list(radius = 1000000L)))

  if (es_version(x) < 600) {

    hhh <- docs_mget(x, index_type_id = list(
      c(ind4, ind4, "hello world"),
      c(ind5, ind5, "hello mars")
    ), verbose = FALSE)
    expect_is(hhh, "list")
    expect_equal(length(hhh$docs), 2)
    expect_true(all(vapply(hhh$docs, "[[", logical(1), "found")))

    # update
    i <- docs_update(x, index = ind4, type = ind4, id = "hello world", body = list(doc = list(a = "an update")))
    expect_is(i, "list")

    # delete
    j <- docs_delete(x, index = ind4, type = ind4, id = "hello world")
    expect_is(j, "list")
    expect_true(j$found)
  }
})

## cleanup -----------------------------------
invisible(index_delete(x, ind, verbose = FALSE))
invisible(index_delete(x, ind2, verbose = FALSE))
invisible(index_delete(x, ind3, verbose = FALSE))
invisible(index_delete(x, ind4, verbose = FALSE))
invisible(index_delete(x, ind5, verbose = FALSE))
