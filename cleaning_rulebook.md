# Data Cleaning Rulebook

This rulebook defines how the raw survey export is cleaned before analysis.

Where possible, cleaning should be automated within `data_analysis.r`. Manual file cleaning should only be done where cleaning cannot be generalized. The main target of data cleaning are free text columns. A copy of the original raw input must be retained at all times as backup. The primary key for the data is `timestamp`.

Test and duplicate rows of data are filtered out in `data_analysis.r`. Incomplete submissions are kept.

### 1. Organization names 
Relevant columns: `organizationName`, `collaborationOrgsList`, `shareDataWhom`

Organization names should be spelled out and presented as their official name. `lookup_tables\organizations_lookup.csv` is used in `data_analysis.r` to automatically assign organization names where possible. All other values are manually mapped to one of the valid organizations in the lookup table. Values from these rows that cannot be mapped to one of the valid organization in the lookup table are handled individually:

### 2. Monitoring areas
Relevant columns:  `marineFishOther`, `marineInvertebratesOther`, `freshwaterMacroSpecify`, `terrestrialInvertebratesOther`,	`amphibiansSpecify`, `reptilesOther`, `plantsOther`, `monitoringAreasOther`

Custom supplied monitoring area names should be grouped and irrelavant responses excluded. Responses are changed to title case to group similar responses and irrelevant responses are excluded or tidied, including: "We have a watershed monitoring program," (excluded), "various lizard species" (tidied to "lizards"), "Benthic for marine" (tidied to "marine benthic"), and "Pine trees (fire effects monitoring in savannah)" (tidied to "pine trees").