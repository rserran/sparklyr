#' @include avro_utils.R
#' @include dplyr_spark.R
#' @include tables_spark.R
#' @include utils.R
NULL

#' Copy an Object into Spark
#'
#' Copy an object into Spark, and return an \R object wrapping the
#' copied object (typically, a Spark DataFrame).
#'
#' @section Advanced Usage:
#'
#' \code{sdf_copy_to} is an S3 generic that, by default, dispatches to
#' \code{sdf_import}. Package authors that would like to implement
#' \code{sdf_copy_to} for a custom object type can accomplish this by
#' implementing the associated method on \code{sdf_import}.
#'
#' @param sc The associated Spark connection.
#' @param x An \R object from which a Spark DataFrame can be generated.
#' @param name The name to assign to the copied table in Spark.
#' @param memory Boolean; should the table be cached into memory?
#' @param repartition The number of partitions to use when distributing the
#'   table across the Spark cluster. The default (0) can be used to avoid
#'   partitioning.
#' @param overwrite Boolean; overwrite a pre-existing table with the name \code{name}
#'   if one already exists?
#' @param struct_columns (only supported with Spark 2.4.0 or higher) A list of
#'   columns from the source data frame that should be converted to Spark SQL
#'   StructType columns.
#'   The source columns can contain either json strings or nested lists.
#'   All rows within each source column should have identical schemas (because
#'   otherwise the conversion result will contain unexpected null values or
#'   missing values as Spark currently does not support schema discovery on
#'   individual rows within a struct column).
#' @param ... Optional arguments, passed to implementing methods.
#'
#' @family Spark data frames
#'
#' @examples
#'
#' \dontrun{
#' sc <- spark_connect(master = "spark://HOST:PORT")
#' sdf_copy_to(sc, iris)
#' }
#'
#' @name sdf_copy_to
#' @export
sdf_copy_to <- function(sc,
                        x,
                        name,
                        memory,
                        repartition,
                        overwrite,
                        struct_columns,
                        ...) {
  UseMethod("sdf_copy_to")
}

#' @export
sdf_copy_to.default <- function(sc,
                                x,
                                name = spark_table_name(substitute(x)),
                                memory = TRUE,
                                repartition = 0L,
                                overwrite = FALSE,
                                struct_columns = list(),
                                ...) {
  sdf_import(x, sc, name, memory, repartition, overwrite, struct_columns, ...)
}

#' @name sdf_copy_to
#' @export
sdf_import <- function(x,
                       sc,
                       name,
                       memory,
                       repartition,
                       overwrite,
                       struct_columns,
                       ...) {
  UseMethod("sdf_import")
}

sdf_prepare_dataframe <- function(x) {
  as.data.frame(
    x,
    stringsAsFactors = FALSE,
    row.names = NULL,
    optional = TRUE
  )
}

#' @export
#' @importFrom dplyr tbl
sdf_import.default <- function(x,
                               sc,
                               name = random_string("sparklyr_tmp_"),
                               memory = TRUE,
                               repartition = 0L,
                               overwrite = FALSE,
                               struct_columns = list(),
                               ...) {
  if (overwrite) {
    spark_remove_table_if_exists(sc, name)
  } else if (name %in% src_tbls(sc)) {
    stop("table ", name, " already exists (pass overwrite = TRUE to overwrite)")
  }

  dots <- list(...)
  serializer <- dots$serializer
  spark_data_copy(
    sc,
    x,
    name = name,
    repartition = repartition,
    serializer = serializer,
    struct_columns = struct_columns
  )

  if (memory && !class(x)[[1]] %in% c("iterator", "list")) {
    tbl_cache_sdf(sc, name, force = FALSE)
  }

  on_connection_updated(sc, name)

  tbl(sc, name)
}

#' Register a Spark DataFrame
#'
#' Registers a Spark DataFrame (giving it a table name for the
#' Spark SQL context), and returns a \code{tbl_spark}.
#'

#'
#' @param x A Spark DataFrame.
#' @param name A name to assign this table.
#'
#' @family Spark data frames
#' @export
sdf_register <- function(x, name = NULL) {
  UseMethod("sdf_register")
}

#' @export
sdf_register.tbl_spark <- function(x, name = NULL) {
  sdf_register(spark_dataframe(x), name)
}

#' @export
sdf_register.list <- function(x, name = NULL) {
  result <- lapply(seq_along(x), function(i) {
    sdf_register(x[[i]], name[[i]])
  })
  names(result) <- name
  result
}

