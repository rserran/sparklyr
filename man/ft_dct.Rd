% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ml_feature_dct.R
\name{ft_dct}
\alias{ft_dct}
\alias{ft_discrete_cosine_transform}
\title{Feature Transformation -- Discrete Cosine Transform (DCT) (Transformer)}
\usage{
ft_dct(
  x,
  input_col = NULL,
  output_col = NULL,
  inverse = FALSE,
  uid = random_string("dct_"),
  ...
)

ft_discrete_cosine_transform(
  x,
  input_col,
  output_col,
  inverse = FALSE,
  uid = random_string("dct_"),
  ...
)
}
\arguments{
\item{x}{A \code{spark_connection}, \code{ml_pipeline}, or a \code{tbl_spark}.}

\item{input_col}{The name of the input column.}

\item{output_col}{The name of the output column.}

\item{inverse}{Indicates whether to perform the inverse DCT (TRUE) or forward DCT (FALSE).}

\item{uid}{A character string used to uniquely identify the feature transformer.}

\item{...}{Optional arguments; currently unused.}
}
\value{
The object returned depends on the class of \code{x}. If it is a
\code{spark_connection}, the function returns a \code{ml_estimator} or a
\code{ml_estimator} object. If it is a \code{ml_pipeline}, it will return
a pipeline with the transformer or estimator appended to it. If a
\code{tbl_spark}, it will return a \code{tbl_spark} with the transformation
 applied to it.
}
\description{
A feature transformer that takes the 1D discrete cosine transform of a real
  vector. No zero padding is performed on the input vector. It returns a real
  vector of the same length representing the DCT. The return vector is scaled
  such that the transform matrix is unitary (aka scaled DCT-II).
}
\details{
\code{ft_discrete_cosine_transform()} is an alias for \code{ft_dct} for backwards compatibility.
}
\seealso{
Other feature transformers: 
\code{\link{ft_binarizer}()},
\code{\link{ft_bucketizer}()},
\code{\link{ft_chisq_selector}()},
\code{\link{ft_count_vectorizer}()},
\code{\link{ft_elementwise_product}()},
\code{\link{ft_feature_hasher}()},
\code{\link{ft_hashing_tf}()},
\code{\link{ft_idf}()},
\code{\link{ft_imputer}()},
\code{\link{ft_index_to_string}()},
\code{\link{ft_interaction}()},
\code{\link{ft_lsh}},
\code{\link{ft_max_abs_scaler}()},
\code{\link{ft_min_max_scaler}()},
\code{\link{ft_ngram}()},
\code{\link{ft_normalizer}()},
\code{\link{ft_one_hot_encoder}()},
\code{\link{ft_one_hot_encoder_estimator}()},
\code{\link{ft_pca}()},
\code{\link{ft_polynomial_expansion}()},
\code{\link{ft_quantile_discretizer}()},
\code{\link{ft_r_formula}()},
\code{\link{ft_regex_tokenizer}()},
\code{\link{ft_robust_scaler}()},
\code{\link{ft_sql_transformer}()},
\code{\link{ft_standard_scaler}()},
\code{\link{ft_stop_words_remover}()},
\code{\link{ft_string_indexer}()},
\code{\link{ft_tokenizer}()},
\code{\link{ft_vector_assembler}()},
\code{\link{ft_vector_indexer}()},
\code{\link{ft_vector_slicer}()},
\code{\link{ft_word2vec}()}
}
\concept{feature transformers}
