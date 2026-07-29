# TRYP Improvement Plan
_Covers the Flutter app (passenger + driver) and the React admin console_

This plan is based on a direct code/schema audit, not the existing PROGRESS.md (which understates what's built and doesn't reflect the issues found). Phases are ordered by risk, not by calendar time — do P0 before anything else ships or gets tested with real users.

---

## P0 — Blocking (do before any further work)

| # | Item | Where | Why it's P0 |
|---|------|-------|--------------|
| 1 | Fix broken `supabase_service.dart` — missing `supabase_flutter` import, orphaned top-level method using undefined `_logger` | `lib/core/services/supabase_service.dart` | App does not compile |
| 2 | Enable RLS on `profiles`, `rides`, `saved_places`, `fare_schemas`, `driver_documents` | Supabase | Every user's data (incl. bank details, ID numbers) is currently readable/writable by anyone with the anon key |
| 3 | Remove Paystack **secret key** from the Flutter client | `lib/core/services/payment_service.dart`, `environment.dart` | Secret key is extractable from any built APK/IPA |
| 4 | Add role check to admin app (`role IN ('admin','super_admin')`), not just "has a session" | `admin/src/App.tsx`, `AuthContext.tsx` | Any passenger/driver account can currently log into the admin console |
| 5 | Fix `admin_audit_logs` / `driver_payouts` RLS — currently `USING (true)` for any authenticated user | Supabase migrations | Same bug as #4, at the database layer |
| 6 | Make `driver-documents` storage bucket private, serve via signed URLs | Supabase storage config | ID docs / licenses currently public by URL |
| 7 | Stop hardcoding the Supabase anon key + a real person's email as migration content in git | `admin/src/lib/supabase.ts`, `grant_super_admin.sql` | Secrets/PII in version control |

**Target:** none of these should be outstanding before you invite a single external tester.

---

## P1 — Core correctness (app actually does what it appears to do)

### App
- [ ] Wire `PhoneVerificationScreenPage` to the real `AuthService.verifyOTP()` call (currently fakes success after 1s delay)
- [ ] Remove the mock-trip fallback in `TripService.requestRide()` — a failed insert should surface an error, not silently return a fake trip
- [ ] Remove/replace the hardcoded mock notification list in `notification_service.dart` with real Supabase-backed notifications
- [ ] Implement or remove the Facebook sign-in button (currently a dead TODO)
- [ ] Add a payment success **server-side verification** step (Paystack webhook → Supabase Edge Function → mark `payment_status = 'paid'`) instead of trusting the client callback
- [ ] Replace default fallback coordinates in `TripModel.fromJson` (Johannesburg lat/lng) with explicit null-handling — silent defaults mask bad data

### Admin
- [ ] Confirm every write-capable action (KYC approval, payout verification, fare schema edits) checks the caller's role server-side (RLS), not just hides the button client-side
- [ ] Add an audit-log entry for every admin mutation (approve driver, edit fares, verify payout) — table exists, make sure it's actually written to consistently

---

## P2 — Missing core features (nothing built yet)

This is the actual gap between "Phase 0 complete" and a working ride-hailing product:

1. **Ride dispatch/matching** — no logic anywhere finds nearby available drivers for a new ride request. Needs a Supabase Edge Function (or Postgres function via PostGIS) that:
   - Queries `profiles` where `is_online = true` and role = driver, ordered by distance to pickup
   - Handles the accept race condition (two drivers accepting simultaneously) — use `UPDATE ... WHERE status = 'requested'` with a returning check, not a plain update
2. **Driver location broadcasting** — `current_lat`/`current_lng` columns exist but no code path updates them or streams them to a passenger's active trip screen
3. **Surge pricing calculation** — `surge_multiplier` columns exist in `rides` and `fare_schemas`, no logic sets them
4. **Fare finalization** — no server-side recalculation of final fare from actual distance/time at trip completion (currently fare is fixed at request time)
5. **Cancellation flow + cancellation fees** — not present in trip status handling
6. **Rating & review submission** — no screen or table interaction found for post-trip ratings, despite `rating` column on `profiles`

---

## P3 — Quality, hardening, polish

- [ ] Add automated tests beyond the default `widget_test.dart` stub — at minimum: `FareCalculatorService`, `TripStatusX` mapping, RLS policy tests (pgTAP or similar)
- [ ] Add Sentry/Crashlytics or similar — right now errors are just `debugPrint`'d, which means production issues are invisible
- [ ] Environment config: fail loudly (not silently) if `SUPABASE_URL`/`SUPABASE_ANON_KEY` are still the placeholder defaults at app start in a release build
- [ ] Admin: replace the `role ?? 'admin'` fallback in `fetchProfile()` — if the profile fetch fails, defaulting to admin is a fail-open bug, should fail closed (no access)
- [ ] Reconcile PROGRESS.md with actual repo state so phase tracking is trustworthy going forward

---

## Suggested sequencing

```
Week 1:        P0 items 1–7 (compile fix + security lockdown)
Week 2–3:      P1 (correctness fixes — no more fake success states)
Week 4–7:      P2 item 1–2 (dispatch + driver location — this is the actual MVP milestone)
Week 8+:       P2 items 3–6, then P3
```

Everything through P1 can be done without new features — it's fixing what already exists to actually be true. P2 is where TRYP becomes a working ride-hailing app rather than a UI shell around Supabase tables.
