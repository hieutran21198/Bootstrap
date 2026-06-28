import type {ReactNode} from 'react';
import Link from '@docusaurus/Link';
import Layout from '@theme/Layout';
import useDocusaurusContext from '@docusaurus/useDocusaurusContext';

import styles from './index.module.css';

type DocCard = {
  to: string;
  title: string;
  body: string;
};

const cards: readonly DocCard[] = [
  {
    to: '/docs/AGENTS',
    title: 'Workspace docs',
    body: 'ADRs, conventions, glossary, findings, debt, and specs that apply across every service and shared package.',
  },
  {
    to: '/portal',
    title: 'Portal service docs',
    body: 'Portal-only ADRs, specs, findings, and debt. Anything that dies with the portal service lives here.',
  },
];

export default function Home(): ReactNode {
  const {siteConfig} = useDocusaurusContext();
  return (
    <Layout title="Home" description={siteConfig.tagline}>
      <header className={styles.hero}>
        <h1 className={styles.title}>{siteConfig.title}</h1>
        <p className={styles.tagline}>{siteConfig.tagline}</p>
      </header>
      <main>
        <section className={styles.cards}>
          {cards.map((card) => (
            <Link key={card.to} to={card.to} className={styles.card}>
              <h2 className={styles.cardTitle}>{card.title}</h2>
              <p className={styles.cardBody}>{card.body}</p>
            </Link>
          ))}
        </section>
      </main>
    </Layout>
  );
}
