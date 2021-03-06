#' @name pg_insert_concept
#' @rdname pg_insert_concept
#' 
#' @title Insert names or concepts in PostgreSQL taxonomic lists
#' 
#' @description 
#' Insert synonyms to existing taxa in a PostgreSQL version of [taxlist-class]
#' objects.
#' 
#' This function is updating the tables `taxonNames` and `names2concepts` in
#' the PostgreSQL version of the database.
#' 
#' @param conn A database connection provided by [dbConnect()].
#' @param taxon_names,taxon_relations,names2concepts,taxon_views,taxon_levels
#'     Character vectors indicating the name of the respective schemas and
#'     tables in database.
#' @param df A data frame with new names and related information (including
#'     taxon concept ID).
#' @param clean A logical value indicating cleaning of characters.
#' @param ... Further arguments passed among methods.
#' 
#' @author Miguel Alvarez \email{kamapu78@@gmail.com}
#' 
#' @aliases pg_insert_concept insert_concept_swea
#' 
#' @export pg_insert_concept
#' 
pg_insert_concept <- function(conn, taxon_names, taxon_relations,
		names2concepts, taxon_views, taxon_levels, df, clean=TRUE, ...) {
	if(clean)
		df <- clean_strings(df)
	if(any(!c("TaxonName","AuthorName") %in% colnames(df)))
		stop("Columns 'TaxonName' and 'AuthorName' are mandatory in argument 'df'.")
	if("TaxonConceptID" %in% colnames(df))
		stop("Column 'TaxonConceptID' detected in 'df'. Use 'pg_insert_synonym' instead?")
	taxa <- postgres2taxlist(conn, taxon_names, taxon_relations,
			names2concepts=names2concepts, taxon_views=taxon_views,
			taxon_levels=taxon_levels, verbose=FALSE, ...)
	# Reimport views
	SQL <-  paste0("SELECT *\n",
			"FROM \"", paste(taxon_views, collapse="\".\""), "\";\n")
	temp_views <- dbGetQuery(conn, SQL)
	colnames(temp_views)[colnames(temp_views) == "data_source"] <- "ViewID"
	taxa@taxonViews <- temp_views
	## Cross-check
	# 1: Check duplicated combinations in 'df'
	if(any(duplicated(df[,c("TaxonName","AuthorName")])))
		stop("Duplicated combinations detected in 'df'.")
	# 2: Check combinations already existing in database
	if(any(with(df, paste(TaxonName, AuthorName)) %in% with(taxa@taxonNames,
					paste(TaxonName, AuthorName))))
		stop("Some combinations in 'df' already exist in database.")
	# 3: Check names already existing as accepted names
	if(any(df$TaxonName %in% accepted_name(taxa)$TaxonName))
		stop("Some names are already existing as accepted names in database.")
	# 4: Check existence of parents in database
	if("Parent" %in% colnames(df) &
			!all(df$Parent %in% taxa@taxonRelations$TaxonConceptID))
		stop("Some entries for 'Parent' in 'df' are not occurring in database.")
	# 5: Check existence of levels in database
	if("Level" %in% colnames(df) &
			!all(paste(df$Level) %in% taxlist::levels(taxa)))
		stop("Some entries for 'Level' in 'df' are not occurring in database.")
	# 6: Check existence of view IDs in database
	if("ViewID" %in% colnames(df) &
			!all(paste(df$ViewID) %in% taxa@taxonViews$ViewID))
		stop("Some entries for 'ViewID' in 'df' are not occurring in database.")
	# 7: Check consistency of levels
	if("Level" %in% colnames(df) & "Parent" %in% colnames(df)) {
		new_levels <- as.integer(factor(df$Level, levels=taxlist::levels(taxa)))
		parent_levels <- with(taxa@taxonRelations,
				as.integer(Level[match(df$Parent, TaxonConceptID)]))
		if(any(new_levels >= parent_levels))
			stop(paste("Children cannot be of equal or higher level than",
							"the respective parents."))
	}
	## TODO: Allow the possibility of inserting some taxon traits
	## Prepare data frame
	# Check existence of the name combination
	SQL <- paste0("SELECT \"TaxonUsageID\", \"TaxonName\", \"AuthorName\"",
			"\n", "FROM \"", paste(taxon_names, collapse="\".\""), "\";")
	db_names <- dbGetQuery(conn, SQL)
	# TODO: this will work only for one entry!!!
	if(with(df, paste(TaxonName, AuthorName)) %in%
			with(db_names, paste(TaxonName, AuthorName))) {
		message(paste0("Taxon name '", with(df, paste(TaxonName, AuthorName)),
								"' already in database. ",
								"This name will be recycled.\n"))
		usage_id <- unlist(db_names[with(db_names,
										paste(TaxonName, AuthorName)) ==
						with(df, paste(TaxonName, AuthorName)),
				"TaxonUsageID"]) - 1
	} else {
		SQL <- paste0("SELECT MAX(\"TaxonUsageID\")", "\n",
				"FROM \"", paste(taxon_names, collapse="\".\""), "\";", "\n")
		usage_id <- unlist(dbGetQuery(conn, SQL))
	}
	df$TaxonUsageID <- usage_id + c(1:nrow(df))
	df$TaxonConceptID <- max(taxa@taxonRelations$TaxonConceptID) + c(1:nrow(df))
	# 2: Get colnames of Postgres tables
	description <- get_description(conn)
	col_names <- with(description,
			column[schema == taxon_names[1] & table == taxon_names[2]])
	col_relations <- with(description,
			column[schema == taxon_relations[1] & table == taxon_relations[2]])
	## Import tables
	# 2: Insert to database
	if(!with(df, paste(TaxonName, AuthorName)) %in%
			with(db_names, paste(TaxonName, AuthorName))) {
		pgInsert(conn, taxon_names, df[,colnames(df) %in% col_names])
	}
	pgInsert(conn, taxon_relations, df[,colnames(df) %in% col_relations])
	pgInsert(conn, names2concepts,
			data.frame(df[,c("TaxonUsageID", "TaxonConceptID")],
					NameStatus="accepted", stringsAsFactors=FALSE))
}

#' @rdname pg_insert_concept
#' @aliases insert_concept_swea
#' 
#' @export insert_concept_swea
#' 
insert_concept_swea <- function(conn,
		taxon_names=c("tax_commons", "taxonNames"),
		taxon_relations=c("swea_dataveg", "taxonRelations"),
		names2concepts=c("swea_dataveg", "names2concepts"),
		taxon_views=c("commons","data_source"),
		taxon_levels=c("tax_commons","taxonLevels"),
		df, ...) {
	pg_insert_concept(conn, taxon_names, taxon_relations, names2concepts,
			taxon_views, taxon_levels, df, ...)
}
