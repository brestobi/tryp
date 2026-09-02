import { ReactNode, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Reveal, RevealGroup, RevealItem } from './Reveal';

export function SectionHead({
  eyebrow,
  title,
  description,
  center,
}: {
  eyebrow: string;
  title: ReactNode;
  description?: string;
  center?: boolean;
}) {
  return (
    <Reveal className={`section-head ${center ? 'center' : ''}`}>
      <span className="eyebrow">{eyebrow}</span>
      <h2>{title}</h2>
      {description && <p>{description}</p>}
    </Reveal>
  );
}

const tones: Record<string, string> = {
  red: '#e31b23',
  blue: '#3b82f6',
  gold: '#e8b84b',
  green: '#22c55e',
};

export function FeatureGrid({
  items,
}: {
  items: { icon: ReactNode; title: string; text: string; tone?: keyof typeof tones }[];
}) {
  return (
    <RevealGroup className="feature-grid">
      {items.map((it, i) => (
        <RevealItem className="feature-card" key={i}>
          <span className="feature-num" style={{ color: tones[it.tone ?? 'red'] }}>
            {it.icon}
          </span>
          <h3>{it.title}</h3>
          <p>{it.text}</p>
        </RevealItem>
      ))}
    </RevealGroup>
  );
}

export function PageHero({ eyebrow, title, description }: { eyebrow: string; title: ReactNode; description: string }) {
  return (
    <section className="page-hero">
      <div className="container">
        <Reveal>
          <span className="eyebrow">{eyebrow}</span>
        </Reveal>
        <Reveal delay={0.08}>
          <h1>{title}</h1>
        </Reveal>
        <Reveal delay={0.16}>
          <p>{description}</p>
        </Reveal>
      </div>
    </section>
  );
}

export function ContentLayout({ toc, children }: { toc: { href: string; label: string }[]; children: ReactNode }) {
  const [active, setActive] = useState(toc[0]?.href ?? '');

  useEffect(() => {
    const headings = toc
      .map((t) => document.querySelector(t.href))
      .filter(Boolean) as Element[];
    if (!headings.length) return;
    const obs = new IntersectionObserver(
      (entries) => {
        entries.forEach((e) => {
          if (e.isIntersecting) setActive(`#${e.target.id}`);
        });
      },
      { rootMargin: '-40% 0px -50% 0px' }
    );
    headings.forEach((h) => obs.observe(h));
    return () => obs.disconnect();
  }, [toc]);

  return (
    <div className="container content-layout">
      <nav className="toc">
        {toc.map((t) => (
          <a key={t.href} href={t.href} className={active === t.href ? 'active' : ''}>
            {t.label}
          </a>
        ))}
      </nav>
      <div className="content-body">{children}</div>
    </div>
  );
}

export function Faq({ items }: { items: { q: string; a: string }[] }) {
  return (
    <div className="faq-list">
      {items.map((it, i) => (
        <details className="faq-item" key={i}>
          <summary>
            {it.q}
            <span aria-hidden="true">＋</span>
          </summary>
          <p>{it.a}</p>
        </details>
      ))}
    </div>
  );
}

export function StoreButtons() {
  return (
    <div className="store-row">
      <a className="store-btn" href="mailto:hello@mytryp.co.za?subject=TRYP%20app%20download">
        <span>▰</span>
        <span>
          <small>Passenger app</small>
          <strong>Get started with TRYP</strong>
        </span>
      </a>
      <Link className="store-btn" to="/drive">
        <span>◉</span>
        <span>
          <small>Driver app</small>
          <strong>Drive with TRYP</strong>
        </span>
      </Link>
    </div>
  );
}
