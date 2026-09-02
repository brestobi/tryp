import { useEffect, useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Menu, X } from 'lucide-react';
import { AnimatePresence, motion } from 'framer-motion';

const links = [
  { href: '/ride', label: 'Ride' },
  { href: '/drive', label: 'Drive' },
  { href: '/business', label: 'Business' },
  { href: '/safety', label: 'Safety' },
  { href: '/about', label: 'About Us' },
  { href: '/support', label: 'Support' },
];

export function Nav() {
  const [scrolled, setScrolled] = useState(false);
  const [open, setOpen] = useState(false);
  const { pathname } = useLocation();

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 24);
    onScroll();
    window.addEventListener('scroll', onScroll, { passive: true });
    return () => window.removeEventListener('scroll', onScroll);
  }, []);

  useEffect(() => setOpen(false), [pathname]);

  return (
    <>
      <header className={`nav ${scrolled ? 'scrolled' : ''}`}>
        <div className="container nav-inner">
          <Link to="/" className="nav-brand">
            <img src="/assets/tryp-icon.png" alt="" />
            TRYP
          </Link>
          <nav className="nav-links">
            {links.map((l) => (
              <Link key={l.href} to={l.href} className={pathname === l.href ? 'active' : ''}>
                {l.label}
              </Link>
            ))}
          </nav>
          <div className="nav-right">
            <Link className="btn btn-ghost btn-sm" to="/#download">Download App</Link>
            <button className="nav-toggle" onClick={() => setOpen(true)} aria-label="Open navigation">
              <Menu size={24} />
            </button>
          </div>
        </div>
      </header>

      <AnimatePresence>
        {open && (
          <motion.div
            className="mobile-nav"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.25 }}
          >
            <button
              onClick={() => setOpen(false)}
              aria-label="Close navigation"
              style={{ position: 'absolute', top: 24, right: 24, background: 'none', border: 'none', color: '#fff', cursor: 'pointer' }}
            >
              <X size={28} />
            </button>
            {links.map((l) => (
              <Link key={l.href} to={l.href}>
                {l.label}
              </Link>
            ))}
            <Link className="btn btn-primary" to="/#download" onClick={() => setOpen(false)}>
              Download App
            </Link>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  );
}
