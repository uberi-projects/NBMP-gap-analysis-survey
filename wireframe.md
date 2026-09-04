# NBMP Gap Analysis Survey - Wireframe

This markdown outlines the flow logic for the NBMP draft gap analysis survey. It is kept in step with `index.html` — when the survey changes, update this file in the same commit.

## Section 0 - Welcome

Informational only. No questions.

## Section 1 - Organization Information

- **Organization Name\*** - free text.

## Section 2 - Biodiversity Monitoring Activities

_Section opens with a highlighted instruction: "Please answer all questions based on work your organization has done in the last 5 years."_

- **Q1. Does your organization do long-term biodiversity monitoring programs and/or project-based biodiversity research?\*** - Yes / No
  - If **Yes** → reveals Q2, and later unlocks the GBIF question in Section 11.
  - If **No** → Q2 stays hidden, and Sections 3–4 are skipped entirely (see Skip Logic 1 below).
- **Q2. Which taxa does your organization do monitoring in?** (only shown if Q1 = Yes) - checkboxes, select all that apply:
  Birds, Mammals, Fish, Marine Invertebrates, Freshwater Macroinvertebrate, Terrestrial Macroinvertebrates, Amphibians, Reptiles, Plants, Other (free text)
  - Several options reveal a nested sub-list when checked (unchecking clears the sub-selections):
    - **Mammals** → Bats, Marine mammals, Primates, Other large/medium/small mammals
    - **Fish** → Freshwater fish, Marine fish (free text "other"); checking **Marine fish** further reveals Sharks, Commercial fish, Reef fish + free text
    - **Marine Invertebrates** → Conch, Crustaceans, Mollusks, Crabs, Lobsters, Corals, Urchins, Sea Cucumbers + free text
    - **Freshwater Macroinvertebrate** → free text "specify"
    - **Terrestrial Macroinvertebrates** → Agricultural Pest Insects, Disease Vector Insects, Butterflies, Bees + free text
    - **Amphibians** → free text "specify"
    - **Reptiles** → Snakes, Crocodiles, Turtles + free text
    - **Plants** → Mangroves, Seaweed/Seagrass/Macroalgae, Hardwood Trees, Epiphytes + free text

---

## Skip Logic 1 - Sections 3–4 (Ecosystems, Research Projects)

**Trigger:** Q1 ("Does your organization do biodiversity monitoring?") = **No**.
**Effect:** Sections 3 and 4 are skipped entirely - Next jumps straight from Section 2 to Section 5. Back navigation from Section 5 jumps straight back to Section 2.

---

## Section 3 - Ecosystems _(skipped if Q1 = No)_

- **Q3. Which ecosystems does your organization do monitoring in?** - checkboxes: Savannah, Pine Forest, Broad-leaved Forest, Shrubland, Wetland, Riparian, Agricultural Areas, Urban, Mangrove and littoral forest, Seagrass, Sparse Algae, Lagoon, Coral Reef, Deep Reef, Open Sea

## Section 4 - Research Projects _(skipped if Q1 = No)_

- **Q4. Long-term biodiversity monitoring projects** (current or closed within the last 5 years) - dynamic table, starts with 1 row, "Add Row" adds unlimited rows: Species/Taxa, Location Name(s), Year(s), Methods, Still Ongoing? (free text)
- **Q5. Project-based research projects conducted in the past 5 years** - same dynamic table pattern (no "Still Ongoing" column), unlimited rows

## Section 5 - Ecosystem Health _(everyone answers - never skipped)_

- **Q6. Which of the following ecosystem health data does your organization collect?** (select all that apply; "No" if none) - checkboxes: Species richness, Presence/absence of indicator or target species, Population size, Freshwater water quality, Marine water quality, Air quality, Soil quality, Nutrient content/levels, Habitat structure, Habitat patch size, Connectivity, Presence of diseases, Extent of diseases, Productivity, Harvest quotas, Other (free text), No
- **Q7. Do you collect any data about the restoration of degraded habitats** (e.g., fire recovery)? - Yes / No
- **Q8. Do you collect data on pollution for any of the following?** - checkboxes: Water, Air, Noise, Light, Thermal pollution, Other (free text), No
- **Q9. Do you collect data on invasive species specifically?** - Yes / No
  - If **Yes** → reveals "If so, which:" free text
- **Q10. Do you measure access to or benefits of ecosystem services?** - Yes / No
  - If **Yes** → reveals checkboxes: Access to clean water, Access to forest products, Access to marine products, Eco-businesses, Carbon stocks, Shoreline protection, Other (free text)
- **Q11. Do you look at the relationship between communities and ecosystem services** (e.g., how communities rely on them)? - Yes / No
- **Q12. Do you collect any data on climate resiliency in ecosystems or communities?** - checkboxes: Yes, communities / Yes, ecosystems / No

## Section 6 - Enforcement

- **Q13. Do you do any enforcement?** - Yes / No
  - If **No** → rest of section (Q14–Q16) hidden.
