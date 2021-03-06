#Examination of 
#Data published in X
#Title: 
#Contact: Hollie Putnam hollieputnam@gmail.com
#Supported by: MCR LTER
#last modified 20170409
#See Readme file for details on data files and metadata

rm(list=ls()) # removes all prior objects

#R Version:
#RStudio Version:
#Read in required libraries
library(seacarb)
library(plyr)
library(reshape)

#~/MyProjects/Moorea/Moorea_April2017/RAnalysis/Data/pH_Calibration_Files/
#~/MyProjects/Moorea/Moorea_April2017/RAnalysis/Data/TA/
#Daily_Temp_pH_Sal.csv
#TA_mass_data.csv

#############################################################
setwd("~/MyProjects/Moorea/Moorea_April2017/RAnalysis/Data/") #set working directory
mainDir<-'~/MyProjects/Moorea/Moorea_April2017/RAnalysis/' #set main directory
#############################################################

path <-("~/MyProjects/Moorea/Moorea_April2017/RAnalysis/Data/pH_Calibration_Files/")
#list all the file names in the folder to get only get the csv files
file.names<-list.files(path = path, pattern = "csv$")
pH.cals <- data.frame(matrix(NA, nrow=length(file.names), ncol=3, dimnames=list(file.names,c("Date", "Intercept", "Slope")))) #generate a 3 column dataframe with specific column names

for(i in 1:length(file.names)) { # for every file in list start at the first and run this following function
  Calib.Data <-read.table(file.path(path,file.names[i]), header=TRUE, sep=",", na.string="NA", as.is=TRUE) #reads in the data files
  model <-lm(mVTris ~ TTris, data=Calib.Data) #runs a linear regression of mV as a function of temperature
  coe <- coef(model) #extracts the coeffecients
  pH.cals[i,2:3] <- coe #inserts them in the dataframe
  pH.cals[i,1] <- substr(file.names[i],1,8) #stores the file name in the Date column
}
colnames(pH.cals) <- c("Calib.Date",  "Intercept",  "Slope")
pH.cals

#constants for use in pH calculation 
R <- 8.31447215 #gas constant in J mol-1 K-1 
F <-96485.339924 #Faraday constant in coulombs mol-1

#read in probe measurements of pH, temperature, and salinity from tanks
daily <- read.csv("Daily_Temp_pH_Sal.csv", header=TRUE, sep=",", na.strings="NA") #load data with a header, separated by commas, with NA as NA

#merge with Seawater chemistry file
SW.chem <- merge(pH.cals, daily, by="Calib.Date")

mvTris <- SW.chem$Temperature*SW.chem$Slope+SW.chem$Intercept #calculate the mV of the tris standard using the temperature mv relationships in the measured standard curves 
STris<-34.5 #salinity of the Tris
phTris<- (11911.08-18.2499*STris-0.039336*STris^2)*(1/(SW.chem$Temperature+273.15))-366.27059+ 0.53993607*STris+0.00016329*STris^2+(64.52243-0.084041*STris)*log(SW.chem$Temperature+273.15)-0.11149858*(SW.chem$Temperature+273.15) #calculate the pH of the tris (Dickson A. G., Sabine C. L. and Christian J. R., SOP 6a)
SW.chem$pH.Total<-phTris+(mvTris/1000-SW.chem$pH.MV/1000)/(R*(SW.chem$Temperature+273.15)*log(10)/F) #calculate the pH on the total scale (Dickson A. G., Sabine C. L. and Christian J. R., SOP 6a)

##### DISCRETE TA CALCULATIONS #####
setwd(file.path(mainDir, 'Data'))
massfile<-"TA_mass_data.csv" # name of your file with masses
path<-"~/MyProjects/Moorea/Moorea_April2017/RAnalysis/Data/TA" #the location of all your titration files
#date<-"TA" #set date of measurement
Sample.Info <- read.csv("TA_mass_data.csv", header=T, sep=",", na.string="NA", as.is=T) #load data
Mass<-read.csv(massfile, header=T, sep=",", na.string="NA", as.is=T, row.names=1)  #load Sample Info Data

