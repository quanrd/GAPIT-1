`GAPIT.Main` <-
function(Y,G=NULL,GD=NULL,GM=NULL,KI=NULL,Z=NULL,CV=NULL,CV.Inheritance=NULL,SNP.P3D=TRUE,GP=NULL,GK=NULL,
                group.from=1000000 ,group.to=1,group.by=10,kinship.cluster="average", kinship.group='Mean',kinship.algorithm=NULL,DPP=50000,
               	ngrid = 100, llin = -10, ulim = 10, esp = 1e-10,
                file.path=NULL,file.from=NULL, file.to=NULL, file.total=NULL, file.fragment = 512, file.G=NULL, file.Ext.G=NULL,file.GD=NULL, file.GM=NULL, file.Ext.GD=NULL,file.Ext.GM=NULL,
                SNP.MAF=0,FDR.Rate=1,SNP.FDR=1,SNP.effect="Add",SNP.impute="Middle",PCA.total=0,  GAPIT.Version=GAPIT.Version,
                name.of.trait, GT = NULL, SNP.fraction = 1, seed = 123, BINS = 20,SNP.test=TRUE,SNP.robust="FaST",
                LD.chromosome=NULL,LD.location=NULL,LD.range=NULL,
                bin.from=10000,bin.to=5000000,bin.by=1000,inclosure.from=10,inclosure.to=1000,inclosure.by=10,
                SNP.permutation=FALSE,SNP.CV=NULL,
                genoFormat=NULL,hasGenotype=NULL,byFile=NULL,fullGD=NULL,PC=NULL,GI=NULL, Timmer = NULL, Memory = NULL,
                sangwich.top=NULL,sangwich.bottom=NULL,QC=TRUE,GTindex=NULL,LD=0.05,
                file.output=TRUE,cutOff=0.01, Model.selection = FALSE, Create.indicator = FALSE,
				QTN=NULL, QTN.round=1,QTN.limit=0, QTN.update=TRUE, QTN.method="Penalty", Major.allele.zero = FALSE,
        QTN.position=NULL){
#Object: To perform GWAS and GPS (Genomic Prediction or Selection)
#Output: GWAS table (text file), QQ plot (PDF), Manhattan plot (PDF), genomic prediction (text file), and
#        genetic and residual variance components
#Authors: Zhiwu Zhang
# Last update: may 12, 2011
##############################################################################################



#Return imediatly in one of these situtiona
shortcut=FALSE
LL.save=1e10
#In case of null Y and null GP, return genotype only  
thisY=Y[,2]
thisY=thisY[!is.na(thisY)]
if(length(thisY) <3){
 shortcut=TRUE
 }else{
  if(var(thisY) ==0) shortcut=TRUE
}
        
if(shortcut){
print(paste("Y is empty. No GWAS/GS performed for ",name.of.trait,sep=""))
return (list(compression=NULL,kinship.optimum=NULL, kinship=KI,PC=PC,GWAS=NULL, GPS=NULL,Pred=NULL, REMLs=NULL,Timmer=Timmer,Memory=Memory))
}

#QC
print("------------Examining data (QC)------------------------------------------")
if(is.null(Y)) stop ("GAPIT says: Phenotypes must exist.")
if(is.null(KI)&missing(GD) & kinship.algorithm!="SUPER") stop ("GAPIT says: Kinship is required. As genotype is not provided, kinship can not be created.")

#When GT and GD are missing, force to have fake ones (creating them from Y),GI is not required in this case
if(is.null(GD) & is.null(GT)) {
	GT=as.matrix(Y[,1])
	GD=matrix(1,nrow(Y),1)	
  GI=as.data.frame(matrix(0,1,3) )
  colnames(GI)=c("SNP","Chromosome","Position")
}

#merge CV with PC
if(PCA.total>0&!is.null(CV))CV=GAPIT.CVMergePC(CV,PC)
if(PCA.total>0&is.null(CV))CV=PC

#Create Z as identity matrix from Y if it is not provided
if(kinship.algorithm!="None" & kinship.algorithm!="SUPER" & is.null(Z)){
taxa=as.character(Y[,1])
Z=as.data.frame(diag(1,nrow(Y)))
Z=rbind(taxa,Z)
taxa=c('Taxa',as.character(taxa))
Z=cbind(taxa,Z)
}

#Add the part of non proportion in Z matrix
if(kinship.algorithm!="None" & kinship.algorithm!="SUPER" & !is.null(Z))
{
  if(nrow(Z)-1<nrow(Y)) Z=GAPIT.ZmatrixFormation(Z=Z,Y=Y)
}

#Create CV with all 1's if it is not provided
noCV=FALSE
if(is.null(CV)){
noCV=TRUE
CV=Y[,1:2]
CV[,2]=1
colnames(CV)=c("taxa","overall")
}

#Remove duplicat and integragation of data
print("QC is in process...")

CVI <- CV
if(QC)
{
  qc <- GAPIT.QC(Y=Y,KI=KI, GT=GT,CV=CV,Z=Z,GK=GK)
  GTindex=qc$GTindex
  Y=qc$Y
  KI=qc$KI
  CV=qc$CV
  Z=qc$Z
  GK=qc$GK

  if(noCV)CVI=qc$CV
}

#TDP
if(kinship.algorithm=="None" )
{
	if(min(CV[,2])==max(CV[,2])) CV=NULL
	
	theTDP=GAPIT.TDP(Y=Y,CV=CV,SNP=as.data.frame(cbind(GT[GTindex],as.matrix(as.data.frame(GD[GTindex,])))),
			QTN=QTN, Round=QTN.round,QTN.limit=QTN.limit, QTN.update=QTN.update, Method=QTN.method)
#print(dim(GM))
#print(length(theTDP$p))

theGWAS=cbind(GM,theTDP$p,NA,NA,NA)	

return (list(Compression=NULL,kinship.optimum=NULL, kinship=NULL,PC=NULL,GWAS=theGWAS, GPS=NULL,Pred=NULL,REMLs=NULL,QTN=theTDP$QTN,Timmer=Timmer,Memory=Memory))

}

print("The value of QC is")
print(QC)

rm(qc)
gc()

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="QC")
Memory=GAPIT.Memory(Memory=Memory,Infor="QC")

