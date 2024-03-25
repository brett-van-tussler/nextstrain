#updating colors for Pango lineage
colors <- read.csv(file = "/labs/PublicHealth/Scripts_repos/jmonroy-nieto/scripTools/T0013_tbls/pangocolors.csv", header=TRUE, check.names=FALSE)
pnglng <- colors[colors$feature == "Pango_lineage",]
print(pnglng)
div2 <- colors[colors$feature == "division2",]
config_file <- rbind(pnglng,div2)
write.table(x = config_file, file = "running_NS/config/colors.tsv", quote = F, row.names = F, col.names = F, sep = '\t', append = TRUE)

