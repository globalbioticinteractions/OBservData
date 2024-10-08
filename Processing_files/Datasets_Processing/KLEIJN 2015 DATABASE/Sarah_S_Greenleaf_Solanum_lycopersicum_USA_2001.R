
library(tidyverse)
#library(sp) #Transforming latitude and longitude
library("iNEXT")
#library(openxlsx)
library(readxl)
#library(parzer) #parse coordinates

dir_ini <- getwd()

##########################
#Data: 69_GreenleafKremenTomato2001
##########################

data_raw <- read_excel("Processing_files/Datasets_processing/KLEIJN 2015 DATABASE/69_GreenleafKremenTomato2001/2001 Tomato Data_editted.xls",
                       sheet = "Bee Counts")
data_raw <- as_tibble(data_raw)
data_raw <- data_raw[1:162,]

# Add sampling week

data_raw$month_of_study <- as.numeric(format(as.Date(data_raw$Date, format="%Y/%m/%d"),"%m"))


# There should be 11 sites
data_raw %>% group_by(Farm) %>% count() #OK!

##############
# Data site
##############

# There are two geolocalizations for each site. We select the first one

data.site <- data_raw  %>%
  select(Farm) %>%
  group_by(Farm) %>% count() %>% select(-n) %>%
  rename(site_id=Farm)

# We add data site ID

data.site$study_id <- "Sarah_S_Greenleaf_Solanum_lycopersicum_USA_2001"
data.site$crop <- "Solanum lycopersicum"
data.site$variety <- "SunGold"
data.site$management <- "organic"
data.site$country <- "USA"
data.site$X_UTM <- NA
data.site$Y_UTM <- NA
data.site$zone_UTM <- NA
data.site$latitude <- NA
data.site$longitude <- NA
data.site$sampling_year <- 2001
data.site$field_size <- NA
data.site$yield <- NA
data.site$yield_units <- NA
data.site$yield2 <- NA
data.site$yield2_units <- NA
data.site$yield_treatments_no_pollinators <- NA
data.site$yield_treatments_no_pollinators <- NA
data.site$yield_treatments_no_pollinators2 <- NA
data.site$yield_treatments_pollen_supplement2 <- NA
data.site$fruits_per_plant <- NA
data.site$fruit_weight <- NA
data.site$plant_density <- NA
data.site$seeds_per_fruit <- NA
data.site$seeds_per_plant <- NA
data.site$seed_weight <- NA
data.site$Publication <- "10.1016/j.biocon.2006.05.025"
data.site$Credit <- "Sarah S. Greenleaf, Claire Kremen"
data.site$Email_contact <- "sgreenleaf@ucdavis.edu"

# Add sampling months

data.site$sampling_start_month <- NA
data.site$sampling_end_month <- NA

sites <- unique(data.site$site_id)

for (i in sites){

  data.site$sampling_start_month[data.site$site_id==i] <-
    data_raw %>% filter(Farm==i) %>%
    select(month_of_study) %>% min()

  data.site$sampling_end_month[data.site$site_id==i] <-
    data_raw %>% filter(Farm==i) %>%
    select(month_of_study) %>% max()
}


###########################
# SAMPLING DATA
###########################

data_raw_obs_aux <- data_raw[,c(1,3:7,9:13)]

sampling <- data_raw_obs_aux %>% select(Farm,`Row Length`,`Total Time`) %>%
  group_by(Farm) %>% summarise_all(sum) %>%
  rename(site_id=Farm,total_area=`Row Length`,total_time=`Total Time`)

data_raw_obs <- data_raw_obs_aux %>%
  select(Farm,`Anthophora urbana`,
         `Bombus vosnesenskii`,Dialictus,Apis) %>%
  rename(site_id=Farm) %>%
  gather("Organism_ID","abundance",c(`Anthophora urbana`,
                                     `Bombus vosnesenskii`,Dialictus,Apis)) %>%
  filter(!is.na(abundance))


data_raw_obs <- data_raw_obs %>% left_join(sampling,by="site_id")


#Add guild via guild list

gild_list_raw <- read_csv("Processing_files/Thesaurus_Pollinators/Table_organism_guild_META.csv")
gild_list <- gild_list_raw %>% select(-Family) %>% unique()

list_organisms <- select(data_raw_obs,Organism_ID) %>% unique() %>% filter(!is.na(Organism_ID))
list_organisms_guild <- list_organisms %>% left_join(gild_list,by=c("Organism_ID"))

