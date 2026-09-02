# TRYP Website v2 — Redesign

A ground-up visual redesign of the TRYP public site: dark, cinematic, photography-led
hero in the spirit of the reference mockup, with GSAP + Framer Motion scroll animations
throughout. All existing marketing and legal copy was ported over as-is (no content was
invented) — see "What was ported" below.

## Stack

- React 18 + TypeScript + Vite
- react-router-dom (client-side routing, clean URLs like /ride, /privacy)
- Framer Motion — scroll-triggered reveals (`whileInView`), staggered grids, mobile menu
- GSAP + ScrollTrigger — hero parallax on scroll
- lucide-react — icons

## Run it

```bash
npm install
npm run dev       # http://localhost:5173
npm run build     # production build -> dist/
npm run preview   # serve the production build locally
```

## Structure

- `src/pages/Home.tsx` — full redesigned homepage (hero, trust strip, quick actions,
  feature grid, phone mockup section, long-distance route panel, ride options, download CTA)
- `src/pages/{Ride,Drive,Business,About,Safety,Support}.tsx` — inner marketing pages,
  same copy as the current site, rebuilt with the new PageHero/ContentLayout/FeatureGrid system
- `src/pages/LegalPage.tsx` — one generic renderer for all 6 legal/policy docs
- `src/legal-content/*.json` (mirrored in `public/legal/`) — the ported legal text,
  programmatically extracted from the existing Astro pages so nothing was retyped or
  paraphrased. Some decorative one-off elements (severity-grid explainer on the Driver
  Code page, the driver acceptance signature block, a couple of "regulatory reference"
  callout links) were dropped in the port for simplicity — the underlying legal text is
  intact, but flag this before publishing if you want those back.
- `src/components/Nav.tsx` — sticky glass nav, shrinks on scroll, full-screen mobile menu
- `src/components/Reveal.tsx` — reusable scroll-reveal wrappers (`Reveal`, `RevealGroup`/`RevealItem`)
- `src/styles/global.css` — the whole design system (CSS variables, dark palette, all component styles)

## Assets you should supply for a real launch

The current build reuses what's in the repo (`assets/city.png`, the red pin logo, app icon)
with a dark overlay treatment on the hero. For a result that matches the reference mockup's
polish, you'll want:

1. **Real (or higher-quality AI) hero photography** — a car on the road at golden hour,
   shot low and wide, with room on the left for the headline. This is the single biggest
   lever on how premium the homepage feels.
2. **Actual passenger/driver app screenshots** — the current phone mockup is a CSS
   illustration standing in for real UI.
3. Optional: driver/community photos for `/about` and `/drive`, and a social preview
   image (og:image) once photography is finalized.

Drop new files into `public/assets/` and swap the `src` in `Home.tsx` / the phone-mock markup.
