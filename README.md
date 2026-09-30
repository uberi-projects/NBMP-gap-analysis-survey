# NBMP Gap Analysis Survey [![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.23066736.svg)](https://doi.org/10.5281/zenodo.23066736)


This repository hosts the HTML code for the National Biodiversity Monitoring Program (NBMP) stakeholder gap analysis survey deployment. The survey is taken through the deployment URL on GitHub Pages, and responses collected using a Google Sheet, connected through a custom Google app.

The code for the HTML survey was written with support from Codex and Claude Code (Sonnet 5), with oversight and testing by the UB-ERI team. The data analysis script was conceptualized, written, and run by the UB-ERI team, with the assistance of Claude Code (Sonnet 5) in reviewing and auditing code as needed.


## Files
- code.gs includes the Google Apps Script that receives submissions and appends them to the response spreadsheet. It must be bound to that Google Sheet and deployed as a Web App. It writes to the tab named in its `SHEET_NAME` constant (default `Responses`), falling back to the first tab, and uses `LockService` so simultaneous submissions are written one at a time. Opening the deployment URL in a browser (a GET) returns `{"status":"ok"}` as a quick liveness check.
- default_headers.csv lists the recommended headers to use in the target response Google Sheet. These should be added to the Google Sheet before collecting responses so that the order of response columns is logical. Though any additional columns needed will be automatically appending as surveys come through.
- data_analysis.r stores R code to analyze any response data export found in the data_deposit folder with the name "UB-ERI Gap Analysis – Responses - Cleaned.csv" and produce outputs in the outputs folder. It also optionally uses two lookup tables from data_deposit/ (see "Species/Taxa Lookup Tables" below).
- index.html is the survey HTML. The deployment URL for the Google Apps Script on the response spreadsheet must be set in one place: the `SUBMIT_URL` constant just above the submit handler in `index.html`.
- wireframe.md contains a shareable wireframe for the survey, including survey question order and options, and skip logic. This is shareable with partners to communicate survey methods.

## Folders
- assets/ — image assets referenced by index.html
- data_deposit/ — this is the location that response data exports to be used for analysis should be manually placed prior to running data_analysis.r. It also holds the optional `studied_taxa_lookup.csv` and `species_taxa_lookup.csv` lookup tables described below.
- outputs/ — this is the location that any analysis products will be created and stored.


## Species/Taxa Lookup Tables (Optional)

`data_analysis.r` optionally reads two more files from `data_deposit/`: `studied_taxa_lookup.csv` and `species_taxa_lookup.csv`. Like the response export, these are not committed (`data_deposit/` is gitignored). They are manually-curated mapping tables that must be created locally. They're only used for the final figure comparing species/taxa of interest against what's actually studied; without them the script errors out at that step, but every other output will already have been produced by then.

They exist because respondents describe species/taxa in free text (monitoring/research project tables, cultural/economic significance, community concern, monitoring gaps), which rarely matches a survey checkbox option verbatim. Each row maps one free-text variant onto the survey's fixed checkbox taxonomy (e.g. `Mammals` > `Bats`). Columns:

