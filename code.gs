function doPost(e) {
  const sheet = SpreadsheetApp.getActiveSpreadsheet().getActiveSheet();
  const data = JSON.parse(e.postData.contents);

  // Add timestamp
  data.timestamp = new Date().toISOString();

  // If no headers yet, create them
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(Object.keys(data));
  }

  // Read headers from row 1
  let headers = sheet.getRange(1, 1, 1, sheet.getLastColumn()).getValues()[0];

  // Add any new keys not in headers
  const newKeys = Object.keys(data).filter(k => !headers.includes(k));
  if (newKeys.length > 0) {
    headers = headers.concat(newKeys);

    // Expand the header row range to the new width
    sheet.getRange(1, 1, 1, headers.length).setValues([headers]);
  }

  // Build row in header order
  const row = headers.map(h => (h in data ? data[h] : ""));

  sheet.appendRow(row);

  return ContentService
    .createTextOutput(JSON.stringify({ status: "success" }))
    .setMimeType(ContentService.MimeType.JSON);
}