- **Q14. What kinds of enforcement activities do you do?** (only if Q13 = Yes) - checkboxes, 16 options (patrol types, camera traps/audio sensors, technological surveillance, prevention, detection, incident response, demarcation, checkpoints, joint operations, compliance)
- **Q15. What kind of illegal activities would your organization usually encounter?** (only if Q13 = Yes) - checkboxes: Wildlife extraction, Illegal Wildlife trade/possession, Illegal Clearing, Illegal Logging, Polluting/dumping, Fires, Squatters/trespassing, Illegal mineral extraction
  - **Wildlife extraction** checked → reveals sub-list: Hunting, Taking live animals, Freshwater fishing, Marine fishing (finfish), Conch harvesting, Lobster harvesting, Sea cucumber harvesting
    - **Hunting** checked → reveals free text "Which species"
- **Q16. Do you collect patrol data using SMART, EarthRanger, or a similar tool?** (only if Q13 = Yes) - checkboxes: Yes SMART / Yes EarthRanger / Yes Other (free text) / No
  - If any "Yes" option checked → reveals **follow-up**: "What kind of patrol data do you collect?" - checkboxes: Patrol hours, Number of infractions, Types of infractions, Arrests, Human encounter profiles, Other (free text)

## Section 7 - Mainstreaming

- **Q17. Do you carry out engagement and outreach activities with communities on biodiversity/ecosystem services?** - Yes / No
  - If **Yes** → reveals:
    - **Q18. Which communities do you engage with?** - long text
    - **Q19. How would you describe the type(s) of engagement you most often do?** - checkboxes, select all that apply: Education on fire management, Illegal wildlife trade, Protected areas and ecosystem benefits, Community governance and participation, Project development and implementation + free text "Other"

---

## Skip Logic 2 - Sections 8–11 (Collaboration, Technology, Data Management, Data Sharing)

These four sections are skipped entirely unless the respondent indicates they collect **any** kind of data. "Collects data" = true if **any** of the following:

- Q1 (biodiversity monitoring) = Yes
- Q6 (ecosystem health data) has any answer other than "No"
- Q7 (habitat restoration) = Yes
- Q8 (pollution data) has any answer other than "No"
- Q9 (invasive species) = Yes
- Q10 (ecosystem services) = Yes
- Q11 (community ecosystem services) = Yes
- Q12 (climate resiliency) has any answer other than "No"

If none of the above are true, the survey jumps straight from Section 7 to Section 12.

---

## Section 8 - Collaboration & Challenges _(skipped per Skip Logic 2)_

- **Q20. Are your data collection activities conducted in collaboration with other organizations?** - Yes / No
  - If **Yes** → reveals "Which organizations do you most often collaborate with?" - long text
- **Q21. What are the major challenges for conducting these data collection activities?** - long text

## Section 9 - Technology & Skill Gaps _(skipped per Skip Logic 2)_

- **Q22. What data collection tools does your organization use?** - checkboxes: Printed Datasheets, SMART, KoboToolbox, Survey123 + free text "Others"
- **Q23. What technological gaps does your organization have for data collection purposes?** - checkboxes: None, Lack of smart devices, Lack of survey equipment, Lack of drones for mapping, Lack of cloud storage + free text "Others"
  - **Lack of survey equipment** checked → reveals free text "Specify"
- **Q24. Do you have the complementary software to operate/process data from your survey equipment? Which software?** - long text
- **Q25. Are you missing any other complementary software, equipment, or technology needed?** (e.g., online subscriptions) - long text
- **Q26. What technical skills and training gaps does your organization have?** - checkboxes: None, Limited data analysis skills, Limited GIS access, Limited technical support, High staff turnover leading to constant retraining needs, Limited technical report writing skills, Limited skills for publishing in peer-review journals, Limited project development and management skills + free text "Others"
- **Q27. What type of training is staff continuously needing?** - checkboxes: None, Technical training, Research and monitoring development, Equipment operation, Software, Data cleaning and entering (for existing databases or systems), Data interpretation and analysis, Technical and scientific report writing + free text "Other"
  - **Technical training** checked → reveals free text "What technical training specifically?"
  - **Software** checked → reveals sub-list: Data processing software, Data analysis software, Geospatial software, Equipment operation software

## Section 10 - Data Management _(skipped per Skip Logic 2)_

- **Q28. When your organization digitizes its data, describe how it does so** - checkboxes: Excel/Google Sheets, Data portals, My organization never digitizes its data
  - **Data portals** checked → reveals free text "List data portals"
