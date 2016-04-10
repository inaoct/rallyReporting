###################################  Script Purpose ############################################
# Uses milestones.csv, features.csv, initiatives.csv, and userstories.csv to process data for Tableau vizualization.
# In all cases the views are filtered by PSI Release prior to exporing to a csv file.
#
# milestones.csv is extarcted from Rally's Plan -> Timeboxes
# The default view was ammended to incluse Notes in addition to the out-of-the box fields.
# Since there is no separate field to indicate milestone status, a status section was added
# within the Notes field. It has the following format: Status: [status value].
# No Status entry indicates that the milestone is on track.
# Color is used to indicate the type of milestone: external dependency or DPIM deliverable.
#
# features.csv is extracted from Rally's Portfolio -> Portfolio Items (Features)
# The default view was ammeded to include the following additional columns:
# Milestones, Initiative, State, Tag. Tag is used to track feature status.
#
# initiatives.csv is extracted from Rally's Portfolio -> Portfolio Items (Initiatives)
# The default view was ammeded in the same way as for features but the info is not relevant.
#
# userstories.csv is extracted from Rally's Plan -> User Stories.
# To get the appropriate data I created a custom view under Plan -> User Stories.
# The view is called "User Stories with Features" and in addition to the default fields
# has the feature that a user story is associated with. Also added is a count of the number of children so we
# can determine if a story is a parent story.
# All user stories that fall under a SAFe release are listed out even if they do not have features.
#
# Instructions for correctly populating the necessary data files can be found in the following doc:
# https://docs.google.com/document/d/1oAAEczpufGGxhYO_9ElY5II2Tvn4JC_6kYEAPjgEO84/edit
###################################################################################################

## IMPORTANT!!! WHEN RUNNING FROM WORK with proxy
#  Make sure to run Sys.setenv(http_proxy= "http://proxy.inbcu.com/:8080")
#  Must be run FIRST - at start of session. Otherwise it does not take.

## IMPORTANT!!! Invoke script with the following command:
# system(paste("RScript rallyConcerto.R","username", "password"))
# where username and password represent the login info for Rally
# Note that when running from work - go to wireless NBCU_BYOD. Otherwise I get curl errors

## Handle library pre-requisites
# Using dplyr for its more intuitive data frame processing
if (!require(dplyr))
    install.packages("dplyr")
library(dplyr)
# Using lubridate for easier date manipulation
if (!require(lubridate))
    install.packages("lubridate")
library(lubridate)
# Using splitstackshape to split multiple values in a cell into separate rows
if (!require(splitstackshape))
    install.packages("splitstackshape")
library(splitstackshape)
# Using xlsx for saving results to excel
if (!require(xlsx))
    install.packages("xlsx")
library(xlsx)

