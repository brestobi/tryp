import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://tryp.co.za',
  output: 'static',
  trailingSlash: 'always',
  integrations: [sitemap()],
});
