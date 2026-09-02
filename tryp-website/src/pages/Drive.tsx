import { Link } from 'react-router-dom';
import { PageHero, ContentLayout, FeatureGrid } from '../components/Blocks';
import { Reveal } from '../components/Reveal';

const toc = [
  { href: '#why', label: 'Why TRYP' },
  { href: '#process', label: 'How onboarding works' },
  { href: '#requirements', label: 'What to prepare' },
  { href: '#start', label: 'Get started' },
];

export default function Drive() {
  return (
    <>
      <PageHero eyebrow="For drivers" title={<>Your car.<br /><em>Your opportunity.</em></>} description="TRYP connects local drivers with passengers who need to get where they are going. Choose when you go online and make the journey work for you." />
      <ContentLayout toc={toc}>
        <h2 id="why">Built for local drivers</h2>
        <p className="lead">Driving with TRYP means joining a service that is growing around the places you already know. The driver app keeps ride information and your working status close at hand.</p>
        <FeatureGrid
          items={[
            { icon: '◷', title: 'Work on your terms', text: 'Choose when you are available and manage your online status from the driver app.', tone: 'green' },
            { icon: '⌖', title: 'Know the trip', text: 'See key ride details before accepting so you can make an informed decision.', tone: 'blue' },
            { icon: '♢', title: 'Grow locally', text: 'Help passengers move through your community while building your driver profile.', tone: 'gold' },
          ]}
        />
        <h2 id="process">A guided onboarding flow</h2>
        <p>The driver app guides you through account registration, profile details, vehicle information, and document submission. The TRYP team reviews the required information before a driver can take rides.</p>
        <FeatureGrid
          items={[
            { icon: '01', title: 'Create your profile', text: 'Register in the driver app with your personal and contact information.', tone: 'red' },
            { icon: '02', title: 'Submit documents', text: 'Provide the required driver and vehicle documents for review.', tone: 'blue' },
            { icon: '03', title: 'Go online', text: 'Once approved, use the driver app to manage your availability and rides.', tone: 'green' },
          ]}
        />
        <h2 id="requirements">What to prepare</h2>
        <p>Keep your valid driver, vehicle, and identity documents available. Final requirements may vary as TRYP completes its launch and compliance process, so the app will provide the most current checklist.</p>
        <Reveal className="notice">
          <strong>Driver onboarding is handled in the TRYP Driver app.</strong>
          This keeps identity and document information inside the protected onboarding flow rather than asking you to submit it on a public website.
        </Reveal>
        <h2 id="start">Interested in driving?</h2>
        <p>Download the driver app when the public store listing is available, or contact the TRYP team to ask about the rollout in your area.</p>
        <div className="actions">
          <a className="btn btn-primary" href="mailto:hello@tryp.co.za">Contact the TRYP team ↗</a>
          <Link className="btn btn-outline" to="/driver-terms">Read Driver Terms →</Link>
          <Link className="btn btn-outline" to="/driver-code">Read Driver Code →</Link>
          <Link className="btn btn-outline" to="/driver-agreement">Read Driver Agreement →</Link>
          <Link className="btn btn-outline" to="/support">Read support →</Link>
        </div>
      </ContentLayout>
    </>
  );
}