#' @export
#' @importFrom dplyr tbl
sdf_register.spark_jobj <- function(x, name = NULL) {
  name <- name %||% paste0("sparklyr_tmp_", gsub("-", "_", uuid::UUIDgenerate()))
  sc <- spark_connection(x)

  if (spark_version(sc) < "2.0.0") {
    invoke(x, "registerTempTable", name)
  } else {
    invoke(x, "createOrReplaceTempView", name)
  }

  on_connection_updated(sc, name)
  tbl(sc, name)
}

#' Randomly Sample Rows from a Spark DataFrame
#'
#' Draw a random sample of rows (with or without replacement)
#' from a Spark DataFrame.
#'
#'
#' @param x An object coercable to a Spark DataFrame.
#' @param fraction The fraction to sample.
#' @param replacement Boolean; sample with replacement?
#' @param seed An (optional) integer seed.
#'
#' @family Spark data frames
#'
#' @export
sdf_sample <- function(x, fraction = 1, replacement = TRUE, seed = NULL) {
  sdf <- spark_dataframe(x)

  sampled <- if (is.null(seed)) {
    sdf %>%
      invoke("sample", as.logical(replacement), as.double(fraction))
  } else {
    sdf %>%
      invoke("sample", as.logical(replacement), as.double(fraction), as.integer(seed))
  }

  sdf_register(sampled)
}

#' Perform Weighted Random Sampling on a Spark DataFrame
#'
#' Draw a random sample of rows (with or without replacement) from a Spark
#' DataFrame
#' If the sampling is done without replacement, then it will be conceptually
#' equivalent to an iterative process such that in each step the probability of
#' adding a row to the sample set is equal to its weight divided by summation of
#' weights of all rows that are not in the sample set yet in that step.
#'
#'
#' @param x An object coercable to a Spark DataFrame.
#' @param weight_col Name of the weight column
#' @param k Sample set size
#' @param replacement Whether to sample with replacement
#' @param seed An (optional) integer seed
#' @family Spark data frames
#'
#' @export
sdf_weighted_sample <- function(x, weight_col, k, replacement = TRUE, seed = NULL) {
  sdf <- spark_dataframe(x)
  sc <- spark_connection(sdf)
  schema <- invoke(sdf, "schema")
  seed <- seed %||% Sys.time()

  sdf %>%
    invoke("rdd") %>%
    invoke_static(
      sc,
      "sparklyr.SamplingUtils",
      ifelse(replacement, "sampleWithReplacement", "sampleWithoutReplacement"),
      .,
      weight_col,
      as.integer(k),
      as.integer(seed)
    ) %>%
    invoke(hive_context(sc), "createDataFrame", ., schema) %>%
    sdf_register()
}

#' Sort a Spark DataFrame
#'
#' Sort a Spark DataFrame by one or more columns, with each column
#' sorted in ascending order.
#'

#'
#' @param x An object coercable to a Spark DataFrame.
#' @param columns The column(s) to sort by.
#'
#' @family Spark data frames
#'
#' @export
sdf_sort <- function(x, columns) {
  df <- spark_dataframe(x)

  columns <- as.character(columns)
  n <- length(columns)
  if (n == 0) {
    stop("must supply one or more column names")
  }

  sorted <- if (n == 1) {
    invoke(df, "sort", columns, list())
  } else {
    invoke(df, "sort", columns[[1]], as.list(columns[-1]))
  }

  sdf_register(sorted)
}

#' Add a Unique ID Column to a Spark DataFrame
#'
#' Add a unique ID column to a Spark DataFrame. The Spark
#' \code{monotonicallyIncreasingId} function is used to produce these and is
#' guaranteed to produce unique, monotonically increasing ids; however, there
#' is no guarantee that these IDs will be sequential. The table is persisted
#' immediately after the column is generated, to ensure that the column is
#' stable -- otherwise, it can differ across new computations.
#'
#' @template roxlate-ml-x
#' @param id The name of the column to host the generated IDs.
#'
#' @export
sdf_with_unique_id <- function(x, id = "id") {
  sdf <- spark_dataframe(x)
  sc <- spark_connection(sdf)

  id <- cast_string(id)

  mii <- invoke_static(
    sc,
    "org.apache.spark.sql.functions",
    "monotonicallyIncreasingId"
  )

  mii <- invoke(mii, "cast", "double")

  transformed <- sdf %>%
    invoke("withColumn", id, mii) %>%
    sdf_persist(storage.level = "MEMORY_ONLY")

  sdf_register(transformed)
}

