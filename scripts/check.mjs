import { readdir, readFile, stat } from 'node:fs/promises';
import { join, extname } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = new URL('../', import.meta.url).pathname;
async function walk(dir) {
  const out = [];
  for (const name of await readdir(dir)) {
    const path = join(dir, name);
    (await stat(path)).isDirectory() ? out.push(...await walk(path)) : out.push(path);
  }
  return out;
}

const files = await walk(root);
const scripts = files.filter(file => ['.js', '.mjs'].includes(extname(file)));
for (const file of scripts) {
  const result = spawnSync(process.execPath, ['--check', file], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error(`${file}: ${result.stderr || result.stdout}`);
}

const contentFiles = files.filter(file => ['.html', '.js', '.mjs', '.md'].includes(extname(file)) && !file.endsWith('scripts/check.mjs'));
const text = (await Promise.all(contentFiles.map(file => readFile(file, 'utf8')))).join('\n');
const prohibited = ['KLI-' + 'DEMO', 'prototype ' + 'fungsional', 'sekedar ' + 'demo'];
if (prohibited.some(term => text.toLowerCase().includes(term.toLowerCase()))) throw new Error('Demo-only content remains');
console.log(`Checked ${files.length} files; production source is structurally valid.`);
