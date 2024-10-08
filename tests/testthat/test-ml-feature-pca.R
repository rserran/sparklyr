skip_connection("ml-feature-pca")
skip_on_livy()
skip_on_arrow_devel()
skip_on_ci()
skip_databricks_connect()
test_that("ft_pca() param setting", {
  test_requires_version("3.0.0")
  sc <- testthat_spark_connection()
  test_args <- list(
    input_col = "foo",
    output_col = "bar",
    k = 4
  )
  test_param_setting(sc, ft_pca, test_args)
})

test_that("ft_pca() works", {
  sc <- testthat_spark_connection()
  mat <- dplyr::tibble(
    V1 = c(0, 2, 4),
    V2 = c(1, 0, 0),
    V3 = c(0, 3, 0),
    V4 = c(7, 4, 6),
    V5 = c(0, 5, 7)
  )

  s <- dplyr::tibble(
    PC1 = c(1.6485728230883807, -4.645104331781534, -6.428880535676489),
    PC2 = c(-4.013282700516296, -1.1167972663619026, -5.337951427775355),
    PC3 = c(-5.524543751369388, -5.524543751369387, -5.524543751369389)
  )
  mat_tbl <- testthat_tbl("mat")

  r <- mat_tbl %>%
    ft_vector_assembler(paste0("V", 1:5), "v") %>%
    ft_pca("v", "pc", k = 3) %>%
    sdf_separate_column("pc", into = paste0("PC", 1:3)) %>%
    select(starts_with("PC", ignore.case = FALSE)) %>%
    collect()

  expect_equal(s, r, tolerance = 1)
})

# Backwards compat

test_that("ml_pca() agrees with Scala result", {

  # import org.apache.spark.ml.feature.PCA
  # import org.apache.spark.ml.linalg.Vectors
  #
  # val data = Array(
  #   Vectors.sparse(5, Seq((1, 1.0), (3, 7.0))),
  #   Vectors.dense(2.0, 0.0, 3.0, 4.0, 5.0),
  #   Vectors.dense(4.0, 0.0, 0.0, 6.0, 7.0)
  # )
  # val df = spark.createDataFrame(data.map(Tuple1.apply)).toDF("features")
  # val pca = new PCA()
  # .setInputCol("features")
  # .setOutputCol("pcaFeatures")
  # .setK(3)
  # .fit(df)
  # val pcaDF = pca.transform(df)
  # val result = pcaDF.select("pcaFeatures")
  # result.collect()
  #
  # res1: Array[org.apache.spark.sql.Row] =
  #   Array([[1.6485728230883807,-4.013282700516296,-5.524543751369388]],
  #         [[-4.645104331781534,-1.1167972663619026,-5.524543751369387]],
  #         [[-6.428880535676489,-5.337951427775355,-5.524543751369389]])

  s <- data.frame(
    PC1 = c(1.6485728230883807, -4.645104331781534, -6.428880535676489),
    PC2 = c(-4.013282700516296, -1.1167972663619026, -5.337951427775355),
    PC3 = c(-5.524543751369388, -5.524543751369387, -5.524543751369389)
  )

  mat_tbl <- testthat_tbl("mat")

  r <- mat_tbl %>%
    ml_pca(k = 3) %>%
    sdf_project() %>%
    select(dplyr::starts_with("PC")) %>%
    collect() %>%
    as.data.frame()

  expect_equal(s, r, tolerance = 1)
})

test_that("sdf_project() returns correct number of columns", {
  mat_tbl <- testthat_tbl("mat")

  for (k in 1:2) {
    expect_equal(
      mat_tbl %>%
        ml_pca(k = k) %>%
        sdf_project() %>%
        select(starts_with("PC")) %>%
        collect() %>%
        ncol(),
      k
    )
  }
})

test_that("sdf_project() takes newdata argument", {
  mat_tbl <- testthat_tbl("mat")

  expect_equal(
    mat_tbl %>%
      ml_pca(k = 3) %>%
      sdf_project() %>%
      collect(),
    mat_tbl %>% ml_pca(k = 3) %>%
      sdf_project(mat_tbl) %>%
      collect()
  )
})

test_clear_cache()