#' Add a Sequential ID Column to a Spark DataFrame
#'
#' Add a sequential ID column to a Spark DataFrame. The Spark
#' \code{zipWithIndex} function is used to produce these. This differs from
#' \code{sdf_with_unique_id} in that the IDs generated are independent of
#' partitioning.
#'
#' @template roxlate-ml-x
#' @param id The name of the column to host the generated IDs.
#' @param from The starting value of the id column
#'
#' @export
sdf_with_sequential_id <- function(x, id = "id", from = 1L) {
  sdf <- spark_dataframe(x)
  sc <- spark_connection(sdf)
  id <- cast_string(id)
  from <- cast_scalar_integer(from)

  transformed <- invoke_static(
    sc,
    "sparklyr.Utils",
    "addSequentialIndex",
    sdf,
    from,
    id,
    spark_session(sc)
  )

  sdf_register(transformed)
}

#' Returns the last index of a Spark DataFrame
#'
#' Returns the last index of a Spark DataFrame. The Spark
#' \code{mapPartitionsWithIndex} function is used to iterate
#' through the last nonempty partition of the RDD to find the last record.
#'
#' @template roxlate-ml-x
#' @param id The name of the index column.
#'
#' @export
#' @importFrom rlang sym
#' @importFrom rlang :=
sdf_last_index <- function(x, id = "id") {
  sdf <- x %>%
    dplyr::transmute(!!sym(id) := as.numeric(!!sym(id))) %>%
    spark_dataframe()
  sc <- spark_connection(sdf)
  id <- cast_string(id)

  invoke_static(
    sc,
    "sparklyr.Utils",
    "getLastIndex",
    sdf,
    id
  )
}

#' Compute (Approximate) Quantiles with a Spark DataFrame
#'
#' Given a numeric column within a Spark DataFrame, compute
#' approximate quantiles.
#'
#' @template roxlate-ml-x
#' @param column The column(s) for which quantiles should be computed.
#' Multiple columns are only supported in Spark 2.0+.
#' @param probabilities A numeric vector of probabilities, for
#'   which quantiles should be computed.
#' @param relative.error The maximal possible difference between the actual
#'   percentile of a result and its expected percentile (e.g., if
#'   `relative.error` is 0.01 and `probabilities` is 0.95, then any value
#'   between the 94th and 96th percentile will be considered an acceptable
#'   approximation).
#' @param weight.column If not NULL, then a generalized version of the Greenwald-
#'   Khanna algorithm will be run to compute weighted percentiles, with each
#'   sample from `column` having a relative weight specified by the corresponding
#'   value in `weight.column`. The weights can be considered as relative
#'   frequencies of sample data points.
#'
#' @export
sdf_quantile <- function(x,
                         column,
                         probabilities = c(0.00, 0.25, 0.50, 0.75, 1.00),
                         relative.error = 1E-5,
                         weight.column = NULL) {
  sdf <- spark_dataframe(x)

  if (is.null(weight.column)) {
    if (length(column) > 1) {
      if (package_version2(sdf$connection$home_version) <
        package_version2("2.0.0")) {
        stop("Spark 2.0+ is required when length(column) > 1")
      }
    }
  }

  nm <-
    names(probabilities) %||%
    paste(signif(probabilities * 100, 3), "%", sep = "")

  column <- lapply(column, cast_string)
  probabilities <- as.list(as.numeric(probabilities))
  relative.error <- cast_scalar_double(relative.error)

  quantiles <- (
    if (is.null(weight.column)) {
      sdf %>%
        invoke(
          "%>%",
          list("stat"),
          list("approxQuantile", column, probabilities, relative.error)
        )
    } else {
      invoke_static(
        spark_connection(x),
        "sparklyr.WeightedQuantileSummaries",
        "approxWeightedQuantile",
        sdf,
        column,
        weight.column,
        probabilities,
        relative.error
      )
    })

  if (length(column) == 1) {
    quantiles <- unlist(quantiles)
    names(quantiles) <- nm
  } else {
    names(quantiles) <- column
    quantiles <- lapply(quantiles, `names<-`, nm)
  }

  quantiles
}

