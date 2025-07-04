skip_connection("connect-shell")
skip_on_livy()
test_requires_version("3.0")
skip_databricks_connect()
sc <- testthat_spark_connection()

iris_tbl <- testthat_tbl("iris")

test_that("'spark_connect' can create a secondary connection", {
  sc2 <- spark_connect(master = "local", app_name = "other")
  spark_disconnect(sc2)

  succeed()
})

test_that("`spark_connect()` returns invisibly", {
  skip_on_arrow() # Why is this skipped on arrow?
  sc2 <- spark_connect(master = "local", app_name = "other")
  expect_identical(
    capture.output(spark_disconnect(sc2)),
    character(0)
  )
})

test_that("'spark_connect' can provide a 'spark_log'", {
  log <- capture.output({
    spark_log(sc)
  })

  expect_gte(length(log), 1)
})

test_that("'spark_connect' fails with bad configuration'", {
  config <- spark_config()

  config$sparklyr.shell.args <- c("--badargument")
  config$sparklyr.connect.timeout <- 3

  expect_error({
    spark_connect(master = "local", app_name = "bad_connection", config = config)
  })
})

test_that("'spark_session_id' generates different ids for different apps", {
  expect_true(
    spark_session_id(app_name = "foo", master = "local") !=
      spark_session_id(app_name = "bar", master = "local")
  )
})

test_that("'spark_session_id' generates same ids for same apps", {
  expect_equal(
    spark_session_id(app_name = "foo", master = "local"),
    spark_session_id(app_name = "foo", master = "local")
  )
})

test_that("'spark_session_random' generates different ids even with seeds", {
  expect_true({
    set.seed(10)
    spark_session_random()
  } != {
    set.seed(10)
    spark_session_random()
  })
})

test_that("'spark_inspect' can enumerate information from the context", {
  result <- capture.output({
    sparklyr:::spark_inspect(spark_context(sc))
  })

  expect_gte(length(result), 100)
})

test_that("'spark_connect' can allow Hive support to be disabled", {
  version <- spark_version(sc)

  if (version >= "2.0.0") {
    expect_equal(get_spark_sql_catalog_implementation(sc), "hive")
  }

  # hive support is enabled by default
  expect_equal(sc$state$hive_support_enabled, TRUE)

  # create another connection with hive support disabled
  config <- spark_config()
  config$sparklyr.connect.enablehivesupport <- FALSE
  sc2 <- spark_connect(
    master = "local",
    app_name = "sparklyr_hive_support_disabled",
    config = config
  )

  if (version >= "2.0.0") {
    expect_equal(get_spark_sql_catalog_implementation(sc2), "in-memory")
  }

  expect_equal(sc2$state$hive_support_enabled, FALSE)
  spark_disconnect(sc2)

  # re-create another connection with hive support explicitly enabled
  config$sparklyr.connect.enablehivesupport <- TRUE
  sc2 <- spark_connect(
    master = "local",
    app_name = "sparklyr_hive_support_enabled",
    config = config
  )

  if (version >= "2.0.0") {
    expect_equal(get_spark_sql_catalog_implementation(sc2), "hive")
  }

  expect_equal(sc2$state$hive_support_enabled, TRUE)
  spark_disconnect(sc2)

  succeed()
})

test_that("spark_connection reports correct dbplyr edition", {
  dbplyr_version <- Sys.getenv("DBPLYR_VERSION")
  if (!identical(dbplyr_version, "") && dbplyr_version < "2") {
    skip("test case is not applicable for dbplyr 1.x")
  }

  expect_equal(
    dbplyr::dbplyr_edition(sc),
    ifelse(identical(Sys.getenv("DBPLYR_API_EDITION"), "1"), 1L, 2L)
  )
})

test_that("Abort shell returns expected output", {
  expect_error(
    abort_shell(
      output_file = tempfile(),
      error_file = tempfile(),
      message = "test",
      spark_submit_path = "",
      shell_args = ""
      )
  )
})

test_that("Misc tests", {
  expect_true(
    spark_connection_in_driver(testthat_spark_connection())
  )

  expect_equal(
    spark_disconnect("test"),
    0
  )

  expect_silent(
    spark_log_file(testthat_spark_connection())
    )
})

test_clear_cache()

