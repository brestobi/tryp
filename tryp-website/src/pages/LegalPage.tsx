import { useEffect, useState } from 'react';
import { PageHero, ContentLayout } from '../components/Blocks';

interface LegalDoc {
  pageTitle: string;
  eyebrow: string;
  heroTitle: string;
  heroDescription: string;
  toc: { href: string; label: string }[];
  html: string;
}

/** Renders one of the ported legal/policy documents by slug (see public/legal/*.json). */
export default function LegalPage({ slug }: { slug: string }) {
  const [doc, setDoc] = useState<LegalDoc | null>(null);
  const [error, setError] = useState(false);

  useEffect(() => {
    setDoc(null);
    setError(false);
    fetch(`/legal/${slug}.json`)
      .then((r) => {
        if (!r.ok) throw new Error(`Failed to load ${slug}`);
        return r.json();
      })
      .then(setDoc)
      .catch(() => setError(true));
  }, [slug]);

  useEffect(() => {
    if (doc) document.title = doc.pageTitle;
    return () => {
      document.title = 'TRYP — Move smarter. Go anywhere.';
    };
  }, [doc]);

  const retry = () => {
    setError(false);
    setDoc(null);
    fetch(`/legal/${slug}.json`)
      .then((r) => {
        if (!r.ok) throw new Error(`Failed to load ${slug}`);
        return r.json();
      })
      .then(setDoc)
      .catch(() => setError(true));
  };

  if (error) {
    return (
      <div className="container" style={{ padding: '220px 0 120px' }}>
        <h1 style={{ color: '#fff' }}>This document is unavailable</h1>
        <p style={{ marginTop: 16 }}>Please try again later or contact TRYP support if you need a copy.</p>
        <button className="btn btn-primary" type="button" onClick={retry} style={{ marginTop: 28 }}>
          Try again
        </button>
      </div>
    );
  }

  if (!doc) {
    return (
      <div className="container" style={{ padding: '220px 0 120px', color: 'var(--text-faint)' }}>
        Loading...
      </div>
    );
  }

  const toc = doc.toc.map((item) => ({
    ...item,
    href: item.href.replace('#driver-term-', '#dterm-'),
  }));

  return (
    <>
      <PageHero
        eyebrow={doc.eyebrow}
        title={<span dangerouslySetInnerHTML={{ __html: doc.heroTitle }} />}
        description={doc.heroDescription}
      />
      <ContentLayout toc={toc}>
        <div className="legal-body">
          <div id="overview" className="legal-overview-anchor" aria-hidden="true" />
          <div dangerouslySetInnerHTML={{ __html: doc.html }} />
        </div>
      </ContentLayout>
    </>
  );
}
