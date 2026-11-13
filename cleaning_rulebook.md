# Data Cleaning Rulebook

This rulebook defines how the raw survey export is cleaned before analysis.

Where possible, cleaning should be automated within `data_analysis.r`. Manual file cleaning should only be done where cleaning cannot be generalized. The main target of data cleaning are free text columns. A copy of the original raw input must be retained at all times as backup. The primary key for the data is `timestamp`.

Test and duplicate rows of data are filtered out in `data_analysis.r`. Incomplete submissions are kept.

### 1. Organization names

Relevant columns: `organizationName`, `collaborationOrgsList`, `shareDataWhom`

Organization names should be spelled out and presented as their official name. `lookup_tables\organizations_lookup.csv` is used in `data_analysis.r` to automatically assign organization names where possible. All other values are manually mapped to one of the valid organizations in the lookup table. Values from these rows that cannot be mapped to one of the valid organization in the lookup table are handled individually.

In `collaborationOrgsList` and `shareDataWhom`, commas should be the separator between multiple answers (e.g., "MarAlliance, CRC, and Blue Ventures" → MarAlliance, CRC, Blue Ventures; "Milwaukee County Zoo/Zoological Society of Milwaukee" → Milwaukee County Zoo, Zoological Society of Milwaukee). Brackets and qualifiers are removed (e.g., "HRHP (Coral/finfish)" → HRHP). Prose is reduced to the organizations or groups it names, and general groups are kept as short descriptors (e.g., "With the WCS, and student volunteers" → WCS, Volunteers, Students; "We normally hire a consultant to collect data..." → Consultants).

### 2. Monitoring areas

Relevant columns:  `marineFishOther`, `marineInvertebratesOther`, `freshwaterMacroSpecify`, `terrestrialInvertebratesOther`,	`amphibiansSpecify`, `reptilesOther`, `plantsOther`, `monitoringAreasOther`

Custom supplied monitoring area names should be grouped and irrelavant responses excluded. Responses are changed to title case to group similar responses and irrelevant responses are excluded or tidied, including: "We have a watershed monitoring program," (excluded), "various lizard species" (tidied to "lizards"), "Benthic for marine" (tidied to "marine benthic"), and "Pine trees (fire effects monitoring in savannah)" (tidied to "pine trees").

### 3. Long-term Projects and Research Projects

Relevant column patterns: `ltSpecies_#`, `ltSites_#`, `ltYears_#`, `ltMethods_#`, `ltOngoing_#`, `rrSpecies_#`, `rrSites_#`, `rrYears_#`, `rrMethods_#`

Species may be any taxonomic or group descriptor of biological organisms. Species should be common names instead of scientific names. Species should also be written in the plural and Title Case. Mixed answers should be split into lists (e.g., "Freshwater fish/systems" → Freshwater Fish, Freshwater Systems). Other brackets and qualifiers should be removed (e.g., "Wildlife (general)" → Wildlife). Any typos should be fixed. Commas should be the separator between multiple answers.

Methods should be standardized where possible (e.g., "camera trapping" and "camera traps" → Camera Trap). Commas should be the separator between multiple answers. Descriptive data, such as an extended list of measured parameters, should be excluded. Methods values that are missing should be filled in where known.

Site names should be spelled out and presented as their official name and district. `lookup_tables\sites_lookup.csv` is used in `data_analysis.r` to automatically assign site names where possible. All other values are manually mapped to one of the valid sites in the lookup table. Values from these rows that cannot be mapped to one of the valid site in the lookup table are handled individually.

Years are kept as reported, apart from tidying. Unknown values are written as Unknown (e.g., "? to present" → Unknown to present; "unsure" → Unknown). Bare numbers are given their unit (e.g., "5" → 5 years). `data_analysis.r` takes the earliest four-digit year as the start year and the latest as the end year, and treats "present", "onwards" and "ongoing" as the current year, so only values with four-digit years appear on the project timelines.

Ongoing values that are missing should be filled in where the answer is known. Ongoing values must be Yes or No. Qualifiers and brackets should be excluded.

### 4. Ecosystem health, pollution, and ecosystem services

Relevant columns: `ecosystemHealthDataOther`, `pollutionDataOther`, `ecosystemServicesOther`

