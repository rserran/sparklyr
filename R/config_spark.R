#' Read Spark Configuration
#'
#' Read Spark Configuration
#'
#' @include avro_utils.R

#' Read Spark Configuration
#'
#' @export
#' @param file Name of the configuration file
#' @param use_default TRUE to use the built-in defaults provided in this package
#'
#' @details
#'
#' Read Spark configuration using the \pkg{\link[config]{config}} package.
#'
#' @return Named list with configuration data
spark_config <- function(file = "config.yml", use_default = TRUE) {
  baseConfig <- list()

  if (use_default) {
    localConfigFile <- system.file(file.path("conf", "config-template.yml"), package = "sparklyr")
    baseConfig <- config::get(file = localConfigFile)
  }

  # allow options to specify sparklyr configuration settings
  optionsConfigCheck <- grepl("^spark\\.|^sparklyr\\.|^livy\\.", names(options()))
  optionsConfig <- options()[optionsConfigCheck]
  baseConfig <- merge_lists(optionsConfig, baseConfig)

  userEnvConfig <- tryCatch(config::get(file = Sys.getenv("SPARKLYR_CONFIG_FILE")), error = function(e) NULL)
  baseEnvConfig <- merge_lists(baseConfig, userEnvConfig)

  isFileProvided <- !missing(file)
  userConfig <- tryCatch(
    config::get(file = file),
    error = function(e) {
      if (isFileProvided) {
        warnMessage <- sprintf(
          "Error reading config file: %s in spark_config(): %s: %s. File will be ignored.",
          file, deparse(e[["call"]]), e[["message"]]
        )
        warning(warnMessage, call. = FALSE)
      }
      NULL
    }
  )

  mergedConfig <- merge_lists(baseEnvConfig, userConfig)

  if (nchar(Sys.getenv("SPARK_DRIVER_CLASSPATH")) > 0 &&
    is.null(mergedConfig$master$`sparklyr.shell.driver-class-path`)) {
    mergedConfig$master$`sparklyr.shell.driver-class-path` <- Sys.getenv("SPARK_DRIVER_CLASSPATH")
  }

  if (is.null(spark_config_value(mergedConfig, c("sparklyr.cores.local", "sparklyr.connect.cores.local")))) {
    mergedConfig$sparklyr.connect.cores.local <- parallel::detectCores()
  }

  if (is.null(spark_config_value(mergedConfig, "spark.sql.shuffle.partitions.local"))) {
    mergedConfig$spark.sql.shuffle.partitions.local <- parallel::detectCores()
  }

  mergedConfig
}

#' A helper function to check value exist under \code{spark_config()}
#'
#' @param config The configuration list from \code{spark_config()}
#' @param name The name of the configuration entry
#' @param default The default value to use when entry is not present
#'
#' @keywords internal
#' @export
spark_config_exists <- function(config, name, default = NULL) {
  if (!name %in% names(config)) default else !identical(config[[name]], FALSE)
}

# recursively merge two lists -- extracted from code used by rmarkdown
# package to merge _output.yml, _site.yml, front matter, etc.:
# https://github.com/rstudio/rmarkdown/blob/master/R/util.R#L174
merge_lists <- function(base_list, overlay_list, recursive = TRUE) {
  if (length(base_list) == 0) {
    overlay_list
  } else if (length(overlay_list) == 0) {
    base_list
  } else {
    merged_list <- base_list
    for (name in names(overlay_list)) {
      base <- base_list[[name]]
      overlay <- overlay_list[[name]]
      if (is.list(base) && is.list(overlay) && recursive) {
        merged_list[[name]] <- merge_lists(base, overlay)
      } else {
        merged_list[[name]] <- NULL
        merged_list <- append(
          merged_list,
          overlay_list[which(names(overlay_list) %in% name)]
        )
      }
    }
    merged_list
  }
}

spark_config_value_retries <- function(config, name, default, retries) {
  success <- FALSE
  value <- default

  while (!success && retries > 0) {
    retries <- retries - 1

    result <- tryCatch(
      {
        list(
          value = spark_config_value(config, name, default),
          success = TRUE
        )
      },
      error = function(e) {
        if (spark_config_value(config, "sparklyr.verbose", FALSE)) {
          message("Reading ", name, " failed with error: ", e$message)
        }

        if (retries > 0) Sys.sleep(1)

        list(
          success = FALSE
        )
      }
    )

    success <- result$success
    value <- result$value
  }

  if (!success) {
    stop("Failed after ", retries, " attempts while reading conf value ", name)
  }

  value
}

