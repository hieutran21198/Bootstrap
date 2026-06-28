import {themes as prismThemes} from 'prism-react-renderer';
import type {Config} from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';
import type {Options as DocsOptions} from '@docusaurus/plugin-content-docs';

const config: Config = {
  title: 'Bootstrap Workspace Docs',
  tagline: 'Workspace-wide and service documentation',

  // GitHub Pages project site: https://hieutran21198.github.io/Bootstrap/
  url: 'https://hieutran21198.github.io',
  baseUrl: '/Bootstrap/',
  organizationName: 'hieutran21198',
  projectName: 'Bootstrap',
  trailingSlash: false,

  onBrokenLinks: 'warn',
  onBrokenAnchors: 'warn',

  markdown: {
    format: 'detect',
    hooks: {
      onBrokenMarkdownLinks: 'warn',
      onBrokenMarkdownImages: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: false,
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      } satisfies Preset.Options,
    ],
  ],

  plugins: [
    [
      '@docusaurus/plugin-content-docs',
      {
        path: '../../docs',
        routeBasePath: 'docs',
        sidebarPath: './sidebarsWorkspace.ts',
        include: ['**/*.md', '**/*.mdx'],
        exclude: ['**/_*.{js,jsx,ts,tsx,md,mdx}', '**/_*/**', '**/.*/**'],
      } satisfies DocsOptions,
    ],
    [
      '@docusaurus/plugin-content-docs',
      {
        id: 'portal',
        path: '../../services/portal/docs',
        routeBasePath: 'portal',
        sidebarPath: './sidebarsPortal.ts',
        include: ['**/*.md', '**/*.mdx'],
        exclude: ['**/_*.{js,jsx,ts,tsx,md,mdx}', '**/_*/**', '**/.*/**'],
      } satisfies DocsOptions,
    ],
  ],

  themeConfig: {
    navbar: {
      title: 'Bootstrap Docs',
      items: [
        {
          type: 'docSidebar',
          sidebarId: 'workspaceSidebar',
          position: 'left',
          label: 'Workspace',
        },
        {
          type: 'docSidebar',
          docsPluginId: 'portal',
          sidebarId: 'portalSidebar',
          position: 'left',
          label: 'Portal',
        },
      ],
    },
    footer: {
      style: 'dark',
      copyright: `Bootstrap workspace documentation`,
    },
    prism: {
      theme: prismThemes.github,
      darkTheme: prismThemes.dracula,
      additionalLanguages: ['bash', 'go', 'nix', 'toml'],
    },
  } satisfies Preset.ThemeConfig,
};

export default config;
