// @ts-check
import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

const repoSlug = 'octopus';
const ghUser = 'leocosta';

export default defineConfig({
  site: `https://${ghUser}.github.io`,
  base: `/${repoSlug}`,
  trailingSlash: 'ignore',
  integrations: [
    starlight({
      title: 'Octopus',
      description:
        'Centralized AI agent configuration for multi-repo teams — skills, bundles, hooks, roles, and continuous learning for Claude Code and friends.',
      logo: {
        light: './public/logo-light.png',
        dark: './public/logo-dark.png',
        alt: 'Octopus',
        replacesTitle: true,
      },
      social: {
        github: `https://github.com/${ghUser}/${repoSlug}`,
      },
      editLink: {
        baseUrl: `https://github.com/${ghUser}/${repoSlug}/edit/main/`,
      },
      sidebar: [
        {
          label: 'Get Started',
          items: [
            { label: 'What is Octopus', slug: 'get-started/what-is-octopus' },
            { label: 'Installation', slug: 'get-started/install' },
            { label: 'Quick Start', slug: 'get-started/quickstart' },
            { label: 'Mental Model', slug: 'get-started/mental-model' },
          ],
        },
        {
          label: 'Bundles',
          autogenerate: { directory: 'bundles' },
          collapsed: true,
        },
        {
          label: 'Skills',
          autogenerate: { directory: 'skills' },
          collapsed: true,
        },
        {
          label: 'Commands',
          autogenerate: { directory: 'commands' },
          collapsed: true,
        },
        {
          label: 'Hooks',
          autogenerate: { directory: 'hooks' },
          collapsed: true,
        },
        {
          label: 'Roles',
          autogenerate: { directory: 'roles' },
          collapsed: true,
        },
        // Architecture ships in a later phase. Re-enable alongside MDX
        // content under docs/site/architecture/.
        // { label: 'Architecture', autogenerate: { directory: 'architecture' }, collapsed: true },
        {
          label: 'Roadmap & Specs',
          collapsed: true,
          items: [
            { label: 'Roadmap', link: '/roadmap/' },
            { label: 'Changelog', link: '/changelog/' },
          ],
        },
      ],
      customCss: ['./src/styles/custom.css'],
    }),
  ],
});
