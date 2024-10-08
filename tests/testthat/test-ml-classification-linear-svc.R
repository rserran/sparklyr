skip_connection("ml-classification-linear-svc")
skip_on_livy()
skip_on_arrow_devel()

skip_databricks_connect()

test_that("ml_linear_svc() default params", {
  test_requires_version("3.0.0")
  sc <- testthat_spark_connection()
  test_default_args(sc, ml_linear_svc)
})

test_that("ml_linear_svc() param setting", {
  test_requires_version("3.0.0")
  sc <- testthat_spark_connection()
  test_args <- list(
    fit_intercept = FALSE,
    reg_param = 1e-4,
    max_iter = 50,
    standardization = FALSE,
    tol = 1e-05,
    threshold = 0.6,
    aggregation_depth = 3,
    features_col = "fcol",
    label_col = "lcol",
    prediction_col = "pcol",
    raw_prediction_col = "rpcol"
  )
  test_param_setting(sc, ml_linear_svc, test_args)
})


test_that("ml_linear_svc() runs", {
  test_requires_version("2.2.0")
  sc <- testthat_spark_connection()
  iris_tbl2 <- testthat_tbl("iris") %>%
    mutate(is_versicolor = ifelse(
      Species == "versicolor", "versicolor", "other"
    )) %>%
    select(-Species)

  expect_error(
    ml_linear_svc(iris_tbl2, is_versicolor ~ .) %>%
      ml_predict(iris_tbl2) %>%
      pull(predicted_label),
    NA
  )
})

test_clear_cache()

