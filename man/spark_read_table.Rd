% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/data_interface.R
\name{spark_read_table}
\alias{spark_read_table}
\title{Reads from a Spark Table into a Spark DataFrame.}
\usage{
spark_read_table(
  sc,
  name,
  options = list(),
  repartition = 0,
  memory = TRUE,
  columns = NULL,
  ...
)
}
\arguments{
\item{sc}{A \code{spark_connection}.}

\item{name}{The name to assign to the newly generated table.}

\item{options}{A list of strings with additional options.
See \url{https://spark.apache.org/docs/latest/sql-programming-guide.html#configuration}.}

\item{repartition}{The number of partitions used to distribute the
generated table. Use 0 (the default) to avoid partitioning.}

\item{memory}{Boolean; should the data be loaded eagerly into memory? (That
is, should the table be cached?)}

\item{columns}{A vector of column names or a named vector of column types.
If specified, the elements can be \code{"binary"} for \code{BinaryType},
\code{"boolean"} for \code{BooleanType}, \code{"byte"} for \code{ByteType},
\code{"integer"} for \code{IntegerType}, \code{"integer64"} for \code{LongType},
\code{"double"} for \code{DoubleType}, \code{"character"} for \code{StringType},
\code{"timestamp"} for \code{TimestampType} and \code{"date"} for \code{DateType}.}

\item{...}{Optional arguments; currently unused.}
}
\description{
Reads from a Spark Table into a Spark DataFrame.
}
\seealso{
Other Spark serialization routines: 
\code{\link{collect_from_rds}()},
\code{\link{spark_insert_table}()},
\code{\link{spark_load_table}()},
\code{\link{spark_read}()},
\code{\link{spark_read_avro}()},
\code{\link{spark_read_binary}()},
\code{\link{spark_read_csv}()},
\code{\link{spark_read_delta}()},
\code{\link{spark_read_image}()},
\code{\link{spark_read_jdbc}()},
\code{\link{spark_read_json}()},
\code{\link{spark_read_libsvm}()},
\code{\link{spark_read_orc}()},
\code{\link{spark_read_parquet}()},
\code{\link{spark_read_source}()},
\code{\link{spark_read_text}()},
\code{\link{spark_save_table}()},
\code{\link{spark_write_avro}()},
\code{\link{spark_write_csv}()},
\code{\link{spark_write_delta}()},
\code{\link{spark_write_jdbc}()},
\code{\link{spark_write_json}()},
\code{\link{spark_write_orc}()},
\code{\link{spark_write_parquet}()},
\code{\link{spark_write_source}()},
\code{\link{spark_write_table}()},
\code{\link{spark_write_text}()}
}
\concept{Spark serialization routines}