- `species_text` — display name for the row.
- `raw_variants` — semicolon-separated exact-text variants that should match this row (matched case-insensitively against respondent free text).
- `mapped_level1` / `mapped_level2` — the checkbox taxonomy node this maps to; blank if unmapped.
- `match_type` — `Exact` (matches a checkbox option verbatim), `Broader Group` (a specific instance of a broader checkbox category), or `Unmapped` (doesn't fit the taxonomy).
- `needs_review`, `notes` — manual QA columns; not read by the script.
- `species_taxa_lookup.csv` only — `source_categories`: semicolon-separated list of which "important species" question(s) this row came from. Must match one of the `important_categories` values in `data_analysis.r` (Culturally Significant, Economically Significant, Community Concern, Monitoring Gap, Monitoring Importance) to appear in the comparison figure.


## Technical Description

### Survey Structure Overview

- **Section 0:** Introduction
- **Section 1:** Organization Information (organization name)
- **Section 2:** Biodiversity Monitoring Activities (Questions 1-2)
- **Section 3:** Ecosystems (Question 3) - *conditionally skipped*
- **Section 4:** Research Projects (Questions 4-5) - *conditionally skipped*
- **Section 5:** Ecosystem Health (Questions 6-12)
- **Section 6:** Enforcement (Questions 13-16) - *conditionally shown*
- **Section 7:** Mainstreaming (Questions 17-19) - *conditionally shown*
- **Section 8:** Collaboration & Challenges (Questions 20-21) - *conditionally skipped*
- **Section 9:** Technology & Skills (Questions 22-27) - *conditionally skipped*
- **Section 10:** Data Management (Questions 28-29) - *conditionally skipped*
- **Section 11:** Data Sharing (Questions 30-36) - *conditionally skipped*
- **Section 12:** National Biodiversity Coordination (Questions 37-39)
- **Section 13:** Significance & Interest (Questions 40-45)

### Conditional Logic

The survey implements conditional skip logic based on respondent answers, which is communicated in detail in wireframe.md

### Toggle Functions

The survey uses toggle functions to show/hide conditional content based on user selections. Key toggle patterns:

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
   - Matches the `name` attributes of form fields in index.html
   - Contains 145 columns total (including timestamp)
   - Column order matters: data is written to columns in the order headers appear
   - Dynamic fields use underscore notation: `ltSpecies_0`, `ltSpecies_1`, ... for table rows.

### Making Changes to the Survey

#### Following the Field Naming Convention

Form field `name` attributes in HTML must  match column headers in the spreadsheet. For example:

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

#### Adding a New Question

1. **In index.html:**
   - Add the question HTML in the appropriate section
   - Give the question's `<label>` a `class="question-label"` attribute
   - Add any necessary toggle functions if the question is conditional
   - Add the toggle function call to `restoreProgress()` if conditional
   - Update validation logic in `nextSection()` if required

2. **In default_headers.csv:**
   - Add the new field name(s) to the CSV in the appropriate position
   - Ensure the name matches the HTML `name` attribute exactly

3. **In Google Sheets:**
   - Add the new column header(s) to match the CSV in the proper position

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

#### Updating Question Numbering

Question numbers are generated automatically in the order questions appear. On page load, a JavaScript one-liner (see the Init block in `index.html`) finds every `<label class="question-label">` in document order and assigns a `data-question-number` attribute (1, 2, 3, …). A CSS `::before` rule then displays that number before the label text.

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

The survey includes dynamic tables where users can add rows. Each table starts
with one row and the respondent can add an unlimited number via the "Add Row"
button. For example:

**Long-term monitoring projects** (Section 4): Fields `ltSpecies_N`, `ltSites_N`, `ltYears_N`, `ltMethods_N`, `ltOngoing_N`

`N` starts at 0. `default_headers.csv` pre-provisions columns for rows 0-4. If a respondent adds a 6th row or beyond, `code.gs` appends the new columns
(`ltSpecies_5`, `ltSites_5`, ...) to the right-hand end of the sheet on the first submission that needs them, and fills them in.

To change how many rows are pre-provisioned, add or remove `_N` column sets in
`default_headers.csv` and the sheet's header row (keeping each table's columns
grouped and contiguous). No `index.html` change is needed.

### Form State Persistence

The survey automatically saves progress to browser localStorage:
- Saves after each section navigation
- Restores on page reload using `restoreProgress()`
- Data remains until the save is confirmed by the server, the respondent clicks "Start Over" (see below), or the user clears browser data
- Data is saved locally only; responses aren't sent to Google Sheets until "Finish" is clicked. On "Finish" the response is POSTed to the Apps Script web app. localStorage is cleared only after the server confirms the save (`{"status":"success"}`); if the request fails or times out, an error with a Retry button is shown and the answers are kept

The "Start Over" button (next to "Previous" in the navigation bar) lets a respondent discard their session. It opens a confirmation dialog; on "Yes" it clears the saved localStorage state, resets the form, and reloads the page so the survey restarts from the beginning. "Cancel" closes the dialog with no change. Handled by `openStartOver()` / `closeStartOver()` / `confirmStartOver()` in `index.html`.

### Deployment Checklist

When deploying or updating the survey:

1. Set the Google Apps Script deployment URL in index.html — the `SUBMIT_URL` constant just above the submit handler (search for `const SUBMIT_URL`)
2. Ensure default_headers.csv matches all form field names in index.html
3. Copy headers from default_headers.csv into row 1 of the response tab, and name that tab `Responses` (or update `SHEET_NAME` in code.gs to match its name)
4. Paste code.gs into the sheet-bound Apps Script project and deploy as a Web App (Execute as: Me; Who has access: Anyone). Re-deploy (new version) after any code.gs change
5. Open the `/exec` URL in a browser — it should show `{"status":"ok"}`
6. Submit the form once from the live (GitHub Pages) URL; confirm the row lands in the spreadsheet AND the "Thank you" screen appears. If an error message shows instead, the web app is unreachable or not deployed with "Anyone" access
7. Verify skip logic works correctly for all paths through the survey if skip logic was edited
