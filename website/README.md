# sling_gql website

Astro + Starlight. Landing page in `src/content/docs/index.mdx`, guides under
`src/content/docs/{guides,tooling,internals}`, theme in `src/styles/custom.css`.

```sh
npm install
npm run dev       # http://localhost:4321/sling_gql/
npm run build     # → dist/
```

Deployed to GitHub Pages (https://tpucci.github.io/sling_gql/) by
`.github/workflows/website.yml` on every push to `main` touching `website/`.
