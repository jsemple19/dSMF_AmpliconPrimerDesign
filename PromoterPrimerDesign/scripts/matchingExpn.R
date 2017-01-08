# 2016-12-20
# matchingExpn.R
# takes list of genes for which primers were designed on X chr and assigns them to quantiles of
# L3 gene expression in order to match to autosomal genes 

setwd("/media/jenny/670FC52648FA85C4/Documents/MeisterLab/dSMF/PromoterPrimerDesign/scripts")

#read in genes selected from ChrX
chosenX<-read.csv("./XdcPrimers/DM_DE_promoter_test_primers_WS250_subset.csv",header=TRUE,stringsAsFactors=FALSE)
chosenX<-chosenX[chosenX$finalSelected=="y","Gene_WB_ID"]

# read in original expression dataset to check it
#wormG<-read.csv("../../expressionMatching/worm_gene.csv")
#wormG<-wormG[,grep("L3",names(wormG))]
#cor(wormG$L3,wormG$N2_L3-1)
#cor(wormG$L3,wormG$L3_N2_L3-1)
#cor(wormG$N2_L3-1,wormG$L3_N2_L3-1)
#correlation strongest with N2_L3-1 and L3_N2_L3-1 probably becuase most of sequencing reads came
#from those runs? L3_N2_L3-1 is probably a weighted average of the two experiments.

#use combined expression filtered by Peter
wormG<-read.csv("../../expressionMatching/Gene_expression_Gerstein_combined.csv",stringsAsFactors=FALSE)
sum(is.na(wormG$Gene))

#convert gene names to wb gene ids
source("/media/jenny/670FC52648FA85C4/Documents/MeisterLab/GenomeVer/geneNameConversion/convertingGeneNamesFunction.R")
conversionTable<-convertGeneNames(wormG$Gene,inputType="wormbase_gene_seq_name")

i<-match(conversionTable$wormbase_gene_seq_name,wormG$Gene)
wormG<-cbind(conversionTable,wormG[i,])


#remove nonexpressed genes
expressed<-wormG[wormG$L3_N2_L3.1>0,]
#determine the cutoffs for gene expression to define deciles in this dataset
qt<-quantile(expressed$L3_N2_L3.1,probs=seq(0,1,0.1))
#ranks<-sapply(expressed$L3_N2_L3.1,function(x) {max(which(x>qt))})

### now look at the distribution of my chosen genes on X among the deciles:
#filter table for genes with primers on X
chosenXexpn<-wormG[match(chosenX, wormG$wormbase_gene),]
#check which decile they fall into
ranksX<-sapply(chosenXexpn$L3_N2_L3.1,function(x) {max(which(x>qt))})
#look at the distribution
table(ranksX)
######old:
#decile:          3  4  5  6  7  8  9 10 
#number of genes: 4  5  4 12  7  5  3  8
######new:
# decile:         3  4  5  6  7  8  9 10 
#number of genes: 2  4  5  8  8  3  2 16 

### now see which deciles the autosomal genes fall into

#read in genes for which primers were designed on autosomes
chosenA<-read.table("./AdcPrimers/DM_DE_promoter_test_primers_WS250.tab",header=TRUE,stringsAsFactors=FALSE)

#subset the expression table to the autosomal genes with primers
i<-match(chosenA$Gene_WB_ID, expressed$wormbase_gene)
chosenAexpn<-expressed[i,]
#check which decile they fall into
ranksA<-sapply(chosenAexpn$L3_N2_L3.1,function(x) {max(which(x>qt))})
#look at the distribution
table(ranksA)
############old:
#decile:            -Inf  1    2    3    4    5    6    7    8    9   10 
#number of genes:     7   13   36   40   67   90  124  144  199  192  236 
###########new:
#decile:           -Inf    1    2    3    4    5    6    7    8    9   10 
#number of genes:    14   29   51   48   93  111  151  172  233  257  352 

#save the ranks into the primer design table
chosenA<-cbind("decile"=ranksA,chosenA)

#### deal with problem that output .tab and .bed have different numbers of rows (amplicons
# that are rejected??):
bedA<-read.delim("./AdcPrimers/test_primers_bed_WS250.bed",stringsAsFactors=FALSE,header=FALSE)
#extract wb gene id from primer id column
bedA<-data.frame("Gene_WB_ID"=sapply(strsplit(bedA$V4,".",fixed=T), '[[',2),
                 "location"=paste0(bedA$V1,":",bedA$V2,"-",bedA$V3),
                 bedA, stringsAsFactors=FALSE)
bedA<-bedA[bedA$Gene_WB_ID %in% chosenA$Gene_WB_ID,]
bedA<-bedA[order(match(bedA$Gene_WB_ID,chosenA$Gene_WB_ID)),]
#add bedfile data for location (and names to double check sorting):
chosenA$nameInBedFile<-bedA$V4
chosenA$location<-bedA$location
chosenA$finalSelected<-""
#reorder columns
chosenA<-chosenA[,c(19,1:3,17:18,4:16)]

