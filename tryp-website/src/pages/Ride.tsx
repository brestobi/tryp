import { PageHero, ContentLayout, FeatureGrid, StoreButtons } from '../components/Blocks';
import { Reveal } from '../components/Reveal';

const toc = [
  { href: '#how', label: 'How it works' },
  { href: '#schedule', label: 'Schedule ahead' },
  { href: '#details', label: 'Ride details' },
  { href: '#download', label: 'Get the app' },
];

export default function Ride() {
  return (
    <>
      <PageHero eyebrow="For passengers" title={<>Get there with<br /><em>confidence.</em></>} description="TRYP gives you a clearer way to move around town — with useful details before, during, and after your ride." />
      <ContentLayout toc={toc}>
        <h2 id="how">Your journey, made simpler</h2>
        <p className="lead">Set your pickup, choose your destination, and let TRYP connect you with a local driver. The app is designed to make the important information easy to find.</p>
        <FeatureGrid
          items={[
            { icon: '01', title: 'Set your route', text: 'Search for your pickup and destination, or refine the location when a landmark is not quite precise enough.', tone: 'red' },
            { icon: '02', title: 'Review your ride', text: 'Choose the available ride option and review the fare and trip details before requesting.', tone: 'blue' },
            { icon: '03', title: 'Follow the trip', text: 'See the ride status and driver details as your journey moves from request to arrival.', tone: 'gold' },
          ]}
        />
        <h2 id="schedule">Need it later?</h2>
        <p>When your day needs more planning, you can schedule a pickup for a future date and time from the passenger app. Your booking remains visible in Activity so you can keep track of it.</p>
        <Reveal className="notice">
          <strong>Scheduling is available in the current passenger app.</strong>
          We are continuing to improve pickup accuracy and local place search as TRYP grows.
        </Reveal>
        <h2 id="details">Information you can use</h2>
        <p>TRYP is built around practical clarity: pickup and destination details, ride type, driver information, trip status, and support access. If something does not look right, contact support before continuing.</p>
        <h2 id="download">Start with the passenger app</h2>
        <p>The official store link will be added here once the public listing is ready. Until then, this page explains the passenger experience and what TRYP is building.</p>
        <div style={{ marginTop: 28 }}>
          <StoreButtons />
        </div>
      </ContentLayout>
    </>
  );
}