#Get indicator of sangwich top and bottom
byPass.top=FALSE
byPass=FALSE
#if(!is.null(sangwich.bottom)) byPass=((sangwich.bottom=="FaST" | sangwich.bottom=="SUPER" | sangwich.bottom=="DC" )& is.null(GP)   )
if(!is.null(sangwich.top)) byPass.top=((sangwich.top=="FaST" | sangwich.top=="SUPER" | sangwich.top=="DC" )                 )
if(!is.null(sangwich.bottom)) byPass=((sangwich.bottom=="FaST" | sangwich.bottom=="SUPER" | sangwich.bottom=="DC" )                 )

print("Try to group from and to were set to 1")

if(byPass){
print("group from and to were set to 1")
  group.from=1
  group.to=1
}

print("------------Examining data (QC) done-------------------------------------")

#Sagnwich top bun: To gep GP if it is not provided
if(!is.null(sangwich.top) & is.null(GP))
{
print("-------------------Sandwich top bun-----------------------------------")

#Create GK if not provided
  if(is.null(GK)){
#    set.seed(1)
    nY=floor(nrow(Y)*.9)
    nG=ncol(GD)
    if(nG>nY){snpsam=sample(1:nG,nY)}else{snpsam=1:nG}
    GK=GD[GTindex,snpsam]
    SNPVar=apply(as.matrix(GK),2,var)
    GK=GK[,SNPVar>0]
    GK=cbind(as.data.frame(GT[GTindex]),as.data.frame(GK)) #add taxa
    
  }
  
  #myGD=cbind(as.data.frame(GT),as.data.frame(GD)) 
  GP=GAPIT.Bread(Y=Y,CV=CV,Z=Z,KI=KI,GK=GK,GD=cbind(as.data.frame(GT),as.data.frame(GD)),GM=GI,method=sangwich.top,GTindex=GTindex,LD=LD,file.output=file.output)$GWAS
  GK=NULL
  
print("-------------------Sagnwich top bun: done-----------------------------")  

} 

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="SagnwichTop")
Memory=GAPIT.Memory(Memory=Memory,Infor="SagnwichTop")

#Sandwich burger and dressing
print("-------------------Sandwich burger and dressing------------------------")

#Handler of group boundry
if(group.from>group.to) stop("GAPIT says: group.to should  be larger than group.from. Please correct them!")

if(is.null(CV) | (!is.null(CV)& group.to<ncol(CV))) {
#The minimum of group is number of columns in CV
  group.from=1
  group.to=1
  warning("The upper bound of groups (group.to) is not sufficient. both boundries were set to a and GLM is performed!")
}

if(!is.null(CV)& group.from<1) {
  group.from=1 #minimum of group is number of columns in CV
  warning("The lower bound of groups should be 1 at least. It was set to 1!")
}
 
nk=1000000000
if(!is.null(KI)) nk=min(nk,nrow(KI))
if(!is.null(GK)) nk=min(nk,nrow(GK))

if(!is.null(KI))
{
  if(group.to>nk) {
    #group.to=min(nrow(KI),length(GTindex)) #maximum of group is number of rows in KI
    group.to=nk #maximum of group is number of rows in KI
    warning("The upper bound of groups is too high. It was set to the size of kinship!") 
  }
	if(group.from>nk){ 
    group.from=nk
    warning("The lower bound of groups is too high. It was set to the size of kinship!") 
  } 
}

if(!is.null(CV)){
 	if(group.to<=ncol(CV)+1) {
	#The minimum of group is number of columns in CV
	  group.from=ncol(CV)+2
	  group.to=ncol(CV)+2
	  warning("The upper bound of groups (group.to) is not sufficient. both boundries were set to their minimum and GLM is performed!")
	}
}

#bin.fold=ceiling(log2(bin.to/bin.from))
#bin.seq=0:bin.fold
#bin.level=bin.from*2^bin.seq

#Set upper bound for inclosure.to
if(inclosure.to>nrow(Y))inclosure.to=nrow(Y)-1

#set inclosure loop levels
bin.level=seq(bin.from,bin.to,by=bin.by)
inclosure=seq(inclosure.from,inclosure.to,by=inclosure.by)

#Optimization for group number, cluster algorithm and kinship type
GROUP=seq(group.to,group.from,by=-group.by)#The reverse order is to make sure to include full model
if(missing("kinship.cluster")) kinship.cluster=c("ward", "single", "complete", "average", "mcquitty", "median", "centroid")
if(missing("kinship.group")) kinship.group=c("Mean", "Max", "Min", "Median")
numSetting=length(GROUP)*length(kinship.cluster)*length(kinship.group)*length(bin.level)*length(inclosure)

#Reform Y, GD and CV into EMMA format
ys=as.matrix(Y[2])
X0=as.matrix(CV[,-1])
CV.taxa=CVI[,1]

#Initial
count=0
Compression=matrix(,numSetting,6)
colnames(Compression)=c("Type","Cluster","Group","REML","VA","VE")

