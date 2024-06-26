args = commandArgs(trailingOnly = TRUE)
if (length(args) == 0) {
  args[[1]] <- "AZ"
}
options(repos = c(CRAN = "https://cloud.r-project.org"))

#Install libraries if they don't exist.
if (!requireNamespace("dplyr", quietly = TRUE)) {
  # Install package
  install.packages("dplyr")
}
if (!requireNamespace("tidyr", quietly = TRUE)) {
  # Install package
  install.packages("tidyr")
}
if (!requireNamespace("googlesheets4", quietly = TRUE)) {
  # Install package
  install.packages("googlesheets4")
}
if (!requireNamespace("googledrive", quietly = TRUE)) {
  # Install package
  install.packages("googledrive")
}
if (!requireNamespace("stringr", quietly = TRUE)) {
  # Install package
  install.packages("stringr")
}
if (!require("BiocManager", quietly = TRUE))
  install.packages("BiocManager")

library(dplyr)

file_locations <- c(
  'meta'="metadata.tsv",
  'sequences'="gisaid.fasta",
  'GISAID_table_description'="tablenamer.csv",
  'county_resolver' = "countyKey.csv",
  'facility' = "facility_modifier.tsv"
)

#Check ------------------

#Filters that are selected using the input args. Currently, we only use AZ for generating nextstrains so this is the only switch that we have provided

filters<- switch(
  args[[1]],
  "AZ" = list(
    "country" = c("USA"),
    "state" = c("Arizona"),
    "variant" = "",
    "root" = "EPI_ISL_426513"
  ),
  
)

#Load the file that will assign types to each of the fields, then read in the file into the GISAID table. Rename Collection.date and Pango.lineage to match what the config file for nextstrain will be expecting.
tabler <- read.csv(file = file_locations['GISAID_table_description'], header = TRUE)

GISAID <- readr::read_tsv(file = file_locations['meta'], col_types = paste0(substr(as.character(tabler$TYPE), start =1 , stop = 1), collapse = ""))
colnames(GISAID)[colnames(GISAID) == 'Collection date'] <- 'collection_date'
colnames(GISAID)[colnames(GISAID) == 'Pango lineage'] <- 'Pango_lineage'

names(GISAID) <- make.names(names(GISAID))

GISAID <- GISAID %>% filter(!Accession.ID %in% c(
  "EPI_ISL_3387525",
  "EPI_ISL_4052437",
  "EPI_ISL_4052437",
  "EPI_ISL_5059295",
  "EPI_ISL_1364670"
))

rm(tabler)
library(tidyr)
library(googlesheets4)
library(googledrive)
library(stringr)
invisible(suppressMessages(suppressWarnings(library(Biostrings))))

#Remove duplicates from GISAID table.
GISAID <- GISAID[!duplicated(GISAID$Virus.name, fromLast = TRUE), ]


#Split the location column into several more specific columns.
suppressWarnings(GISAID <- cbind(
  GISAID[, !(names(GISAID) %in% "Location")],
  separate(GISAID["Location"], sep =' /[ ]*', col="Location", into = c("continent", "country",  "division1", "division2", "division3", "division4"))
))

#table filtering --------------------------------------------------------------------------------------
county_resolver <- read.csv(header = T, file = file_locations['county_resolver'])

GISAID$division2[is.na(GISAID$division2)] <- "None Provided"
GISAID$division2[GISAID$division1 == "california" & GISAID$division2 %in% c("maricopa")] <- "Kern"
GISAID$division1 <- tolower(GISAID$division1)
GISAID$division2 <- tolower(GISAID$division2)

#resolve county using a table that we created manually to fix typos in GISAID and assign the correct county where there are errors. Set to lower case to make simpler. Updates counties when city names were used as well.
GISAID <- left_join(GISAID,county_resolver, by = c('division2'= 'original'))
GISAID[!is.na(GISAID[,'stateReplace']),]$division1 <- as.character(GISAID[!is.na(GISAID[,'stateReplace']),]$stateReplace)
GISAID[!is.na(GISAID[,'replacement']),]$division2 <- as.character(GISAID[!is.na(GISAID[,'replacement']),]$replacement)
GISAID$replacement <- NULL
GISAID$stateReplace <- NULL
counties <- c("apache", "cochise", "coconino", "gila", "graham", "greenlee", "la paz", "maricopa", "mohave", "navajo", "pima", "pinal", "santa cruz", "yavapai", "yuma", "none provided")

GISAID <- GISAID[(GISAID$division2 %in% counties),]

#Fix the rows that have an animal name in the Virus.name. This is the case for a vast minority of samples.
GISAID$headerLead <- GISAID$Virus.name
# Create a new column with the modified values
GISAID$Virus.name <- sapply(strsplit(GISAID$Virus.name, "/"), function(x) {
  if (length(x) == 5) {
    paste(x[-2], collapse = "/")
  } else {
    paste(x, collapse = "/")
  }
})

GISAID <- GISAID %>%
  separate(col = "Virus.name", into = c("virus", "country2", "identifier", "year"), sep = "/") %>%
  select(-country2)

#Sample a subset of data. Get the most recent x rows and sample for 2999 others. Always select the root. This always results in 8000 samples.
# Sort the data frame by date

GISAID <- GISAID[order(GISAID$collection_date, decreasing = TRUE),]

# Select the top x rows
x <- 4000
root_row <- GISAID[GISAID$Accession.ID == filters$root, ]
GISAID <- GISAID[GISAID$Accession.ID != filters$root, ]
top_x_rows <- GISAID[1:x, ]
top_x_rows <- rbind(top_x_rows, root_row)