#' Creates Spark Configuration
#'
#' @param config The Spark configuration object.
#' @param packages A list of named packages or versioned packagese to add.
#' @param version The version of Spark being used.
#' @param scala_version Acceptable Scala version of packages to be loaded
#' @param ... Additional configurations
#'
#' @keywords internal
#' @export
spark_config_packages <- function(config, packages, version, scala_version = NULL, ...) {
  version <- spark_version_latest(version)

  scala_version <- scala_version %||% (
    if (version >= "4.0.0") {
      "2.13"
    } else if (version >= "3.0.0") {
      "2.12"
    } else {
      "2.11"
    }
  )

  if ("kafka" %in% packages) {
    packages <- packages[-which(packages == "kafka")]

    if (version < "2.0.0") stop("Kafka requires Spark 2.x")

    kafka_package <- sprintf("org.apache.spark:spark-sql-kafka-0-10_%s:", scala_version)
    kafka_package <- paste0(kafka_package, version)

    config$sparklyr.shell.packages <- c(config$sparklyr.shell.packages, kafka_package)
  }

  if ("delta" %in% packages) {
    packages <- packages[-which(packages == "delta")]

    if (version < "2.4.2") stop("Delta Lake requires Spark 2.4.2 or newer")

    delta <- list(
      list(spark = "2.4", delta = "0.6.0"),
      list(spark = "3.0", delta = "0.8.0"),
      list(spark = "3.1", delta = "1.0.1"),
      list(spark = "3.2", delta = "2.0.2"),
      list(spark = "3.3", delta = "2.3.0"),
      list(spark = "3.4", delta = "2.4.0"),
      list(spark = "3.5", delta = "3.0.0"),
      list(spark = "4.0", delta = "4.0.0")
    ) %>%
      purrr::keep(~ .x$spark >= substr(version, 1, 3)) %>%
      head(1) %>%
      unlist()

    delta_version <- delta[2]

    if(version >= "3.5") {
      delta_name <- "delta-spark"
    } else{
      delta_name <- "delta-core"
    }

    config$sparklyr.shell.packages <- c(
      config$sparklyr.shell.packages,
      sprintf(
        "io.delta:%s_%s:%s",
        delta_name,
        scala_version,
        delta_version
        )
    )
    if(version >= 3.3) {
      config$`spark.sql.extensions` <- "io.delta.sql.DeltaSparkSessionExtension"
      config$`spark.sql.catalog.spark_catalog` <- "org.apache.spark.sql.delta.catalog.DeltaCatalog"
    }
  }

  if ("avro" %in% packages) {
    packages <- packages[-which(packages == "avro")]

    if (is.null(version)) {
      stop(
        "`package = \"avro\")` requires Spark version to be specified via ",
        "`spark_connect(..., version = <Spark version>)`"
      )
    }

    config$sparklyr.shell.packages <- c(
      config$sparklyr.shell.packages,
      spark_avro_package_name(version, scala_version)
    )
  }

  if ("rapids" %in% packages) {
    packages <- packages[-which(packages == "rapids")]

    if (version < "3.0.0") {
      stop("RAPIDS library requires Spark 3.0.0 or higher")
    }

    additional_configs <- list(...)
    config$sparklyr.shell.packages <- c(
      config$sparklyr.shell.packages,
      (
        if (additional_configs$method %in% c("databricks", "databricks-connect")) {
          "com.nvidia:rapids-4-spark_2.12:0.1.0-databricks"
        } else {
          "com.nvidia:rapids-4-spark_2.12:0.1.0"
        }),
      "ai.rapids:cudf:0.14"
    )

    rapids_prefix <- "spark.rapids."
    rapids_configs <- connection_config(
      sc = list(config = config),
      prefix = rapids_prefix
    )
    rapids_configs[["sql.incompatibleOps.enabled"]] <-
      rapids_configs[["sql.incompatibleOps.enabled"]] %||% "true"
    config <- append(
      config,
      list(sparklyr.shell.conf = "spark.plugins=com.nvidia.spark.SQLPlugin")
    )
    for (idx in seq_along(rapids_configs)) {
      k <- names(rapids_configs)[[idx]]
      v <- rapids_configs[[idx]]
      config <- append(
        config,
        list(sparklyr.shell.conf = paste0(rapids_prefix, k, "=", v))
      )
    }
  }

  if (!is.null(packages)) {
    config$sparklyr.shell.packages <- c(config$sparklyr.shell.packages, packages)
  }

  config
}