#add indicator of overall mean
if(min(X0[,1])!=max(X0[,1])) X0 <- cbind(1, X0) #do not add overall mean if X0 has it already at first column


Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="DataProcessing")
Memory=GAPIT.Memory(Memory=Memory,Infor="DataProcessing")

print("-------------------------Iteration in process--------------------------")
print(paste("Total iterations: ",numSetting,sep=""))

#Loop to optimize cluster algorithm, group number and kinship type
for (bin in bin.level){
for (inc in inclosure){

#Grill: update KI if GK or GP is provided
if(!byPass & (!is.null(GK) | !is.null(GP)))
{  
  print("Grilling KI...")

    myGenotype<-GAPIT.Genotype(G=NULL,GD=cbind(as.data.frame(GT),as.data.frame(GD)),GM=GI,KI=NULL,kinship.algorithm=kinship.algorithm,PCA.total=0,SNP.fraction=SNP.fraction,SNP.test=SNP.test,
                  file.path=file.path,file.from=file.from, file.to=file.to, file.total=file.total, file.fragment = file.fragment, file.G=file.G, 
                  file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
                  SNP.MAF=SNP.MAF,FDR.Rate = FDR.Rate,SNP.FDR=SNP.FDR,SNP.effect=SNP.effect,SNP.impute=SNP.impute,
                  LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range,
                  GP=GP,GK=GK,bin.size=bin,inclosure.size=inc,SNP.CV=SNP.CV,
                  Timmer = Timmer, Memory = Memory,GTindex=GTindex,sangwich.top=NULL,sangwich.bottom=sangwich.bottom,
                  file.output=file.output, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)
   
  Timmer=myGenotype$Timmer
  Memory=myGenotype$Memory

  KI=myGenotype$KI

#update group set by new KI
  nk=nrow(KI)
GROUP=GROUP[GROUP<=nk]
}

for (ca in kinship.cluster){
for (group in GROUP){
for (kt in kinship.group){

#Do not screen SNP unless existing genotype and one combination
if(numSetting==1 & hasGenotype){
 optOnly=FALSE
}else{
optOnly=TRUE
}
if(!SNP.test) optOnly=TRUE

if(optOnly | Model.selection){
 colInclude=1
 optOnly = TRUE
}else{
 colInclude=c(1:ncol(GD))
}

if(!optOnly) {print("Compressing and Genome screening..." )}
count=count+1

#Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 1")
#Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 1")

if(!byPass)
{
if(count==1)print("-------Mixed model with Kinship-----------------------------")
if(group<ncol(X0)+1) group=1 # the emma function (emma.delta.REML.dLL.w.Z) does not allow K has dim less then CV. turn to GLM (group=1)
  
cp <- GAPIT.Compress(KI=KI,kinship.cluster=ca,kinship.group=kt,GN=group,Timmer=Timmer,Memory=Memory)
Timmer=cp$Timmer
Memory=cp$Memory

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_cp")
Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2_cp")

#print("BK...")
bk <- GAPIT.Block(Z=Z,GA=cp$GA,KG=cp$KG)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_bk")
Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 bk")

#print("ZC...")
zc <- GAPIT.ZmatrixCompress(Z=Z,GAU =bk$GA)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_zc")
Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 zc")

#print("wraping...")
#Reform KW and Z into EMMA format

zrow=nrow(zc$Z)
zcol=ncol(zc$Z)-1
#Z1=matrix(as.numeric(as.matrix(zc$Z[,-1])),nrow=zrow,ncol=zcol)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Prio PreP3D")
Memory=GAPIT.Memory(Memory=Memory,Infor="Prio PreP3D")

#Evaluating maximum likelohood
#print("Calling EMMAxP3D...")

#print("It made it to here")
#print("The dimension of xs is:")
#print("The value of SNP.impute is")
#print(SNP.impute)

#write.table(zc$Z, "Z.csv", quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)

#print(dim(as.matrix(as.data.frame(GD[GTindex,colInclude]))))
p3d <- GAPIT.EMMAxP3D(ys=ys,xs=as.matrix(as.data.frame(GD[GTindex,colInclude])),K = as.matrix(bk$KW) ,Z=matrix(as.numeric(as.matrix(zc$Z[,-1])),nrow=zrow,ncol=zcol),X0=X0,CVI=CVI,CV.Inheritance=CV.Inheritance,GI=GI,SNP.P3D=SNP.P3D,Timmer=Timmer,Memory=Memory,fullGD=fullGD,
        SNP.permutation=SNP.permutation, GP=GP,
			 file.path=file.path,file.from=file.from,file.to=file.to,file.total=file.total, file.fragment = file.fragment, byFile=byFile, file.G=file.G,file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
       GTindex=GTindex,genoFormat=genoFormat,optOnly=optOnly,SNP.effect=SNP.effect,SNP.impute=SNP.impute,name.of.trait=name.of.trait, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)

Timmer=p3d$Timmer
Memory=p3d$Memory

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Post PreP3D")
Memory=GAPIT.Memory(Memory=Memory,Infor="Post PreP3D")

#print("Cluster algorithm, kinship type, groups, VG, Ve and REML:")
print(paste(count, "of",numSetting,"--","Vg=",round(p3d$vgs,4), "VE=",round(p3d$ves,4),"-2LL=",round(p3d$REMLs,2), "  Clustering=",ca,"  Group number=", group ,"  Group kinship=",kt,sep = " "))

#Recoding the optimum KI
if(count==1){
  KI.save=KI
  LL.save=p3d$REMLs
}else{
  if(p3d$REMLs<LL.save){
    KI.save=KI
    LL.save=p3d$REMLs
  }
}

#print(paste("CA is ",ca))
#print(paste("group is ",group))
#print(paste("kt is ",kt))

#recording Compression profile on array
Compression[count,1]=kt
Compression[count,2]=ca
Compression[count,3]=group
Compression[count,4]=p3d$REMLs
Compression[count,5]=p3d$vgs
Compression[count,6]=p3d$ves
#print("result saved")

}else{# end of if(!byPass)

#Set QTNs
if(count==1)print("-------The burger is SNP-----------------------------------")
  #bin.size=bin
  #inclosure.size=inc

#@@@This section is not useful
if(!is.null(GP))
{
  #print("Being specific...")

  myGenotype<-GAPIT.Genotype(G=NULL,GD=NULL,GM=GI,KI=NULL,kinship.algorithm="SUPER",PCA.total=0,SNP.fraction=SNP.fraction,SNP.test=SNP.test,
                    file.path=file.path,file.from=file.from, file.to=file.to, file.total=file.total, file.fragment = file.fragment, file.G=file.G, 
                    file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
                    SNP.MAF=SNP.MAF,FDR.Rate = FDR.Rate,SNP.FDR=SNP.FDR,SNP.effect=SNP.effect,SNP.impute=SNP.impute,
                    LD.chromosome=LD.chromosome,LD.location=LD.location,LD.range=LD.range,
                    GP=GP,GK=NULL,bin.size=bin,inclosure.size=inc,SNP.CV=SNP.CV,GTindex=GTindex,sangwich.top=NULL,sangwich.bottom=sangwich.bottom,
                    Timmer = Timmer, Memory = Memory,file.output=file.output, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)
    
  Timmer=myGenotype$Timmer
  Memory=myGenotype$Memory
  
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Genotype for burger")
  Memory=GAPIT.Memory(Memory=Memory,Infor="Genotype for burger")
  
  #print("Extracting QTNs...")  
  #SNP.QTN=myGenotype$SNP.QTN
  #QTN=GD[,SNP.QTN] 
  #colnames(QTN)=myGenotype$GI[SNP.QTN,1]
  #QTN=cbind(myGenotype$GT,QTN)   #add taxa
  #colnames(QTN)[1]="taxa"
  GK=GD[GTindex,myGenotype$SNP.QTN]
  SNPVar=apply(as.matrix(GK),2,var)
  GK=GK[,SNPVar>0]
  GK=cbind(as.data.frame(GT[GTindex]),as.data.frame(GK)) #add taxa

  #GP=NULL
}# end of if(is.null(GK)) 


if(!is.null(GK) & numSetting>1)
{
print("-------Calculating likelihood-----------------------------------")
  myBurger=GAPIT.Burger(Y=Y,CV=CV,GK=GK)
  myREML=myBurger$REMLs
  myVG=myBurger$vg
  myVE=myBurger$ve
}else{
  myREML=NA
  myVG=NA
  myVE=NA
}

#Recoding the optimum GK
if(count==1){
  GK.save=GK
  LL.save=myREML
}else{
  if(myREML<LL.save){
    GK.save=GK
    LL.save=myREML
  }
}
  
#Put to storage
Compression[count,1]=1
Compression[count,2]=bin
Compression[count,3]=inc
Compression[count,4]=myREML
Compression[count,5]=myVG
Compression[count,6]=myVG
print(Compression[count,]) 

#print("---------------SUPER 2nd stage: calculating LL ------------------------")


}   # end of if(byPass)

}#end of for (ca in kinship.cluster)

#Skip the rest group in case group 1 is finished
if(group==1) break #To skip the rest group interations

}#end of for (group in GROUP)
}#end of for (kt in kinship.group)

}#end of for (inc in inclosure)
}#end of for (bin in bin.level)


