# Data Cleaning Rulebook

This rulebook defines how the raw survey export is cleaned before analysis.

Where possible, cleaning should be automated within `data_analysis.r`. Manual file cleaning should only be done where cleaning cannot be generalized. The main target of data cleaning are free text columns. A copy of the original raw input must be retained at all times as backup. The primary key for the data is `timestamp`.

Test and duplicate rows of data are filtered out in `data_analysis.r`. Incomplete submissions are kept.

### 1. Organization names

Relevant columns: `organizationName`, `collaborationOrgsList`, `shareDataWhom`

Organization names should be spelled out and presented as their official name. `lookup_tables\organizations_lookup.csv` is used in `data_analysis.r` to automatically assign organization names where possible. All other values are manually mapped to one of the valid organizations in the lookup table. Values from these rows that cannot be mapped to one of the valid organization in the lookup table are handled individually.

### 2. Monitoring areas

Relevant columns:  `marineFishOther`, `marineInvertebratesOther`, `freshwaterMacroSpecify`, `terrestrialInvertebratesOther`,	`amphibiansSpecify`, `reptilesOther`, `plantsOther`, `monitoringAreasOther`

Custom supplied monitoring area names should be grouped and irrelavant responses excluded. Responses are changed to title case to group similar responses and irrelevant responses are excluded or tidied, including: "We have a watershed monitoring program," (excluded), "various lizard species" (tidied to "lizards"), "Benthic for marine" (tidied to "marine benthic"), and "Pine trees (fire effects monitoring in savannah)" (tidied to "pine trees").

### 3. Long-term Projects and Research Projects

Relevant column patterns: `ltSpecies_#`, `ltSites_#`, `ltYears_#`, `ltMethods_#`, `ltOngoing_#`, `rrSpecies_#`, `rrSites_#`, `rrYears_#`, `rrMethods_#`

Species may be any taxonomic or group descriptor of biological organisms. Species should be common names instead of scientific names. Species should also be written in the plural and Title Case. Mixed answers should be split into lists (e.g., "Freshwater fish/systems" → Freshwater Fish, Freshwater Systems). Other brackets and qualifiers should be removed (e.g., "Wildlife (general)" → Wildlife). Any typos should be fixed. Commas should be the separator between multiple answers.

Methods should be standardized where possible (e.g., "camera trapping" and "camera traps" → Camera Trap). Commas should be the separator between multiple answers. Descriptive data, such as an extended list of measured parameters, should be excluded. Methods values that are missing should be filled in where known.

Site names should be spelled out and presented as their official name and district. `lookup_tables\sites_lookup.csv` is used in `data_analysis.r` to automatically assign site names where possible. All other values are manually mapped to one of the valid sites in the lookup table. Values from these rows that cannot be mapped to one of the valid site in the lookup table are handled individually.

Ongoing values that are missing should be filled in where the answer is known. Ongoing values must be Yes or No. Qualifiers and brackets should be excluded.
