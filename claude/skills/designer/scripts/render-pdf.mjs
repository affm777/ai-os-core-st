#!/usr/bin/env node
// render-pdf.mjs: rendert eine HTML-Seite per Playwright-Node-API zu Vektor-PDF.
// Verantwortung: nur Chromium-Steuerung + page.pdf(). Kein System-Browser-Pfad,
// kein Channel-Lookup. Nutzt das über `npx playwright install chromium` (siehe
// bootstrap.sh) gebündelte Chromium aus dem ms-playwright-Cache. Plattformneutral
// (macOS + Windows 11 / Git Bash), ersetzt den früheren macOS-only
// `--print-to-pdf`-Aufruf in SKILL.md Pfad B.
//
// Aufruf:
//   node render-pdf.mjs --url <http-url-oder-file-url> --output <pfad.pdf> [--format A4]
//   node render-pdf.mjs --url <url> --output <pfad.pdf> --width <pt> --height <pt>
//
// --format akzeptiert alles was Playwright page.pdf() versteht (A4, Letter, A3,
// A5, Legal, Tabloid, ...). Default: A4. Für Maße, die page.pdf() nicht direkt
// kennt (z.B. Visitenkarte, Social-Formate), --width/--height in pt statt
// --format übergeben (siehe FORMATS in assemble-pdf.mjs für pt-Referenzwerte).

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i];
    if (k.startsWith('--')) args[k.slice(2)] = argv[++i];
  }
  return args;
}

async function main() {
  const { url, output, format, width, height } = parseArgs(process.argv);
  if (!url || !output) {
    console.error('Usage: render-pdf.mjs --url <url> --output <file.pdf> [--format A4 | --width <pt> --height <pt>]');
    process.exit(1);
  }

  let chromium;
  try {
    ({ chromium } = await import('playwright'));
  } catch (err) {
    console.error(
      'playwright (Node-Paket) nicht importierbar. Im Skill-Ordner installieren:\n' +
      '  cd ~/.claude/skills/designer && npm install --silent\n' +
      `Original-Fehler: ${err.message}`
    );
    process.exit(1);
  }

  const pdfOptions = {
    path: output,
    printBackground: true,
    preferCSSPageSize: true,
  };
  if (width && height) {
    pdfOptions.width = `${width}pt`;
    pdfOptions.height = `${height}pt`;
  } else {
    pdfOptions.format = format || 'A4';
  }

  let browser;
  try {
    browser = await chromium.launch({ headless: true });
  } catch (err) {
    console.error(
      'Chromium-Start fehlgeschlagen — vermutlich kein Browser installiert. Nachholen mit:\n' +
      '  npx playwright install chromium\n' +
      `Original-Fehler: ${err.message}`
    );
    process.exit(1);
  }

  try {
    // Isoliertes Temp-Profil (Default bei chromium.launch ohne persistentes
    // Kontext-Verzeichnis) — kein Profilkonflikt wie beim System-Edge-Aufruf.
    const page = await browser.newPage();
    await page.goto(url, { waitUntil: 'networkidle' });
    await page.pdf(pdfOptions);
    console.log(`Wrote ${output} (${pdfOptions.format || `${width}x${height}pt`})`);
  } catch (err) {
    console.error(`PDF-Render fehlgeschlagen: ${err.message}`);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

main().catch(err => {
  console.error(err.message);
  process.exit(1);
});