#it would be better to have this stored in a csv file and retrieved in "one go"
getProjectFileData <- function() {
    projectFiles <- data.frame(
        RallyProject = "MVPDAdminC",
        featuresURL = "https://rally1.rallydev.com/slm/webservice/v2.x/artifact.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F38172781027&projectScopeDown=true&projectScopeUp=false&fetch=FormattedID%2CName%2CRelease%2CPercentDoneByStoryPlanEstimate%2CPercentDoneByStoryCount%2CProject%2CMilestones%2CParent%2CState%2CTags%2CDirectChildrenCount&order=DragAndDropRank%20ASC&types=portfolioitem%2Ffeature&query",
        initiativesURL = "https://rally1.rallydev.com/slm/webservice/v2.x/artifact.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F38172781027&projectScopeDown=true&projectScopeUp=false&fetch=FormattedID%2CName%2CRelease%2CPercentDoneByStoryPlanEstimate%2CPercentDoneByStoryCount%2CProject%2CMilestones%2CParent%2CState%2CTags%2CDirectChildrenCount&order=DragAndDropRank%20ASC&types=portfolioitem%2Fepic&query=",
        milestonesURL = "https://rally1.rallydev.com/slm/webservice/v2.x/milestone.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F38172781027&projectScopeDown=true&projectScopeUp=false&fetch=FormattedID%2CFormattedID%2CDisplayColor%2CName%2CTargetDate%2CTotalArtifactCount%2CTargetProject%2CNotes&order=TargetDate%20DESC&query=((Projects%20contains%20%22%2Fproject%2F38172781027%22)%20OR%20(TargetProject%20%3D%20null))",
        # userstoriesURL = "https://rally1.rallydev.com/slm/webservice/v2.x/artifact.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F38172781027&projectScopeDown=true&projectScopeUp=true&fetch=FormattedID%2CFormattedID%2CName%2CRelease%2CIteration%2CScheduleState%2CPlanEstimate%2CTaskEstimateTotal%2CTaskRemainingTotal%2CProject%2COwner%2CFeature%2CDirectChildrenCount%2CParent&order=DragAndDropRank%20ASC&types=hierarchicalrequirement&query=",
        userstoriesURL = "https://rally1.rallydev.com/slm/webservice/v2.x/artifact.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F38172781027&projectScopeDown=true&projectScopeUp=true&fetch=FormattedID%2CFormattedID%2CName%2CRelease%2CIteration%2CScheduleState%2CPlanEstimate%2CTaskEstimateTotal%2CTaskRemainingTotal%2CProject%2COwner%2CFeature%2CDirectChildrenCount%2CParent&order=DragAndDropRank%20ASC&types=hierarchicalrequirement&query=(((Release%20%3D%20%22%2Frelease%2F1638ca78-bc81-4c2a-b135-fb5e4c492062%22)%20OR%20(Release%20%3D%20%22%2Frelease%2F1638ca78-bc81-4c2a-b135-fb5e4c492062%22))%20OR%20(Release%20%3D%20%22%2Frelease%2Ff94be348-ca7f-4871-a739-9d659a685c7d%22))",
        # userstoriesURL = "https://www.dropbox.com/s/ygdtapx69k0hawn/userstoriesAdmin.csv?dl=0",
        stringsAsFactors = FALSE
    )
    
    
    # projectFiles <- rbind(
    #   projectFiles,
    #   c(
    #    "TVEArt",
    #     "https://rally1.rallydev.com/slm/webservice/v2.x/artifact.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F42007008861&projectScopeDown=true&projectScopeUp=true&fetch=FormattedID%2CName%2CRelease%2CPercentDoneByStoryPlanEstimate%2CPercentDoneByStoryCount%2CProject%2CMilestones%2CParent%2CState%2CTags&order=Parent%20ASC&types=portfolioitem%2Ffeature&query=(Release%20%3D%20%22%2Frelease%2F42008546124%22)",
    #     "https://rally1.rallydev.com/slm/webservice/v2.x/artifact.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F42007008861&projectScopeDown=true&projectScopeUp=true&fetch=FormattedID%2CName%2CRelease%2CPercentDoneByStoryPlanEstimate%2CPercentDoneByStoryCount%2CProject%2CMilestones%2CParent%2CState%2CTags&order=Parent%20ASC&types=portfolioitem%2Finitiative&query=(Project%20%3D%20%22%2Fproject%2F42007008861%22)",
    #     "https://rally1.rallydev.com/slm/webservice/v2.x/milestone.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F42007008861&projectScopeDown=true&projectScopeUp=true&fetch=FormattedID%2CFormattedID%2CDisplayColor%2CName%2CTargetDate%2CTotalArtifactCount%2CTargetProject%2CNotes&order=TargetDate%20ASC&query=(((Projects%20contains%20%22%2Fproject%2F42007008861%22)%20OR%20(TargetProject%20%3D%20null))%20AND%20(TargetDate%20%3E%3D%20%222015-12-16T00%3A00%3A00-05%3A00%22))",
    #     #"https://www.dropbox.com/s/r46ep9s19po317b/userstories.csv?dl=0"
    #     "https://rally1.rallydev.com/slm/webservice/v2.x/artifact.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F42007008861&projectScopeDown=true&projectScopeUp=true&fetch=FormattedID%2CFormattedID%2CName%2CRelease%2CIteration%2CScheduleState%2CPlanEstimate%2CTaskEstimateTotal%2CTaskRemainingTotal%2CProject%2COwner%2CFeature%2CDirectChildrenCount%2CParent&order=DragAndDropRank%20ASC&types=hierarchicalrequirement&query=(Release%20%3D%20%22%2Frelease%2F42008546124%22)"
    #   )
    #  )
    
    projectFiles <- rbind(
        projectFiles,
        c(
            "ConcertoArt",
            # FEATURES
            "https://rally1.rallydev.com/slm/webservice/v2.x/artifact.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F53007765047&projectScopeDown=true&projectScopeUp=true&fetch=FormattedID%2CName%2CRelease%2CPercentDoneByStoryPlanEstimate%2CPercentDoneByStoryCount%2CProject%2CMilestones%2CParent%2CState%2CTags%2CDirectChildrenCount&order=Parent%20ASC&types=portfolioitem%2Ffeature&query=(Release%20%3D%20%22%2Frelease%2F0ec32483-1181-4663-bdad-af33280086ea%22)",
            # INITIATIVES
            "https://rally1.rallydev.com/slm/webservice/v2.x/artifact.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F53007765047&projectScopeDown=true&projectScopeUp=true&fetch=FormattedID%2CName%2CRelease%2CPercentDoneByStoryPlanEstimate%2CPercentDoneByStoryCount%2CProject%2CMilestones%2CParent%2CState%2CTags%2CDirectChildrenCount&order=Parent%20ASC&types=portfolioitem%2Fepic&query=",
            # MILESTONES
            "https://rally1.rallydev.com/slm/webservice/v2.x/milestone.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F53007765047&projectScopeDown=true&projectScopeUp=true&fetch=FormattedID%2CFormattedID%2CDisplayColor%2CName%2CTargetDate%2CTotalArtifactCount%2CTargetProject%2CNotes&order=TargetDate%20ASC&query=((Projects%20contains%20%22%2Fproject%2F53007765047%22)%20OR%20(TargetProject%20%3D%20null))",
            # USER STORIES
            "https://rally1.rallydev.com/slm/webservice/v2.x/artifact.csv?workspace=%2Fworkspace%2F14663827143&project=%2Fproject%2F53007765047&projectScopeDown=true&projectScopeUp=true&fetch=FormattedID%2CFormattedID%2CName%2CRelease%2CIteration%2CScheduleState%2CPlanEstimate%2CTaskEstimateTotal%2CTaskRemainingTotal%2CProject%2COwner%2CFeature%2CDirectChildrenCount%2CParent&order=DragAndDropRank%20ASC&types=hierarchicalrequirement&query=((Release%20%3D%20%22%2Frelease%2F1638ca78-bc81-4c2a-b135-fb5e4c492062%22)%20OR%20(Release%20%3D%20%22%2Frelease%2F0ec32483-1181-4663-bdad-af33280086ea%22))"
        )
    )
    projectFiles
}


