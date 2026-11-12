/// <reference types="vitest" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icon.svg', 'apple-touch-icon.png'],
      manifest: {
        name: 'Forja — evolução pessoal',
        short_name: 'Forja',
        description: 'Construa hábitos reais e evolua seu personagem.',
        lang: 'pt-BR',
        theme_color: '#0B0D12',
        background_color: '#0B0D12',
        display: 'standalone',
        orientation: 'portrait',
        start_url: '/',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        navigateFallback: '/index.html',
        // Dados do Supabase nunca são servidos do cache
        runtimeCaching: [],
      },
    }),
  ],
  test: { environment: 'jsdom', globals: false },
});