# Remove rows with NA values from the remaining data frame
remaining_rows <- GISAID[(x + 1):nrow(GISAID), ]
#remaining_rows <- remaining_rows[complete.cases(remaining_rows), ]

# Calculate sampling probabilities for remaining rows
y <- 2500
num_remaining <- nrow(remaining_rows)

if (num_remaining > 1) {
  sampling_probs <- 1 / log(1:num_remaining)
} else {
  sampling_probs <- NA
}
#Get ride of the infinite value
sampling_probs[!is.finite(sampling_probs)] <- 2

# Sample the remaining y rows
# Use a seed that is the current time.
sampled_remaining_rows <- remaining_rows[sample(num_remaining, size = y, replace = FALSE, prob = sampling_probs), ]


# Combine top x rows and sampled remaining rows
GISAID <- rbind(top_x_rows, sampled_remaining_rows)
GISAID <- GISAID[order(GISAID$collection_date), ]

rm(top_x_rows, sampled_remaining_rows, remaining_rows)

#We can put in extra information, "run_id" for tgen samples so we use our master spreadsheet and archive data to get that run_id information.
# service_token <- "/labs/COVIDseq/COVIDpoint/creds.json"
# gs4_deauth()  # Deauthenticate first to ensure a fresh authentication
# gs4_auth(path = service_token)

# master_url <- "https://docs.google.com/spreadsheets/d/1hxVCleH0bTQU84Fd0_uNQDSm-MrivADIMBoPJhegl1I/edit#gid=0"
# archive_url <- "https://docs.google.com/spreadsheets/d/1VefYYtwcvXtSWcsHv4-GGOERVNACOYztIQNV5GNOfB4/edit#gid=1334399407"
# master_data <- read_sheet(master_url)
# archive <- read_sheet(archive_url)

# #Fill non-TGen data with "OTHER"
GISAID$dataset <- "OTHER"

# #Fill in the "dataset" with the run_id, loop through master and archive data.
# for (i in 1:nrow(master_data)) {
#   idx <- grepl(master_data$`rna_id(tg#)`[i], GISAID$identifier)
#   GISAID$dataset[idx] <- master_data$run_id[i]
# }
# for (i in 1:nrow(archive)) {
#   idx <- grepl(archive$`rna_id(tg#)`[i], GISAID$identifier)
#   GISAID$dataset[idx] <- archive$run_id[i]
# }

# rm(archive, master_data)

#Update facilities using the modifier_facility table.
facilitator <- read.table(file = file_locations['facility'], header = T, sep = '\t')

#add fasta identifier
GISAID$strain <- gsub(pattern = " ", replacement = "_", x = paste0(GISAID$identifier, "_", GISAID$division2, "_", substr(GISAID$year, nchar(GISAID$year) - 1, nchar(GISAID$year))))

#Replace facilities with new values.

GISAID$Submitting_Facility <- vector("character", nrow(GISAID))
for (i in 1:nrow(facilitator)) {
  idx <- grepl(facilitator$regex[i], GISAID$identifier)
  GISAID$Submitting_Facility[idx] <- facilitator$facility[i]
}

GISAID$US.location <- paste0(GISAID$division2,"_",GISAID$division1)
GISAID$dataset2 <-""

final_columns <- c('headerLead', 'virus', 'country', 'identifier', 'year', 'Type', 'Accession.ID', 'collection_date', 'Additional.location.information', 'Sequence.length', 'Host', 'Patient.age', 'Gender', 'Clade', 'Pango_lineage', 'Pangolin.version', 'Variant', 'AA.Substitutions', 'Submission.date', 'Is.reference.', 'Is.complete.', 'Is.high.coverage.', 'Is.low.coverage.', 'N.Content', 'continent', 'division1', 'division2', 'division3', 'division4', 'dataset', 'dataset2', 'US.location', 'strain', 'Submitting_Facility')

GISAID <- GISAID[, final_columns, drop = FALSE]

write.table(x = GISAID, file = "subset_metadata.tsv", quote = F, sep = '\t', row.names = F)
write(file = "root.name", x = GISAID$strain[GISAID$Accession.ID == filters$root] )

#Using "headerLead" input the seqkit command line tool will select the fastqs. Then pipe that to remove duplicates, write lines that are 80 characters in length, thread 4 times
con = file("tmp.seqselect.txt")
writeLines(as.character(GISAID$headerLead), con = con)
close(con)

system(sprintf("/home/bvan-tassel/tools/bin/seqkit grep -f tmp.seqselect.txt %s | /home/bvan-tassel/tools/bin/seqkit rmdup  -n -j 4 > tmp.selected_seq.fasta", file_locations['sequences'])) #seqkit grep -f tmp.seqselect.txt %s | seqkit rmdup  -n -w 80 -j 4 > tmp.selected_seq.fasta

#store into DNAStringSet. Update names to remove charactes after '|'
dna_stringset <- readDNAStringSet(filepath= "./tmp.selected_seq.fasta" , format = "FASTA")

names(dna_stringset) <- gsub(perl= TRUE, pattern="\\|.*$", replacement="", names(dna_stringset))

#rename the fasta files.
names(dna_stringset) <- unlist(sapply(names(dna_stringset),function(currentID) {return(GISAID[GISAID$headerLead == currentID,'strain'][1])}))

# save fasta
writeXStringSet(x = dna_stringset, filepath = "./subset_sequences.fasta", format = "FASTA")

system("rm tmp*")