#retrieves the data for all projects and combines them by milestones, features, initiatives, and user stories
retrieveProjectData <- function(projectFiles) {
    featureData <- data.frame()
    initiativeData <- data.frame()
    milestoneData <- data.frame()
    userstoryData <- data.frame()
    
    # get Rally username and password from command line arguments.
    # These are needed to retrieve data directly from Rally.
    args <- commandArgs(trailingOnly = TRUE)
    username <- as.character(args[1])
    password <- as.character(args[2])
    curlOptions <-
        paste("-L -u", paste(username, password, sep = ":"))
    
    for (i in 1:nrow(projectFiles))
    {
        featuresFile <-
            paste("./data/features", projectFiles$RallyProject[i], ".csv", sep = "")
        download.file(
            projectFiles$featuresURL[i],
            destfile = featuresFile ,
            method = "curl", quiet = TRUE, extra = curlOptions
        )
        featureData <- rbind(featureData, processFeatures(featuresFile))
        
        initiativesFile <-
            paste("./data/initiatives", projectFiles$RallyProject[i], ".csv", sep = "")
        download.file(
            projectFiles$initiativesURL[i],
            destfile = initiativesFile,
            method = "curl", quiet = TRUE, extra = curlOptions
        )
        initiativeData <-
            rbind(initiativeData, processInitiatives(initiativesFile))
        
        milestonesFile <-
            paste("./data/milestones", projectFiles$RallyProject[i], ".csv", sep = "")
        download.file(
            projectFiles$milestonesURL[i],
            destfile = milestonesFile,
            method = "curl", quiet = TRUE, extra = curlOptions
        )
        milestoneData <-
            rbind(milestoneData, processMilestones(milestonesFile))
        
        userstoriesFile <-
            paste("./data/userstories", projectFiles$RallyProject[i], ".csv", sep = "")
        download.file(
            projectFiles$userstoriesURL[i],
            destfile = userstoriesFile,
            method = "curl", quiet = TRUE, extra = curlOptions
        )
        userstoryData <-
            rbind(userstoryData, processUserstories(userstoriesFile))
    }
    list(
        "milestones" = milestoneData, "initiatives" = initiativeData,
        "features" = featureData, "userstories" = userstoryData
    )
}


