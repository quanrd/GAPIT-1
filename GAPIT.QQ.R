`GAPIT.QQ` <-
function(P.values, plot.type = "log_P_values", name.of.trait = "Trait",DPP=50000){
#Object: Make a QQ-Plot of the P-values
#Options for plot.type = "log_P_values" and "P_values" 
#Output: A pdf of the QQ-plot
#Authors: Alex Lipka and Zhiwu Zhang
# Last update: May 9, 2011 
##############################################################################################


# Sort the data by the raw P-values
print("Sorting p values")
print(paste("Number of P values: ",length(P.values)))
if(length(P.values[P.values>0])<1) return(NULL)

DPP=round(DPP/4) #Reduce to 1/4 for QQ plot

P.values <- P.values[order(P.values)]
  
#Set up the p-value quantiles
print("Setting p_value_quantiles...")
p_value_quantiles <- (1:length(P.values))/(length(P.values)+1)


if(plot.type == "log_P_values")
{
    log.P.values <- -log10(P.values)
    log.Quantiles <- -log10(p_value_quantiles)
	
    index=GAPIT.Pruning(log.P.values,DPP=DPP)
    log.P.values=log.P.values[index ]
    log.Quantiles=log.Quantiles[index]

    pdf(paste("GAPIT.", name.of.trait,".QQ-Plot.pdf" ,sep = ""))
    par(mar = c(5,5,5,5))
    qqplot(log.Quantiles, log.P.values, xlim = c(0,max(log.Quantiles)), ylim = c(0,max(log.P.values)), 
           cex.axis=1.5, cex.lab=2, lty = 1, lwd = 1, col = "Blue" ,xlab =expression(Expected~~-log[10](italic(p))),
           ylab = expression(Observed~~-log[10](italic(p))), main = paste(name.of.trait,sep=" "))
    abline(a = 0, b = 1, col = "red")
    dev.off()   
}


if(plot.type == "P_values")
{
  pdf(paste("QQ-Plot_", name.of.trait,".pdf" ,sep = ""))
  par(mar = c(5,5,5,5))
  qqplot(p_value_quantiles, P.values, xlim = c(0,1), 
         ylim = c(0,1), type = "l" , xlab = "Uniform[0,1] Theoretical Quantiles", 
         lty = 1, lwd = 1, ylab = "Quantiles of P-values from GWAS", col = "Blue",
         main = paste(name.of.trait,sep=" "))
  abline(a = 0, b = 1, col = "red")
  dev.off()   
}


  #print("GAPIT.QQ  accomplished successfully!")
  

}
