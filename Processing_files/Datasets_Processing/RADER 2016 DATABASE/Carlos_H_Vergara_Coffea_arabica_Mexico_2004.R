
library(tidyverse)
library(sp) #Transforming latitude and longitude
library("iNEXT")

dir_ini <- getwd()

##########################
#Data: Vergara_2004
##########################

data_raw <- read_csv("Processing_files/Datasets_Processing/RADER 2016 DATABASE/Individual CSV/Vergara_2004.csv")
data_raw <- as_tibble(data_raw)

#Fixing last row

data_raw$site[64] <- "ORD4"
data_raw$land_management[64] <- "conventional"
data_raw$latitude[64] <- "19°27.898' N"
data_raw$longitude[64] <- "96°56.058? W"

round_df <- function(x, digits) {
  # round all numeric variables
  # x: data frame
  # digits: number of digits to round
  numeric_columns <- sapply(x, mode) == 'numeric'
  x[numeric_columns] <-  round(x[numeric_columns], digits)
  x
}

data_raw[64,30:ncol(data_raw)] <- round_df(data_raw[64,30:ncol(data_raw)], 0)

# Remove columns full of NA's
data_raw_without_NAs <-
  data_raw[,colSums(is.na(data_raw))<nrow(data_raw)]



############################
# FIELD INFORMATION
############################

data.site_aux <- tibble(
  study_id = "Carlos_H_Vergara_Coffea_arabica_Mexico_2004",
  site_id = data_raw_without_NAs$site,
  crop = "Coffea arabica",
  variety = NA,
  management = data_raw_without_NAs$land_management,
  country = "Mexico",
  latitude = data_raw_without_NAs$latitude,
  longitude = data_raw_without_NAs$longitude,
  X_UTM=NA,
  Y_UTM=NA,
  zone_UTM=NA,
  sampling_start_month = data_raw_without_NAs$month_of_study,
  sampling_end_month = data_raw_without_NAs$month_of_study,
  sampling_year = data_raw_without_NAs$Year_of_study,
  field_size = NA,
  yield = data_raw_without_NAs$fruitset,
  yield_units= "Fruit set (%): initial number of floral buds in the respective branch and the number of developing fruits",
  yield2= NA,
  yield2_units= NA,
  yield_treatments_no_pollinators= data_raw_without_NAs$final_fruitset,
  yield_treatments_pollen_supplement=NA,
  yield_treatments_no_pollinators2= NA,
  yield_treatments_pollen_supplement2=NA,
  fruits_per_plant= NA,
  fruit_weight=  NA,
  plant_density= NA,
  seeds_per_fruit= NA,
  seeds_per_plant= NA,
  seed_weight= NA
)

# Fix latitude ORD04

data.site_aux$latitude[data.site_aux$site_id=="ORD4"]<- "19°27.898' N"
data.site_aux$longitude[data.site_aux$site_id=="ORD4"] <- "96°56.058' W"

# Fix sampling months

sites <- unique(data.site_aux$site_id)

for (i in sites){

  data.site_aux$sampling_start_month[data.site_aux$site_id==i] <-
    data.site_aux %>% filter(site_id==i) %>%
    select(sampling_start_month) %>% min()

  data.site_aux$sampling_end_month[data.site_aux$site_id==i] <-
    data.site_aux %>% filter(site_id==i) %>%
    select(sampling_end_month) %>% max()

  data.site_aux$sampling_year[data.site_aux$site_id==i] <-
    data.site_aux %>% filter(site_id==i) %>%
    select(sampling_year) %>% max()

}

data.site <- data.site_aux %>%
  group_by(study_id,site_id,crop,variety,management,country,
           latitude,longitude,X_UTM,zone_UTM,sampling_end_month,sampling_year,yield_units) %>%
  summarise_all(mean, na.rm = TRUE)