processProjects <- function() {
    combinedList <- retrieveProjectData(getProjectFileData())
    mergedData <- mergeData(combinedList)
    saveData(
        mergedData$featuresAndMilestones,
        mergedData$featuresAndStoriesForStatus,
        mergedData$initiativesAndMilestones,
        mergedData$featuresAndUserstories
    )
}


mergeData <- function(combinedProjectData) {
    denormFeatureData <-
        denormalizeFeatures(combinedProjectData$features)
    ammendedMilestoneData <-
        ammendMilestones(combinedProjectData$milestones)
    denormInitiativeData <-
        denormalizeInitiatives(combinedProjectData$initiatives)
    
    mergedFeaturesAndMilestones <-
        mergeFeaturesAndMilestones(denormFeatureData, ammendedMilestoneData)
    mergeFeaturesAndUserstoriesForStatus <-
        mergeFeaturesAndUserstoriesForStatus(combinedProjectData$userstories,
            combinedProjectData$features)
    mergedInitiativesAndMilestones <-
        mergeInitiativesAndMilestones(denormInitiativeData, ammendedMilestoneData)
    mergedFeaturesAndUserstories <-
        mergeFeaturesAndUserstories(combinedProjectData$userstories,
            combinedProjectData$features)
    list(
        "featuresAndMilestones" = mergedFeaturesAndMilestones,
        "featuresAndStoriesForStatus" = mergeFeaturesAndUserstoriesForStatus,
        "initiativesAndMilestones" = mergedInitiativesAndMilestones,
        "featuresAndUserstories" = mergedFeaturesAndUserstories
    )
}

processMilestones <- function(milestonesFile) {
    ## Process milestones
    #  Milestone data needs to be stored in CSV file (excel file presents difficulties with dates)
    milestoneData <-
        read.table(
            milestonesFile, sep = ",", header = TRUE, comment.char = "", quote = "\""
        )
    milestoneData <-
        rename(
            milestoneData, MilestoneID = Formatted.ID,
            MilestoneName = Name, MilestoneColor = Display.Color
        )
    #extract milestones status from milestone Notes
    extractStatus <-
        function(x) {
            ifelse(grepl("Status", x),  sub("\\].*", "", sub(".*\\[", "", x)), "On Track")
        }
    Sys.setlocale('LC_ALL', 'C') #handle warning messages input string 1 is invalid in this locale
    
    milestoneData <-
        mutate(
            milestoneData, MilestoneDate = as.Date(mdy_hms(as.character(Target.Date))),
            MilestoneStatus = sapply(Notes, extractStatus),
            MilestoneType = ifelse(
                is.na(MilestoneColor), "TBD",
                ifelse(
                    MilestoneColor == "#ee6c19", "DPIM Deliverable",
                    ifelse(
                        MilestoneColor == "#df1a7b", "External Dependency", "Internal Milestone"
                    )
                )
            )
        )
    milestoneData
}

