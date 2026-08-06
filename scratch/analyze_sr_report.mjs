import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = process.argv[2] ?? "C:/Users/CZ/Documents/ReportTester-279661518 - SR.xlsx";
const previewDir = process.argv[3] ?? "C:/Users/CZ/.codex/visualizations/2026/08/06/019fd523-3838-7361-8b4d-f2721c621be4/sr-report-previews";

const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);

await fs.mkdir(previewDir, { recursive: true });
for (const sheet of workbook.worksheets.items) {
  const details = await workbook.inspect({
    kind: "table",
    sheetId: sheet.name,
    range: "A1:M75",
    maxChars: 30000,
    tableMaxRows: 75,
    tableMaxCols: 13,
    tableMaxCellChars: 240,
  });
  console.log(`===SUMMARY:${sheet.name}:A1:M75===`);
  console.log(details.ndjson);

  const preview = await workbook.render({
    sheetName: sheet.name,
    range: "A1:M75",
    scale: 1,
    format: "png",
  });
  const safeName = sheet.name.replace(/[^a-zA-Z0-9_-]+/g, "_");
  await fs.writeFile(`${previewDir}/${safeName}.png`, new Uint8Array(await preview.arrayBuffer()));
}
