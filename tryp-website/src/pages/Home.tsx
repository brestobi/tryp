import { useEffect, useRef } from 'react';
import { Link } from 'react-router-dom';
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { ShieldCheck, Clock, Wallet, ArrowUpRight, MapPin, Zap, Grid3x3 } from 'lucide-react';
import { Reveal, RevealGroup, RevealItem } from '../components/Reveal';
import { SectionHead, FeatureGrid, StoreButtons } from '../components/Blocks';

gsap.registerPlugin(ScrollTrigger);

export default function Home() {
  const heroImgRef = useRef<HTMLImageElement>(null);
  const heroSectionRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const ctx = gsap.context(() => {
      if (heroImgRef.current && heroSectionRef.current) {
        gsap.to(heroImgRef.current, {
          yPercent: 14,
          ease: 'none',
          scrollTrigger: {
            trigger: heroSectionRef.current,
            start: 'top top',
            end: 'bottom top',
            scrub: true,
          },
        });
      }

      gsap.utils.toArray<HTMLElement>('.stat-num').forEach((el) => {
        const target = Number(el.dataset.count ?? 0);
        const suffix = el.dataset.suffix ?? '';
        const obj = { val: 0 };
        gsap.to(obj, {
          val: target,
          duration: 1.6,
          ease: 'power2.out',
          scrollTrigger: { trigger: el, start: 'top 85%', once: true },
          onUpdate: () => (el.textContent = Math.round(obj.val) + suffix),
        });
      });
    });
    return () => ctx.revert();
  }, []);

  return (
    <>
      {/* HERO */}
      <section className="hero" ref={heroSectionRef}>
        <div className="hero-media">
          <img ref={heroImgRef} src="/assets/city.png" alt="A TRYP driver's car on the road" />
        </div>
        <div className="hero-scrim" />
        <div className="hero-glow" />
        <img className="hero-mark" src="/assets/tryp-icon.png" alt="" aria-hidden="true" />

        <div className="container hero-content">
          <div className="hero-eyebrow">
            <span className="dot" /> Local rides. Real connection.
          </div>
          <h1>
            Your city.
            <br />
            <em>Your journey.</em>
          </h1>
          <p className="hero-lead">
            Safe, reliable rides for everyday movement — built around the people and places of Limpopo.
          </p>
          <div className="hero-actions">
            <a className="btn btn-primary" href="#download">
              Get the TRYP app <ArrowUpRight size={18} />
            </a>
            <Link className="btn btn-ghost" to="/drive">
              Drive with TRYP →
            </Link>
          </div>
          <p className="hero-note">
            <span className="status-dot" /> Rolling out across Limpopo, South Africa
          </p>
        </div>

        <div className="trust-strip">
          <div className="container trust-grid">
            <div className="trust-item">
              <span className="trust-icon">
                <ShieldCheck size={20} />
              </span>
              <div>
                <h4>Safe rides</h4>
                <p>Your safety is our priority at every step.</p>
              </div>
            </div>
            <div className="trust-item">
              <span className="trust-icon">
                <Clock size={20} />
              </span>
              <div>
                <h4>On time</h4>
                <p>Reliable rides, right when you need them.</p>
              </div>
            </div>
            <div className="trust-item">
              <span className="trust-icon">
                <Wallet size={20} />
              </span>
              <div>
                <h4>Affordable</h4>
                <p>Great rides at prices that make sense.</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* QUICK ACTIONS */}
      <div className="container">
        <RevealGroup className="quick-grid">
          <RevealItem>
            <Link className="quick-card" to="/ride">
              <span className="quick-icon">
                <MapPin size={20} />
              </span>
              <div>
                <h4>Need a ride?</h4>
                <p>Get there with confidence</p>
              </div>
              <span className="arrow">→</span>
            </Link>
          </RevealItem>
          <RevealItem>
            <Link className="quick-card" to="/drive">
              <span className="quick-icon">
                <Zap size={20} />
              </span>
              <div>
                <h4>Want to drive?</h4>
                <p>Your car. Your opportunity.</p>
              </div>
              <span className="arrow">→</span>
            </Link>
          </RevealItem>
          <RevealItem>
            <Link className="quick-card" to="/business">
              <span className="quick-icon">
                <Grid3x3 size={20} />
              </span>
              <div>
                <h4>Moving a team?</h4>
                <p>Explore TRYP Business</p>
              </div>
              <span className="arrow">→</span>
            </Link>
          </RevealItem>
          <RevealItem>
            <Link className="quick-card" to="/safety">
              <span className="quick-icon">
                <ShieldCheck size={20} />
              </span>
              <div>
                <h4>Travel safely</h4>
                <p>Know what to expect</p>
              </div>
              <span className="arrow">→</span>
            </Link>
          </RevealItem>
        </RevealGroup>
      </div>

      {/* THE TRYP DIFFERENCE */}
      <section className="section">
        <div className="container">
          <SectionHead
            eyebrow="The TRYP difference"
            title={
              <>
                Less friction.
                <br />
                <span className="soft">More moving.</span>
              </>
            }
            description="Whether you are crossing town, heading home, or building your next opportunity, TRYP keeps the journey clear."
          />
          <FeatureGrid
            items={[
              { icon: '01', title: 'Door-to-door, made simple', text: 'Set your pickup, choose your destination, and see the journey clearly from start to finish.', tone: 'red' },
              { icon: '02', title: 'When you need it', text: 'Request a ride now or schedule ahead when the day needs a little more planning.', tone: 'blue' },
              { icon: '03', title: 'A ride you can trust', text: 'Stay informed with driver details, trip status, and support when you need it.', tone: 'gold' },
            ]}
          />
        </div>
      </section>

      {/* TECHNOLOGY THAT FEELS HUMAN */}
      <section className="section" style={{ background: 'var(--bg-elevated)', borderTop: '1px solid var(--line)', borderBottom: '1px solid var(--line)' }}>
        <div className="container split">
          <Reveal>
            <span className="eyebrow">For passengers and drivers</span>
            <h2 style={{ fontSize: 'clamp(2rem, 4vw, 3rem)', color: '#fff', marginTop: 16 }}>
              Technology that feels
              <br />
              <em style={{ fontStyle: 'normal', color: 'var(--red-bright)' }}>human.</em>
            </h2>
            <p style={{ marginTop: 20, fontSize: '1.05rem' }}>
              TRYP is being built close to the communities it serves. Practical features, straightforward support, and a
              service that respects your time.
            </p>
            <ul className="check-list">
              <li>
                <span className="tick">✓</span> Request now or schedule ahead
              </li>
              <li>
                <span className="tick">✓</span> Follow your trip in real time
              </li>
              <li>
                <span className="tick">✓</span> See clear driver and ride details
              </li>
              <li>
                <span className="tick">✓</span> Choose when you go online as a driver
              </li>
            </ul>
            <Link className="btn btn-primary" to="/about" style={{ marginTop: 32 }}>
              Why TRYP exists →
            </Link>
          </Reveal>
          <Reveal delay={0.15}>
            <div className="phone-mock">
              <div className="screen">
                <span className="greet">Good morning, Bresley</span>
                <span className="search">⌕ Where to?</span>
                <div className="map-fill" />
                <span className="cta">Confirm ride</span>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* LONG DISTANCE */}
      <section className="section">
        <div className="container">
          <SectionHead
            eyebrow="Long-distance rides"
            title={
              <>
                Go further with
                <br />
                <span className="soft">TRYP.</span>
              </>
            }
            description="Find available seats on intercity routes and make the longer journey easier to plan."
          />
          <Reveal delay={0.1} className="route-panel" as="div">
            <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: 0, alignItems: 'stretch' }}>
              <div className="route-map">
                <span className="route-path" />
                <span className="route-pin start"><span>T</span></span>
                <span className="route-pin finish"><span>T</span></span>
                <span className="route-label start">Tzaneen, Limpopo</span>
                <span className="route-label finish">The Oaks</span>
              </div>
              <div style={{ padding: '40px 36px', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                <span className="eyebrow">Travel together</span>
                <h2 style={{ fontSize: '1.9rem', color: '#fff', marginTop: 12 }}>
                  More miles.
                  <br />
                  <em style={{ fontStyle: 'normal', color: 'var(--red-bright)' }}>More possibility.</em>
                </h2>
                <p style={{ marginTop: 14 }}>
                  Drivers can post intercity trips, and passengers can reserve a seat with secure card payment.
                </p>
                <div className="actions" style={{ display: 'flex', gap: 12, marginTop: 22, flexWrap: 'wrap' }}>
                  <Link className="btn btn-primary btn-sm" to="/ride">Explore rides →</Link>
                  <Link className="btn btn-outline btn-sm" to="/drive">Post a trip →</Link>
                </div>
              </div>
            </div>
          </Reveal>
        </div>
      </section>

      {/* RIDE OPTIONS + DOWNLOAD */}
      <section className="section" style={{ paddingTop: 0 }}>
        <div className="container">
          <SectionHead
            eyebrow="Choose your TRYP"
            title={
              <>
                A clear journey,
                <br />
                <span className="soft">all the way.</span>
              </>
            }
            description="Simple tools for everyday movement, whether you are taking a trip or making one possible."
          />
          <RevealGroup className="ride-options">
            <RevealItem className="ride-option">
              <h3>TRYP <span>GO</span></h3>
              <p>Affordable everyday rides around town.</p>
              <span className="price">Everyday<small>movement</small></span>
            </RevealItem>
            <RevealItem className="ride-option">
              <h3>TRYP <span>COMFORT</span></h3>
              <p>More comfort and space when you need it.</p>
              <span className="price">More<small>room</small></span>
            </RevealItem>
            <RevealItem className="ride-option">
              <h3>TRYP <span>LONG DISTANCE</span></h3>
              <p>Intercity seats for the road ahead.</p>
              <span className="price">Go<small>further</small></span>
            </RevealItem>
          </RevealGroup>

          <Reveal delay={0.1} id="download" className="download-banner">
            <div>
              <h3>Download the TRYP app</h3>
              <p>Your ride, your way. Store links will be added before public launch.</p>
            </div>
            <StoreButtons />
          </Reveal>
        </div>
      </section>
    </>
  );
}
