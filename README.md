# NBMP Gap Analysis Survey

This repository hosts the HTML code for the National Biodiversity Monitoring Program (NBMP) stakeholder gap analysis survey deployment. The survey is taken through the deployment URL on GitHub Pages, and responses collected using a Google Sheet, connected through a custom Google app.

The code was written with extensive support from Codex and Claude Code, with oversight and testing by the UB-ERI team.


## Files
- .gitignore defines which local files and folders should not be committed to the repository (in this case, generated outputs and local-only data).
- code.gs includes the Google Apps Script that receives submissions and appends them to the response spreadsheet. It must be bound to that Google Sheet and deployed as a Web App. It writes to the tab named in its `SHEET_NAME` constant (default `Responses`), falling back to the first tab, and uses `LockService` so simultaneous submissions are written one at a time. Opening the deployment URL in a browser (a GET) returns `{"status":"ok"}` as a quick liveness check.
- default_headers.csv lists the recommended headers to use in the target response Google Sheet. These should be added to the Google Sheet before collecting responses.
- data_analysis.r stores R code to analyze any response data exports found in the data_deposit folder and produce outputs in the outputs folder. (NOT YET IMPLEMENTED)
- index.html is the survey HTML. The deployment URL for the Google Apps Script on your response spreadsheet must be set in one place: the `SUBMIT_URL` constant just above the submit handler in `index.html` (search for `const SUBMIT_URL`).


## Folders
- assets/ — image assets referenced by index.html. Currently holds the two organization logos shown on the Welcome screen (`logo-ub-eri.jpg` and `logo-nbio.jpg`).
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

The survey uses **33 toggle functions** to show/hide conditional content based on user selections. Key toggle patterns:

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
   - Serializes concurrent submissions with `LockService` so rows can't collide
   - Appends new row with timestamp and all response data
   - Returns `{"status":"success"}` (or `{"status":"error", ...}`) to the HTML form, which the form reads to confirm the save

3. **default_headers.csv** (Schema Definition)
   - Defines the exact column structure for the response spreadsheet
   - **Must match** the `name` attributes of form fields in index.html
   - Contains 145 columns total (including timestamp)
   - Column order matters: data is written to columns in the order headers appear
   - Dynamic fields use underscore notation: `ltSpecies_0`, `ltSpecies_1`, ... for table rows. Columns for rows 0-4 are pre-provisioned; if a respondent adds a 6th row or more, `code.gs` appends the extra columns (`ltSpecies_5`, ...) to the end of the sheet automatically (see Dynamic Tables below)

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
   - Give the question's `<label>` a `class="question-label"` attribute — **do not add a number prefix**; numbering is automatic (see below)
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

#### Question Numbering

Question numbers are generated automatically — they are not written into the HTML. On page load, a JavaScript one-liner (see the Init block in `index.html`) finds every `<label class="question-label">` in document order and assigns a `data-question-number` attribute (1, 2, 3, …). A CSS `::before` rule then displays that number before the label text.

This means:
- Adding, removing, or reordering questions renumbers everything automatically.
- When writing a question label, use `class="question-label"` with no number prefix:

```html
<label class="question-label">Does your organization do biodiversity monitoring?</label>
```

CSS counters were intentionally not used here because the survey shows one section at a time via `display: none`, which causes CSS counters to reset per visible section.

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

The survey includes three dynamic tables where users can add rows. Each table starts
with one row and the respondent can add **an unlimited number** via the "Add Row"
button (there is no cap — respondents are expected to list every project/concern they
have).

- **Long-term monitoring projects** (Section 4): Fields `ltSpecies_N`, `ltSites_N`, `ltYears_N`, `ltMethods_N`, `ltOngoing_N`
- **Recent research projects** (Section 4): Fields `rrSpecies_N`, `rrSites_N`, `rrYears_N`, `rrMethods_N`
- **Community species concerns** (Section 13): Fields `ccCommunity_N`, `ccDistrict_N`, `ccSpecies_N`, `ccReason_N`

`N` starts at 0. `default_headers.csv` pre-provisions columns for rows 0-4. If a
respondent adds a 6th row or beyond, `code.gs` appends the new columns
(`ltSpecies_5`, `ltSites_5`, ...) to the right-hand end of the sheet on the first
submission that needs them, and fills them in. No data is lost, but those overflow
columns are added in first-seen order rather than pre-grouped.

**For analysis:** read these table columns by header name, not by fixed position —
the three tables are variable-width.

To change how many rows are pre-provisioned, add or remove `_N` column sets in
`default_headers.csv` and the sheet's header row (keeping each table's columns
grouped and contiguous). No `index.html` change is needed — the "Add Row" buttons
already generate unlimited `_N` field names.

### Form State Persistence

The survey automatically saves progress to browser localStorage:
- Saves after each section navigation
- Restores on page reload using `restoreProgress()`
- Data remains until the save is confirmed by the server, the respondent clicks "Start Over" (see below), or the user clears browser data
- **Important:** Data is saved locally only; responses aren't sent to Google Sheets until "Finish" is clicked
- On "Finish" the response is POSTed to the Apps Script web app. localStorage is cleared only after the server confirms the save (`{"status":"success"}`); if the request fails or times out, an error with a **Retry** button is shown and the answers are kept

The **"Start Over"** button (next to "Previous" in the navigation bar) lets a respondent discard their session. It opens a confirmation dialog; on "Yes" it clears the saved localStorage state, resets the form, and reloads the page so the survey restarts from the beginning. "Cancel" closes the dialog with no change. Handled by `openStartOver()` / `closeStartOver()` / `confirmStartOver()` in `index.html`.

### Deployment Checklist

When deploying or updating the survey:

1. Set the Google Apps Script deployment URL in index.html — the `SUBMIT_URL` constant just above the submit handler (search for `const SUBMIT_URL`)
2. Ensure default_headers.csv matches all form field names in index.html
3. Copy headers from default_headers.csv into row 1 of the response tab, and name that tab `Responses` (or update `SHEET_NAME` in code.gs to match its name)
4. Paste code.gs into the sheet-bound Apps Script project and deploy as a Web App (Execute as: Me; Who has access: Anyone). Re-deploy (new version) after any code.gs change
5. Open the `/exec` URL in a browser — it should show `{"status":"ok"}`
6. Submit the form once from the live (GitHub Pages) URL; confirm the row lands in the spreadsheet AND the "Thank you" screen appears. If an error message shows instead, the web app is unreachable or not deployed with "Anyone" access — fix before sending the survey out
7. Verify skip logic works correctly for all paths through the survey
