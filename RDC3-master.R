# program:    RDC3-master.R
# task:       Demonstrate basic Stata Workflow
# version:    First draft
# project:    Texas Census Research Data Center Workshop on 
#             project management
# author:     Nathanael Rosenheim \ Jan 30 2015


# What it is the root directory on your computer?
setwd("C:/Users/Nathanael/Dropbox/MyProjects/RDC3")

# *******-*********-*********-*********-*********-*********-*********/
#  Obtain Data -                                                    */
# *******-*********-*********-*********-*********-*********-*********/
# Data output from Stata RDC3-Master.do file

clean <- read.csv("clean/RDC3-SAIPE_POP_2010_TX.csv", header=TRUE)
attach(clean)

# *******-*********-*********-*********-*********-*********-*********/
#  Model Data                                                       */
# *******-*********-*********-*********-*********-*********-*********/

#Figure 6.2 on page 158
m1 <- lm(PALL~p_wa+p_ba+p_h)
summary(m1)

detach(clean)
