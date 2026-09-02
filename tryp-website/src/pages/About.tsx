import { Link } from 'react-router-dom';
import { PageHero, ContentLayout, FeatureGrid } from '../components/Blocks';
import { Reveal } from '../components/Reveal';

const toc = [
  { href: '#why', label: 'Why TRYP' },
  { href: '#approach', label: 'Our approach' },
  { href: '#where', label: 'Where we are going' },
];

export default function About() {
  return (
    <>
      <PageHero eyebrow="About TRYP" title={<>Built for the<br /><em>journey here.</em></>} description="TRYP is a local ride platform designed to make everyday movement simpler for passengers and create new opportunity for drivers." />
      <ContentLayout toc={toc}>
        <h2 id="why">Why we are building TRYP</h2>
        <p className="lead">Everyday transport should feel more understandable, more connected, and more relevant to the places people actually live.</p>
        <p>TRYP is starting in Limpopo, South Africa, with a focus on practical local rides. We are building for passengers who need a dependable way to get around and for drivers who want a flexible way to participate in their local economy.</p>
        <h2 id="approach">Our approach</h2>
        <FeatureGrid
          items={[
            { icon: '⌖', title: 'Local first', text: 'We pay attention to the roads, places, and everyday patterns of the communities we serve.', tone: 'red' },
            { icon: '♢', title: 'Clear by design', text: 'We prefer useful information and straightforward actions over unnecessary complexity.', tone: 'blue' },
            { icon: '◷', title: 'Growing carefully', text: 'We are adding capability as the service, support, and local operating model mature.', tone: 'gold' },
          ]}
        />
        <h2 id="where">Where we are going</h2>
        <p>TRYP is beginning with passenger and driver mobile apps, supported by a public website and an operations console. Over time, the service will expand its local coverage, improve pickup accuracy, and add the tools that make a real difference to the people using it.</p>
        <Reveal className="notice">
          <strong>TRYP is in active rollout.</strong>
          Some public information, store links, support details, and legal documents will be finalized before the official public launch.
        </Reveal>
        <div className="actions">
          <Link className="btn btn-primary" to="/ride">Ride with TRYP →</Link>
          <Link className="btn btn-outline" to="/drive">Drive with TRYP →</Link>
        </div>
      </ContentLayout>
    </>
  );
}