if(Model.selection == TRUE){ 

  print("------------------------Model selection for optimal number of PCs and Covariates-------------------------------------------------")
  #update KI with the best likelihood
  KI=KI.save
  if(numSetting>1){
  Compression=Compression[order(as.numeric(Compression[,4]),decreasing = FALSE),]  #sort on REML
  kt=Compression[1,1]
  ca=Compression[1,2]
  group=Compression[1,3]
  }

  cp <- GAPIT.Compress(KI=KI,kinship.cluster=ca,kinship.group=kt,GN=group,Timmer=Timmer,Memory=Memory)
  Timmer=cp$Timmer
  Memory=cp$Memory

  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_cp")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2_cp")

  bk <- GAPIT.Block(Z=Z,GA=cp$GA,KG=cp$KG)
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_bk")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 bk")

  zc <- GAPIT.ZmatrixCompress(Z=Z,GAU =bk$GA)

  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_zc")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 zc")

  z0=as.matrix(zc$Z[,-1])
  Z1=matrix(as.numeric(z0),nrow=nrow(z0),ncol=ncol(z0))


  
  BIC <- rep(NA,ncol(X0))
  LogLike <- rep(NA, ncol(X0))
  for(i in 1:ncol(X0)){#1 because the first column of X0 is the intercept

    X0.test <- as.matrix(X0[,1:i]) 
    
    #print("The dim of bk$KW is ")
    #print(dim(bk$KW))
    

    p3d <- GAPIT.EMMAxP3D(ys=ys,xs=as.matrix(as.data.frame(GD[,1])),K = as.matrix(bk$KW) ,Z=Z1,X0=X0.test,CVI=CVI,CV.Inheritance=CV.Inheritance,GI=GI,SNP.P3D=SNP.P3D,Timmer=Timmer,Memory=Memory,fullGD=fullGD,
            SNP.permutation=SNP.permutation, GP=GP,
			      file.path=file.path,file.from=file.from,file.to=file.to,file.total=file.total, file.fragment = file.fragment, byFile=byFile, file.G=file.G,file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
            GTindex=GTindex,genoFormat=genoFormat,optOnly=TRUE,SNP.effect=SNP.effect,SNP.impute=SNP.impute,name.of.trait=name.of.trait, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)

    
    
    k.num.param <- 2+i
    #k is (i-1) because we have the following parameters in the likelihood function:
    #  intercept
    #  (i-1) covariates
    #  sigma_g
    #  delta
    
    #print(paste("The value of round(p3d$REMLs,5) is ", round(p3d$REMLs,5), sep = ""))
    #print(paste("The value of log(GTindex) is ", log(GTindex), sep = ""))
    #print(paste("The value of 0.5*k.num.param*log(GTindex) is ", 0.5*k.num.param*log(nrow(Z1)), sep = ""))
    
    LogLike[i] <- p3d$logLM
    BIC[i] <- p3d$logLM -(0.5*k.num.param*log(nrow(Z1)))
    
    #print("The value of k.num.param  is: ")
    #print(k.num.param)
    
    #print(paste("The value of nrow(Z1) is ", nrow(Z1), sep = ""))  
    
    }   
    Optimum.from.BIC <- which(BIC == max(BIC))
    
    print(paste("-----------------------The optimal number of PCs/covariates is ", (Optimum.from.BIC-1)," -------------------------", sep = ""))
    
    BIC.Vector <- cbind(as.matrix(rep(0:(ncol(X0)-1))), as.matrix(BIC), as.matrix(LogLike))

           
    #print(seq(0:ncol(X0)))
    
       #print(BIC.Vector)
 
    colnames(BIC.Vector) <- c("Number of PCs/Covariates", "BIC (larger is better) - Schwarz 1978", "log Likelihood Function Value")
    
    write.table(BIC.Vector, paste("GAPIT.", name.of.trait, ".BIC.Model.Selection.Results.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
    
    #print(BIC.Vector)
    
    X0 <- X0[,1:(Optimum.from.BIC)]
    
    if(Optimum.from.BIC == 1){
    X0 <- as.matrix(X0)
    }
    print("The dimension of X0 after model selection is:")
    print(dim(X0))
    
    print("The head of X0 after model selection is")
    print(head(X0))
    

}



print("---------------------Sandwich bottom bun-------------------------------")
print("Compression") 
print(Compression)

#Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Compression")
#Memory=GAPIT.Memory(Memory=Memory,Infor="Copmression")

if(numSetting==1)
{
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GWAS")
  Memory=GAPIT.Memory(Memory=Memory,Infor="GWAS")
}
  
#Perform GWAS with the optimum setting
#This section is omited if there is only one setting
if((numSetting>1)| (!is.null(sangwich.bottom)&!byPass) | Model.selection) {
  print("Genomic screening..." )
  
optOnly=FALSE  #set default to false and change it to TRUE in these situations:
if(!hasGenotype) optOnly=TRUE
if(!SNP.test) optOnly=TRUE

if(optOnly){
 colInclude=1
}else{
 colInclude=c(1:ncol(GD))
}

if(numSetting>1){
#Find the best ca,kt and group
Compression=Compression[order(as.numeric(Compression[,4]),decreasing = FALSE),]  #sort on REML
kt=Compression[1,1]
ca=Compression[1,2]
group=Compression[1,3]

print(paste("Optimum: ",Compression[1,2],Compression[1,1],Compression[1,3],Compression[1,5], Compression[1,6],Compression[1,4] ,sep = " "))
}#end  if(numSetting>1)

print("--------------  Sandwich bottom ------------------------") 

if(!byPass) 
{ 
print("--------------  Sandwich bottom with raw burger------------------------") 

 if(Model.selection == FALSE){
  #update KI with the best likelihood
  if(is.null(sangwich.bottom)) KI=KI.save

  cp <- GAPIT.Compress(KI=KI,kinship.cluster=ca,kinship.group=kt,GN=group,Timmer=Timmer,Memory=Memory)
  Timmer=cp$Timmer
  Memory=cp$Memory
  
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_cp")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2_cp")
  
  bk <- GAPIT.Block(Z=Z,GA=cp$GA,KG=cp$KG)
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_bk")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 bk")
  
  zc <- GAPIT.ZmatrixCompress(Z=Z,GAU =bk$GA)
  
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="PreP3D 2_zc")
  Memory=GAPIT.Memory(Memory=Memory,Infor="PreP3D 2 zc")
  
  #Reform KW and Z into EMMA format
  
  z0=as.matrix(zc$Z[,-1])   
  Z1=matrix(as.numeric(z0),nrow=nrow(z0),ncol=ncol(z0))
 }
 
 print("--------------EMMAxP3D with the optimum setting-----------------------") 
  p3d <- GAPIT.EMMAxP3D(ys=ys,xs=as.matrix(as.data.frame(GD[GTindex,colInclude]))   ,K = as.matrix(bk$KW) ,Z=Z1,X0=as.matrix(X0),CVI=CVI, CV.Inheritance=CV.Inheritance,GI=GI,SNP.P3D=SNP.P3D,Timmer=Timmer,Memory=Memory,fullGD=fullGD,
          SNP.permutation=SNP.permutation, GP=GP,
    			 file.path=file.path,file.from=file.from,file.to=file.to,file.total=file.total, file.fragment = file.fragment, byFile=byFile, file.G=file.G,file.Ext.G=file.Ext.G,file.GD=file.GD, file.GM=file.GM, file.Ext.GD=file.Ext.GD,file.Ext.GM=file.Ext.GM,
           GTindex=GTindex,genoFormat=genoFormat,optOnly=optOnly,SNP.effect=SNP.effect,SNP.impute=SNP.impute,name.of.trait=name.of.trait, Create.indicator = Create.indicator, Major.allele.zero = Major.allele.zero)  
    
  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GWAS")
  Memory=GAPIT.Memory(Memory=Memory,Infor="GWAS")  
 print("--------------EMMAxP3D with the optimum setting done------------------") 
  
}#end of if(!byPass) 
}#end of if(numSetting>1 & hasGenotype & !SNP.test)  