# Check NA's in guild
list_organisms_guild %>% filter(is.na(Guild)) %>% group_by(Organism_ID) %>% count()

# Fix NA's
list_organisms_guild$Guild[list_organisms_guild$Organism_ID=="Anthophora urbana"] <- "other_wild_bees"
list_organisms_guild$Guild[list_organisms_guild$Organism_ID=="Apis"] <- "honeybees"
list_organisms_guild$Guild[list_organisms_guild$Organism_ID=="Dialictus"] <- "other_wild_bees"

#Sanity Checks
list_organisms_guild %>% filter(is.na(Guild)) %>% group_by(Organism_ID) %>% count()

#Add guild to observations
data_obs_guild <- data_raw_obs %>% left_join(list_organisms_guild, by = "Organism_ID")


#######################
# INSECT SAMPLING
#######################


# Remove entries with zero abundance
data_obs_guild  <- data_obs_guild  %>% filter(abundance>0)

insect_sampling <- tibble(
  study_id = "Sarah_S_Greenleaf_Solanum_lycopersicum_USA_2001",
  site_id = data_obs_guild$site_id,
  pollinator = data_obs_guild$Organism_ID,
  guild = data_obs_guild$Guild,
  sampling_method = "transect",
  abundance = data_obs_guild$abundance,
  total_sampled_area = data_obs_guild$total_area,
  total_sampled_time = data_obs_guild$total_time,
  total_sampled_flowers = NA,
  Description = "In each field, bee visits to tomato flowers were recorded along walking transects at the rate of 10 m/min, covering each row twice, once in each direction. In small fields, transects were walked along all rows. In larger fields, surveys were carried out at up to four transects, each 80m long. Each field was sampled between 8:30 and 12:30 on three different days, in the early, mid, and late morning, respectively."
)

#setwd("C:/Users/USUARIO/Desktop/OBservData/Datasets_storage")
write_csv(insect_sampling, "Processing_files/Datasets_storage/insect_sampling_Sarah_S_Greenleaf_Solanum_lycopersicum_USA_2001.csv")
#setwd(dir_ini)

#######################################
# ABUNDANCE
#######################################

# Add site observations

data_obs_guild_2 <-  data_obs_guild %>%
  group_by(site_id,Organism_ID,Guild) %>% summarise_all(sum,na.rm=TRUE)


abundance_aux <- data_obs_guild_2 %>%
  group_by(site_id,Guild) %>% count(wt=abundance) %>%
  spread(key=Guild, value=n)



names(abundance_aux)

# There are "bumblebees"      "honeybees"       "other_wild_bees"

# GUILDS:honeybees, bumblebees, other wild bees, syrphids, humbleflies,
# other flies, beetles, non-bee hymenoptera, lepidoptera, and other

abundance_aux <- abundance_aux %>% mutate(lepidoptera=0,beetles=0,other_flies=0,
                                          syrphids=0,other=0,humbleflies=0,
                                          non_bee_hymenoptera=0,
                                          total=0)
abundance_aux[is.na(abundance_aux)] <- 0
abundance_aux$total <- rowSums(abundance_aux[,c(2:ncol(abundance_aux))])

data.site <- data.site %>% left_join(abundance_aux, by = "site_id")

######################################################
# ESTIMATING CHAO INDEX
######################################################

abundace_field <- data_obs_guild %>%
  select(site_id,Organism_ID,abundance)%>%
  group_by(site_id,Organism_ID) %>% count(wt=abundance)

abundace_field <- abundace_field %>% spread(key=Organism_ID,value=n)


abundace_field[is.na(abundace_field)] <- 0
abundace_field$r_obser <-  0
abundace_field$r_chao <-  0

for (i in 1:nrow(abundace_field)) {
  x <- as.numeric(abundace_field[i,2:(ncol(abundace_field)-2)])
  chao  <-  ChaoRichness(x, datatype = "abundance", conf = 0.95)
  abundace_field$r_obser[i] <-  chao$Observed
  abundace_field$r_chao[i] <-  chao$Estimator
}

# Load our estimation for taxonomic resolution
percentage_species_morphos <- 0.9

richness_aux <- abundace_field %>% select(site_id,r_obser,r_chao)
richness_aux <- richness_aux %>% rename(observed_pollinator_richness=r_obser,
                                        other_pollinator_richness=r_chao) %>%
  mutate(other_richness_estimator_method="Chao1",richness_restriction="only bees")

if (percentage_species_morphos < 0.8){
  richness_aux[,2:ncol(richness_aux)] <- NA
}