- **Q29. Do you have any data that is currently undigitized?** (describe it, and whether you'd like digitization help) - long text

## Section 11 - Data Sharing _(skipped per Skip Logic 2)_

- **Q30. Do you submit reports on your data to the government of Belize?** - Yes / No / We do not do reporting
- **Q31. Do you publish your technical reports online** (e.g., website)? - Yes / No / We do not do reporting
  - If **Yes** → reveals "How often do you publish your technical reports online?" - 1+ times/year, 1+ times/5yrs, 1+ times/10yrs (single choice)
- **Q32. Do you publish peer-reviewed papers on your data?** - Yes / No
  - If **Yes** → reveals "How often do you publish papers?" - 1+ times/year, 1+ times/5yrs, 1+ times/10yrs (single choice)
- **Q33. Do you share data results in a public data dashboard?** - Yes / No
- **Q34. Do you share your datasets outside your organization?** - Yes / No
  - If **Yes** → reveals free text "To whom?"
- **Q35. Do you publish your datasets on any online repositories?** - Yes / No
  - If **Yes** → reveals free text "Which repositories?"
- **Q36. Would you be interested in publishing your biodiversity data on GBIF (gbif.org) with UB-ERI support?**
  - **Only shown if Q1 = Yes** (biodiversity monitoring). Not tied to Skip Logic 2 - this question has its own independent visibility rule.
  - Yes / No / Maybe / I am already involved

---

## Section 12 - National Biodiversity Coordination _(everyone answers - never skipped)_

- **Q37. Is your organization involved in any national working groups related to biodiversity in Belize?** (e.g., Coral Reef Monitoring Network, Sea Turtle WG, Jaguar WG) - Yes / No
  - If **Yes** → reveals long text to list working groups
- **Q38. Is your organization leading any of the national working groups?** - Yes / No
  - If **Yes** → reveals long text to state which ones
- **Q39. Is your organization involved in any species or ecosystem task force?** (e.g., Manatee Task Force) - Yes / No
  - If **Yes** → reveals long text to list

## Section 13 - Significance & Interest _(everyone answers - never skipped)_

**Communities**

- **Q40. Which species do you consider of cultural significance in your region/area of work?** - long text
- **Q41. Which species do you consider of economic significance in your region/area of work?** - long text
- **Q42. Have communities you work with expressed concern for specific species?** (e.g., dwindling numbers, or pest) - Yes / No
  - If **Yes** → reveals dynamic table (starts with 1 row, "Add Row" adds unlimited rows): Community, District, Species, Reason of Concern

**Managers & Experts**

- **Q43. Which potential species/taxa would your organization be interested in monitoring/studying in the future? Why?** - long text
- **Q44. Which species/taxa in Belize need more biodiversity monitoring?** - two long text boxes: (a) Lack of/gap in monitoring, (b) Importance of the species/taxa
- **Q45. Which area(s) in Belize need more biodiversity monitoring?** - two long text boxes: (a) Lack of/gap in monitoring, (b) Importance of the area

---

## Full Section Map (with skip conditions)

| #   | Section                            | Shown when                                             |
| --- | ---------------------------------- | ------------------------------------------------------ |
| 0   | Welcome                            | Always                                                 |
| 1   | Organization Info                  | Always                                                 |
| 2   | Monitoring Activities              | Always                                                 |
| 3   | Ecosystems                         | Q1 = Yes                                               |
| 4   | Research Projects                  | Q1 = Yes                                               |
| 5   | Ecosystem Health                   | Always                                                 |
| 6   | Enforcement                        | Always (sub-questions gated by Q13)                    |
| 7   | Mainstreaming                      | Always (sub-questions gated by Q17)                    |
| 8   | Collaboration & Challenges         | Collects any data (see Skip Logic 2)                   |
| 9   | Technology & Skill Gaps            | Collects any data                                      |
| 10  | Data Management                    | Collects any data                                      |
| 11  | Data Sharing                       | Collects any data (Q36 additionally gated by Q1 = Yes) |
| 12  | National Biodiversity Coordination | Always                                                 |
| 13  | Significance & Interest            | Always                                                 |

## Other Behaviors

- **Progress saving:** answers autosave to the respondent's browser (localStorage) after every "Next"/"Previous" click, so a respondent can close the tab and resume later on the same device/browser. Nothing is sent to the response spreadsheet until **Finish** (the last section's Next button) is clicked.
- **Back navigation:** respects the same skip logic in reverse - e.g., going back from Section 5 lands on Section 2 if Sections 3–4 were skipped.
- **Validation:** only two hard stops in the whole survey - a blank Organization Name (Section 1) and an unanswered Q1 (Section 2). All other questions can be left blank.
- **Start Over:** a "Start Over" button sits next to "Previous" in the nav bar on every section. It opens a confirmation dialog; confirming clears the saved localStorage progress, resets the form, and reloads so the survey restarts from the Welcome screen. "Cancel" (or Esc, or clicking the backdrop) closes it with no change.
- **Submission:** on **Finish** the response is POSTed to the Google Apps Script web app. The saved progress is cleared only once the server confirms the save. If the request fails or times out (~20s), an error message with a **Retry** button is shown and the answers are kept - so Retry never loses data.
- **Dynamic tables (Q4, Q5, Q42):** start with one row; "Add Row" appends an unlimited number, and "Remove" deletes a row. The response spreadsheet pre-provisions columns for rows 0-4; if a respondent adds a 6th row or more, the Apps Script appends the extra columns to the end of the sheet automatically (no data lost). Analysis should read these columns by header name, since the tables are variable-width.