# Select the mV for pH=3 and pH=3.5 based on your probe calibration
pH35<-mean(Sample.Info$pH35, na.rm=T) #take the average mV reading for pH 3.5 across all samples
pH3<-mean(Sample.Info$pH3, na.rm=T) #take the average mV reading for pH 3.0 across all samples

#find all the titration data files
file.names<-list.files(path=path) #list all the file names in your data and sample directory
file.names <- file.names[grep("[.]csv", file.names)] # select only get the csv files

#create an empty dataframe to put the TA values in
nrow<-length(file.names) #set number of rows to the number of samples
TA <- matrix(nrow = nrow, ncol = 3) #set the dimensions of the dataframe
rownames(TA)<-file.names #identify row names
colnames(TA)<-c('Sample.ID','Mass','TA.Mes') #identify column names

# set working directory to where the data is
setwd(file.path(mainDir, 'Data/TA'))

#run a for loop to bring in the titration files on at a time and calculate TA
for(i in 1: length(file.names)) {
  Data<-read.table(file.names[i], header=F, sep=",", na.string="NA",as.is=T) #read in each data file
  Data<-Data[-1:-6,] #remove the rows with characters
  
  # everything was brought in as a character because of the second line, converts back to numeric
  Data$Temperature<-as.numeric(Data[,7]) #convert to numeric and assign temperature column
  Data$Signal<-as.numeric(Data[,3]) #convert to numeric and assign mV column
  Data$Volume<-as.numeric(Data[,1]) #convert to numeric and assign volumn of titrant column
  
  #name of the file without .csv
  name<-unlist(strsplit(file.names[i], split='.', fixed=TRUE))[1]
  
  #identifies the indices of values between pH 3 and 3.5 
  mV<-which(Data$Signal<pH3 & Data$Signal>pH35) 
  
  #density of your titrant: specific to each bottle
  d<-100*(-0.0000040*mean(Data$Temperature[mV], na.rm=T)^2-0.0001108*mean(Data$Temperature[mV], na.rm=T)+1.0288)/1000
  # d2<-100*(-0.00000350*mean(Data$Temperature[mV], na.rm=T)^2-0.0001319*mean(Data$Temperature[mV], na.rm=T)+1.02907)/1000
  # d3<-100*(-0.00000379*mean(Data$Temperature[mV], na.rm=T)^2-0.00012043*mean(Data$Temperature[mV], na.rm=T)+1.0296876)/1000
  # 
  # d <- if(Mass[name,4] =="d1") {
  #   d1                              #if density function = d1 use d1
  # } else if(Mass[name,4] =="d2") {
  #   d2                              #if density function = d2 use d2
  # } else if(Mass[name,4] =="d3")
  #   d3                              #if density function = d3 use d3
  
  #concentration of your titrant: specific to each bottle
  c<-Mass[name,3]
  
  #Salinity of your samples: changed with every sample
  s<-Mass[name,2]
  
  #mass of sample in g: changed with every sample
  mass<-Mass[name,1]
  
  #Calculate TA
  #at function is based on code in saecarb package by Steeve Comeau, Heloise Lavigne and Jean-Pierre Gattuso
  TA[i,1]<-name #add sample name to data output
  TA[i,2]<-mass #add mass to data output
  TA[i,3]<-10000000*at(S=s,T=mean(Data$Temperature[mV], na.rm=T), C=c, d=d, pHTris=NULL, ETris=NULL, weight=mass, E=Data$Signal[mV], volume=Data$Volume[mV]) #add TA to data output
}

TA <- data.frame(TA) #make a dataframe from the TA results
setwd(file.path(mainDir, 'Output')) #set output location
write.table(TA,paste("TA", "output",".csv"),sep=",", row.names = FALSE)#exports your data as a CSV file
setwd(file.path(mainDir, 'Data'))