data.site <- data.site %>% left_join(richness_aux, by = "site_id")

##############
# SAMPLING
##############

data.site <- data.site %>% left_join(sampling, by = "site_id")


###################
# VISITATION RATE
###################

visit_aux = abundance_aux %>% left_join(sampling, by = "site_id") %>%
  mutate(
    visit_bumblebees=bumblebees/total_time,
    visit_honeybees=honeybees/total_time,
    visit_other_wild_bees=other_wild_bees/total_time,
    visit_lepidoptera=lepidoptera/total_time,
    visit_beetles=beetles/total_time,
    visit_other_flies=other_flies/total_time,
    visit_syrphids=syrphids/total_time,
    visit_other=other/total_time,
    visit_humbleflies=humbleflies/total_time,
    visit_non_bee_hymenoptera=non_bee_hymenoptera/total_time,
    visit_total=total/total_time,
  )

visit_aux <- visit_aux[,c(1,15:25)]

data.site <- data.site %>% left_join(visit_aux, by = "site_id")


###############################
# FIELD LEVEL DATA
###############################


field_level_data <- tibble(
  study_id = data.site$study_id,
  site_id = data.site$site_id,
  crop = data.site$crop,
  variety = data.site$variety,
  management = data.site$management,
  country = data.site$country,
  latitude = data.site$latitude,
  longitude = data.site$longitude,
  X_UTM=data.site$X_UTM,
  Y_UTM=data.site$Y_UTM,
  zone_UTM=data.site$zone_UTM,
  sampling_start_month = data.site$sampling_start_month,
  sampling_end_month = data.site$sampling_end_month,
  sampling_year = data.site$sampling_year,
  field_size = data.site$field_size,
  yield=data.site$yield,
  yield_units=data.site$yield_units,
  yield2=data.site$yield2,
  yield2_units=data.site$yield2_units,
  yield_treatments_no_pollinators=data.site$yield_treatments_no_pollinators,
  yield_treatments_pollen_supplement=data.site$yield_treatments_no_pollinators,
  yield_treatments_no_pollinators2=data.site$yield_treatments_no_pollinators2,
  yield_treatments_pollen_supplement2=data.site$yield_treatments_pollen_supplement2,
  fruits_per_plant=data.site$fruits_per_plant,
  fruit_weight= data.site$fruit_weight,
  plant_density=data.site$plant_density,
  seeds_per_fruit=data.site$seeds_per_fruit,
  seeds_per_plant=data.site$seeds_per_plant,
  seed_weight=data.site$seed_weight,
  observed_pollinator_richness=data.site$observed_pollinator_richness,
  other_pollinator_richness=data.site$other_pollinator_richness,
  other_richness_estimator_method=data.site$other_richness_estimator_method,
  richness_restriction = data.site$richness_restriction,
  abundance = data.site$total,
  ab_honeybee = data.site$honeybees,
  ab_bombus = data.site$bumblebees,
  ab_wildbees = data.site$other_wild_bees,
  ab_syrphids = data.site$syrphids,
  ab_humbleflies= data.site$humbleflies,
  ab_other_flies= data.site$other_flies,
  ab_beetles=data.site$beetles,
  ab_lepidoptera=data.site$lepidoptera,
  ab_nonbee_hymenoptera=data.site$non_bee_hymenoptera,
  ab_others = data.site$other,
  total_sampled_area = data.site$total_area,
  total_sampled_time = data.site$total_time,
  visitation_rate_units = "visits to flowers per hour",
  visitation_rate = data.site$visit_total,
  visit_honeybee = data.site$visit_honeybees,
  visit_bombus = data.site$visit_bumblebees,
  visit_wildbees = data.site$visit_other_wild_bees,
  visit_syrphids = data.site$visit_syrphids,
  visit_humbleflies = data.site$visit_humbleflies,
  visit_other_flies = data.site$visit_other_flies,
  visit_beetles = data.site$visit_beetles,
  visit_lepidoptera = data.site$visit_lepidoptera,
  visit_nonbee_hymenoptera = data.site$visit_non_bee_hymenoptera,
  visit_others = data.site$visit_other,
  Publication = data.site$Publication,
  Credit = data.site$Credit,
  Email_contact = data.site$Email_contact
)

#setwd("C:/Users/USUARIO/Desktop/OBservData/Datasets_storage")
write_csv(field_level_data, "Processing_files/Datasets_storage/field_level_data_Sarah_S_Greenleaf_Solanum_lycopersicum_USA_2001.csv")
#setwd(dir_ini)

