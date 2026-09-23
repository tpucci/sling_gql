// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://tpucci.github.io',
  base: '/sling_gql',
  integrations: [
    starlight({
      title: 'sling_gql',
      description:
        'A GraphQL client for Flutter where the widget is the query. Proof of concept.',
      logo: { src: './src/assets/logo.svg', alt: 'sling_gql' },
      favicon: '/favicon.svg',
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/tpucci/sling_gql' }],
      editLink: { baseUrl: 'https://github.com/tpucci/sling_gql/edit/main/website/' },
      customCss: ['./src/styles/custom.css'],
      lastUpdated: true,
      sidebar: [
        {
          label: 'Start here',
          items: [
            { label: 'Why sling_gql?', slug: 'guides/why' },
            { label: 'Getting started', slug: 'guides/getting-started' },
          ],
        },
        {
          label: 'Guides',
          items: [
            { label: 'Querying data', slug: 'guides/querying' },
            { label: 'Loading states & errors', slug: 'guides/loading-and-errors' },
            { label: 'Batching & waterfalls', slug: 'guides/batching-and-waterfalls' },
            { label: 'Pagination', slug: 'guides/pagination' },
            { label: 'Caching', slug: 'guides/caching' },
          ],
        },
        {
          label: 'Tooling',
          items: [
            { label: 'Code generation', slug: 'tooling/code-generation' },
            { label: 'Mock API', slug: 'tooling/mock-api' },
            { label: 'Example app', slug: 'tooling/example-app' },
          ],
        },
        {
          label: 'Internals',
          items: [
            { label: 'Architecture', slug: 'internals/architecture' },
            { label: 'Feasibility notes', slug: 'internals/feasibility' },
            { label: 'Roadmap', slug: 'internals/roadmap' },
            { label: 'Working on the repo', slug: 'internals/contributing' },
          ],
        },
      ],
    }),
  ],
});
