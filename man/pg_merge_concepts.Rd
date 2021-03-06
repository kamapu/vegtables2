% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pg_merge_concepts.R
\name{pg_merge_concepts}
\alias{pg_merge_concepts}
\alias{pg_merge_concepts.PostgreSQLConnection}
\title{Merge multiple concepts into one}
\usage{
pg_merge_concepts(conn, ...)

\method{pg_merge_concepts}{PostgreSQLConnection}(
  conn,
  names2concepts,
  taxon_relations,
  taxon_traits,
  concept_id,
  ...
)
}
\arguments{
\item{conn}{A database connection provided by \code{\link[=dbConnect]{dbConnect()}}.}

\item{...}{Further arguments passed among methods.}

\item{taxon_relations, taxon_traits, names2concepts}{Character vectors containing the name
of the schema and for the respective information.}

\item{concept_id}{ID of taxon concepts to be merged.}
}
\description{
Different taxon concepts may be merged by taxonomic revisions.

All concepts indicated in argument \code{concept_id} will be set as
synonyms of the first concept in the vector.

Take care of producing backups before starting the manipulation of
databases.
}
\author{
Miguel Alvarez \email{kamapu78@gmail.com}
}