#print("Screening wiht the optimum setting done") 

if(byPass)
{
print("---------------Sandwich bottom with grilled burger---------------------") 
print("---------------Sandwich bottom: reload bins ---------------------------")

#SUPER: Final screening
  GK=GK.save
  myBread=GAPIT.Bread(Y=Y,CV=CV,Z=Z,GK=GK,GD=cbind(as.data.frame(GT),as.data.frame(GD)),GM=GI,method=sangwich.bottom,GTindex=GTindex,LD=LD,file.output=file.output)
              
  print("SUPER saving results...")

  Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GWAS")
  Memory=GAPIT.Memory(Memory=Memory,Infor="GWAS")  

   
}   #end of if(byPass)

print("--------------------Final results presentations------------------------")



#Plotting optimum group kinship
if(!byPass) 
{ 
if(length(bk$KW)>1 &length(bk$KW)<length(KI) & length(bk$KW)<1000 &file.output){
pdf(paste("GAPIT.",name.of.trait,".Kin.Optimum.pdf",sep=""), width = 12, height = 12)
par(mar = c(25,25,25,25))
heatmap.2(as.matrix(bk$KW),  cexRow =.2, cexCol = 0.2, col=rev(heat.colors(256)), scale="none", symkey=FALSE, trace="none")
dev.off()
}
}


