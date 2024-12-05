# updating colors for Pango lineage
colors <- read.csv(file = "/tnorth_labs/PublicHealth/Scripts_repos/jmonroy-nieto/scripTools/T0013_tbls/pangocolors.csv", header=TRUE, check.names=FALSE)
pnglng <- colors[colors$feature == "Pango_lineage",]
write.table(x = pnglng, file = "running_NS/config/colors.tsv", quote = F, row.names = F, col.names = F, sep = '\t', append = TRUE)
