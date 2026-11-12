/// <reference types="vitest" />
// Build da versão individual como um único arquivo HTML, publicado como página no claude.ai.
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { viteSingleFile } from 'vite-plugin-singlefile';

export default defineConfig({
  plugins: [react(), viteSingleFile()],
  define: {
    'import.meta.env.VITE_BACKEND': JSON.stringify('local'),
    'import.meta.env.VITE_ROUTER': JSON.stringify('memory'),
  },
  build: { outDir: 'dist-pagina', assetsInlineLimit: 100_000_000 },
});
