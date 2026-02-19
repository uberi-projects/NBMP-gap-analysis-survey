# NBMP Gap Analysis Survey

This repository hosts the HTML code for the National Biodiversity Monitoring Program (NBMP) stakeholder gap analysis survey deployment. The survey is taken through the deployment URL on GitHub Pages, and responses collected using a Google Sheet, connected through a custom Google app.

The code was written with extensive support from Codex and Claude Code, with oversight and testing by the UB-ERI team.


## Files
- .gitignore defines which local files and folders should not be committed to the repository (in this case, generated outputs and local-only data).
- code.gs includes the Google Apps Script which attaches to the target response spreadsheet. This should be attached to the target response Google Sheet. 
- default_headers.csv lists the recommended headers to use in the target response Google Sheet. These should be added to the Google Sheet before collecting responses.
- data_analysis.r stores R code to analyze any response data exports found in the data_deposit folder and produce outputs in the outputs folder. (NOT YET IMPLEMENTED)
- index.html is the survey HTML. The deployment URL for the Google Apps Script on your response spreadsheet must be set in the submit handler in two places: the primary fetch URL and the no-cors retry URL inside `submitToGoogleSheet()`. See `index.html:1703` and `index.html:1718`.


## Folders
- data_deposit/ — this is the location that any response data exports to be used for analysis should be manually placed prior to running data_analysis.r.
- outputs/ — this is the location that any analysis products will be created.


## Technical Description

### Survey Structure Overview

The survey consists of **14 sections** (numbered 0-13) containing **45 questions** total:

- **Section 0:** Introduction (no questions, informational only)
- **Section 1:** Organization Information (organization name)
- **Section 2:** Biodiversity Monitoring Activities (Questions 1-2)
- **Section 3:** Ecosystems (Question 3) - *conditionally skipped*
- **Section 4:** Research Projects (Questions 4-5) - *conditionally skipped*
- **Section 5:** Ecosystem Health (Questions 6-12) - *everyone answers*
- **Section 6:** Enforcement (Questions 13-16) - *conditionally shown*
- **Section 7:** Mainstreaming (Questions 17-19) - *conditionally shown*
- **Section 8:** Collaboration & Challenges (Questions 20-21) - *conditionally skipped*
- **Section 9:** Technology & Skills (Questions 22-27) - *conditionally skipped*
- **Section 10:** Data Management (Questions 28-29) - *conditionally skipped*
- **Section 11:** Data Sharing (Questions 30-36) - *conditionally skipped*
- **Section 12:** National Biodiversity Coordination (Questions 37-39)
- **Section 13:** Significance & Interest (Questions 40-45)

### Conditional Logic & Skip Patterns

The survey implements skip logic based on respondent answers:

#### Skip Logic 1: Biodiversity Monitoring Sections (Sections 3-4)
- **Trigger:** If respondent answers "No" to Question 1 ("Does your organization do biodiversity monitoring?")
- **Behavior:** Sections 3-4 are automatically skipped
- **Implementation:** `shouldSkipMonitoringSections()` function checks for "No" answer and navigation functions skip these sections

#### Skip Logic 2: Data Collection Sections (Sections 8-11)
- **Trigger:** If respondent does NOT collect any data (biodiversity OR ecosystem health data)
- **Behavior:** Sections 8-11 (Collaboration, Technology, Data Management, Data Sharing) are automatically skipped
- **Implementation:** `collectsAnyData()` function checks:
  - Biodiversity monitoring (Question 1 = "Yes")
  - Ecosystem health data (Question 6 = "Yes")
  - Habitat restoration data (Question 7 = "Yes")
  - Pollution data (Question 8, any except "No")
  - Invasive species data (Question 9 = "Yes")
  - Ecosystem services data (Question 10 = "Yes")
  - Community ecosystem services data (Question 11 = "Yes")
  - Climate resiliency data (Question 12, any except "No")
- **Result:** If ANY of these are true, respondent must answer Sections 8-11

#### Skip Logic 3: GBIF Question (Question 36)
- **Trigger:** Only shown if respondent does biodiversity monitoring (Question 1 = "Yes")
- **Behavior:** Question 36 is hidden if they don't do biodiversity monitoring
- **Implementation:** `toggleGbifQuestion()` function conditionally displays/hides the question

### Toggle Functions

The survey uses **32 toggle functions** to show/hide conditional content based on user selections. Key toggle patterns:

- **Nested checkbox groups:** Selecting a parent checkbox reveals sub-options (e.g., "Mammals" reveals specific mammal types)
- **Follow-up questions:** Answering "Yes" reveals additional detail questions (e.g., "Do you collaborate?" → "With whom?")
- **Other/Specify fields:** Selecting "Other" reveals text input fields for specification

All toggle functions are called in `restoreProgress()` to ensure conditional fields display correctly when users return to saved sessions.

### File Relationships & Data Flow

#### HTML → Google Apps Script → Google Sheets

1. **index.html** (Frontend)
   - Contains the complete survey form with all questions
   - Implements client-side validation, skip logic, and conditional display
   - Saves progress to browser localStorage for session persistence
   - On submission, serializes all form data into JSON format
   - Sends data via POST request to the Google Apps Script web app URL

