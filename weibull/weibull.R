"Rahil Patel"
"https://stats.stackexchange.com/questions/346249/fitting-weibull-distribution-in-r"


dat <- read.csv('df.csv')
dat <- dat[order(dat$loc.id,dat$year.id),]
dat$loc.id <- factor(dat$loc.id)
dat$year.id <- factor(dat$year.id)

library(plyr)
#hacking the original data from the cumulative
to.density <- function(cdf) {  #given input (a cdf vector), returns respective densities
  y <- c(); cdf <- cdf[,'cum.per.plant']
  for (cum in seq(1,NROW(cdf))) {y <- c(y, ifelse(cum==1, cdf[cum], cdf[cum]-cdf[cum-1]))}
  return(y)
}

densities <- dlply(dat, .(loc.id, year.id), to.density) #apply to each location X year in dat
dat <- cbind(dat,dens=unlist(densities)) #bind density data to dat

#forming a dataset of the variable planting time
#--because the proportions go to the thousandths place, a pseudo-sample of time.id's with n=1000 should allow usage 
#--of fitdist
rep.vec <- function(df) {
  y <- c()
  for (row in rownames(df)) {y <- c(y, rep(df[row,'time.id'], df[row,'dens']*1000))}
  return(y)
}
#may want to include year.id in the split (excluded)
time.sample <- dlply(dat, .(loc.id), rep.vec) #apply to each location in dat



#fitting separate Weibull distributions for each loc.id (may want to include year.id in the split)
library(fitdistrplus)
fit.weibull <- function(loc) {
  y <- summary(fitdist(loc,'weibull'))[[1]]
  return(y)
}
params <- lapply(time.sample, fit.weibull) #apply to each element in time sample



#creating predictive model - on a daily rather than weekly domain
predict1.cum.plant <- function(day, loc.id, params) {
  pweibull(day, shape=params[[loc.id]][[1]], scale=params[[loc.id]][[2]]*7) #'scaling' 7x the scale parameter 
}

predict2.cum.plant <- function(day, loc.id, params) {
  pweibull(day/7, shape=params[[loc.id]][[1]], scale=params[[loc.id]][[2]]) #'scaling' 1/7x the random variable 
}

#example - the models are equal, which is obvious from the pdf equation!
predict1.cum.plant(35, 2, params)
predict2.cum.plant(35, 2, params) 
pweibull(5, shape=params[[2]][[1]], scale=params[[2]][[2]]) #by week



#turning the time data into a dataframe for plotting with ggplot2
time <- stack(time.sample); colnames(time) <- c('time.week', 'location.index')

#for the sake of brevity, model assessment is virtually excluded; some plots are included plots below, nonetheless
#--distribution fit - diagnostic plots can be used by calling a fitdist summary into a plot()

col.scheme <- c('red3', 'springgreen4', 'royalblue4')
#--plot of non-cumulative data for location.index subjects (1:3)
library(ggplot2)
dens.plot <- ggplot(time[time$location.index %in% seq(1,3),], 
                    aes(x=time.week,  
                        fill=location.index)) +
               geom_histogram(aes(y=..density..), 
                              binwidth=1, 
                              alpha =.35, 
                              position='identity')
for (cnt in seq(1,3)) {
  dens.plot <- dens.plot + stat_function(fun=dweibull, 
                                         args=list(shape=params[[cnt]][[1]], 
                                                   scale=params[[cnt]][[2]]),
                                         color=col.scheme[cnt], #simple way of using iteration # for color
                                         alpha=.8)
}
dens.plot <- dens.plot + scale_color_manual(values = col.scheme) +
                         scale_fill_manual(values = col.scheme) +
                         scale_x_continuous(limits=c(0,12),
                                            breaks=seq(0,14,2)) +
                         scale_y_continuous(limits=c(0,1)) +
                         scale_fill_discrete(name='location',
                                             labels=c('loc 1','loc 2','loc 3')) +
                         labs(x='week', y='density') +
                         ggtitle('fitted pdf') +
                         guides(color=guide_legend(override.aes=list(alpha=.8))) +
                         theme_minimal() +
                         theme(text=element_text(family='Josefin Sans'),
                               plot.title=element_text(hjust=.5,
                                                       face='italic'),
                               axis.title=element_text(face='plain',
                                                       color='dimgrey'),
                               axis.text=element_text(color='black'),
                               legend.background=element_rect(color='black',
                                                              size=.2))

#--plot of cumulative data for loc.id subjects (1:3)
cum.plot <- ggplot(dat[dat$loc.id %in% seq(1,3),], 
                   aes(x=time.id,
                       y=cum.per.plant,
                       color=loc.id)) +
            geom_point()
for (cnt in seq(1,3)) {
  cum.plot <- cum.plot + stat_function(fun=pweibull, 
                                       args=list(shape=params[[cnt]][[1]], 
                                                 scale=params[[cnt]][[2]]),
                                       color=col.scheme[cnt], #simple way of using iteration # for color
                                       alpha=.8) 
}
cum.plot <- cum.plot + scale_color_manual(values = col.scheme) +
                       scale_fill_manual(values = col.scheme) +
                       scale_x_continuous(limits=c(0,12),
                                          breaks=seq(0,12,2)) +
                       scale_y_continuous(limits=c(0,1),
                                          position='right') +
                       labs(x='week', y='cumulative density') +
                       ggtitle('fitted cdf') +
                       theme_minimal() +
                       theme(legend.position="none",
                             text=element_text(family='Josefin Sans'),
                             plot.title=element_text(hjust=.5,
                                                     face='italic'),
                             axis.title=element_text(face='plain',
                                                     color='dimgrey'),
                             axis.text=element_text(color='black'))

#collecting the legend with grob
#--source: https://stackoverflow.com/a/13650878/5099971
get.legend <- function(gplt) {
  tmp <- ggplot_gtable(ggplot_build(gplt))
  leg <- which(sapply(tmp$grob, function(x) x$name)=='guide-box')
  legend <- tmp$grob[[leg]]
  return(legend)
}

lgnd <- get.legend(dens.plot)

#bringing the plots together
library(gridExtra)
grid.arrange(dens.plot + theme(legend.position='none'), 
             lgnd, 
             cum.plot, 
             layout_matrix=rbind(c(1,1,1,1,1,1,2,3,3,3,3,3,3),
                                 c(NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA)))