# Add a dummy milestone with an ID of MISSING and a name of Undefined
# This is necessary to ensure we dpo not miss features or initiatives when merging milestones with portfolio items
ammendMilestones <- function(milestoneData) {
    dummyMilestoneRow <- data.frame(
        MilestoneID = "MI0",
        MilestoneName = "Milestone Not Assigned",
        MilestoneColor = "",
        Target.Date = NA,
        Total.Artifact.Count = 0,
        Target.Project = "",
        Notes = "",
        MilestoneDate = NA,
        MilestoneStatus = "",
        MilestoneType = ""
    )
    ammendedMilestoneData <- rbind(milestoneData, dummyMilestoneRow)
    ammendedMilestoneData
}

processInitiatives <- function(initiativesFile) {
    ## Process INITIATIVES
    #  Note that using quote = "\"" is important here so that we could read in correctly any records that have commas in their values
    initiativeData <-
        read.table(
            initiativesFile, sep = ",", header = TRUE, comment.char = "", quote = "\"", fill = FALSE
        )
    initiativeData <-
        rename(initiativeData, InitiativeID = Formatted.ID, BusinessArea = Name)
    initiativeData <-
        mutate(initiativeData, Milestones = ifelse(Milestones == "", "MI0: Fake",
            as.character(Milestones))) ## ensure that these rows are not dropped when splitting
    initiativeData
}

denormalizeInitiatives <- function(initiativeData) {
    ## Process initiative milestones - multiple milestones are stored in the same cell, separated by ";".
    #  Need to extract each milestone into its own line
    denormInitiativeData <-
        cSplit(initiativeData, "Milestones", sep = ";", direction = "long")
    #  Extract milestone IDs
    firstElement <- function(x) {
        x[1]
    }
    milestoneIDs <-
        strsplit(as.character(denormInitiativeData$Milestones), ":")
    denormInitiativeData <- mutate(denormInitiativeData,
        MilestoneID = sapply(milestoneIDs, firstElement))
    denormInitiativeData
}

processFeatures <- function(featuresFile) {
    ## Process FEATURES
    #  Note that using quote = "\"" is important here so that we could read in correctly any records that have commas in their values
    featureData <-
        read.table(
            featuresFile, sep = ",", header = TRUE, comment.char = "", quote = "\"", fill = FALSE
        )
    featureData <-
        rename(
            featureData, FeatureID = Formatted.ID, FeatureName = Name, BusinessArea = Parent,
            FeatureState = State, FeatureStatus = Tags
        )
    featureData <- mutate(
        featureData,
        BusinessArea = gsub(".*: ", "", BusinessArea),
        FeatureState = ifelse(
            FeatureState == "", "Not Started",
            ifelse(
                FeatureState == "Discovering" , "In Tech Discovery",
                ifelse(
                    FeatureState == "Developing", "In Progress",
                    ifelse(FeatureState == "Done", "Complete", "NA")
                )
            )
        ),
        FeatureStatus = ifelse(
            FeatureStatus == "", "On Track",
            ifelse(
                FeatureStatus == "Complete", "Complete",
                ifelse(FeatureStatus == "On Track", "On Track", "NA")
            )
        ),
        FeatureName = gsub("PSI 1 - ", "", FeatureName),
        Milestones = ifelse(Milestones == "", "MI0: Fake", as.character(Milestones))
    ) ## ensure that these rows are not dropped when splitting
    
    featureData
    
}

denormalizeFeatures <- function(featureData) {
    ## Process feature milestones - multiple milestones are stored in the same cell, separated by ";".
    #  Need to extract each milestone into its own line
    denormFeatureData <-
        cSplit(featureData, "Milestones", sep = ";", direction = "long")
    #  Extract milestone IDs
    firstElement <- function(x) {
        x[1]
    }
    milestoneIDs <-
        strsplit(as.character(denormFeatureData$Milestones), ":")
    denormFeatureData <- mutate(denormFeatureData,
        MilestoneID = sapply(milestoneIDs, firstElement))
    denormFeatureData
}