#load CRM standard Info
CRMs <- read.csv("CRM_TA_Data.csv", header=TRUE, sep=",", na.strings="NA") #load data with a header, separated by commas, with NA as NA
Refs <- merge(CRMs, TA, by="Sample.ID") #merge the TA calculations with the Reference metadata
Refs$TA.Mes <- as.numeric(paste(Refs$TA.Mes)) #set valuse as numeric
Refs$Per.Off <- 100*((Refs$TA.Mes-Refs$CRM.TA)/Refs$CRM.TA) #calculate the percent difference of the TA from the CRM
Refs$TA.Corr <- Refs$CRM.TA-Refs$TA.Mes
Refs <- Refs[order(Refs$Date, abs(Refs$TA.Corr) ), ] #sort by id and reverse of abs(value)
Refs <- Refs[ !duplicated(Refs$Date), ]              # take the first row within each id
Refs #view data
setwd(file.path(mainDir, 'Output')) #set output location
write.table(Refs, file="Corrected_CRM.csv",sep=",", row.names = FALSE)#exports your data as a CSV file
setwd(file.path(mainDir, 'Data'))
CRM.res <- mean(Refs$Per.Off, na.rm=T) #calculate the average % difference of TA from CRM values over the course of the experiment
CRM.res #view the resolution of TA assay according to tests againsts Dickson CRMs

#####SEAWATER CHEMISTRY ANALYSIS FOR DISCRETE MEASUREMENTS#####
#Seawater chemistry table from simultaneous TA, pH, temperature and salinity measurements
#merge calculated pH and daily measures with TA data and run seacarb
SW.chem$Sample.ID <- paste(SW.chem$Date, SW.chem$Tank, sep='_') #generate new row with concatenated sample id
#TA <- TA[ grep("CRM", TA$Sample.ID, invert = TRUE) , ]
SW.chem <- merge(SW.chem,TA, by="Sample.ID", all = TRUE, sort = T) #merge seawater chemistry with total alkalinity
SW.chem <- na.omit(SW.chem) #remove NA
SW.chem <- merge(SW.chem, Refs[c("Date", "TA.Corr")], by="Date", all = F, sort = F) #merge seawater chemistry with total alkalinity
SW.chem$TA.Mes <- as.numeric(paste(SW.chem$TA.Mes)) #set as numeric
SW.chem$TA.Corr <- as.numeric(paste(SW.chem$TA.Corr)) #set as numeric
SW.chem$Corrected.TA <- SW.chem$TA.Mes - SW.chem$TA.Corr #correct for offset from CRM
SW.chem <- na.omit(SW.chem) #remove NA

#Calculate CO2 parameters using seacarb
carb.ouptput <- carb(flag=8, var1=SW.chem$pH.Total, var2=SW.chem$Corrected.TA/1000000, S= SW.chem$Salinity, T=SW.chem$Temperature, P=0, Pt=0, Sit=0, pHscale="T", kf="pf", k1k2="l", ks="d") #calculate seawater chemistry parameters using seacarb
carb.ouptput$ALK <- carb.ouptput$ALK*1000000 #convert to µmol kg-1
carb.ouptput$CO2 <- carb.ouptput$CO2*1000000 #convert to µmol kg-1
carb.ouptput$HCO3 <- carb.ouptput$HCO3*1000000 #convert to µmol kg-1
carb.ouptput$CO3 <- carb.ouptput$CO3*1000000 #convert to µmol kg-1
carb.ouptput$DIC <- carb.ouptput$DIC*1000000 #convert to µmol kg-1
carb.ouptput <- carb.ouptput[,-c(1,4,5,8,10:13,19)]
carb.ouptput <- cbind(SW.chem$Date,  SW.chem$Tank,  SW.chem$Treatment, carb.ouptput) #combine the sample information with the seacarb output
colnames(carb.ouptput) <- c("Date",  "Tank",  "Treatment",	"Salinity",	"Temperature", "pH",	"CO2",	"pCO2","HCO3",	"CO3",	"DIC", "TA",	"Aragonite.Sat") #Rename columns to describe contents
carb.ouptput
setwd(file.path(mainDir, 'Output')) #set output location
write.table(carb.ouptput, file="SW_Chem_Table_byTank.csv",sep=",", row.names = FALSE)#exports your data as a CSV file
setwd(file.path(mainDir, 'Data'))

