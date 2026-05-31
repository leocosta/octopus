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
      defaultLocale: 'root',
      locales: {
        root: { label: '🇺🇸 EN', lang: 'en' },
        'pt-br': { label: '🇧🇷 PT-BR', lang: 'pt-BR' },
      },
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
          translations: { 'pt-BR': 'Comece Aqui' },
          items: [
            {
              label: 'What is Octopus',
              translations: { 'pt-BR': 'O que é o Octopus' },
              slug: 'get-started/what-is-octopus',
            },
            {
              label: 'Installation',
              translations: { 'pt-BR': 'Instalação' },
              slug: 'get-started/install',
            },
            {
              label: 'Quick Start',
              translations: { 'pt-BR': 'Início Rápido' },
              slug: 'get-started/quickstart',
            },
            {
              label: 'Mental Model',
              translations: { 'pt-BR': 'Modelo Mental' },
              slug: 'get-started/mental-model',
            },
          ],
        },
        {
          label: 'Bundles',
          translations: { 'pt-BR': 'Bundles' },
          autogenerate: { directory: 'bundles' },
          collapsed: true,
        },
        {
          label: 'Skills',
          translations: { 'pt-BR': 'Skills' },
          autogenerate: { directory: 'skills' },
          collapsed: true,
        },
        {
          label: 'Commands',
          translations: { 'pt-BR': 'Comandos' },
          autogenerate: { directory: 'commands' },
          collapsed: true,
        },
        {
          label: 'Hooks',
          translations: { 'pt-BR': 'Hooks' },
          autogenerate: { directory: 'hooks' },
          collapsed: true,
        },
        {
          label: 'Roles',
          translations: { 'pt-BR': 'Roles' },
          autogenerate: { directory: 'roles' },
          collapsed: true,
        },
        {
          label: 'Architecture',
          translations: { 'pt-BR': 'Arquitetura' },
          autogenerate: { directory: 'architecture' },
          collapsed: true,
        },
        {
          label: 'Reference',
          translations: { 'pt-BR': 'Referência' },
          collapsed: true,
          items: [
            {
              label: 'Changelog',
              translations: { 'pt-BR': 'Changelog' },
              link: '/changelog/',
            },
          ],
        },
      ],
      customCss: ['./src/styles/custom.css'],
    }),
  ],
});
