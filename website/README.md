# TRYP official public website

This folder contains the public-facing TRYP information website. It is intentionally a **plain static multi-page site**, not another Flutter app, admin console, Vite project, or client-side router.

## Structure

- `/index.html` — public homepage
- `/ride/` — passenger information
- `/drive/` — driver information
- `/safety/` — safety and trust guidance
- `/support/` — FAQs and support contact
- `/about/` — TRYP story and approach
- `/privacy/` — privacy working draft for legal review
- `/terms/` — terms working draft for legal review
- `/styles.css` — shared design system and responsive layout
- `/assets/` — TRYP logos and image slots

The directory structure gives pages real clean URLs such as `https://tryp.co.za/privacy/` without JavaScript routing.

## Preview locally

From the project root, run a static server of your choice, for example:

```bash
cd website
python3 -m http.server 8080
```

Then open `http://localhost:8080/`.

## Deploy

The included `vercel.json` uses folder-style trailing slashes. It is ready for deployment as a static directory on Vercel or another static host. Keep the canonical URL format consistent with `/privacy/`, `/terms/`, and the other trailing-slash pages.

## Images to add later

The current homepage uses a CSS illustration as a temporary product placeholder. When the final images are supplied:

1. Put approved files in `website/assets/`.
2. Prefer descriptive names such as `passenger-app-home.png`, `driver-app-requests.png`, or `tzaneen-road.jpg`.
3. Add explicit `width`, `height`, and meaningful `alt` text.
4. Replace the temporary visual only after the supplied asset has been reviewed at desktop and mobile sizes.

## Launch checklist

- Confirm the public domain and canonical URLs.
- Replace placeholder store links with the official Google Play / App Store links.
- Confirm the public service area and launch wording.
- Replace `hello@tryp.co.za` with the approved support address if different.
- Have `/privacy/` and `/terms/` reviewed and approved for the launch jurisdiction.
- Add final photography, app screenshots, and social preview metadata.
- Add analytics only after the privacy approach is confirmed.
