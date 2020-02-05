# trace plots for bach
# add TF plot
# trace_plots11.r - modify colours to match boxplots

library(tidyverse)
library(cowplot)
library(scales) # for dates
library(rkt) # Mann-Kendall test
library(lubridate)
library(lfstat)
library(FlowScreen)
library(RColorBrewer)
library(naniar)

# path for output
# out_path <- 'run - eckhardt_priors_narrow/'
print(out_path)

##### read in data ####
source('read_data9.r')
nruns <- nrow(runlist)

# choose rows to run
rows <- 1:nruns # to run all sites
ah <- vector("list", nruns) # all hydrographs
# rows <- c(20,21) # to run a subset of sites, useful for testing
# i <- rows[[10]]

#### loop through data sets ####
i <- rows[1]
for (i in rows){

# set axis options for each set
if (i %in% c(1,9,17)) { # Tahuna
  TPlimits <- c(0,0.4)
  TPbreaks <- seq(0,0.8,0.2)
  TNlimits <- c(0,6)
  TNbreaks <- seq(0,6,2)
  flowlimits <- c(0,20)
  flowbreaks <- seq(0,20,5)
} else if (i %in% c(2,10,18)) { # Otama
  TPlimits <- c(0,0.4)
  TPbreaks <- seq(0,0.8,0.2)
  TNlimits <- c(0,6)
  TNbreaks <- seq(0,6,2)
  flowlimits <- c(0,5)
  flowbreaks <- seq(0,5,1)
} else if (i %in% c(3,11,19)) { # Waiotapu
  TPlimits <- c(0,0.4)
  TPbreaks <- seq(0,0.8,0.2)
  TNlimits <- c(0,6)
  TNbreaks <- seq(0,6,2)
  flowlimits <- c(0,10)
  flowbreaks <- seq(0,10,2)
  } else if (i %in% c(4,12,20)) { # Pokai
  TPlimits <- c(0,0.4)
  TPbreaks <- seq(0,0.8,0.2)
  TNlimits <- c(0,6)
  TNbreaks <- seq(0,6,2)
  flowlimits <- c(0,20)
  flowbreaks <- seq(0,20,5)
} else if (i %in% c(5,13,21)) { # Piako
  TPlimits <- c(0,0.4)
  TPbreaks <- seq(0,0.8,0.2)
  TNlimits <- c(0,6)
  TNbreaks <- seq(0,6,2)
  flowlimits <- c(0,8)
  flowbreaks <- seq(0,8,2)
} else if (i %in% c(6,14,22)) { # Waitoa
  TPlimits <- c(0,0.4)
  TPbreaks <- seq(0,0.8,0.2)
  TNlimits <- c(0,6)
  TNbreaks <- seq(0,6,2)
  flowlimits <- c(0,8)
  flowbreaks <- seq(0,8,2)
} else if (i %in% c(7,15,23)) { # Waihou
  TPlimits <- c(0,0.4)
  TPbreaks <- seq(0,0.8,0.2)
  TNlimits <- c(0,6)
  TNbreaks <- seq(0,6,2)
  flowlimits <- c(0,80)
  flowbreaks <- seq(0,80,20)
} else if (i %in% c(8,16,24)) { # Puniu
  TPlimits <- c(0,0.4)
  TPbreaks <- seq(0,0.8,0.2)
  TNlimits <- c(0,6)
  TNbreaks <- seq(0,6,2)
  flowlimits <- c(0,60)
  flowbreaks <- seq(0,60,20)
} else {
  stop()
}

# rough estimate for total flow (TF)
TFlimits <- flowlimits * 1;
TFbreaks <- flowbreaks * 1;
  
data_file_name <- paste(runlist$catchfile[i], '_data.dat', sep='')
opt_file_name <- runlist$optfile[i]
print(paste(data_file_name, "+", opt_file_name))
  
# assemble run options/data into vectors (?)
arun <- runlist[i, ]
adata <- data[grep(pattern=data_file_name, x=data$file), ]
aarea <- tibble(area=adata$area[1])
aoptions <- options[opt_file_name, ]
aalloptions <- cbind(arun, aoptions, aarea) # combine into one data table
startcalib <- aalloptions$startcalib
endcalib <- aalloptions$endcalib
catchname <- aalloptions$catchname
setname <- aalloptions$setname
keeps <- c('startrun', 'startcalib', 'endcalib', 'startvalid', 'endvalid')
intoptions <- as.vector(t(aalloptions[keeps]))
nintoptions <- length(intoptions)
keeps <- c('chem1ae', 'chem1re', 'chem2ae', 'chem2re', 'area')
realoptions <- as.vector(t(aalloptions[keeps]))
nrealoptions <- length(realoptions)
date <- as.vector(adata$date)
ndate <- length(date)
flow <- as.vector(adata$flow)
TP <- as.vector(adata$TP)
TN <- as.vector(adata$TN)
meanTPcalib <- mean(TP[startcalib:endcalib], na.rm=TRUE)
meanTNcalib <- mean(TN[startcalib:endcalib], na.rm=TRUE)
meanTFcalib <- mean(flow[startcalib:endcalib])
TP[is.na(TP)] <- -1 # stan doesn't understand NA
TN[is.na(TN)] <- -1 # stan doesn't understand NA

# add flow info
adata <- adata %>%
  mutate(x=rep(1:ndate, times=1), 
         xdate=as.Date(date, origin='1899-12-30'),
         TF=flow) 

# define date range
fromdate <- as.Date(intoptions[2], origin='2000-12-31') 
todate <- as.Date(intoptions[3], origin='2000-12-31') 
daterange = c(fromdate, todate)

#### do hydrograph ####

# get hydrograph
y6 <- adata %>%
  mutate(pc="data") %>%
  select(pc, TF, x, xdate) %>%
  filter(x %in% c(startcalib:endcalib)) %>%
  mutate(
    flow=TF,
    day=day(xdate),
    month=month(xdate),
    year=year(xdate)
  )
ldata <- createlfobj(y6, hyearstart=1) # does baseflow separation
y6$baseflow <- ldata$baseflow
bfi <- BFI(ldata)   
print(paste("BFI Fixed    =", bfi))
y6$baseflow2 <- bf_eckhardt(y6$flow, 0.98, 0.8)
bfi2 <- sum(y6$baseflow2) / sum(y6$flow)
print(paste("BFI Eckhardt =", bfi2))

p0 <- ggplot() +
  labs(title='', y='Flow '~(m^3~s^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  # scale_colour_manual(values=c('orchid','darkorchid','darkmagenta','darkorchid','orchid')) +
  scale_colour_manual(values=c('black','black','black','black','black')) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  # scale_y_continuous(expand=c(0, 0), limits=TFlimits, breaks=TFbreaks) +
  scale_y_continuous(expand=c(0, 0), breaks=TFbreaks) +
  coord_cartesian(ylim=TFlimits) +
  # geom_ribbon(data=y6, mapping=aes(x=xdate, ymin=TF-0.2*tci*TF, ymax=TF+0.2*tci*TF), colour='lightgrey', fill='lightgrey') +
  geom_line(data=y6, mapping=aes(x=xdate, y=TF, colour=pc))
aah <- p0 + 
  annotate(geom="label", x=min(y6$xdate)+120, y=max(TFlimits)*0.8, label=setname, size=4)  +
  # geom_line(data=y6, mapping=aes(x=xdate, y=baseflow2), colour="red") +
  labs(y='') 
# print(aah)

# now do stuff that only applies to data sets that have chem data
file_name <- paste(out_path, setname, '_traces.rds', sep='')
if (file.exists(file_name)){
  
# simple trend analysis on adata
print("Simple trend analysis")
tdata <- adata %>% 
  select(shortname, TF, TP, TN, x, xdate) %>%
  filter(x %in% c(startcalib:endcalib)) %>%
  mutate(
    day=day(xdate),
    month=month(xdate),
    year=year(xdate)
  ) 
qflows <- quantile(tdata$TF, c(0.05, 0.50, 0.95))
tyear <- tibble(year = unique(tdata$year)) %>% 
  mutate(
    shortname = tdata$shortname[1],
    TP05 = NA_real_, 
    TP50 = NA_real_, 
    TP95 = NA_real_, 
    TN05 = NA_real_, 
    TN50 = NA_real_, 
    TN95 = NA_real_
  )
j <- 1
for (j in 1:nrow(tyear)){
  tdatai <- tdata %>% 
    filter(year == tyear$year[j]) %>% 
    drop_na()
  # modelTP <- loess(TP ~ TF, data = tdatai, control = loess.control(surface = "interpolate"))
  # modelTN <- loess(TN ~ TF, data = tdatai, control = loess.control(surface = "interpolate"))
  if (nrow(tdatai) > 3){
    modelTP <- lm(TP ~ poly(TF, 3), data = tdatai)
    modelTN <- lm(TN ~ poly(TF, 3), data = tdatai)
    tdatai$modelTP <- predict(modelTP, tdatai)
    tdatai$modelTN <- predict(modelTN, tdatai)
    ggplot(tdatai) +
      geom_point(mapping = aes(x = TF, y = TP)) +
      geom_line(mapping = aes(x = TF, y = modelTP), colour = "red")
    ggplot(tdatai) +
      geom_point(mapping = aes(x = TF, y = TN)) +
      geom_line(mapping = aes(x = TF, y = modelTN), colour = "blue")
    tyear$TP05[j] <- predict(modelTP, data.frame(TF = qflows[1]))
    tyear$TP50[j] <- predict(modelTP, data.frame(TF = qflows[2]))
    tyear$TP95[j] <- predict(modelTP, data.frame(TF = qflows[3]))
    tyear$TN05[j] <- predict(modelTN, data.frame(TF = qflows[1]))
    tyear$TN50[j] <- predict(modelTN, data.frame(TF = qflows[2]))
    tyear$TN95[j] <- predict(modelTN, data.frame(TF = qflows[3]))
  }
}
ggplot(tyear) +
  labs(title = paste(tyear$shortname[1], "TP")) +
  geom_line(mapping = aes(x = year, y = TP05), colour = "blue") +
  geom_line(mapping = aes(x = year, y = TP50), colour = "green") +
  geom_line(mapping = aes(x = year, y = TP95), colour = "red") 
ggplot(tyear) +
  labs(title = paste(tyear$shortname[1], "TN")) +
  geom_line(mapping = aes(x = year, y = TN05), colour = "blue") +
  geom_line(mapping = aes(x = year, y = TN50), colour = "green") +
  geom_line(mapping = aes(x = year, y = TN95), colour = "red") 

# read traces
traces <- read_rds(file_name)

# read quartiles from previous run to compare
# old_path <- "../bach_constant/run - eckhardt_priors_narrow/"
old_path <- paste0(out_path, "/old_quartiles/")
old_quartiles <- paste0(old_path, aalloptions$setname, "_quartiles.rds")
old_quartiles <- str_replace(old_quartiles, "\\(x\\)", c("(a)", "(b)", "(c)"))
old_fits <- vector("list", 3)  
old_fits[[1]] <- readRDS(old_quartiles[1]) %>% mutate(xdate = dmy("1-July-2004")) %>% slice(4:8)
if (file.exists(old_quartiles[2])){
  old_fits[[2]] <- readRDS(old_quartiles[2]) %>% mutate(xdate = dmy("1-July-2009")) %>% slice(4:8)
} else {
  old_fits[[2]] <- readRDS(old_quartiles[1]) %>% 
    replace_with_na_all(~TRUE) %>% 
    mutate(xdate = dmy("1-July-2009")) %>% slice(4:8)
}
old_fits[[3]] <- readRDS(old_quartiles[3]) %>% mutate(xdate = dmy("1-July-2014")) %>% slice(4:8)
old_box <- bind_rows(old_fits) %>% mutate(pc=rep(c('2.5%', '25%', '50%', '75%', '97.5%'), 3))

# this is probably a better approach, use a single data frame for all variables
# temp <- traces %>%
#   select('2.5%', '25%', '50%', '75%', '97.5%') %>%
#   mutate(name=rownames(traces)) %>%
#   gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='val') %>%
#   mutate(var=rep(c('Fast', 'Medium', 'Slow', 'TP', 'TN'), times=ndate*5),
#          date=rep(1:ndate, each=5, times=5))

sort <- c(1,5,2,4,3)
# tpcol <- c('chartreuse','green','seagreen','green','chartreuse')
# tncol <- c('pink','red','darkred','red','pink')
# fcol <- c('orange','firebrick','darkorange','firebrick','orange')
# mcol <- c('deepskyblue','blue','darkblue','blue','deepskyblue')
# scol <- c('orchid','darkorchid','darkmagenta','darkorchid','orchid')
choose <- c(3,5,7,5,3)
tpcol <- brewer.pal(9,"OrRd")[choose]
tncol <- brewer.pal(9,"YlGn")[choose]
fcol <- brewer.pal(9,"YlOrBr")[choose-1]
mcol <- brewer.pal(9,"PuBu")[choose+1]
scol <- brewer.pal(9,"RdPu")[choose+1]

keeps <- grep(',3]', rownames(traces), invert=FALSE) 
y3 <- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='Slow') %>%
  mutate(x=rep(1:ndate, times=5), 
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib))

keeps <- grep(',2]', rownames(traces), invert=FALSE) 
y2 <- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='Medium') %>%
  mutate(x=rep(1:ndate, times=5),
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib)) %>%
  mutate(Medium=Medium-y3$Slow)

