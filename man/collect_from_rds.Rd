% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sdf_wrapper.R
\name{collect_from_rds}
\alias{collect_from_rds}
\title{Collect Spark data serialized in RDS format into R}
\usage{
collect_from_rds(path)
}
\arguments{
\item{path}{Path to a local RDS file that is produced by `spark_write_rds()`
(RDS files stored in HDFS will need to be downloaded to local filesystem
first (e.g., by running `hadoop fs -copyToLocal ...` or similar)}
}
\description{
Deserialize Spark data that is serialized using `spark_write_rds()` into a R
dataframe.
}
\seealso{
Other Spark serialization routines: 
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
\code{\link{spark_read_table}()},
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
