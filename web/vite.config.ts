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
        // A função de envio das notificações não é uma página do app
        navigateFallbackDenylist: [/^\/api\//],
        // Dados do Supabase nunca são servidos do cache
        runtimeCaching: [],
        // Notificações: mostrar o push e abrir a tela certa ao tocar (public/push-sw.js)
        importScripts: ['push-sw.js'],
      },
    }),
  ],
  build: {
    rollupOptions: {
      output: {
        // Bibliotecas mudam pouco: num pacote separado, ficam em cache entre as atualizações do app
        manualChunks: { react: ['react', 'react-dom', 'react-router-dom'], supabase: ['@supabase/supabase-js'] },
      },
    },
  },
  test: { environment: 'jsdom', globals: false },
});