2. **code.gs** (Backend - Google Apps Script)
   - Deployed as a web app attached to the target Google Sheets response spreadsheet
   - Receives POST requests from the HTML form
   - Parses incoming JSON data
   - Maps form field names to spreadsheet columns using header row
   - Appends new row with timestamp and all response data
   - Returns success/error status to the HTML form

3. **default_headers.csv** (Schema Definition)
   - Defines the exact column structure for the response spreadsheet
   - **Must match** the `name` attributes of form fields in index.html
   - Contains 115 columns total (including timestamp)
   - Column order matters: data is written to columns in the order headers appear
   - Dynamic fields use underscore notation: `ltSpecies_0`, `ltSpecies_1`, `ltSpecies_2` for table rows

#### Critical Field Naming Convention

Form field `name` attributes in HTML **must exactly match** column headers in the spreadsheet:

```html
<!-- HTML form field -->
<input type="text" name="organizationName">

<!-- Corresponding CSV header -->
organizationName
```

For dynamic table rows that users can add:
```html
<!-- HTML generates: name="ltSpecies_0", name="ltSpecies_1", name="ltSpecies_2" -->
<!-- CSV headers: ltSpecies_0, ltSpecies_1, ltSpecies_2 -->
```

### Making Changes to the Survey

#### Adding a New Question

1. **In index.html:**
   - Add the question HTML in the appropriate section
   - Update question numbering for this and all subsequent questions
   - Add any necessary toggle functions if the question is conditional
   - Add the toggle function call to `restoreProgress()` if conditional
   - Update validation logic in `nextSection()` if required

2. **In default_headers.csv:**
   - Add the new field name(s) to the CSV in the appropriate position
   - Ensure the name matches the HTML `name` attribute exactly

3. **In Google Sheets:**
   - Add the new column header(s) to match the CSV
   - Position matters: columns should match the CSV order

#### Adding a New Section

1. **In index.html:**
   - Add new section div with correct `data-section` number
   - Add section comment: `<!-- Section X: Section Name -->`
   - Renumber all subsequent sections
   - Update all questions in subsequent sections
   - Add section to conditional skip logic if needed (in `nextSection()`, `prevSection()`)
   - Update `totalSections` span if needed (though JavaScript calculates this dynamically)

2. **CSV/Sheets:** Add any new fields as described above

#### Modifying Skip Logic

Skip logic is controlled in three key functions in index.html:

- `shouldSkipMonitoringSections()` - determines if Sections 3-4 should be skipped
- `collectsAnyData()` - determines if respondent collects any data
- `shouldSkipDataSections()` - uses `collectsAnyData()` to determine if Sections 8-11 should be skipped
- `nextSection()` and `prevSection()` - implement the skip behavior during navigation

To modify skip behavior, update the conditional checks in these functions.

#### Adding Conditional Display Logic

1. Create a toggle function:
```javascript
function toggleMyNewField() {
    const triggerChecked = document.querySelector('input[name="triggerField"][value="Yes"]')?.checked;
    const targetElement = document.getElementById("myConditionalField");
    if (targetElement) {
        targetElement.style.display = triggerChecked ? "block" : "none";
    }
}
```

2. Add `onchange` handler to the trigger field:
```html
<input type="radio" name="triggerField" value="Yes" onchange="toggleMyNewField()">
```

3. Add function call to `restoreProgress()` to ensure it runs on page load

### Dynamic Tables

The survey includes three dynamic tables where users can add rows:

- **Long-term monitoring projects** (Section 4): Fields `ltSpecies_0-2`, `ltSites_0-2`, `ltYears_0-2`, `ltMethods_0-2`, `ltOngoing_0-2`
- **Recent research projects** (Section 4): Fields `rrSpecies_0-2`, `rrSites_0-2`, `rrYears_0-2`, `rrMethods_0-2`
- **Community species concerns** (Section 13): Fields `ccCommunity_0-2`, `ccDistrict_0-2`, `ccSpecies_0-2`, `ccReason_0-2`

Each table supports up to 3 rows (indices 0-2). To add more rows:
1. Increment the maximum row counter in the `addRow()` functions
2. Add additional column headers to default_headers.csv (e.g., `ltSpecies_3`, `ltSpecies_4`)
3. Add corresponding columns to the Google Sheets response spreadsheet

### Form State Persistence

The survey automatically saves progress to browser localStorage:
- Saves after each section navigation
- Restores on page reload using `restoreProgress()`
- Data remains until form submission or user clears browser data
- **Important:** Data is saved locally only; responses aren't sent to Google Sheets until "Finish" is clicked

### Deployment Checklist

When deploying or updating the survey:

1. Update Google Apps Script deployment URL in index.html — search for `submitToGoogleSheet` and update the two fetch URLs (primary and no-cors retry)
2. Ensure default_headers.csv matches all form field names in index.html
3. Copy headers from default_headers.csv to first row of Google Sheets response spreadsheet
4. Attach code.gs to the response spreadsheet and deploy as web app
5. Set web app permissions to "Anyone" for public access
6. Test form submission and verify data appears correctly in spreadsheet
7. Verify skip logic works correctly for all paths through the survey
