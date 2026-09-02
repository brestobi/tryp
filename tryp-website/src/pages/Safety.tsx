import { Link } from 'react-router-dom';
import { PageHero, ContentLayout, FeatureGrid } from '../components/Blocks';
import { Reveal } from '../components/Reveal';

const toc = [
  { href: '#before', label: 'Before the trip' },
  { href: '#during', label: 'During the trip' },
  { href: '#support', label: 'Getting support' },
  { href: '#emergency', label: 'Emergencies' },
];

export default function Safety() {
  return (
    <>
      <PageHero eyebrow="Our promise" title={<>Move with<br /><em>peace of mind.</em></>} description="TRYP is designed to make trip information clear, keep people informed, and give passengers and drivers a straightforward path to support." />
      <ContentLayout toc={toc}>
        <h2 id="before">Before the trip</h2>
        <p className="lead">A safer journey begins with useful information. Review your pickup and destination carefully, confirm that the ride details match what you expect, and only continue when you are comfortable.</p>
        <FeatureGrid
          items={[
            { icon: '⌖', title: 'Clear pickup details', text: 'Use accurate locations and landmarks so the passenger and driver can find one another more easily.', tone: 'red' },
            { icon: '♢', title: 'Know who is arriving', text: 'Passenger and driver details are shown in the app as the ride progresses.', tone: 'blue' },
            { icon: '◷', title: 'See trip status', text: 'Follow the journey from request through completion instead of being left guessing.', tone: 'gold' },
          ]}
        />
        <h2 id="during">During the trip</h2>
        <p>Stay aware of your surroundings and use the in-app trip information as your source of truth. Passengers should check the vehicle and driver details before entering. Drivers should only begin a trip when the correct passenger is present.</p>
        <h2 id="support">When something does not feel right</h2>
        <p>End the interaction if you feel unsafe and contact local emergency services when there is immediate danger. For account, payment, or trip issues, contact the TRYP support team so the issue can be recorded and followed up.</p>
        <Reveal className="notice">
          <strong>TRYP is not an emergency response service.</strong>
          In an immediate emergency, contact the appropriate local emergency service first. Support channels are for non-emergency assistance and follow-up.
        </Reveal>
        <h2 id="emergency">Emergency guidance</h2>
        <p>If you are in immediate danger, move to a safe public place if possible and contact local emergency services. Do not use the public website as a substitute for emergency assistance.</p>
        <div className="actions">
          <Link className="btn btn-primary" to="/safety-policy">Read Safety Policy →</Link>
          <Link className="btn btn-outline" to="/support">Visit support ↗</Link>
          <Link className="btn btn-outline" to="/privacy">Read privacy →</Link>
        </div>
      </ContentLayout>
    </>
  );
}
