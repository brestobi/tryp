import { Link } from 'react-router-dom';

export default function NotFound() {
  return (
    <section className="page-hero">
      <div className="container">
        <span className="eyebrow">Page not found</span>
        <h1>Let’s get you<br /><em>moving again.</em></h1>
        <p>The page you requested does not exist or may have moved.</p>
        <Link className="btn btn-primary" to="/" style={{ marginTop: 28 }}>
          Back to TRYP
        </Link>
      </div>
    </section>
  );
}
