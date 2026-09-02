import { Link } from 'react-router-dom';

export function Footer() {
  return (
    <footer className="footer">
      <div className="container footer-grid">
        <div>
          <Link to="/" className="footer-brand">
            <img src="/assets/tryp-icon.png" alt="" />
            TRYP
          </Link>
          <p className="tag">Move smarter. Go anywhere.</p>
          <span className="footer-location">
            <span className="status-dot" /> Built for Limpopo, South Africa
          </span>
        </div>
        <div className="footer-col">
          <strong>Explore</strong>
          <Link to="/ride">Ride</Link>
          <Link to="/drive">Drive</Link>
          <Link to="/business">Business</Link>
        </div>
        <div className="footer-col">
          <strong>Company</strong>
          <Link to="/about">About Us</Link>
          <Link to="/safety">Safety</Link>
          <Link to="/support">Help</Link>
        </div>
        <div className="footer-col">
          <strong>Legal</strong>
          <Link to="/privacy">Privacy</Link>
          <Link to="/terms">Passenger Terms</Link>
          <Link to="/driver-terms">Driver Terms</Link>
          <Link to="/driver-code">Driver Code</Link>
          <Link to="/safety-policy">Safety Policy</Link>
          <Link to="/driver-agreement">Driver Agreement</Link>
          <a href="mailto:hello@tryp.co.za">Contact</a>
        </div>
      </div>
      <div className="container footer-bottom">
        <span>© 2026 TRYP. All rights reserved.</span>
        <span>
          South Africa · <a href="#top">Back to top ↑</a>
        </span>
      </div>
    </footer>
  );
}
