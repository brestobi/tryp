import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  site: 'https://mytryp.co.za',
  output: 'static',
  trailingSlash: 'always',
  integrations: [sitemap()],
});
