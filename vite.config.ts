import { resolve } from 'node:path';
import { defineConfig } from 'vite';

// Each entry becomes a real HTML file in dist/ at the same path.
// Nginx can serve /sms/ from dist/sms/index.html without a Node.js server.
export default defineConfig({
  appType: 'mpa',
  build: {
    rolldownOptions: {
      input: {
        home: resolve(import.meta.dirname, 'index.html'),
        product: resolve(import.meta.dirname, 'pester-ai/index.html'),
        sms: resolve(import.meta.dirname, 'sms/index.html'),
        terms: resolve(import.meta.dirname, 'sms-terms/index.html'),
        privacy: resolve(import.meta.dirname, 'privacy/index.html'),
        contact: resolve(import.meta.dirname, 'contact/index.html'),
      },
    },
  },
});
