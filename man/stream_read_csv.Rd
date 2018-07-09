% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/stream_data.R
\name{stream_read_csv}
\alias{stream_read_csv}
\title{Read CSV Stream}
\usage{
stream_read_csv(sc, path, name = NULL, header = TRUE, columns = NULL,
  delimiter = ",", quote = "\\"", escape = "\\\\", charset = "UTF-8",
  null_value = NULL, options = list(), ...)
}
\arguments{
\item{sc}{A \code{spark_connection}.}

\item{path}{The path to the file. Needs to be accessible from the cluster.
Supports the \samp{"hdfs://"}, \samp{"s3a://"} and \samp{"file://"} protocols.}

\item{name}{The name to assign to the newly generated stream.}

\item{header}{Boolean; should the first row of data be used as a header?
Defaults to \code{TRUE}.}

\item{columns}{A vector of column names or a named vector of column types.}

\item{delimiter}{The character used to delimit each column. Defaults to \samp{','}.}

\item{quote}{The character used as a quote. Defaults to \samp{'"'}.}

\item{escape}{The character used to escape other characters. Defaults to \samp{'\'}.}

\item{charset}{The character set. Defaults to \samp{"UTF-8"}.}

\item{null_value}{The character to use for null, or missing, values. Defaults to \code{NULL}.}

\item{options}{A list of strings with additional options.}

\item{...}{Optional arguments; currently unused.}
}
\description{
Reads a CSV stream as a Spark dataframe stream.
}
\seealso{
Other Spark stream serialization: \code{\link{stream_read_jdbc}},
  \code{\link{stream_read_json}},
  \code{\link{stream_read_kafka}},
  \code{\link{stream_read_orc}},
  \code{\link{stream_read_parquet}},
  \code{\link{stream_read_text}},
  \code{\link{stream_write_csv}},
  \code{\link{stream_write_jdbc}},
  \code{\link{stream_write_json}},
  \code{\link{stream_write_kafka}},
  \code{\link{stream_write_memory}},
  \code{\link{stream_write_orc}},
  \code{\link{stream_write_parquet}},
  \code{\link{stream_write_text}}
}