#!/usr/bin/env node
// assemble-pdf.mjs — fuegt PNG-Frames zu einer PDF zusammen.
// Verantwortung: nur Assembly. Browser-Steuerung delegiert an playwright-cli.
// Aufruf:
//   node assemble-pdf.mjs --inputs "./build/foo-*.png" --output "./out/foo.pdf" --format a4
//
// --format akzeptiert: a4, a4-landscape, letter, a3, a5, dl, visitenkarte, postkarte,
//                      16-9, 4-3, 9-16,
//                      linkedin-post, linkedin-carousel, linkedin-banner,
//                      instagram-post, instagram-story,
//                      newsletter,
//                      custom:WIDTHxHEIGHT  (in pt, z.B. custom:1200x630)

import { PDFDocument } from 'pdf-lib';
import { readFile, writeFile } from 'node:fs/promises';
import { glob } from 'node:fs/promises';  // node 22+ — fallback unten
import { existsSync } from 'node:fs';

// pt-Maße (1pt = 1/72 inch).
const FORMATS = {
  'a4':              [595.28, 841.89],
  'a4-landscape':    [841.89, 595.28],
  'letter':          [612, 792],
  'a3':              [841.89, 1190.55],
  'a5':              [419.53, 595.28],
  'dl':              [280.63, 595.28],
  'visitenkarte':    [240.94, 155.91],   // 85x55mm
  'postkarte':       [419.53, 297.64],   // 148x105mm
  '16-9':            [1920, 1080],
  '4-3':             [1440, 1080],
  '9-16':            [1080, 1920],
  'linkedin-post':   [1200, 627],
  'linkedin-carousel': [1080, 1080],
  'linkedin-banner': [1584, 396],
  'instagram-post':  [1080, 1080],
  'instagram-story': [1080, 1920],
  'newsletter':      [600, 800],         // Email-Default; bei Multi-Page passt jede Page Hoehe
};

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i++) {
    const k = argv[i];
    if (k.startsWith('--')) args[k.slice(2)] = argv[++i];
  }
  return args;
}

function resolveFormat(name) {
  if (name.startsWith('custom:')) {
    const [w, h] = name.slice(7).split('x').map(Number);
    if (!w || !h) throw new Error(`Invalid custom format: ${name} (expected custom:WIDTHxHEIGHT)`);
    return [w, h];
  }
  if (!FORMATS[name]) {
    throw new Error(`Unknown format: ${name}. Known: ${Object.keys(FORMATS).join(', ')} or custom:WxH`);
  }
  return FORMATS[name];
}

async function expandGlob(pattern) {
  // Fallback ohne node:fs glob (vor node 22): einfacher Glob-Resolver per fs.readdir.
  const { readdir } = await import('node:fs/promises');
  const path = await import('node:path');
  const dir = path.dirname(pattern);
  const base = path.basename(pattern);
  const regex = new RegExp('^' + base.replace(/\./g, '\\.').replace(/\*/g, '.*') + '$');
  if (!existsSync(dir)) throw new Error(`Input directory not found: ${dir}`);
  const files = (await readdir(dir)).filter(f => regex.test(f)).sort();
  return files.map(f => path.join(dir, f));
}

async function main() {
  const { inputs, output, format } = parseArgs(process.argv);
  if (!inputs || !output || !format) {
    console.error('Usage: assemble-pdf.mjs --inputs "<glob>" --output "<file.pdf>" --format <name|custom:WxH>');
    process.exit(1);
  }

  const [pageW, pageH] = resolveFormat(format);
  const files = await expandGlob(inputs);
  if (files.length === 0) {
    console.error(`No input files matched: ${inputs}`);
    process.exit(1);
  }

  const pdf = await PDFDocument.create();
  for (const file of files) {
    const bytes = await readFile(file);
    const png = await pdf.embedPng(bytes);
    const page = pdf.addPage([pageW, pageH]);
    page.drawImage(png, { x: 0, y: 0, width: pageW, height: pageH });
  }

  const out = await pdf.save();
  await writeFile(output, out);
  console.log(`Wrote ${output} (${files.length} pages, ${pageW}x${pageH}pt)`);
}

main().catch(err => {
  console.error(err.message);
  process.exit(1);
});
