import { useEffect } from 'react';
import { Routes, Route, useLocation } from 'react-router-dom';
import { Nav } from './components/Nav';
import { Footer } from './components/Footer';
import Home from './pages/Home';
import Ride from './pages/Ride';
import Drive from './pages/Drive';
import Business from './pages/Business';
import About from './pages/About';
import Safety from './pages/Safety';
import Support from './pages/Support';
import LegalPage from './pages/LegalPage';
import NotFound from './pages/NotFound';

function ScrollToTop() {
  const { pathname, hash } = useLocation();
  useEffect(() => {
    const scrollToTarget = () => {
      if (hash) {
        document.querySelector(hash)?.scrollIntoView();
      } else {
        window.scrollTo({ top: 0, behavior: 'auto' });
      }
    };

    const frame = window.requestAnimationFrame(scrollToTarget);
    return () => window.cancelAnimationFrame(frame);
  }, [pathname, hash]);
  return null;
}

export default function App() {
  return (
    <div id="top">
      <ScrollToTop />
      <Nav />
      <main>
        <Routes>
          <Route path="/" element={<Home />} />
          <Route path="/ride" element={<Ride />} />
          <Route path="/drive" element={<Drive />} />
          <Route path="/business" element={<Business />} />
          <Route path="/about" element={<About />} />
          <Route path="/safety" element={<Safety />} />
          <Route path="/support" element={<Support />} />
          <Route path="/privacy" element={<LegalPage slug="privacy" />} />
          <Route path="/terms" element={<LegalPage slug="terms" />} />
          <Route path="/driver-terms" element={<LegalPage slug="driver-terms" />} />
          <Route path="/driver-code" element={<LegalPage slug="driver-code" />} />
          <Route path="/driver-agreement" element={<LegalPage slug="driver-agreement" />} />
          <Route path="/safety-policy" element={<LegalPage slug="safety-policy" />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </main>
      <Footer />
    </div>
  );
}