#' Persist a Spark DataFrame
#'
#' Persist a Spark DataFrame, forcing any pending computations and (optionally)
#' serializing the results to disk.
#'
#' Spark DataFrames invoke their operations lazily -- pending operations are
#' deferred until their results are actually needed. Persisting a Spark
#' DataFrame effectively 'forces' any pending computations, and then persists
#' the generated Spark DataFrame as requested (to memory, to disk, or
#' otherwise).
#'
#' Users of Spark should be careful to persist the results of any computations
#' which are non-deterministic -- otherwise, one might see that the values
#' within a column seem to 'change' as new operations are performed on that
#' data set.
#'
#' @template roxlate-ml-x
#' @param storage.level The storage level to be used. Please view the
#'   \href{https://spark.apache.org/docs/latest/programming-guide.html#rdd-persistence}{Spark Documentation}
#'   for information on what storage levels are accepted.
#' @param name A name to assign this table. Passed to [sdf_register()].
#' @export
sdf_persist <- function(x, storage.level = "MEMORY_AND_DISK", name = NULL) {
  sdf <- spark_dataframe(x)
  sc <- spark_connection(sdf)

  storage.level <- cast_string(storage.level)

  sl <- invoke_static(
    sc,
    "org.apache.spark.storage.StorageLevel",
    storage.level
  )

  sdf %>%
    invoke("persist", sl) %>%
    sdf_register(name = name)
}

#' Checkpoint a Spark DataFrame
#'
#' @param x an object coercible to a Spark DataFrame
#' @param eager whether to truncate the lineage of the DataFrame
#' @export
sdf_checkpoint <- function(x, eager = TRUE) {
  eager <- cast_scalar_logical(eager)

  x %>%
    spark_dataframe() %>%
    invoke("checkpoint", eager) %>%
    sdf_register()
}

#' Broadcast hint
#'
#' Used to force broadcast hash joins.
#'
#' @template roxlate-ml-x
#'
#' @export
sdf_broadcast <- function(x) {
  sdf <- spark_dataframe(x)
  sc <- spark_connection(sdf)

  invoke_static(
    sc,
    "org.apache.spark.sql.functions",
    "broadcast", sdf
  ) %>%
    sdf_register()
}

#' Repartition a Spark DataFrame
#'
#' @template roxlate-ml-x
#'
#' @param partitions number of partitions
#' @param partition_by vector of column names used for partitioning, only supported for Spark 2.0+
#'
#' @export
sdf_repartition <- function(x, partitions = NULL, partition_by = NULL) {
  sdf <- spark_dataframe(x)
  sc <- spark_connection(sdf)

  partitions <- partitions %||% 0L %>%
    cast_scalar_integer()

  if (spark_version(sc) >= "2.0.0") {
    partition_by <- cast_string_list(partition_by, allow_null = TRUE) %||% list()

    return(
      invoke_static(sc, "sparklyr.Repartition", "repartition", sdf, partitions, partition_by) %>%
        sdf_register()
    )
  } else {
    if (!is.null(partition_by)) {
      stop("partitioning by columns only supported for Spark 2.0.0 and later")
    }

    invoke(sdf, "repartition", partitions) %>%
      sdf_register()
  }
}

#' Gets number of partitions of a Spark DataFrame
#'
#' @template roxlate-ml-x
#' @export
sdf_num_partitions <- function(x) {
  x %>%
    spark_dataframe() %>%
    invoke("%>%", list("rdd"), list("getNumPartitions"))
}

#' Coalesces a Spark DataFrame
#'
#' @template roxlate-ml-x
#' @param partitions number of partitions
#' @export
sdf_coalesce <- function(x, partitions) {
  sdf <- spark_dataframe(x)
  sc <- spark_connection(sdf)

  partitions <- cast_scalar_integer(partitions)

  if (partitions < 1) {
    stop("number of partitions must be positive")
  }

  sdf %>%
    invoke("coalesce", partitions) %>%
    sdf_register()
}

validate_cols <- function(x, cols) {
  present <- cols %in% colnames(x)
  if (any(!present)) {
    msg <- paste0(
      "The following columns are not in the data frame: ",
      paste0(cols[which(!present)], collapse = ", ")
    )
    stop(msg)
  }
}

#' Compute summary statistics for columns of a data frame
#'
#' @param x An object coercible to a Spark DataFrame
#' @param cols Columns to compute statistics for, given as a character vector
#' @export
sdf_describe <- function(x, cols = colnames(x)) {
  validate_cols(x, cols)

  cols <- cast_string_list(cols)

  x %>%
    spark_dataframe() %>%
    invoke("describe", cols) %>%
    sdf_register()
}

