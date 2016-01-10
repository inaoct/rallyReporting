###################################  Script Purpose ############################################
# Uses milestones.csv, features.csv, and userstories.csv to process data for Tableau vizualization.
# In all cases the views are filtered by PSI Release prior to exporing to a csv file.
#
# milestones.csv is extarcted from Rally's Plan -> Timeboxes
# The default view was ammended to incluse Notes in addition to the out-of-the box fields.
# Since there is no separate field to indicate milestone status, a status section was added 
# within the NOtes field. It has the following format: Status: [status value]. 
# No Status entry indicates that the milestone is on track.
# Color is used to indicate the type of milestone: external dependency or DPIM deliverable.
#
# features.csv is extracted from Rally's Portfolio -> Portfolio Items
# The default view was ammeded to include the following additional columns:
# Milestones, Initiative, State, Tag. Tag is used to track feature status.
# 
# userstories.csv is extracted from Rally's Plan -> User Stories. 
# To get the appropriate data I created a custom view under Plan -> User Stories.
# The view is called "User Stories with Features" and in addition to the defaul fields 
# has the feature that a user story is associated with. 
# All user stories that fall under a SAFe release are listed out even if they do not have features.
###################################################################################################

## WHEN RUNNING FROM WORK with proxy 
#  Make sure to run Sys.setenv(http_proxy= "http://proxy.inbcu.com/:8080") 
#  Must be run FIRST - at start of session. Otherwise it does not take.
library(dplyr) # used for easier data frame manipulation
library(splitstackshape) # used to split multiple values in a cell into separate rows


## Process milestones
#  Milestone data needs to be stored in CSV file (excel file presents difficulties with dates)
milestoneData <- read.table("./data/milestones.csv", sep = ",", header = TRUE, comment.char = "")
milestoneData <- rename(milestoneData, MilestoneID = Formatted.ID, 
                        MilestoneName = Name, MilestoneColor = Display.Color)
#extract milestones status from milestone Notes
extractStatus <- function(x) {ifelse(grepl("Status", x),  sub("\\].*", "", sub(".*\\[", "", x)), "On Track")}
Sys.setlocale('LC_ALL', 'C') #handle warning messages input string 1 is invalid in this locale
milestoneData <- mutate(milestoneData, MilestoneDate = as.Date(as.character(Target.Date), "%m/%d/%y"),
                        MilestoneStatus = sapply(Notes, extractStatus),
                        MilestoneType = ifelse(is.na(MilestoneColor), "TBD",
                                               ifelse(MilestoneColor == "#ee6c19", "Client Deliverable", 
                                                      ifelse(MilestoneColor == "#df1a7b", "External Dependency", "NA"))))

## Process features
#  Note that using quote = "\"" is important here so that we could read in correctly any records that have commas in their values
featureData <- read.table("./data/features.csv", sep = ",", header = TRUE, comment.char = "", quote = "\"", fill = FALSE)
featureData <- rename(featureData, FeatureID = Formatted.ID, FeatureName = Name, BusinessArea = Parent, 
                      FeatureState = State, FeatureStatus = Tags)
featureData <- mutate(featureData, 
                      BusinessArea = gsub(".*: ", "", BusinessArea),
                      FeatureState = ifelse(FeatureState == "", "Not Started",
                                                         ifelse(FeatureState == "Discovering" , "In Tech Discovery",
                                                                ifelse(FeatureState == "Developing", "In Development", 
                                                                       ifelse(FeatureState == "Done", "Complete", "NA" )))))


## Process feature milestones - multiple milestones are stored in the same cell, separated by ";".
#  Need to extract each milestone into its own line
denormFeatureData <- cSplit(featureData, "Milestones", sep = ";", direction = "long")
#  Extract milestone IDs
firstElement <- function(x){x[1]}
milestoneIDs <- strsplit(as.character(denormFeatureData$Milestones), ":")
denormFeatureData <- mutate(denormFeatureData, 
                            MilestoneID = sapply(milestoneIDs, firstElement))

## Merge the feature and milestone data frames. We need to get all features independent of whether or not they have milestones.
#  Merge by milestone ID
mergedData <- merge(denormFeatureData, milestoneData, by.x = "MilestoneID", by.y = "MilestoneID", all.x = TRUE )
plotData <- select(mergedData, MilestoneID, MilestoneName, FeatureID, FeatureName, BusinessArea, MilestoneType, MilestoneDate, 
                   FeatureState, FeatureStatus, MilestoneStatus)

## Write the resulting data to an excel file. 
#  This will be used for visualization in Tableau.
write.xlsx(plotData, file = "./data/features_and_milestones.xlsx", row.names = FALSE, showNA = FALSE)

## Process user stories
userStoryData <- read.table("./data/userstories.csv", sep = ",", header = TRUE, comment.char = "", quote = "\"", fill = FALSE)
userStoryData <- rename(userStoryData, UserStoryID = Formatted.ID, UserStoryName = Name, Team = Project)
#  Extract feature ID for subsequent merge. If a user story does not have a feature, set the ID to "MISSING".
#  UNDEF would be used to merge with a dummy feature so that user stories with no features can be present in the visualization.
userStoryData <- mutate(userStoryData, FeatureID = ifelse(Feature == "", "MISSING", gsub("^Feature ", "", gsub(":.*", "", Feature))),
                        Iteration = ifelse(Iteration == "", "Iteration Missing", as.character(Iteration)))

## Prep features for merging with user stories.
#  Add a dummy feature with an ID of MISSING and a name of Undefined
dummyFeatureRow <- data.frame( FeatureID = "MISSING", 
                               FeatureName = "Feature Not Assigned", 
                               Release = "",
                               Percent.Done.By.Story.Plan.Estimate = 0,
                               Percent.Done.By.Story.Count = 0,
                               Project = "1", 
                               Milestones = "Undefined Milestone", 
                               BusinessArea = "Undefined Business Area", 
                               FeatureState = "TBD",
                               FeatureStatus = "TBD")
ammendedFeatureData <- rbind(featureData, dummyFeatureRow)

## Merge the feature and user story data frames. We need to get all user stories independent on whether or not they have features
#  Also want to get features that do not have user stories
#  Merge by feature ID
mergedStoryData <- merge(userStoryData, ammendedFeatureData, by.x = "FeatureID", by.y = "FeatureID", all.x = TRUE, all.y = TRUE )
storyPlotData <- select(mergedStoryData, BusinessArea, FeatureID, FeatureName, 
                   UserStoryID, UserStoryName, Iteration, Team, FeatureState, FeatureStatus)

# After the merge any features that have not been assigned stories will have null values in the respective fields. 
# Amend that by explicitly stating that there are no stories assigned and no iterations
# Need to account for 1) no story, 2) no iteration, and 3) no team
storyPlotData <- mutate(storyPlotData, UserStoryID = ifelse(is.na(UserStoryID), "MISSING", as.character(UserStoryID)), 
                        UserStoryName= ifelse(is.na(UserStoryName), "No User Story", as.character(UserStoryName)),
                        Iteration = ifelse(is.na(Iteration), "No Iteration", as.character(Iteration)), 
                        Team = ifelse(is.na(Team), "No Team", as.character(Team)))

## Write the resulting data to an excel file. 
#  This will be used for visualization in Tableau.
write.xlsx(storyPlotData, file = "./data/stories_and_features.xlsx", row.names = FALSE, showNA = FALSE)