# Columns full of NAs return NaN: Set those Nan to NA
# is.nan doesn't actually have a method for data frames, unlike is.na
is.nan.data.frame <- function(x){
  do.call(cbind, lapply(x, is.nan))}

data.site[is.nan(data.site)] <- NA

############################################################

# Fix latitude/longitude symbols

data.site$latitude <- str_replace(data.site$latitude, "´", "'")
data.site$latitude <- str_replace(data.site$latitude, "’", "'")
data.site$latitude <- str_replace(data.site$latitude, "'", "'")

data.site$longitude <- str_replace(data.site$longitude,"´", "'")
data.site$longitude <- str_replace(data.site$longitude, "’", "'")
data.site$longitude[8] <- "96°56.058' W"
# Convert Latitude/Longitude from degrees min sec to decimal
#19?12.664' N	96?53.984? W
chd = substr(data.site$latitude, 3, 3)[1]
chm = substr(data.site$latitude, 10, 10)[1]

cd = char2dms(data.site$latitude,chd=chd,chm=chm)
data.site$latitude <- as.numeric(cd)

chd = substr(data.site$longitude, 3, 3)[1]
chm = substr(data.site$longitude, 10, 10)[1]

cd = char2dms(data.site$longitude,chd = chd,chm = chm)
data.site$longitude <- as.numeric(cd)

#########################



#########################
# Adding credit, Publication and contact

data.site$Publication <- ":10.1016/j.agee.2008.08.001"
data.site$Credit  <- "Carlos H. Vergara and Ernesto I. Badano"
data.site$Email_contact <- "carlosh.vergara@udlap.mx"

###########################
# SAMPLING DATA
###########################


data_raw_obs <- data_raw %>%
  select(site, names(data_raw[30:ncol(data_raw)]))

# Remove NAs
data_raw_obs <-
  data_raw_obs[,colSums(is.na(data_raw_obs))<nrow(data_raw_obs)]


data_raw_gather <- data_raw_obs %>% rename(site_id = site)%>%
  gather(-site_id,key = "Organism_ID", value = 'Abundance', !contains("site_id"))
data_raw_gather$Family <- as.character(NA)

#Add guild via guild list

gild_list <- read_csv("Processing_files/Thesaurus_Pollinators/Table_organism_guild_META.csv")

data_raw_gather <- data_raw_gather %>% left_join(gild_list,by=c("Organism_ID","Family"))

#Check NA's in guild
data_raw_gather %>% filter(is.na(Guild))

#######################
# INSECT SAMPLING
#######################

# In each plot, a 150 m standardized transect line was set and an
# observer walked this line in 30 min and captured all flower-visiting
# bees with a net within a 4-m wide corridor. In each site, two sets of pan
# traps of three colours (yellow, white and blue) were placed with a

# Remove entries with zero abundance
data_raw_gather <- data_raw_gather %>% filter(Abundance>0,!is.na(Abundance))


insect_sampling <- tibble(
  study_id = "Carlos_H_Vergara_Coffea_arabica_Mexico_2004",
  site_id = data_raw_gather$site_id,
  pollinator = data_raw_gather$Organism_ID,
  guild = data_raw_gather$Guild,
  sampling_method = "observations",
  abundance = data_raw_gather$Abundance,
  total_sampled_area = NA,
  total_sampled_time = 4*25,
  total_sampled_flowers = NA,
  Description = " At each plantation, the four selected coffee plants were sequentially observed for 25 min each"
)

#setwd("C:/Users/USUARIO/Desktop/OBservData/Datasets_storage")
write_csv(insect_sampling, "Processing_files/Datasets_storage/insect_sampling_Carlos_H_Vergara_Coffea_arabica_Mexico_2004.csv")
#setwd(dir_ini)

#######################################
# ABUNDANCE
#######################################

# Add site observations

data_raw_gather2 <-  data_raw_gather %>%
  group_by(site_id,Organism_ID,Family,Guild) %>% summarise_all(sum,na.rm=TRUE)


