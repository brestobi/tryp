import { Link } from 'react-router-dom';
import { PageHero, ContentLayout, Faq } from '../components/Blocks';
import { Reveal } from '../components/Reveal';

const toc = [
  { href: '#passengers', label: 'Passengers' },
  { href: '#drivers', label: 'Drivers' },
  { href: '#contact', label: 'Contact us' },
];

export default function Support() {
  return (
    <>
      <PageHero eyebrow="We are here to help" title={<>Questions,<br /><em>answered.</em></>} description="Find a quick answer below or contact the TRYP team about a passenger, driver, account, or trip issue." />
      <ContentLayout toc={toc}>
        <h2 id="passengers">Passenger questions</h2>
        <Faq
          items={[
            { q: 'Can I schedule a ride?', a: 'Yes. The passenger app supports booking a pickup for a future date and time, in addition to requesting a ride now.' },
            { q: 'What if my pickup location is not precise?', a: 'Review the suggested location and refine the pickup details in the app. More advanced map pin features may be added as the product develops.' },
            { q: 'Where can I see my scheduled ride?', a: 'Scheduled and completed rides appear in the Activity area of the passenger app.' },
          ]}
        />
        <h2 id="drivers">Driver questions</h2>
        <Faq
          items={[
            { q: 'How do I join TRYP as a driver?', a: 'Use the driver app onboarding flow to register, add your vehicle and submit the required documents for review.' },
            { q: 'Where do I see ride requests?', a: 'Approved drivers can see available ride requests in the driver app, including relevant pickup and destination information.' },
          ]}
        />
        <h2 id="contact">Contact TRYP</h2>
        <div className="contact-grid">
          <Reveal className="contact-card">
            <h3>General support</h3>
            <p>For non-emergency passenger and driver questions.</p>
            <a href="mailto:hello@tryp.co.za">hello@tryp.co.za ↗</a>
          </Reveal>
          <Reveal delay={0.08} className="contact-card">
            <h3>Safety concern</h3>
            <p>If there is immediate danger, contact local emergency services first. For follow-up, contact TRYP support.</p>
            <Link to="/safety">Read safety guidance →</Link>
          </Reveal>
        </div>
        <div className="notice">Support contact details are temporary placeholders until the official TRYP support address and hours are confirmed.</div>
      </ContentLayout>
    </>
  );
}