processUserstories <- function(userstoriesFile) {
    ## Process user stories
    userStoryData <-
        read.table(
            userstoriesFile, sep = ",", header = TRUE, comment.char = "", quote = "\"", fill = FALSE
        )
    userStoryData <-
        rename(
            userStoryData, UserStoryID = Formatted.ID, UserStoryName = Name, Team = Project, StoryStatus = Schedule.State
        )
    #  Extract feature ID for subsequent merge. If a user story does not have a feature, set the ID to "MISSING".
    #  UNDEF would be used to merge with a dummy feature so that user stories with no features can be present in the visualization.
    userStoryData <-
        mutate(
            userStoryData, FeatureID = ifelse(Feature == "", "MISSING", gsub(
                "^Feature ", "", gsub(":.*", "", Feature)
            )),
            Iteration = ifelse(
                Iteration == "", "Iteration Missing", as.character(Iteration)
            ),
            IsParentStory = ifelse(Direct.Children.Count > 0, TRUE, FALSE)
        )
    
    # Remove stories that are parents. Those stories are not actionable by themselves and cannot be assigned a release.
    userStoryData <- filter(userStoryData, IsParentStory == FALSE)
    userStoryData
}

mergeFeaturesAndMilestones <-
    function(denormFeatureData, ammendedMilestoneData) {
        ## Merge the feature and milestone data frames. We need to get all features independent of whether or not they have milestones.
        #  Merge by milestone ID
        mergedFeatureData <-
            merge(
                denormFeatureData, ammendedMilestoneData, by.x = "MilestoneID", by.y = "MilestoneID", all.x = TRUE
            )
        
        # Drop rows with dummy milestones
        # mergedFeatureData <-
        #  filter(mergedFeatureData, MilestoneID != "MI0")
        plotFeatureData <-
            select(
                mergedFeatureData, MilestoneID, MilestoneName, FeatureID, FeatureName, BusinessArea, MilestoneType, MilestoneDate,
                FeatureState, FeatureStatus, MilestoneStatus, Notes, Percent.Done.By.Story.Count, Direct.Children.Count
            )
        plotFeatureData
    }

mergeInitiativesAndMilestones <-
    function(denormInitiativeData, ammendedMilestoneData) {
        ## Merge the initiative and milestone data frames. We need to get all initiatives independent of whether or not they have milestones.
        #  Merge by milestone ID
        mergedInitiativeData <-
            merge(
                denormInitiativeData, ammendedMilestoneData, by.x = "MilestoneID", by.y = "MilestoneID", all.x = TRUE
            )
        # Drop rows with dummy milestones
        mergedInitiativeData <-
            filter(mergedInitiativeData, MilestoneID != "MI0")
        plotInitiativeData <-
            select(
                mergedInitiativeData, MilestoneID, MilestoneName, InitiativeID, BusinessArea,
                MilestoneType, MilestoneDate, MilestoneStatus, Notes
            )
        
        # Fill in dates with no entry so that the Tableau Calendar includes all dates.
        fillerDates <-
            seq(as.Date("2015/12/1"), as.Date("2016/4/30"), by = "day")
        milestoneDates <- unique(plotInitiativeData$MilestoneDate)
        #get all dates that do not have any milestones
        missingDates <-
            as.Date(setdiff(fillerDates, milestoneDates), origin = "1970-1-1")
        fillRecords <-
            data.frame(
                MilestoneID = "", MilestoneName = "", InitiativeID = "", BusinessArea = "",
                MilestoneType = "",  MilestoneDate = missingDates, MilestoneStatus = "", Notes = ""
            )
        plotInitiativeData <- rbind(plotInitiativeData, fillRecords)
        plotInitiativeData
    }

