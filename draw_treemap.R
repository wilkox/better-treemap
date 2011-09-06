#read in the data
data = read.csv("matrix.csv", head=TRUE);

#load the library
library(portfolio)

#set the output
pdf("treemap.pdf");

#draw the treemap
map.market(id=data$name, area=data$contrib, group=data$category, color=data$reldif, lab=c(TRUE, TRUE), main="Contribution of Ks to variation between N and S")

#kill the output device
dev.off()