abundance_aux <- data_raw_gather2 %>%
  group_by(site_id,Guild) %>% count(wt=Abundance) %>%
  spread(key=Guild, value=n)

names(abundance_aux)

# There are     "beetles" "honeybees" "" "non_bee_hymenoptera"
# "" other_flies, "other_wild_bees"     "syrphids"

# GUILDS:honeybees, bumblebees, other wild bees, syrphids, humbleflies,
# other flies, beetles, non-bee hymenoptera, lepidoptera, and other

abundance_aux <- abundance_aux %>% mutate(bumblebees=0,lepidoptera=0,
  other=0,humbleflies=0,total=0)
abundance_aux[is.na(abundance_aux)] <- 0
abundance_aux$total <- rowSums(abundance_aux[,c(2:ncol(abundance_aux))])

data.site <- data.site %>% left_join(abundance_aux, by = "site_id")

######################################################
# ESTIMATING CHAO INDEX
######################################################

abundace_field <- data_raw_gather %>%
  select(site_id,Organism_ID,Abundance)%>%
  group_by(site_id,Organism_ID) %>% count(wt=Abundance)

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

tax_res <- read_csv("Processing_files/Datasets_Processing/RADER 2016 DATABASE/taxon_table_Rader.csv")
#Mutate pollinator labels to match those of taxon table
tax_estimation <- insect_sampling %>% mutate(pollinator=str_replace(pollinator,"_"," ")) %>%
  left_join(tax_res, by="pollinator")
tax_estimation %>% group_by(rank) %>% count()

percentage_species_morphos <-
  sum(tax_estimation$rank %in% c("morphospecies","species"))/nrow(tax_estimation)

richness_aux <- abundace_field %>% select(site_id,r_obser,r_chao)
richness_aux <- richness_aux %>% rename(observed_pollinator_richness=r_obser,
                                        other_pollinator_richness=r_chao) %>%
  mutate(other_richness_estimator_method="Chao1")

if (percentage_species_morphos < 0.8){
  richness_aux[,2:ncol(richness_aux)] <- NA
}

data.site <- data.site %>% left_join(richness_aux, by = "site_id")


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
  yield_treatments_pollen_supplement=data.site$yield_treatments_pollen_supplement,
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
  richness_restriction = NA,
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
  total_sampled_area = NA,
  total_sampled_time = 4*25,
  visitation_rate_units = "visits per plant and hour",
  visitation_rate = (60/100)*data.site$total,
  visit_honeybee = (60/100)*data.site$honeybees,
  visit_bombus = (60/100)*data.site$bumblebees,
  visit_wildbees = (60/100)*data.site$other_wild_bees,
  visit_syrphids = (60/100)*data.site$syrphids,
  visit_humbleflies = (60/100)*data.site$humbleflies,
  visit_other_flies = (60/100)*data.site$other_flies,
  visit_beetles = (60/100)*data.site$beetles,
  visit_lepidoptera = (60/100)*data.site$lepidoptera,
  visit_nonbee_hymenoptera = (60/100)*data.site$non_bee_hymenoptera,
  visit_others = (60/100)*data.site$other,
  Publication = data.site$Publication,
  Credit = data.site$Credit,
  Email_contact = data.site$Email_contact
)

# UPDATE CARLOS
missing_area <- bind_rows(
tibble(site_id="MIR1",field_size= 0.7),
tibble(site_id="MIR2",field_size= 1.53),
tibble(site_id="MIR3",field_size= 2.6),
tibble(site_id="MIR4",field_size= 6.65),
tibble(site_id="ORD1",field_size= 4.88),
tibble(site_id="ORD2",field_size= 4.88),
tibble(site_id="ORD3",field_size= 18.29),
tibble(site_id="ORD4",field_size= 7.2),
tibble(site_id="SOL1",field_size= 0.1925),
tibble(site_id="SOL2",field_size= 0.4446),
tibble(site_id="SOL3",field_size= 3.738),
tibble(site_id="SOL4",field_size= 3.2),
tibble(site_id="VSE1",field_size= 1.53),
tibble(site_id="VSE2",field_size= 0.513),
tibble(site_id="VSE3",field_size= 4),
tibble(site_id="VSE4",field_size= 0.8)
)

