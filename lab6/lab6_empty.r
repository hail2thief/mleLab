##############################################################
# Start with a clean workspace
rm(list=ls())

# Function to load packages
loadPkg=function(toLoad){
  for(lib in toLoad){
	if(! lib %in% installed.packages()[,1])
	  { install.packages(lib, repos='http://cran.rstudio.com/') }
	suppressMessages( library(lib, character.only=TRUE) ) }
}

# Load libraries
packs=c("ggplot2", 'reshape2', 'sp', 'geosphere', 'MASS', 'grid')
loadPkg(packs)

# Set a theme for gg
theme_set(theme_bw())

# Functions that I use frequently
char = function(x){ as.character(x) }
num = function(x){ as.numeric(char(x)) }

# Relevant paths
labPath='~/Dropbox/Duke/Spring 2015/PS 733/lab6/'
##############################################################

##############################################################
# Out of sample validation
setwd(labPath)
load('fish.RData')


##############################################################

##############################################################
# Cross Validation

# Divide Fish data into n random subsets

##############################################################

##############################################################
# Review of HW4
# First lets load map
setwd(labPath)
load('crisp.map.rda')
centroids=sp::coordinates(crisp.map)
rownames(centroids)=crisp.map$COWCODE
colnames(centroids)=c('long','lat')

# Lets load in contagion data
load('contagionMatrices.rda')

# Lets divide contMats into four time periods
brks=cbind(start=seq(1, length(contMats), length(contMats)/4), 
	end=seq(38, length(contMats), length(contMats)/4))
contMatBuck=lapply(1:nrow(brks), function(ii){ 
	contSub=contMats[brks[ii,1]:brks[[ii,2]]] 
	contSubSum=Reduce('+', contSub)
	contDyadic=melt(contSubSum)
	contDyadic[contDyadic$value>0,]
	})
names(contMatBuck)=paste(
	names(contMats)[brks[,1]], 
	names(contMats)[brks[,2]], sep=' to ')
summary(contMatBuck)

# Now lets plot maps with contagion arrows for each of these matrices
par(mfrow=c(2,2), mar=c(0,0,0,0), oma=c(0,0,0,0))
for(ii in 1:length(contMatBuck)){
	contM=contMatBuck[[ii]]
	segCont=cbind( centroids[char(contM$Var1),],  centroids[char(contM$Var2),])
	colnames(segCont)=c('longStart','latStart','longEnd','latEnd')

	# Create base map
	plot(crisp.map, lwd=0.5, border='darkgrey', col='white', bg='white')
	# Add date label
	text(-5, -50, names(contMatBuck)[ii])
	# Draw line segments
	for(i in 1:nrow(segCont)){
	  spread=geosphere::gcIntermediate( segCont[i,1:2], segCont[i,3:4], 
	  	n=50, addStartEnd=TRUE)
	  lines(spread, col="black", lwd=0.8)
	  arrows(spread[nrow(spread)-1,1],spread[nrow(spread)-1,2], 
	  	spread[nrow(spread),1],spread[nrow(spread),2],length=.04)
	  points(segCont[i,1], segCont[i,2], cex=.4)
	}
}
par(mar=c(4, 4, 2, 0.5), oma=c(2,2,2,2), mfrow=c(1,1), mgp=c(2,.7,0))
##############################################################

##############################################################
# Reviw of HW5
setwd(labPath)
load('fish.RData')

# Interaction between elf and income
dv='fhrev'
ivs=c('muslim', 'income', 'elf', 'growth', 'britcol', 'postcom', 'opec', 'elf*income')
modForm=formula(paste0( dv, ' ~ ', paste(ivs, collapse=' + ') ))
mod = lm(modForm, data=fish)
round(summary(mod)$'coefficients',3)

# Lets assess the interactive effect

# Create a scenario matrix
elfRange=quantile(fish$elf, probs=seq(0,1,.25))
incRange=sort(unique(fish$income))

attach(fish)
scen = expand.grid(1, median(muslim), incRange, elfRange, mean(growth),
	median(britcol), median(postcom), median(opec))
detach(fish)
# Add interaction term
scen = cbind( scen, scen[,3]*scen[,4] )
# Add column headers to scenario
colnames(scen) = names( coef(mod) )
# Convert scen to matrix so we can perform operations on it
scen = data.matrix(scen)

# Lets get predicted values
pred = scen %*% coef(mod)

# Account for systematic uncertainty
sims=1000
draws = mvrnorm(sims, coef(mod), vcov(mod))
sysUncert = scen %*% t(draws)
sysInts = t(apply(sysUncert, 1, function(x){ quantile(x, c(0.025, 0.975)) }))

# Account for stochastic uncertainty
sigma=sqrt( mean( resid(mod)^2 ) )
stoUncert = t(apply(sysUncert, 1, function(x){ rnorm(sims, x, sigma) }))
stoInts = t(apply(stoUncert, 1, function(x){ quantile(x, c(0.025, 0.975)) }))

# Combine for plotting
ggData=data.frame(
		cbind(pred, sysInts, stoInts, scen[,'income'], scen[,'elf'])
	)
names(ggData)=c('fit', 'sysLo', 'sysHi', 'stoLo', 'stoHi', 'income', 'elf')

# Plot
tmp=ggplot(ggData, aes(x=income, y=fit))
tmp=tmp + geom_line()
tmp=tmp + geom_ribbon(aes(ymin=sysLo, ymax=sysHi), alpha=.9)
tmp=tmp + geom_ribbon(aes(ymin=stoLo, ymax=stoHi), alpha=.3)
tmp=tmp + facet_grid(~elf)
tmp

# Dag's surface plot (a.k.a. : heatmap, matrix diagram)
# Create a scenario matrix
attach(fish)
elfRange=seq(min(elf), max(elf), .05)
incRange=seq(min(income), max(income), .05)

scen = expand.grid(1, median(muslim), incRange, elfRange, mean(growth),
	median(britcol), median(postcom), median(opec))
detach(fish)
# Add interaction term
scen = cbind( scen, scen[,3]*scen[,4] )
# Add column headers to scenario
colnames(scen) = names( coef(mod) )
# Convert scen to matrix so we can perform operations on it
scen = data.matrix(scen)

# Get predicted values
pred = scen %*% coef(mod)

# Create dataframe for plotting
ggData = data.frame( cbind(scen[,'income'], scen[,'elf'], pred) )
names(ggData)=c('income', 'elf', 'pred')

# Make a surface plot
tmp=ggplot(ggData, aes(x=income, y=elf, fill=pred)) 
tmp=tmp + xlab('Income') + ylab('Ethnic Frac.')
tmp=tmp + geom_tile(colour='darkgrey')
tmp=tmp + scale_fill_gradient2(midpoint=4.5, space='rgb', 
  low="#d73027", mid="white", high="#4575b4",
  name='FH\n')
tmp=tmp + scale_x_continuous(expand=c(0,0)) + scale_y_continuous(expand=c(0,0))
tmp=tmp + theme(axis.ticks=element_blank(), 
  legend.position='top', legend.key.width=unit(2,'cm'),
  panel.grid.major = element_blank(), panel.grid.minor = element_blank() )
tmp
##############################################################