mergeFeaturesAndUserstories <-
    function(userStoryData, featureData) {
        ## Prep features for merging with user stories.
        #  Add a dummy feature with an ID of MISSING and a name of Undefined
        dummyFeatureRow <- data.frame(
            FeatureID = "MISSING",
            FeatureName = "Feature Not Assigned",
            Release = "",
            Percent.Done.By.Story.Plan.Estimate = 0,
            Percent.Done.By.Story.Count = 0,
            Project = "1",
            Milestones = "Undefined Milestone",
            BusinessArea = "Undefined Business Area",
            FeatureState = "TBD",
            FeatureStatus = "TBD",
            Direct.Children.Count = 0
        )
        ammendedFeatureData <- rbind(featureData, dummyFeatureRow)
        
        ## Merge the feature and user story data frames. We need to get all user stories independent on whether or not they have features
        #  Also want to get features that do not have user stories
        #  Merge by feature ID
        mergedStoryData <-
            merge(
                userStoryData, ammendedFeatureData, by.x = "FeatureID", by.y = "FeatureID", all.x = TRUE, all.y = TRUE
            )
        storyPlotData <-
            select(
                mergedStoryData, BusinessArea, FeatureID, FeatureName,
                UserStoryID, UserStoryName, Iteration, Team, FeatureState, FeatureStatus, StoryStatus
            )
        
        # After the merge any features that have not been assigned stories will have null values in the respective fields.
        # Amend that by explicitly stating that there are no stories assigned and no iterations
        # Need to account for 1) no story, 2) no iteration, and 3) no team
        storyPlotData <-
            mutate(
                storyPlotData, UserStoryID = ifelse(is.na(UserStoryID), "MISSING", as.character(UserStoryID)),
                UserStoryName = ifelse(
                    is.na(UserStoryName), "No User Story", as.character(UserStoryName)
                ),
                Iteration = ifelse(is.na(Iteration), "No Iteration", as.character(Iteration)),
                Team = ifelse(is.na(Team), "No Team", as.character(Team))
            )
        storyPlotData
    }

mergeFeaturesAndUserstoriesForStatus <-
    function(userStoryData, featureData) {
        ## Merge the feature and user story data frames. We need to get all features that are part of the PSI independent
        #  on whether or not they have stories.
        #  Merge by feature ID
        mergedStoryData <-
            merge(
                userStoryData, featureData, by.x = "FeatureID", by.y = "FeatureID", all.y = TRUE
            )
        featureStatusPlotData <-
            select(
                mergedStoryData, BusinessArea, FeatureID, FeatureName,
                UserStoryID, UserStoryName, Iteration, Team, FeatureState, FeatureStatus, StoryStatus
            )
        featureStatusPlotData
    }


saveData <- function(mergedFeaturesAndMilestones,
    mergedFeaturesAndStoriesForStatus,
    mergedInitiativesAndMilestones,
    mergedFeaturesAndUserstories) {
    ## Write the resulting data to an excel file.
    #  This will be used for visualization in Tableau.
    write.xlsx(
        mergedFeaturesAndMilestones, file = "./data/features_and_milestonesC.xlsx", row.names = FALSE, showNA = FALSE
    )
    
    ## Write the resulting data to an excel file.
    #  This will be used for visualization in Tableau.
    write.xlsx(
        mergedFeaturesAndStoriesForStatus, file = "./data/features_and_stories_for_statusC.xlsx", row.names = FALSE, showNA = FALSE
    )
    
    ## Write the resulting data to an excel file.
    #  This will be used for visualization in Tableau.
    write.xlsx(
        mergedInitiativesAndMilestones, file = "./data/initiatives_and_milestonesC.xlsx", row.names = FALSE, showNA = FALSE
    )
    
    ## Write the resulting data to an excel file.
    #  This will be used for visualization in Tableau.
    write.xlsx(
        mergedFeaturesAndUserstories, file = "./data/stories_and_featuresC.xlsx", row.names = FALSE, showNA = FALSE
    )
    
}


processProjects()
