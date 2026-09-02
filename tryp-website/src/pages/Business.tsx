import { Link } from 'react-router-dom';
import { PageHero, ContentLayout, FeatureGrid } from '../components/Blocks';
import { Reveal } from '../components/Reveal';

const toc = [
  { href: '#opportunities', label: 'Opportunities' },
  { href: '#built', label: 'What we are building' },
  { href: '#contact', label: 'Talk to TRYP' },
];

export default function Business() {
  return (
    <>
      <PageHero eyebrow="For businesses" title={<>Move your team.<br /><em>Move business forward.</em></>} description="TRYP Business is being shaped for organisations that need dependable local transport, scheduled movement, and a trusted partner on the road." />
      <ContentLayout toc={toc}>
        <h2 id="opportunities">Practical transport for real work</h2>
        <p className="lead">From staff movement to business travel and partner fleets, TRYP is exploring tools that make organised transport easier to coordinate.</p>
        <FeatureGrid
          items={[
            { icon: '▦', title: 'Team movement', text: 'Help people get to work, meetings, and important places with clearer scheduled transport.', tone: 'red' },
            { icon: '◷', title: 'Planned journeys', text: 'Build transport around the working day instead of leaving every trip to chance.', tone: 'blue' },
            { icon: '♢', title: 'Local partnerships', text: 'Work with a growing mobility platform that understands the communities it serves.', tone: 'gold' },
          ]}
        />
        <h2 id="built">What we are building</h2>
        <p>TRYP Business will grow as our local operations, fleet partnerships, and support model mature. We are taking a careful approach so every new capability is useful, understandable, and supported properly.</p>
        <Reveal className="notice">
          <strong>Business partnerships are opening gradually.</strong>
          Tell us about your transport needs and the TRYP team can record your interest for the next rollout phase.
        </Reveal>
        <h2 id="contact">Talk to TRYP</h2>
        <p>For staff transport, fleet partnerships, or local business enquiries, contact the team directly.</p>
        <div className="actions">
          <a className="btn btn-primary" href="mailto:hello@tryp.co.za?subject=TRYP%20Business%20enquiry">Start a conversation ↗</a>
          <Link className="btn btn-outline" to="/about">About TRYP →</Link>
        </div>
      </ContentLayout>
    </>
  );
}
