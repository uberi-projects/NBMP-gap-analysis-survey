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
