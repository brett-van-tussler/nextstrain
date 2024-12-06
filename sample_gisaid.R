# Get command line arguments; default to "AZ" if none are provided
args = commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  args[[1]] <- "AZ"
}

# Set CRAN repository for package installations
options(repos = c(CRAN = "https://cloud.r-project.org"))

# Install necessary libraries if they are not already installed
if (!requireNamespace("dplyr", quietly = TRUE)) {
  install.packages("dplyr")
}
if (!requireNamespace("tidyr", quietly = TRUE)) {
  install.packages("tidyr")
}
if (!requireNamespace("googlesheets4", quietly = TRUE)) {
  install.packages("googlesheets4")
}
if (!requireNamespace("googledrive", quietly = TRUE)) {
  install.packages("googledrive")
}
if (!requireNamespace("stringr", quietly = TRUE)) {
  install.packages("stringr")
}
if (!require("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager")
}

# Load required library
library(dplyr)

# Define file locations for metadata, sequences, and other supporting files
file_locations <- c(
  'meta' = "metadata.tsv",
  'sequences' = "gisaid.fasta",
  'GISAID_table_description' = "tablenamer.csv",
  'county_resolver' = "countyKey.csv",
  'facility' = "facility_modifier.tsv"
)

# Define filters for data processing, defaulting to Arizona
filters <- switch(
  args[[1]],
  "AZ" = list(
    "country" = c("USA"),
    "state" = c("Arizona"),
    "variant" = "",
    "root" = "EPI_ISL_426513"
  )
)

# Load a table that maps field types and read metadata with specified types
tabler <- read.csv(file = file_locations['GISAID_table_description'], header = TRUE)
GISAID <- readr::read_tsv(
  file = file_locations['meta'],
  col_types = paste0(substr(as.character(tabler$TYPE), start = 1, stop = 1), collapse = "")
)

# Rename columns to match Nextstrain configuration expectations
colnames(GISAID)[colnames(GISAID) == 'Collection date'] <- 'collection_date'
colnames(GISAID)[colnames(GISAID) == 'Pango lineage'] <- 'Pango_lineage'
names(GISAID) <- make.names(names(GISAID))

# Filter out invalid records based on accession IDs
GISAID <- GISAID %>% filter(!Accession.ID %in% c(
  "EPI_ISL_3387525",
  "EPI_ISL_4052437",
  "EPI_ISL_5059295",
  "EPI_ISL_1364670"
))

# Remove duplicate records based on Virus.name
GISAID <- GISAID[!duplicated(GISAID$Virus.name, fromLast = TRUE), ]

# Split the "Location" column into separate geographic components
suppressWarnings(
  GISAID <- cbind(
    GISAID[, !(names(GISAID) %in% "Location")],
    separate(GISAID["Location"], sep = ' /[ ]*', col = "Location", into = c("continent", "country", "division1", "division2", "division3", "division4"))
  )
)

# Load county resolver to clean and correct geographic data
county_resolver <- read.csv(header = TRUE, file = file_locations['county_resolver'])
GISAID$division2[is.na(GISAID$division2)] <- "None Provided"
GISAID$division1 <- tolower(GISAID$division1)
GISAID$division2 <- tolower(GISAID$division2)

# Resolve typos and errors in geographic information using county resolver
GISAID <- left_join(GISAID, county_resolver, by = c('division2' = 'original'))
GISAID$division1[!is.na(GISAID$stateReplace)] <- as.character(GISAID$stateReplace[!is.na(GISAID$stateReplace)])
GISAID$division2[!is.na(GISAID$replacement)] <- as.character(GISAID$replacement[!is.na(GISAID$replacement)])
GISAID$replacement <- NULL
GISAID$stateReplace <- NULL

# Filter data to include only specific counties
counties <- c("apache", "cochise", "maricopa", "pima", "yuma", "none provided")
GISAID <- GISAID[GISAID$division2 %in% counties, ]

# Clean and restructure Virus.name field for consistency
GISAID$Virus.name <- sapply(strsplit(GISAID$Virus.name, "/"), function(x) {
  if (length(x) == 5) {
    paste(x[-2], collapse = "/")
  } else {
    paste(x, collapse = "/")
  }
})



# Separate Virus.name into multiple columns for specific attributes
GISAID <- GISAID %>%
  separate(col = "Virus.name", into = c("virus", "country2", "identifier", "year"), sep = "/") %>%
  select(-country2)

# Sort records by collection date and filter for recent and representative data
GISAID <- GISAID[order(GISAID$collection_date, decreasing = TRUE), ]
x <- 4000
root_row <- GISAID[GISAID$Accession.ID == filters$root, ]
GISAID <- GISAID[GISAID$Accession.ID != filters$root, ]
top_x_rows <- GISAID[1:x, ]
remaining_rows <- GISAID[(x + 1):nrow(GISAID), ]

# Sample remaining rows with weighted probabilities
sampling_probs <- 1 / log(1:nrow(remaining_rows))
sampling_probs[!is.finite(sampling_probs)] <- 2
sampled_remaining_rows <- remaining_rows[sample(nrow(remaining_rows), size = 2500, prob = sampling_probs), ]

# Combine sampled and sorted data
GISAID <- rbind(top_x_rows, sampled_remaining_rows)
GISAID <- GISAID[order(GISAID$collection_date), ]

# Add strain identifier and clean up facilities data
facilitator <- read.table(file = file_locations['facility'], header = TRUE, sep = '\t')
GISAID$Submitting_Facility <- vector("character", nrow(GISAID))
for (i in 1:nrow(facilitator)) {
  idx <- grepl(facilitator$regex[i], GISAID$identifier)
  GISAID$Submitting_Facility[idx] <- facilitator$facility[i]
}

# Write final processed data to files
write.table(GISAID, file = "subset_metadata.tsv", quote = FALSE, sep = '\t', row.names = FALSE)
write("root.name", GISAID$strain[GISAID$Accession.ID == filters$root])

#Using "headerLead" input the seqkit command line tool will select the fastqs. Then pipe that to remove duplicates, write lines that are 80 characters in length, thread 4 times
con = file("tmp.seqselect.txt")
writeLines(as.character(GISAID$headerLead), con = con)
close(con)
system(sprintf("seqkit grep -f tmp.seqselect.txt %s | seqkit rmdup  -n -j 4 > tmp.selected_seq.fasta", file_locations['sequences'])) 

#store into DNAStringSet. Update names to remove charactes after '|'
dna_stringset <- readDNAStringSet(filepath= "./tmp.selected_seq.fasta" , format = "FASTA")

# Remove all characters after the first | in the sequence names using a regular expression (\\|.*$ matches everything from | to the end of the string)
names(dna_stringset) <- gsub(perl= TRUE, pattern="\\|.*$", replacement="", names(dna_stringset))

# update the sequence names in the dna_stringset by replacing them with corresponding strain names (strain names look like this: AZ-TG268903_none_provided_20)found in the GISAID
names(dna_stringset) <- unlist(sapply(names(dna_stringset),function(currentID) {return(GISAID[GISAID$headerLead == currentID,'strain'][1])}))

# save fasta to the subset files
writeXStringSet(x = dna_stringset, filepath = "./subset_sequences.fasta", format = "FASTA")

system("rm tmp*")
