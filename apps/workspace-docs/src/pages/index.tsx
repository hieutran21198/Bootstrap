import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

import styles from './index.module.css';

const GITHUB_URL = 'https://github.com/hieutran21198/Bootstrap';

type DocCard = {
  to: string;
  title: string;
  body: string;
};

const workspaceTracks: readonly DocCard[] = [
  {
    to: '/docs/adrs',
    title: 'ADRs',
    body: 'Architecture Decision Records — append-only, numbered decisions that shape the workspace.',
  },
  {
    to: '/docs/conventions',
    title: 'Conventions',
    body: 'Living workspace rules: Go code style, package SRP, service architecture, and more.',
  },
  {
    to: '/docs/glossary',
    title: 'Glossary',
    body: 'Canonical terms and definitions shared across every service and package.',
  },
  {
    to: '/docs/findings',
    title: 'Findings',
    body: 'Dated debugging investigations and research notes, resolved and archived.',
  },
  {
    to: '/docs/debt',
    title: 'Tech debt',
    body: 'The technical debt register with an append-only encounter ledger.',
  },
  {
    to: '/docs/specs',
    title: 'Specs',
    body: 'Feature and system design documents for cross-cutting work.',
  },
];

const entryCards: readonly DocCard[] = [
  {
    to: '/docs/AGENTS',
    title: 'Workspace docs',
    body: 'Standards that apply across every service and shared package — start here.',
  },
  {
    to: '/portal',
    title: 'Portal service docs',
    body: 'Portal-only ADRs, specs, findings, and debt. Service-scoped knowledge.',
  },
];

const quickStart = `git clone <repo> bootstrap
cd bootstrap
direnv allow   # auto-enters the dev shell on every cd
ws-info        # workspace overview (auto-runs on shell entry)`;

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout title="Home" description={siteConfig.tagline}>
      <header className={styles.hero}>
        <h1 className={styles.title}>{siteConfig.title}</h1>
        <p className={styles.tagline}>{siteConfig.tagline}</p>
        <div className={styles.heroButtons}>
          <Link className={styles.buttonPrimary} to="/docs/AGENTS">
            Browse workspace docs
          </Link>
          <Link className={styles.buttonSecondary} to="/portal">
            Portal docs
          </Link>
        </div>
      </header>

      <main>
        <section className={styles.section}>
          <p className={styles.lead}>
            A greenfield Go monorepo scaffold managed by Nix + devenv. This site
            renders the workspace&rsquo;s living documentation — the conventions
            enforced by tooling, the decisions behind them, and every
            service&rsquo;s own docs — in one place.
          </p>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Start here</h2>
          <div className={styles.cards}>
            {entryCards.map((card) => (
              <Link key={card.to} to={card.to} className={styles.card}>
                <h3 className={styles.cardTitle}>{card.title}</h3>
                <p className={styles.cardBody}>{card.body}</p>
              </Link>
            ))}
          </div>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Workspace doc tracks</h2>
          <div className={styles.cards}>
            {workspaceTracks.map((card) => (
              <Link key={card.to} to={card.to} className={styles.card}>
                <h3 className={styles.cardTitle}>{card.title}</h3>
                <p className={styles.cardBody}>{card.body}</p>
              </Link>
            ))}
          </div>
        </section>

        <section className={styles.section}>
          <h2 className={styles.sectionTitle}>Quick start</h2>
          <p className={styles.sectionLead}>
            Prerequisites: Nix with flakes, direnv, and devenv. No Makefile, no
            setup script — devenv is the runner.
          </p>
          <pre className={styles.codeBlock}>
            <code>{quickStart}</code>
          </pre>
        </section>

        <section className={styles.section}>
          <div className={styles.links}>
            <Link className={styles.linkChip} to="/docs/AGENTS">
              AGENTS.md
            </Link>
            <Link className={styles.linkChip} href={GITHUB_URL}>
              GitHub repository
            </Link>
          </div>
        </section>
      </main>
    </Layout>
  );
}
