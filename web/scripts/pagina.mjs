// Converte o build de arquivo único em um fragmento de página para publicar no claude.ai
// (a plataforma acrescenta doctype, <head> e <body> sozinha).
import { readFileSync, writeFileSync } from 'node:fs';

const html = readFileSync('dist-pagina/index.html', 'utf8');
const pick = (re) => [...html.matchAll(re)].map((m) => m[0]);
const styles = pick(/<style[^>]*>[\s\S]*?<\/style>/g);
const scripts = pick(/<script[^>]*>[\s\S]*?<\/script>/g);
const fonts = pick(/<link[^>]+fonts\.googleapis\.com\/css2[^>]*>/g);

const page = [
  '<title>Forja</title>',
  '<meta name="claude:viewport-fit-sides" content="cover">',
  ...fonts,
  ...styles,
  '<div id="root"></div>',
  ...scripts,
].join('\n');
writeFileSync('dist-pagina/forja.html', page);
console.log(`dist-pagina/forja.html: ${(page.length / 1024).toFixed(0)} KB`);