#' Remove duplicates from a Spark DataFrame
#'
#' @param x An object coercible to a Spark DataFrame
#' @param cols Subset of Columns to consider, given as a character vector
#' @export
sdf_drop_duplicates <- function(x, cols = NULL) {
  validate_cols(x, cols)

  cols <- cast_string_list(cols, allow_null = TRUE)
  sdf <- spark_dataframe(x)

  sdf_deduplicated <- if (is.null(cols)) {
    invoke(sdf, "dropDuplicates")
  } else {
    invoke(sdf, "dropDuplicates", cols)
  }

  sdf_register(sdf_deduplicated)
}

#' transform a subset of column(s) in a Spark Dataframe
#'
#' @param x An object coercible to a Spark DataFrame
#' @param cols Subset of columns to apply transformation to
#' @param fn Transformation function taking column name as the 1st parameter, the
#'  corresponding \code{org.apache.spark.sql.Column} object as the 2nd parameter,
#'  and returning a transformed \code{org.apache.spark.sql.Column} object
transform_sdf <- function(x, cols, fn) {
  all_cols <- colnames(x)
  sdf <- spark_dataframe(x)
  transformed_cols <- lapply(
    all_cols,
    function(col) {
      col_obj <- invoke_new(
        spark_connection(x),
        "org.apache.spark.sql.Column",
        col
      )
      if (col %in% cols) {
        fn(col, col_obj) %>% invoke("as", col)
      } else {
        col_obj
      }
    }
  )

  invoke(sdf, "select", transformed_cols) %>% sdf_register()
}

#' Convert column(s) to avro format
#'
#' @param x An object coercible to a Spark DataFrame
#' @param cols Subset of Columns to convert into avro format
#'
#' @export
sdf_to_avro <- function(x, cols = colnames(x)) {
  validate_cols(x, cols)
  validate_spark_avro_pkg_version(spark_connection(x))

  cols <- cast_string_list(cols, allow_null = TRUE)
  transform_sdf(
    x,
    cols,
    function(col, col_obj) {
      invoke_static(
        spark_connection(x),
        "org.apache.spark.sql.avro",
        "to_avro",
        col_obj
      )
    }
  )
}

#' Convert column(s) from avro format
#'
#' @param x An object coercible to a Spark DataFrame
#' @param cols Named list of columns to transform from Avro format plus a valid Avro
#'   schema string for each column, where column names are keys and column schema strings
#'   are values (e.g.,
#'   \code{c(example_primitive_col = "string",
#'   example_complex_col = "{\"type\":\"record\",\"name\":\"person\",\"fields\":[
#'   {\"name\":\"person_name\",\"type\":\"string\"}, {\"name\":\"person_id\",\"type\":\"long\"}]}")}
#'
#' @export
sdf_from_avro <- function(x, cols) {
  validate_cols(x, names(cols))
  validate_spark_avro_pkg_version(spark_connection(x))

  transform_sdf(
    x,
    names(cols),
    function(col, col_obj) {
      col_schema <- cols[[col]]
      invoke_static(
        spark_connection(x),
        "org.apache.spark.sql.avro",
        "from_avro",
        col_obj,
        col_schema
      )
    }
  )
}