missing_variety <- bind_rows(
tibble(site_id="MIR1", crop="Coffea arabica", variety="Typica, Bourbon, Mundo Novo and Caturra"),
tibble(site_id="MIR2", crop=" Coffea arabica", variety=" Typica, Bourbon, Mundo Novo and Caturra"),
tibble(site_id="MIR3", crop=" Coffea arabica", variety=" Typica, Bourbon, Mundo Novo and Caturra"),
tibble(site_id="MIR4", crop=" Coffea arabica", variety=" Typica, Bourbon, Mundo Novo and Caturra"),
tibble(site_id="ORD1", crop=" Coffea arabica", variety=" Garnica"),
tibble(site_id="ORD2", crop=" Coffea arabica", variety=" Garnica"),
tibble(site_id="ORD3", crop=" Coffea arabica", variety=" Garnica"),
tibble(site_id="ORD4", crop=" Coffea arabica", variety=" Garnica"),
tibble(site_id="SOL1", crop=" Coffea arabica", variety=" Caturra"),
tibble(site_id="SOL2", crop=" Coffea arabica", variety=" Caturra"),
tibble(site_id="SOL3", crop=" Coffea arabica", variety=" Caturra"),
tibble(site_id="SOL4", crop=" Coffea arabica", variety=" Caturra"),
tibble(site_id="VSE1", crop=" Coffea arabica", variety=" Catimor CR-95"),
tibble(site_id="VSE2", crop=" Coffea arabica", variety=" Catimor CR-95"),
tibble(site_id="VSE3", crop=" Coffea arabica", variety=" Catimor CR-95"),
tibble(site_id="VSE4", crop=" Coffea arabica", variety=" Catimor CR-95"))

missing_coordinates <- bind_rows(
tibble(site_id="MIR1", latitude=19.2110667, longitude=-96.8997333),
tibble(site_id="MIR2", latitude=19.2135333, longitude=-96.8995167),
tibble(site_id="MIR3", latitude=19.2098833, longitude=-96.8965),
tibble(site_id="MIR4", latitude=19.2101167, longitude=-96.8876667),
tibble(site_id="ORD1", latitude=19.2055833, longitude=-96.8977333),
tibble(site_id="ORD2", latitude=19.20565, longitude=-96.89855),
tibble(site_id="ORD3", latitude=19.2070167, longitude=-96.8843),
tibble(site_id="ORD4", latitude=19.2063, longitude=-96.8850667),
tibble(site_id="SOL1", latitude=19.3756833, longitude=-96.98785),
tibble(site_id="SOL2", latitude=19.4815667, longitude=-96.991),
tibble(site_id="SOL3", latitude=19.3808, longitude=-96.989),
tibble(site_id="SOL4", latitude=19.38185, longitude=-96.9887833),
tibble(site_id="VSE1", latitude=19.4726667, longitude=-96.9256333),
tibble(site_id="VSE2", latitude=19.4724667, longitude=-96.9286167),
tibble(site_id="VSE3", latitude=19.4715833, longitude=-96.92925),
tibble(site_id="VSE4", latitude=19.4649667, longitude=-96.9343))

field_level_data$variety <- missing_variety$variety
field_level_data$latitude <- missing_coordinates$latitude
field_level_data$longitude <- missing_coordinates$longitude
field_level_data$field_size <- missing_area$field_size

#setwd("C:/Users/USUARIO/Desktop/OBservData/Datasets_storage")
write_csv(field_level_data, "Processing_files/Datasets_storage/field_level_data_Carlos_H_Vergara_Coffea_arabica_Mexico_2004.csv")
#setwd(dir_ini)