#write in which ones have already been selected (just need to adjust numbers in categories
#not rechoose them all)
oldChosenA<-read.csv("./AdcPrimers_old/DM_DE_promoter_test_primers_WS250_withRanks_subset.csv",
                                   header=TRUE,stringsAsFactors=FALSE)
oldChosenA<-oldChosenA[oldChosenA$FinalSelected=="y","Gene_WB_ID"]
chosenA$finalSelected[chosenA$Gene_WB_ID %in% oldChosenA]<-"y"

write.csv(chosenA,"./AdcPrimers/DM_DE_promoter_test_primers_WS250_withRanks.csv")


##############3 after doing manual selection: check for similar expression patterns
finalChosenA<-read.csv("./AdcPrimers/DM_DE_promoter_test_primers_WS250_withRanks_subset.csv",
                       header=TRUE,stringsAsFactors=FALSE)
finalChosenA<-finalChosenA[finalChosenA$finalSelected=="y","Gene_WB_ID"]

expnChosen<-rbind(cbind("chr"=rep("chrX",48),expressed[expressed$wormbase_gene %in% chosenX,]),
                  cbind("chr"=rep("Autosomes",48),expressed[expressed$wormbase_gene %in% finalChosenA,]))

library(ggplot2)
library(reshape)
#ggplot(expnChosen[,c(1,3,7,8,10:17)],aes(x="chr",y="PolII_EE_FE"))+geom_boxplot()

pdf(file="./primerQC.pdf", width=11,height=8,paper="a4r")

mm=melt(expnChosen[,c(1,3,7,8,10:17)],id=c("wormbase_gene","chr"))
names(mm)<-c("wormbase_gene","chr","dataset","expression")
ggplot(mm,aes(x=chr,y=log2(expression),fill=chr)) + geom_boxplot() + facet_wrap(~dataset,nrow=2)


############### compare other attirbutes of primers
chosenX<-read.csv("./XdcPrimers/DM_DE_promoter_test_primers_WS250_subset.csv",header=TRUE,stringsAsFactors=FALSE)
chosenX<-chosenX[chosenX$finalSelected=="y",]
#names(chosenX)<-c(names(chosenX)[1],"fragID",names(chosenX)[2:18])
#names(chosenX)[5]<-"Amplicon"
names(chosenX)[6]<-"orientation"


finalChosenA<-read.csv("./AdcPrimers/DM_DE_promoter_test_primers_WS250_withRanks_subset.csv",
                       header=TRUE,stringsAsFactors=FALSE)
finalChosenA<-finalChosenA[finalChosenA$finalSelected=="y",]
names(finalChosenA)[6]<-"NameFromBEDfile"
#names(finalChosenA)[2]<-"fragID"
#names(finalChosenA)[5]<-"PrimerID"
names(finalChosenA)[7]<-"Amplicon"

primerData<-rbind(cbind("chr"=rep("chrX",48),chosenX[,4:19]),
                  cbind("chr"=rep("Autosomes",48),finalChosenA[,c(6,7,5,8:20)]))

primerData<-cbind(primerData,"location"=unlist(lapply(sapply(primerData$Amplicon,strsplit,":"),'[[',1)))
table(primerData$location)
#chrI  chrII chrIII  chrIV   chrV   chrX 
#7      9      6     10     16     48 

table(primerData$orientation,primerData$chr)
#chrX Autosomes
#fw   18        22
#rc   30        26

#names(mm)<-c("wormbase_gene","chr","dataset","expression")
#ggplot(mm,aes(x=chr,y=log2(expression),fill=chr)) + geom_boxplot() + facet_wrap(~dataset,nrow=2)
mm=melt(primerData[,c(1,2,7:17)],id=c("NameFromBEDfile","chr"))
ggplot(mm,aes(x=chr,y=value,fill=chr)) + geom_boxplot() + 
    facet_wrap(~variable,scales="free")

mm=melt(primerData[,c(1,2,9:17)],id=c("NameFromBEDfile","chr"))
ggplot(mm,aes(value,fill=chr)) + geom_histogram() + 
  facet_wrap(~chr+variable,scales="free",nrow=2)

dev.off()

table(primerData$FwC.covered+primerData$RvC.covered)
#0  1  2  3  4  5  6  7  8  9 10 
#6  8 18 12 22 11  7  5  4  1  2 

primerTable<-data.frame("primerNames"=c(paste0("X",1:48,"_f"),paste0("A",1:48,"_f"), paste0("X",1:48,"_r"), paste0("A",1:48,"_r")),
      "seq"=c(primerData$Fwseq,primerData$Rvseq))
      
write.csv(primerTable,"primerSeqs2order.csv",row.names=FALSE,quote=FALSE)