pdf("~/MyProjects/Moorea/Moorea_April2017/RAnalysis/Output/Treatment_SW_Chem.pdf")
par(mfrow=c(3,2))
boxplot(Temperature ~ Treatment, data = carb.ouptput, lwd = 1, xlab= "Treatment", ylab="Temp °C", ylim=c(27,29))
stripchart(Temperature ~ Treatment, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
boxplot(pH ~ Treatment, data = carb.ouptput, lwd = 1, xlab= "Treatment", ylab="pH (total)", ylim=c(7.4,8.2))
stripchart(pH ~ Treatment, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
boxplot(pCO2 ~ Treatment, data = carb.ouptput, lwd = 1, xlab= "Treatment", ylab="pCO2 µatm", ylim=c(300,1600))
stripchart(pCO2 ~ Treatment, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
boxplot(TA ~ Treatment, data = carb.ouptput, lwd = 1, xlab= "Treatment", ylab="Total Alkalinity µmol kg-1", ylim=c(2250,2400))
stripchart(TA ~ Treatment, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
boxplot(Aragonite.Sat ~ Treatment, data = carb.ouptput, lwd = 1, xlab= "Treatment", ylab="Aragonite Sat State", ylim=c(0.5,4.5))
stripchart(Aragonite.Sat ~ Treatment, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
boxplot(DIC ~ Treatment, data = carb.ouptput, lwd = 1, xlab= "Treatment", ylab="DIC µmol kg-1", ylim=c(1950,2400))
stripchart(DIC ~ Treatment, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
dev.off()



pdf("~/MyProjects/Moorea/Moorea_April2017/RAnalysis/Output/Tank_SW_Chem.pdf")
par(mfrow=c(3,2))
boxplot(Temperature ~ Tank, data = carb.ouptput, lwd = 1, xlab= "Tank", ylab="Temp °C", ylim=c(27,29))
stripchart(Temperature ~ Tank, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
boxplot(pH ~ Tank, data = carb.ouptput, lwd = 1, xlab= "Tank", ylab="pH (total)", ylim=c(7.4,8.2))
stripchart(pH ~ Tank, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
boxplot(pCO2 ~ Tank, data = carb.ouptput, lwd = 1, xlab= "Tank", ylab="pCO2 µatm", ylim=c(300,1600))
stripchart(pCO2 ~ Tank, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
boxplot(TA ~ Tank, data = carb.ouptput, lwd = 1, xlab= "Tank", ylab="Total Alkalinity µmol kg-1", ylim=c(2250,2400))
stripchart(TA ~ Tank, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
boxplot(Aragonite.Sat ~ Tank, data = carb.ouptput, lwd = 1, xlab= "Tank", ylab="Aragonite Sat State", ylim=c(0.5,4.5))
stripchart(Aragonite.Sat ~ Tank, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
boxplot(DIC ~ Tank, data = carb.ouptput, lwd = 1, xlab= "Tank", ylab="DIC µmol kg-1", ylim=c(1950,2400))
stripchart(DIC ~ Tank, vertical = TRUE, data = carb.ouptput, 
           method = "jitter", add = TRUE, pch = 24, col = 'blue')
dev.off()


carbo.melted <- melt(carb.ouptput) #reshape the dataframe to more easily summarize all output parameters
mean.carb.output <-ddply(carbo.melted, .(Treatment, variable), summarize, #For each subset of a data frame, apply function then combine results into a data frame.
                               N = length(na.omit(value)), #number of records
                               mean = (mean(value)),       #take the average of the parameters (variables) summarized by treatments
                               sem = (sd(value)/sqrt(N))) #calculate the SEM as the sd/sqrt of the count or data length
mean.carb.output # display mean and sem 