#' Create a Spark dataframe containing all combinations of inputs
#'
#' Given one or more R vectors/factors or single-column Spark dataframes,
#' perform an expand.grid operation on all of them and store the result in
#' a Spark dataframe
#'
#' @param sc The associated Spark connection.
#' @param ... Each input variable can be either a R vector/factor or a Spark
#'   dataframe. Unnamed inputs will assume the default names of 'Var1', 'Var2',
#'   etc in the result, similar to what `expand.grid` does for unnamed inputs.
#' @param broadcast_vars Indicates which input(s) should be broadcasted to all
#'   nodes of the Spark cluster during the join process (default: none).
#' @param memory Boolean; whether the resulting Spark dataframe should be
#'   cached into memory (default: TRUE)
#' @param repartition Number of partitions the resulting Spark dataframe should
#'   have
#' @param partition_by Vector of column names used for partitioning the
#'   resulting Spark dataframe, only supported for Spark 2.0+
#'
#' @examples
#'
#' \dontrun{
#' sc <- spark_connect(master = "local")
#' grid_sdf <- sdf_expand_grid(sc, seq(5), rnorm(10), letters)
#' }
#'
#' @export
sdf_expand_grid <- function(
                            sc,
                            ...,
                            broadcast_vars = NULL,
                            memory = TRUE,
                            repartition = NULL,
                            partition_by = NULL) {
  if (spark_version(sc) < "2.0.0") {
    stop("`sdf_expand_grid()` requires Spark 2.0.0 or above")
  }

  vars <- list(...)
  if (length(vars) == 0) {
    invoke(spark_session(sc), "emptyDataFrame") %>% sdf_register()
  } else {
    if (is.null(names(vars))) {
      names(vars) <- rep("", length(vars))
    }
    for (i in seq_along(vars)) {
      var_name <- names(vars[i])
      if (is.null(var_name) || identical(var_name, "")) {
        names(vars)[[i]] <- sprintf("Var%d", i)
      }
      if (!"tbl_spark" %in% class(vars[[i]])) {
        vars[[i]] <- sdf_copy_to(
          sc, data.frame(vars[i]),
          name = random_string("sparklyr_tmp_")
        )
      }
    }
    broadcast_vars <- rlang::enexpr(broadcast_vars)
    if (!rlang::is_null(broadcast_vars)) {
      broadcast_vars <- broadcast_vars %>%
        (
          function(exprs) {
            if (length(exprs) > 1) {
              as.list(exprs)[-1]
            } else {
              as.list(exprs)[1]
            }
          }) %>%
        lapply(rlang::as_string) %>%
        unlist()
    }
    for (x in broadcast_vars) {
      idxes <- which(names(vars) %in% x)
      if (length(idxes) > 0) {
        for (idx in idxes) {
          vars[[idx]] <- sdf_broadcast(vars[[idx]])
        }
      } else {
        warning(
          sprintf("Broadcast variable '%s'", x),
          " is not among the list of input variable(s)! It will be ignored."
        )
      }
    }

    vars_ordering <- lapply(vars, colnames) %>% unlist()
    # reverse ordering of variables so that the 1st variable in the input is the
    # one varying the fastest, 2nd one varying the 2nd fastest, etc in the cross
    # join output
    vars <- rev(vars)

    grid_sdf <- spark_dataframe(vars[[1]])
    for (i in seq(2, length(vars))) {
      grid_sdf <- invoke(grid_sdf, "crossJoin", spark_dataframe(vars[[i]]))
    }

    grid_sdf <- grid_sdf %>%
      invoke("select", vars_ordering[[1]], as.list(vars_ordering[-1])) %>%
      sdf_register()

    if (!is.null(repartition) || !is.null(partition_by)) {
      grid_sdf <- grid_sdf %>% sdf_repartition(repartition, partition_by)
    }

    if (memory) {
      invoke(spark_dataframe(grid_sdf), "cache")
    }

    grid_sdf
  }
}

#' Compute the number of records within each partition of a Spark DataFrame
#'
#' @template roxlate-ml-x
#'
#' @examples
#'
#' \dontrun{
#' library(sparklyr)
#' sc <- spark_connect(master = "spark://HOST:PORT")
#' example_sdf <- sdf_len(sc, 100L, repartition = 10L)
#' example_sdf %>%
#'   sdf_partition_sizes() %>%
#'   print()
#' }
#'
#' @export
sdf_partition_sizes <- function(x) {
  sc <- spark_connection(x)

  rs <- invoke_static(
    sc,
    "sparklyr.PartitionUtils",
    "computePartitionSizes",
    spark_dataframe(x)
  )

  # workaround to make CRAN happy
  partition_index <- NULL

  data.frame(
    partition_index = lapply(rs, function(p) p[[1]]) %>% unlist(),
    partition_size = lapply(rs, function(p) p[[2]]) %>% unlist()
  ) %>%
    dplyr::arrange(partition_index)
}

#' Subsetting operator for Spark dataframe
#'
#' Susetting operator for Spark dataframe allowing a subset of column(s) to be
#' selected using syntaxes similar to those supported by R dataframes
#'
#' @param x The Spark dataframe
#' @param i Expression specifying subset of column(s) to include or exclude
#'   from the result (e.g., `["col1"]`, `[c("col1", "col2")]`, `[1:10]`, `[-1]`,
#'   `[NULL]`, or `[]`)
#' @export
`[.tbl_spark` <- function(x, i) {
  if (missing(i)) {
    x
  } else if (is.null(i)) {
    x %>%
      spark_connection() %>%
      spark_session() %>%
      invoke("emptyDataFrame") %>%
      sdf_register()
  } else {
    rx <- replicate_colnames(x)
    cols <- colnames(rx[i])

    x %>>% dplyr::select %@% lapply(cols, as.symbol)
  }
}