keeps <- grep(',1]', rownames(traces), invert=FALSE) 
y1 <- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='Fast') %>%
  mutate(x=rep(1:ndate, times=5),
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib)) %>%
  mutate(Fast=Fast-y2$Medium-y3$Slow)

# keeps <- grep(',1]', rownames(traces), invert=FALSE) 
# y6 <- as_tibble(traces[keeps,]) %>% 
#   select('2.5%', '25%', '50%', '75%', '97.5%') %>%
#   gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='TF') %>%
#   mutate(x=rep(1:ndate, times=5),
#          xdate=as.Date(x, origin='2000-12-31')) %>%
#   filter(x %in% c(startcalib:endcalib)) 

keeps <- grep(',4]', rownames(traces), invert=FALSE) 
y4 <- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='TP') %>%
  mutate(x=rep(1:ndate, times=5),
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib))

keeps <- grep(',5]', rownames(traces), invert=FALSE) 
y5<- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='TN') %>%
  mutate(x=rep(1:ndate, times=5),
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib))

keeps <- grep(',6]', rownames(traces), invert=FALSE) 
y6<- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='fastTP') %>%
  mutate(x=rep(1:ndate, times=5),
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib))

keeps <- grep(',7]', rownames(traces), invert=FALSE) 
y7<- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='medTP') %>%
  mutate(x=rep(1:ndate, times=5),
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib))

