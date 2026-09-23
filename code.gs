/**
 * NBMP Gap Analysis Survey - response receiver.
 *
 * Bind this script to the response Google Sheet (Extensions > Apps Script from
 * the sheet), then deploy it as a Web App with:
 *   - Execute as:      Me
 *   - Who has access:  Anyone
 * Paste the resulting /exec URL into the SUBMIT_URL constant in index.html.
 *
 * index.html POSTs one JSON object per submission. Keys are matched to the
 * header row of the sheet (row 1); values are written in that column order.
 */

// Tab that responses are written to. If your response tab has a different name,
// change this string. If the name does not match any tab, the first tab is used.
var SHEET_NAME = "Responses";

function doPost(e) {
  var lock = LockService.getScriptLock();
  // Wait up to 30s for any other in-progress submission to finish. This makes
  // simultaneous submissions queue and write one at a time instead of colliding
  // (which could drop a response or corrupt the header row).
  lock.waitLock(30000);

  try {
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    var sheet = ss.getSheetByName(SHEET_NAME) || ss.getSheets()[0];

    var data = JSON.parse(e.postData.contents);
    data.timestamp = new Date().toISOString();

    // Seed the header row from the first submission if the sheet is empty.
    if (sheet.getLastRow() === 0) {
      sheet.appendRow(Object.keys(data));
    }

    var headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];

    // Append any keys that are not already columns (e.g. extra dynamic-table rows).
    var newKeys = Object.keys(data).filter(function (k) {
      return headers.indexOf(k) === -1;
    });
    if (newKeys.length > 0) {
      headers = headers.concat(newKeys);
      sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
    }

    var row = headers.map(function (h) {
      return Object.prototype.hasOwnProperty.call(data, h) ? data[h] : "";
    });
    sheet.appendRow(row);

    return ContentService
      .createTextOutput(JSON.stringify({ status: "success" }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService
      .createTextOutput(JSON.stringify({ status: "error", message: String(err) }))
      .setMimeType(ContentService.MimeType.JSON);
  } finally {
    lock.releaseLock();
  }
}

// Open the /exec URL in a browser to check the deployment is live: it should
// return {"status":"ok"}.
function doGet() {
  return ContentService
    .createTextOutput(JSON.stringify({ status: "ok" }))
    .setMimeType(ContentService.MimeType.JSON);
}