Custom supplied data types should be short descriptors of the data collected, not descriptions of the activity. `data_analysis.r` converts these responses to Title Case. `ecosystemHealthDataOther` and `pollutionDataOther` are not split, so each cell should hold a single descriptor (e.g., "Lionfish research" → Invasive species). `ecosystemServicesOther` is split on commas, so commas should be the separator between multiple answers (e.g., "riparian forests. mapping river accesses" → riparian forests, mapping river accesses). Prose is reduced to the data types it describes (e.g., the InVEST response → Coastal Vulnerability, Habitat Risk Assessment, Recreation and Tourism Model).

Responses that describe one of the fixed survey options are moved to that option: the option is selected in the checkbox column, and the custom response is blanked (e.g., "On World water day annually, we test for fecal bacteria" → Water pollution selected in `pollutionData`, replacing Other).

### 5. Invasive species

Relevant column: `invasiveSpeciesWhich`

Species follow the conventions in Section 3. `data_analysis.r` prints the response verbatim after the organization name, so commas should be the separator between multiple answers. Variants of the same species are merged (e.g., "Lion Fish" and "Lionfish presence" → Lionfish). Brackets and qualifiers are removed (e.g., "Armored (Devil) Catfish" → Armored Catfish; "Aedes spp. mosquitoes" → Aedes Mosquitoes; "Red Eared slider turtles were relinquished to us in the past" → Red-eared Slider Turtles). Answers that are not invasive species are excluded (e.g., "humans", "aquatic macro invertebrates in general").

### 6. Enforcement

Relevant column: `patrolDataToolsOtherSpecify`

`data_analysis.r` replaces the "Other" option in `patrolDataTools` with the value of `patrolDataToolsOtherSpecify`, so this value should be the name of the tool only (e.g., "GAIA system for foot patrols" → Gaia GPS).

### 7. Engagement communities

Relevant column: `engagementCommunities`