#Merge GWAS resultss from files to update ps,maf and nobs in p3d
if(byFile&!fullGD)
{
print("Loading GWAS results from file...")
for (file in file.from:file.to)
{

#Initicalization
frag=1
numSNP=file.fragment

while(numSNP==file.fragment) {     #this is problematic if the read end at the last line  

#Initicalization GI to detect reading empty line
#theGI=NULL
#theP=NULL
#theMAF=NULL
#thenobs=NULL

#reload results from files
print(paste("Current file ",file,"Fragment: ",frag))

theGI <- try(read.table(paste("GAPIT.TMP.GI.",name.of.trait,file,".",frag,".txt",sep=""), head = TRUE)   ,silent=TRUE)
theP <- try(read.table(paste("GAPIT.TMP.ps.",name.of.trait,file,".",frag,".txt",sep=""), head = FALSE)   ,silent=TRUE)
theMAF <- try(read.table(paste("GAPIT.TMP.maf.",name.of.trait,file,".",frag,".txt",sep=""), head = FALSE),silent=TRUE)
thenobs <- try(read.table(paste("GAPIT.TMP.nobs.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
thersquare_base <- try(read.table(paste("GAPIT.TMP.rsquare.base.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
thersquare <- try(read.table(paste("GAPIT.TMP.rsquare.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
          thedf  <- try(read.table(paste("GAPIT.TMP.df.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
          thetvalue  <- try(read.table(paste("GAPIT.TMP.tvalue.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
          thestderr  <- try(read.table(paste("GAPIT.TMP.stderr.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)
theeffect.est <- try(read.table(paste("GAPIT.TMP.effect.est.",name.of.trait,file,".",frag,".txt",sep=""),head= FALSE),silent=TRUE)

if(inherits(theGI, "try-error"))  {
#if(nrow(theGI)<1){
  numSNP=0
  #print("This fragment is empty.")
}else{



#print("Records loaded for this fragment.")
  numSNP=nrow(theGI)  
  colnames(theP)="P"
  colnames(theMAF )="MAF"
  colnames(thenobs )="nobs"
  colnames(thersquare_base) = "Base.Model.R.square"  
  colnames(thersquare) = "Model.R.square"
            colnames(thedf) = "Model.DF"
            colnames(thetvalue) = "Model.tvalue"
            colnames(thestderr) = "Model.stderr"
  colnames(theeffect.est) = "Effect.Est"    
  colnames(theGI) = colnames(GI)
 



#Merge results  
  if(file==file.from & frag==1){

    GI=theGI  
    allP=theP
    allMAF=theMAF
    allnobs=thenobs
    allrsquare_base=thersquare_base
    allrsquare=thersquare
              alldf=thedf
              alltvalue=thetvalue
              allstderr=thestderr
    alleffect.est=theeffect.est
  }else{
    allP=as.data.frame(rbind(as.matrix(allP),as.matrix(theP))  )
    allMAF=as.data.frame(rbind(as.matrix(allMAF),as.matrix(theMAF)) )
    allnobs=as.data.frame(rbind(as.matrix(allnobs),as.matrix(thenobs)))
    allrsquare_base=as.data.frame(rbind(as.matrix(allrsquare_base),as.matrix(thersquare_base)))
    allrsquare=as.data.frame(rbind(as.matrix(allrsquare),as.matrix(thersquare)))
              alldf=as.data.frame(rbind(as.matrix(alldf),as.matrix(thedf)))
              alltvalue=as.data.frame(rbind(as.matrix(alltvalue),as.matrix(thetvalue)))
              allstderr=as.data.frame(rbind(as.matrix(allstderr),as.matrix(thestderr)))
    alleffect.est=as.data.frame(rbind(as.matrix(alleffect.est),as.matrix(theeffect.est)))
    GI=as.data.frame(rbind(as.matrix(GI),as.matrix(theGI)))
  }

}#end of  if(inherits(theGI, "try-error")) (else section)

#setup for next fragment
frag=frag+1   #Progress to next fragment 

}#end of loop on fragment: while(numSNP==file.fragment)
}#end of loop on file

#update p3d with components from files
  p3d$ps=allP
  p3d$maf=allMAF
  p3d$nobs=allnobs
  p3d$rsquare_base=allrsquare_base
  p3d$rsquare=allrsquare
      p3d$df=alldf
      p3d$tvalue=alltvalue
      p3d$stderr=allstderr
  p3d$effect.est=alleffect.est
  
#Delete all the GAPIT.TMP files
theFile=paste("GAPIT.TMP.",name.of.trait,".*")
  system('cmd /c del "GAPIT.TMP*.*"') 
  system('cmd /c del "GAPIT.TMP*.*"') 
  print("GWAS results loaded from all files succesfully!")
} #end of if(byFile)

#--------------------------------------------------------------------------------------------------------------------#
#Final report   
print("Generating summary" )
GWAS=NULL
GPS=NULL
rm(zc)
gc()

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Final")
Memory=GAPIT.Memory(Memory=Memory,Infor="Final")

#genomic prediction
print("Genomic Breeding Values (GBV) ..." )

if(!byPass) 
{
if(length(bk$KW)>ncol(X0)) {
    gs <- GAPIT.GS(KW=bk$KW,KO=bk$KO,KWO=bk$KWO,GAU=bk$GAU,UW=cbind(p3d$BLUP,p3d$PEV))
}

print("Writing GBV and Acc..." )

GPS=NULL
if(length(bk$KW)>ncol(X0)) GPS=gs$BLUP

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="GPS")
Memory=GAPIT.Memory(Memory=Memory,Infor="GPS")

#Make heatmap for distribution of BLUP and PEV
print("GBV and accuracy distribution..." )
if(length(bk$KW)>ncol(X0) &file.output) {
  GAPIT.GS.Visualization(gsBLUP = gs$BLUP, BINS=BINS,name.of.trait = name.of.trait)
}

#Make a plot Summarzing the Compression Results, if more than one "compression level" has been assessed
print("Compression portfolios..." )
#print(Compression)
if(file.output) GAPIT.Compression.Visualization(Compression = Compression, name.of.trait = name.of.trait)
print("Compression Visualization done")

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Compression.Visualization")
Memory=GAPIT.Memory(Memory=Memory,Infor="Compression.Visualization")

ps=p3d$ps
nobs=p3d$nobs
maf=p3d$maf
rsquare_base=p3d$rsquare_base
rsquare=p3d$rsquare
      df=p3d$df
      tvalue=p3d$tvalue
      stderr=p3d$stderr
effect.est=p3d$effect.est

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Extract p3d results")
Memory=GAPIT.Memory(Memory=Memory,Infor="Extract p3d results")
  
}else{
  print("The head of myBread$GWAS is")
  print(head(myBread$GWAS))
  
  GPS=myBread$BLUP
  ps=myBread$GWAS[,4]
  nobs=myBread$GWAS[,6]
  maf=myBread$GWAS[,5]*0+.5
  rsquare_base=rep(NA,length(ps))
  rsquare=rep(NA,length(ps))
  df=rep(NA,length(nobs))
  tvalue=rep(NA,length(nobs))
  stderr=rep(NA,length(nobs))
  effect.est=rep(NA,length(nobs))
  
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Extract bread results")
Memory=GAPIT.Memory(Memory=Memory,Infor="Extract bread results")
 
}

#Merge BLUP and BLUE
if((!byPass)&(!Model.selection)){
 #print("GAPIT before BLUP and BLUE")
 BLUE=data.frame(cbind(data.frame(CV.taxa),data.frame(p3d$BLUE)))
 colnames(BLUE)=c("Taxa","BLUE")
 BB= merge(gs$BLUP, BLUE, by.x = "Taxa", by.y = "Taxa")
 Prediction=BB[,5]+BB[,7]
 Pred=data.frame(cbind(BB,data.frame(Prediction)))
  #print("GAPIT after BLUP and BLUE")
}


#Export BLUP and PEV
if(!byPass &file.output) 
{
print("Exporting BLUP and Pred")
  try(write.table(gs$BLUP, paste("GAPIT.", name.of.trait,".BLUP.csv" ,sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE))
  try(write.table(Pred, paste("GAPIT.", name.of.trait,".PRED.csv" ,sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE))
}

if(byPass) 
{
  theK.return=NULL
}else{
  theK.return=cp$KG
}
if(byPass)Compression[1,4]=0 #create a fake value to aloow output of SUPER 

#Export GWAS results
if(hasGenotype &SNP.test &!is.na(Compression[1,4]))     #require not NA REML 
{
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Extract GWAS start")
Memory=GAPIT.Memory(Memory=Memory,Infor="Extract GWAS start")


  print("Filtering SNPs with MAF..." )
	index=maf>=SNP.MAF	     
	PWI.Filtered=cbind(GI,ps,maf,nobs,rsquare_base,rsquare)[index,]
	colnames(PWI.Filtered)=c("SNP","Chromosome","Position ","P.value", "maf", "nobs", "Rsquare.of.Model.without.SNP","Rsquare.of.Model.with.SNP")

if(!byPass){  
   if(Create.indicator){
    #Add a counter column for GI
    GI.counter <- cbind(GI, seq(1:nrow(GI))) 
    
    #Turn GI and effect.est into data frames
    GI.counter.data.frame <- data.frame(GI.counter)
    colnames(GI.counter.data.frame) <- c("X1", "X2", "X3", "X4")
    
    effect.est.data.frame <- data.frame(effect.est)
    colnames(effect.est.data.frame) <- c("X1", "X2", "X3")
            
    #Do a merge statement
    GWAS.2 <- merge(GI.counter.data.frame, effect.est.data.frame, by.x = "X4", by.y = "X1")
    
    #Remove the counter column
    GWAS.2 <- GWAS.2[,-1]
    
    #Add column names
    colnames(GWAS.2) <- c("SNP","Chromosome","Position ", "Genotype", "Allelic Effect Estimate")
    
    
   }
   
   if(!Create.indicator){ 
    GWAS.2 <- cbind(GI, effect.est)
    colnames(GWAS.2) <- c("SNP","Chromosome","Position ", "Allelic Effect Estimate")
   } 
}
  	     
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="MAF filtered")
Memory=GAPIT.Memory(Memory=Memory,Infor="MAF filtered")
		     
  print("SNPs filtered with MAF")
  
  if(!is.null(PWI.Filtered))
  {

  #Run the BH multiple correction procedure of the results
  #Create PWIP, which is a table of SNP Names, Chromosome, bp Position, Raw P-values, FDR Adjusted P-values
  print("Calculating FDR..." )
  PWIP <- GAPIT.Perform.BH.FDR.Multiple.Correction.Procedure(PWI = PWI.Filtered, FDR.Rate = FDR.Rate, FDR.Procedure = "BH")
  
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Multiple Correction")
Memory=GAPIT.Memory(Memory=Memory,Infor="Multiple Correction")


  #QQ plots
  print("QQ plot..." )
  if(file.output) GAPIT.QQ(P.values = PWIP$PWIP[,4], name.of.trait = name.of.trait,DPP=DPP)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="QQ plot")
Memory=GAPIT.Memory(Memory=Memory,Infor="QQ plot")


  #Manhattan Plots
  
  
   print("Manhattan plot (Genomewise)..." )
#  if(file.output) GAPIT.Manhattan(GI.MP = PWIP$PWIP[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Genomewise",cutOff=cutOff)
#  if(file.output) GAPIT.Manhattan(GI.MP = PWIP$PWIP[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Genomewise",cutOff=cutOff,seqQTN=QTN.position)  #QTN does not work with sorted P
  if(file.output) GAPIT.Manhattan(GI.MP = cbind(GI[,-1],ps), name.of.trait = name.of.trait, DPP=DPP, plot.type = "Genomewise",cutOff=cutOff,seqQTN=QTN.position) 

 print("Manhattan plot (Chromosomewise)..." )
  if(file.output) GAPIT.Manhattan(GI.MP = PWIP$PWIP[,2:4], name.of.trait = name.of.trait, DPP=DPP, plot.type = "Chromosomewise",cutOff=cutOff)

Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Manhattan plot")
Memory=GAPIT.Memory(Memory=Memory,Infor="Manhattan plot")


  #Association Table
  print("Association table..." )
  #GAPIT.Table(final.table = PWIP$PWIP, name.of.trait = name.of.trait,SNP.FDR=SNP.FDR)
  GWAS=PWIP$PWIP[PWIP$PWIP[,9]<=SNP.FDR,]
  print("Joining tvalue and stderr" )
  
        DTS=cbind(GI,df,tvalue,stderr)
        colnames(DTS)=c("SNP","Chromosome","Position","DF","t Value","std Error")	

  print("Creating ROC table and plot" )
	if(file.output) myROC=GAPIT.ROC(t=tvalue,se=stderr,Vp=var(ys),trait=name.of.trait)
  print("ROC table and plot created" )

  if(file.output){
   write.table(GWAS, paste("GAPIT.", name.of.trait, ".GWAS.Results.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
   write.table(DTS, paste("GAPIT.", name.of.trait, ".Df.tValue.StdErr.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
   if(!byPass) write.table(GWAS.2, paste("GAPIT.", name.of.trait, ".Allelic_Effect_Estimates.csv", sep = ""), quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
  }


  
  } #end of if(!is.null(PWI.Filtered))
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Extract GWAS end")
Memory=GAPIT.Memory(Memory=Memory,Infor="Extract GWAS end")

  
} #end of if(hasGenotype )

#Log
if(file.output) log=GAPIT.Log(Y=Y,KI=KI,Z=Z,CV=CV,SNP.P3D=SNP.P3D,
				group.from = group.from ,group.to =group.to ,group.by = group.by ,kinship.cluster = kinship.cluster, kinship.group= kinship.group,
                      	ngrid = ngrid , llin = llin , ulim = ulim , esp = esp ,name.of.trait = name.of.trait)
#Memory usage
#GAPIT.Memory.Object(name.of.trait=name.of.trait)

#Timming
Timmer=GAPIT.Timmer(Timmer=Timmer,Infor="Report")
Memory=GAPIT.Memory(Memory=Memory,Infor="Report")
if(file.output){
file=paste("GAPIT.", name.of.trait,".Timming.csv" ,sep = "")
write.table(Timmer, file, quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)

file=paste("GAPIT.", name.of.trait,".Memory.Stage.csv" ,sep = "")
write.table(Memory, file, quote = FALSE, sep = ",", row.names = FALSE,col.names = TRUE)
}
print(paste(name.of.trait, "has been analyzed successfully!") )
print(paste("The results are saved in the directory of ", getwd()) )
print("==========================================================================================")

if(byPass | Model.selection) Pred <- NA

return (list(Timmer=Timmer,Compression=Compression,kinship.optimum=theK.return, kinship=KI,PC=PC,GWAS=GWAS, GPS=GPS,Pred=Pred,REMLs=Compression[count,4],Timmer=Timmer,Memory=Memory))

}#The function GAPIT.Main ends here


