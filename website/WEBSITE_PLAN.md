# TRYP official website plan

## Product role

The public website is TRYP's official information, trust, and conversion layer. It is not a web version of the passenger app, driver app, or admin console.

The website should answer four questions quickly:

1. What is TRYP?
2. Can I use it as a passenger?
3. Can I drive with it?
4. Where do I find support, privacy, and terms information?

## Architecture decision

Use plain static HTML and shared CSS in `website/`:

- no Vite
- no React runtime
- no client-side routing
- no web ride booking
- no web driver KYC
- real directory URLs such as `/privacy/` and `/terms/`

This keeps the public site fast, crawlable, easy to deploy, and easy to maintain while the product is in rollout.

## Page map

- `/` — homepage and brand gateway
- `/ride/` — passenger experience, scheduling, trip information, and app CTA
- `/drive/` — driver opportunity, onboarding expectations, and driver app CTA
- `/safety/` — trust, safety, and emergency guidance
- `/support/` — passenger/driver FAQs and contact entry points
- `/about/` — TRYP story, local approach, and rollout context
- `/privacy/` — privacy policy working draft pending legal approval
- `/terms/` — terms of service working draft pending legal approval

## Visual direction

The visual system is based on the TRYP mobile apps and the provided mock direction:

- warm white/gray editorial canvas
- near-black utility typography
- cobalt blue for action, live state, and emphasis
- Space Grotesk display headings and DM Sans body copy
- broad spacing, quiet borders, rounded utility cards
- CSS visual placeholder now; supplied photography and app screenshots later

## Phase 1: current public shell

- responsive static homepage
- real multi-page URLs
- passenger and driver information pages
- safety and support pages
- About page
- privacy and terms working drafts with visible review status
- canonical links, robots file, sitemap, and static hosting config

## Phase 2: launch readiness

- replace all placeholder app/store URLs
- confirm public domain and support email
- add final screenshots and approved local photography
- finish legal review for privacy and terms
- add social preview image and final metadata
- confirm service area, launch date, fares, cancellations, and driver requirements

## Phase 3: growth

- local business and fleet partnership page
- referral landing pages
- campaign-specific driver acquisition pages
- help center expansion
- analytics after privacy consent/notice decisions are finalized

## Content decisions still needed

- official domain
- registered entity name
- public support and privacy email
- launch locations and wording
- app store listing URLs
- driver requirements and approved earnings language
- final privacy policy and terms of service
- photography, app screenshots, and social preview artwork