Community names should be spelled out and presented as their official name. `lookup_tables\communities_lookup.csv` is used in `data_analysis.r` to automatically assign community names where possible. Commas should be the separator between multiple answers (e.g., "La Democracia and Mahogany Heights" → La Democracia, Mahogany Heights; "Big Falls/St. Paul's Bank" → Big Falls, St. Paul's Bank). Introductions, qualifiers and "etc" are removed (e.g., "buffer communities of yellow-headed parrot nesting/roosting grounds - Santa Cruz, ..." → Santa Cruz, ...; "Alta Vista , Valley Community and Steadfast Village" → Alta Vista, Valley Community, Steadfast). Places named within prose are kept, including those with more limited engagement. Audiences that are not places are kept as short descriptors (e.g., "Schools, socials and visitors" → Schools, Visitors; "but we also participate in a broad range of public programs" → Public Programs).

### 8. Engagement types

Relevant column: `engagementTypesOther`

Custom supplied engagement types should be short topics, in sentence case to match the fixed survey options. `data_analysis.r` splits responses on commas and does not change their case, so the same topic must be written identically across rows (e.g., "community science and biodiversity monitoring" and "Capacity building for citizen science monitoring" → Citizen science). Prose is reduced to its topics (e.g., "Riparian reforestation, community development and agroforestry and livelihoods" → Ecosystem restoration, Agroforestry, Community development and livelihoods; "youth engagement, introducing the parks obligations and importance. Cleaning campaign" → Youth engagement, Clean-up campaigns). Topics that duplicate a fixed survey option are excluded (e.g., "project development and implementation").

### 9. Challenges

Relevant column: `challenges`

Challenges are free text in the survey, but `data_analysis.r` splits responses on commas, converts them to Title Case and plots every distinct value. Responses are therefore condensed into a comma-separated list of controlled terms. Terms currently in use are: Funding, Resources, Time, Staff Availability, Staff Capacity, Staff Turnover, Technical Training, Equipment Acquisition, Equipment Maintenance, Laboratory Access, Vehicle Rental Costs, Weather, Safety, Needing to Work Nocturnally, Access to Study Sites, Logistics, Scheduling, Coordination, Partnerships, Community Engagement, Jurisdiction Overlap, Permit Acquisition, Inter-Organizational Competition, Data Storage, Data Sharing, Data Sharing Perceptions, Data Fragmentation, Consistent Data Collection, Consistent Data Management, and Consistent Data Analysis. A new term is only added when a challenge cannot be described by an existing term. For example, "Funding; vehicle or ATV availability, fuel, Equipment; training." → Funding, Logistics, Equipment Acquisition, Technical Training.

### 10. Data tools, technological gaps, skill gaps, and training needs

Relevant columns: `dataToolsOther`, `surveyEquipmentSpecify`, `techGapsOther`, `skillGapsOther`, `trainingNeedsOther`, `technicalTrainingSpecify`

`data_analysis.r` splits these responses on commas and does not change their case, so commas should be the separator between multiple answers and the same answer must be written identically across rows. Tools in `dataToolsOther` are presented as their product name in Title Case (e.g., "rite n rain notebooks, gps" → Rite in the Rain Notebooks, GPS; "We have a WISKY database..." → WISKI, GeoPortal). All other columns are written in sentence case, except for product names and acronyms. `techGapsOther` follows the "Lack of ..." wording of the fixed options (e.g., "Vessel no longer operational for crocodile surveys" → Lack of operational vessel), and `skillGapsOther` follows the "Limited ... skills" wording (e.g., "No Data collection and management" → Limited data collection skills, Limited data management skills).

Duplicate answers in the same cell are merged, and variants of the same answer are standardized (e.g., "GPS/GNSS devices", "High Quality GNSS" and "Garmin GPS units" → GPS; "coustic recorders" and "acoustics recorder" → Acoustic recorders). Explanations, quantities and qualifiers are removed (e.g., "We have 8 camera camera traps but need more coverage" → Camera traps). Responses that are not tools, gaps or training needs are blanked (e.g., "We pass the data to ERI for processing and analysis"; "Gaps may be project specific..."). Responses that duplicate a fixed survey option are kept in the fixed option's wording (e.g., "Project Development and Implementation." → Project development and implementation).

### 11. Digitization

Relevant columns: `digitizationPortals`, `undigitizedData`

Portals are presented as their official name, and commas should be the separator between multiple answers. Explanations are removed (e.g., "Kobo toolbox automated data digitization developed by our internal technical team." → KoboToolbox). The same portal is written identically across `digitizationPortals` and `onlineReposWhichOnes` (e.g., AGRRA Data Portal, GMA Mangrove Restoration Tracker, InVEST).

`undigitizedData` is printed verbatim in `data_analysis.r`, which does not filter non-answers. Responses that report no undigitized data, or that do not describe any undigitized data, are blanked (e.g., "No", "None", "No, all our data is entered in a Google Spreadsheet."). Remaining responses are reduced to a short description of the undigitized data (e.g., "Bird data and past marine surveys" → Bird data, Past marine surveys). A bare "Yes" is set to Unspecified data.

### 12. Data sharing

Relevant columns: `onlineReposWhichOnes`, `onlineRepos`

Repository names are presented as their official name, following the conventions in Section 11. `data_analysis.r` splits responses on commas and semicolons and counts every distinct value. Links are replaced with the repository name (e.g., "https://zenodo.org/records/17823336" → Zenodo). Qualifiers are removed (e.g., "Dryad or similar" → Dryad; "some BioBlitz data are published to iNaturalist and eBird" → iNaturalist, eBird).

Where the response shows that data is not shared to an online repository, the response is blanked and `onlineRepos` is changed from Yes to No (e.g., "in our annual reports").

### 13. Working groups and task forces

Relevant columns: `workingGroupsListText`, `workingGroupsLeadingListText`, `taskForceListText`, `workingGroupsInvolved`, `workingGroupsLeading`

Working group and task force names should be spelled out and presented as their official name, in Title Case. `data_analysis.r` splits `workingGroupsListText` and `taskForceListText` on commas and semicolons and counts every distinct value, so variants of the same group must be identical (e.g., "NCRMN", "NCRWG", "National Coral Reef Network" and "Coral Monitoring Network" → National Coral Reef Monitoring Network; "Jaguar", "JWG" and "National Jaguar Working Group" → Jaguar Working Group; "SPAGS Working Group" → Spawning Aggregation Working Group; "Belize Blue Carbon" → Blue Carbon Working Group; "National Wildfire Working Group" → National Fire Working Group). Commas should be the separator between multiple answers. Organizations that are not working groups or task forces are excluded (e.g., "FCD", "WCS"), and responses that only name partner organizations are blanked.

Where the response shows past membership or leadership only, the response is blanked and `workingGroupsInvolved` or `workingGroupsLeading` is changed from Yes to No (e.g., "Not currently, but we aim to rekindle national conversation around threatened trees in 2027").

### 14. Species of significance and monitoring gaps

Relevant columns: `culturalSpecies`, `economicSpecies`, `speciesMonitoringGap`, `ccSpecies_#`

Species follow the conventions in Section 3. Scientific names are replaced with common names (e.g., "Dermatemys mawii" and "Central American River Turtle" → Hicatees; "Theobroma cacao" → Cacao). Species are written at the level used in `lookup_tables\species_taxa_lookup.csv` (e.g., "Lane Snapper" and "Mutton Snappers" → Snappers; "Queen Conch" → Conch; "Baird's Tapir" → Tapirs). Group descriptors with examples are replaced with the examples (e.g., "game species (paca, armadillo, ...)" → Gibnuts, Armadillos, ...), and habitats are given as their dominant taxa (e.g., "Coral, mangroves, seagrass ecosystems" → Corals, Mangroves, Seagrass). Explanations are removed (e.g., "Theobroma cacao (chocolate) and the jaguar (tourism)" → Cacao, Jaguars). Responses that refer to another answer are filled with that answer (e.g., "All of the above" in `economicSpecies` → the same row's `culturalSpecies`). Responses that report no species, or do not name a species or taxon, are blanked (e.g., "None", "too many to list", "All the species", "Game species").

`data_analysis.r` splits these responses on commas and semicolons and matches every value, ignoring case, against `species_text` and `raw_variants` in `lookup_tables\species_taxa_lookup.csv`. Values that do not match raise a warning when the script is run. New species are added to the lookup table rather than being forced into an existing entry.

### 15. Community concerns

Relevant column pattern: `ccDistrict_#`

Districts must be one or more of Belize, Cayo, Corozal, Orange Walk, Stann Creek, and Toledo, comma-separated. `data_analysis.r` converts districts to Title Case and uses them as heatmap columns, so abbreviations, typos and places are converted to their district (e.g., "OW" → Orange Walk; "Stann Crek" → Stann Creek; "Ambergris Caye" → Belize; "Dangriga to PG" → Stann Creek, Toledo). Nationwide responses are set to all six districts (e.g., "Country wide" → Belize, Cayo, Corozal, Orange Walk, Stann Creek, Toledo).

Species in `ccSpecies_#` follow Section 14.

### 16. Monitoring area gaps

Relevant column: `areaMonitoringGap`

Areas should be spelled out and presented as their official name, in Title Case, using the site names in `lookup_tables\sites_lookup.csv` where possible (e.g., "phmr" → Port Honduras Marine Reserve; "Paynes Creek NP" → Payne's Creek National Park; "area 1" → Fishing Area 1). Broader areas that are not sites are presented as short regions or habitats (e.g., "Rivers/estuary" → Rivers, Estuaries; "The MPA's that border Belize on the north and south" → Border MPAs). `data_analysis.r` splits responses on commas and semicolons and counts every distinct value, so commas should be the separator between multiple answers. Explanations are removed and typos are fixed (e.g., "Maya Mountain Mastiff" → Maya Mountain Massif). Responses that do not name an area are blanked (e.g., "all areas that is needed", "All the important areas").

### 17. Uncleaned columns

The following free-text columns are not cleaned: `huntingSpecies`, `patrolDataTypesOtherSpecify`, `complementarySoftware`, `missingSoftwareEquipment`, `ccCommunity_#`, `ccReason_#`, `futureMonitoring`, `speciesMonitoringImportance`, and `areaMonitoringImportance`. `huntingSpecies` and `patrolDataTypesOtherSpecify` are not used in `data_analysis.r`. `futureMonitoring` and the importance columns are quoted verbatim beside the organization name, as they explain reasoning.

Checkbox, multiple-choice and Yes/No columns are only changed where a free-text response shows the selected option is wrong (see Sections 4, 12 and 13), as their values come directly from the survey options and `data_analysis.r` matches them exactly.