keeps <- grep(',8]', rownames(traces), invert=FALSE) 
y8<- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='slowTP') %>%
  mutate(x=rep(1:ndate, times=5),
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib))

keeps <- grep(',9]', rownames(traces), invert=FALSE) 
y9<- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='fastTN') %>%
  mutate(x=rep(1:ndate, times=5),
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib))

keeps <- grep(',10]', rownames(traces), invert=FALSE) 
y10<- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='medTN') %>%
  mutate(x=rep(1:ndate, times=5),
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib))

keeps <- grep(',11]', rownames(traces), invert=FALSE) 
y11<- as_tibble(traces[keeps,]) %>% 
  select('2.5%', '25%', '50%', '75%', '97.5%') %>%
  gather('2.5%', '25%', '50%', '75%', '97.5%', key='pc', value='slowTN') %>%
  mutate(x=rep(1:ndate, times=5),
         xdate=as.Date(x, origin='2000-12-31'),
         pc=factor(pc, levels=c('2.5%', '25%', '50%', '75%', '97.5%')[sort], ordered=TRUE)) %>%
  filter(x %in% c(startcalib:endcalib))

##### plot chem trace ####
tci <- qt(.975,7) # how many s.e. for 95% c.i.

p4 <- ggplot() +
  labs(title='', y='TP '~(mg~L^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  # scale_colour_manual(values=c('orange','firebrick','darkred','firebrick','orange')) +
  scale_colour_manual(values=tpcol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), limits=TPlimits, breaks=TPbreaks) +
  geom_ribbon(data=y4, mapping=aes(x=xdate, ymin=TP-0.02*tci, ymax=TP+0.02*tci), colour='lightgrey', fill='lightgrey') +
  geom_line(data=y4, mapping=aes(x=xdate, y=TP, colour=pc)) +
  geom_point(data=adata, mapping=aes(x=xdate, y=TP)) 

p4r <- ggplot() +
  labs(title='', y='TP residual '~(mg~L^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  # scale_colour_manual(values=c('orange','firebrick','darkred','firebrick','orange')) +
  scale_colour_manual(values=tpcol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), limits=TPlimits, breaks=TPbreaks) +
  geom_ribbon(data=y4, mapping=aes(x=xdate, ymin=TP-0.02*tci, ymax=TP+0.02*tci), colour='lightgrey', fill='lightgrey') +
  geom_line(data=y4, mapping=aes(x=xdate, y=TP, colour=pc)) +
  geom_point(data=adata, mapping=aes(x=xdate, y=TP)) 

p6 <- ggplot() +
  labs(title='', y='fTP '~(mg~L^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  # scale_colour_manual(values=c('orange','firebrick','darkred','firebrick','orange')) +
  scale_colour_manual(values=tpcol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), limits=TPlimits, breaks=TPbreaks) +
  geom_point(data=old_box, mapping=aes(x=xdate, y=chem1fast), colour="grey") +
  geom_line(data=y6, mapping=aes(x=xdate, y=fastTP, colour=pc)) 

p7 <- ggplot() +
  labs(title='', y='mTP '~(mg~L^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  # scale_colour_manual(values=c('orange','firebrick','darkred','firebrick','orange')) +
  scale_colour_manual(values=tpcol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), limits=TPlimits, breaks=TPbreaks) +
  geom_point(data=old_box, mapping=aes(x=xdate, y=chem1med), colour="grey") +
  geom_line(data=y7, mapping=aes(x=xdate, y=medTP, colour=pc)) 

p8 <- ggplot() +
  labs(title='', y='sTP '~(mg~L^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  # scale_colour_manual(values=c('orange','firebrick','darkred','firebrick','orange')) +
  scale_colour_manual(values=tpcol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), limits=TPlimits, breaks=TPbreaks) +
  geom_point(data=old_box, mapping=aes(x=xdate, y=chem1slow), colour="grey") +
  geom_line(data=y8, mapping=aes(x=xdate, y=slowTP, colour=pc)) 

temp <- filter(adata, TP>0.4)
if (nrow(temp)>0){
  p4 <- p4 + # add labelled outliers
    geom_point(data=temp, mapping=aes(x=xdate, y=0.37)) +
    geom_text(data=temp, mapping=aes(x=xdate, y=0.37, label=as.character(TP)), nudge_x=200) 
}

# testing
print(p4)

#### trend analysis ####
res4 <- y4 %>%
  filter(pc == "50%") %>%
  rename(TPmodel = TP) %>%
  left_join(adata, by=c("x", "xdate")) %>%
  drop_na() %>%
  mutate(TPres = TP - TPmodel) %>%
  mutate(xdate2=decimal_date(xdate),
         month=month(xdate))
ggplot() +
  geom_point(data=res4, mapping=aes(x=xdate, y=TPres)) 
if (sum(!is.na(res4$TP))>35){
  res4fit <- rkt(date=res4$xdate2, y=res4$TPres, block=res4$month, correct=TRUE)
  print(paste("TPres trend = ", res4fit$B/median(res4$TP, na.rm=TRUE), "p = ", res4fit$sl))
} else if (sum(!is.na(res4$TP))>0){
  res4fit <- rkt(date=res4$xdate2, y=res4$TPres)
  print(paste("TPres trend = ", res4fit$B/median(res4$TP, na.rm=TRUE), "p = ", res4fit$sl))
} else {
  print("Not enough data for TP trend")
}

p5 <- ggplot() +
  labs(title='', y='TN '~(mg~L^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  scale_colour_manual(values=tncol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), limits=TNlimits, breaks=TNbreaks) +
  geom_ribbon(data=y5, mapping=aes(x=xdate, ymin=TN-0.2*tci, ymax=TN+0.2*tci), colour='lightgrey', fill='lightgrey') +
  geom_line(data=y5, mapping=aes(x=xdate, y=TN, colour=pc)) +
  geom_point(data=adata, mapping=aes(x=xdate, y=TN))

p9 <- ggplot() +
  labs(title='', y='fTN '~(mg~L^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  scale_colour_manual(values=tncol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), limits=TNlimits, breaks=TNbreaks) +
  geom_point(data=old_box, mapping=aes(x=xdate, y=chem2fast), colour="grey") +
  geom_line(data=y9, mapping=aes(x=xdate, y=fastTN, colour=pc)) 

p10 <- ggplot() +
  labs(title='', y='mTN '~(mg~L^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  scale_colour_manual(values=tncol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), limits=TNlimits, breaks=TNbreaks) +
  geom_point(data=old_box, mapping=aes(x=xdate, y=chem2med), colour="grey") +
  geom_line(data=y10, mapping=aes(x=xdate, y=medTN, colour=pc)) 

p11 <- ggplot() +
  labs(title='', y='sTN '~(mg~L^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  scale_colour_manual(values=tncol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), limits=TNlimits, breaks=TNbreaks) +
  geom_point(data=old_box, mapping=aes(x=xdate, y=chem2slow), colour="grey") +
  geom_line(data=y11, mapping=aes(x=xdate, y=slowTN, colour=pc)) 

res5 <- y5 %>%
  filter(pc == "50%") %>%
  rename(TNmodel = TN) %>%
  left_join(adata, by=c("x", "xdate")) %>%
  drop_na() %>%
  mutate(TNres = TN - TNmodel) %>%
  mutate(xdate2=decimal_date(xdate),
         month=month(xdate))
ggplot() +
  geom_point(data=res5, mapping=aes(x=xdate, y=TNres)) 
if (sum(!is.na(res4$TN))>35){
  res5fit <- rkt(date=res5$xdate2, y=res5$TNres, block=res5$month, correct=TRUE)
  print(paste("TNres trend = ", res5fit$B/median(res5$TN, na.rm=TRUE), "p = ", res5fit$sl))
} else if (sum(!is.na(res4$TN))>0){
  res5fit <- rkt(date=res5$xdate2, y=res5$TNres)
  print(paste("TNres trend = ", res5fit$B/median(res5$TN, na.rm=TRUE), "p = ", res5fit$sl))
} else { 
  print("Not enough data for TN trend")
}

# fit plot
# plotchem <- plot_grid(p4, p5, p0, nrow=3, align="v")
# print(plotchem)
# file_name <- paste(out_path, setname, '_chemtrace.png', sep="")
# save_plot(file_name, plotchem, base_height=7, base_width=8)

#### plot flow trace ####
p1 <- ggplot() +
  labs(title='', y='Fast '~(m^3~s^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  scale_colour_manual(values=fcol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), breaks=flowbreaks) +
  coord_cartesian(ylim=flowlimits) +
  geom_line(data=y1, mapping=aes(x=xdate, y=Fast, colour=pc)) 

p2 <- ggplot() +
  labs(title='', y='Med. '~(m^3~s^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  scale_colour_manual(values=mcol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), breaks=flowbreaks) +
  coord_cartesian(ylim=flowlimits) +
  geom_line(data=y2, mapping=aes(x=xdate, y=Medium, colour=pc)) 

p3 <- ggplot() +
  labs(title='', y='Slow '~(m^3~s^{-1}), x='', colour='Percentile') +
  theme_cowplot() +
  theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
  panel_border(colour='black') +  
  scale_colour_manual(values=scol[sort]) +
  scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
  scale_y_continuous(expand=c(0, 0), breaks=flowbreaks) +
  coord_cartesian(ylim=flowlimits) +
  geom_line(data=y3, mapping=aes(x=xdate, y=Slow, colour=pc)) 

y6$Slow <- filter(y3, pc=="50%")$Slow
y6$Medium <- filter(y2, pc=="50%")$Medium 
aah <- aah +
  geom_line(data=y6, mapping=aes(x=xdate, y=Medium+Slow), colour="deepskyblue") + # add bach results
  geom_line(data=y6, mapping=aes(x=xdate, y=Slow), colour="orchid") + # add bach results
  annotate(geom="label", x=min(y6$xdate)+120, y=max(TFlimits)*0.8, label=setname, size=4) # rewrite label
  
# plotflow <- plot_grid(p1, p2, p3, nrow=3, align="v")
# print(plotflow)
# file_name <- paste(out_path, setname, '_flowtrace.png', sep="")
# save_plot(file_name, plotflow, base_height=7, base_width=8)

# p1 <- ggplot() +
#   labs(title='', y='Fast '~(m^3~s^{-1}), x='', colour='Percentile') +
#   theme_cowplot() +
#   theme(legend.position='none', plot.margin=unit(c(0, 0.3, 0, 0), 'cm'), plot.title=element_blank()) +
#   panel_border(colour='black') +  
#   scale_colour_manual(values=c('orange','firebrick','darkred','firebrick','orange')) +
#   scale_x_date(limits=daterange, date_labels='%Y', date_breaks='1 year') +
#   scale_y_continuous(expand = c(0, 0), breaks=seq(0,10,2)) +
#   coord_cartesian(ylim=c(0, 10)) +
#   geom_line(data=y1, mapping=aes(x=xdate, y=Fast, colour=pc)) 

title <- ggdraw() + draw_label(catchname, fontface='bold')
plotall <- plot_grid(title, p4, p5, p0, p1, p2, p3, ncol=1, rel_heights=c(0.3,1,1,1,1,1,1), align="v")
# print(plotall)
file_name <- paste(out_path, setname, '_alltrace.png', sep="")
save_plot(file_name, plotall, base_height=10, base_width=8)

title <- ggdraw() + draw_label(catchname, fontface='bold')
plotall <- plot_grid(title, p6, p7, p8, p9, p10, p11, ncol=1, rel_heights=c(0.3,1,1,1,1,1,1), align="v")
# print(plotall)
file_name <- paste(out_path, setname, '_conctrace.png', sep="")
save_plot(file_name, plotall, base_height=10, base_width=8)

# some useful information
print(paste('Mean flow calib =',meanTFcalib))
print(paste('Min fast flow =',min(y1$Fast)))
print(paste('Max fast flow =',max(y1$Fast)))
print(paste('Min medium flow =',min(y2$Medium)))
print(paste('Max medium flow =',max(y2$Medium)))
print(paste('Min slow flow =',min(y3$Slow)))
print(paste('Max slow flow =',max(y3$Slow)))

} # end if file exists

ah[[aalloptions$setseq]] <- aah # store hydrograph

} # end for loop

#### plot all hydrographs ####
if (nruns==24){
  blank <- ggplot(data.frame()) + geom_point()
  plotah <- plot_grid(
    blank, blank, blank,
    ah[[1]], ah[[2]], ah[[3]], 
    ah[[4]], ah[[5]], ah[[6]],
    ah[[7]], ah[[8]], ah[[9]],
    ah[[10]], ah[[11]], ah[[12]],
    ah[[13]], ah[[14]], ah[[15]],
    ah[[16]], ah[[17]], ah[[18]],
    ah[[19]], ah[[20]], ah[[21]],
    ah[[22]], ah[[23]], ah[[24]],
    rel_heights=c(0.2,1,1,1,1,1,1,1,1), ncol=3, align="v")
  # print(plotah)
  file_name <- paste(out_path, 'all_hydrotrace.png', sep="")
  save_plot(file_name, plotah, base_height=12, base_width=12)
} else if (nruns==8){
  blank <- ggplot(data.frame()) + geom_point()
  plotah <- plot_grid(
    blank, 
    ah[[1]], ah[[2]], ah[[3]], 
    ah[[4]], ah[[5]], ah[[6]],
    ah[[7]], ah[[8]],
    rel_heights=c(0.2,1,1,1,1,1,1,1,1), ncol=1, align="v")
  # print(plotah)
  file_name <- paste(out_path, 'all_hydrotrace.png', sep="")
  save_plot(file_name, plotah, base_height=12, base_width=12)
}

