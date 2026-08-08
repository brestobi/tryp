# Paystack live payments for TRYP

This integration uses a Paystack **live secret key** only inside Supabase Edge Functions. Never put the secret key in Flutter, the admin web app, `.env`, git, or chat.

## Paystack dashboard setup

1. In Paystack, switch to **Live** mode.
2. Copy the live **public key** (`pk_live_...`) and **secret key** (`sk_live_...`).
3. Create or confirm the Paystack subaccount that should receive the driver/settlement share. Copy its subaccount code (`ACCT_...`).
4. Set the webhook URL to:

   `https://lapkfscxtkvbuojysygk.supabase.co/functions/v1/paystack-webhook`

5. Configure the webhook for live events, including `charge.success`.
6. Confirm the live account supports the currency used by TRYP (`ZAR` in this codebase). Paystack account and subaccount settlement eligibility must match the selected currency/country.

## Supabase secrets

In Supabase Dashboard → **Edge Functions → Secrets**, add these values. This avoids shell-history and process-list exposure:

```text
PAYSTACK_SECRET_KEY=sk_live_REPLACE_WITH_YOUR_LIVE_SECRET
PAYSTACK_SUBACCOUNT_CODE=ACCT_REPLACE_WITH_YOUR_SUBACCOUNT
PAYSTACK_CURRENCY=ZAR
PAYSTACK_BEARER=account
```

If you prefer the CLI, use a protected CI secret store or an interactive shell and remove the command from history immediately afterward. Never paste the secret into this repository or chat.

Optional: `PAYSTACK_TRANSACTION_CHARGE` is a flat amount in the smallest currency unit. Leave it unset unless you intentionally want Paystack's `transaction_charge` behavior.

`PAYSTACK_PUBLIC_KEY` is not required by the new hosted-checkout path. If another client flow still needs it, it is safe to provide the live public key to Flutter, but it is not a secret:

```env
PAYSTACK_PUBLIC_KEY=pk_live_REPLACE_WITH_YOUR_LIVE_PUBLIC_KEY
```

Do not set `PAYSTACK_SECRET_KEY` in the Flutter `.env` file.

## Deploy database and functions

Apply the migration and deploy the functions:

```bash
supabase db push
supabase functions deploy paystack-initialize
supabase functions deploy paystack-verify
supabase functions deploy paystack-webhook --no-verify-jwt
supabase functions deploy paystack-admin-verify
```

The webhook function is also configured with `verify_jwt = false` in `supabase/config.toml`; it authenticates requests using Paystack's `x-paystack-signature` HMAC SHA-512 header. The initialize and verify functions require the logged-in passenger's Supabase JWT.

## Flutter build configuration

The passenger app now opens the server-created Paystack hosted checkout URL. Build normally with the Supabase URL and publishable/anon key already used by TRYP:

```bash
flutter pub get
flutter build apk --release \
  --dart-define=SUPABASE_URL='https://lapkfscxtkvbuojysygk.supabase.co' \
  --dart-define=SUPABASE_ANON_KEY='YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY'
```

## Payment flow

1. Passenger selects Paystack and requests a ride.
2. Supabase initializes the transaction using the server-side fare, live secret, and configured subaccount.
3. Flutter opens Paystack's hosted authorization URL.
4. Paystack sends `charge.success` to the webhook.
5. The webhook verifies the transaction against Paystack's API, including amount, currency, and subaccount, then marks the ride `paid`.
6. `paystack-verify` is called by the passenger app on resume to recover when a webhook is delayed or missed.
7. Admin transaction lookups use `paystack-admin-verify`; the admin UI no longer displays synthetic/random Paystack results.

The client callback/redirect is not trusted to mark payments as paid.

## Test safely before going live

- Use Paystack **test mode** keys first with a separate test subaccount and test webhook URL.
- Confirm the database payment reference is populated and unique.
- Confirm a successful transaction reaches `paid` only after webhook/API verification.
- Confirm an incorrect amount, currency, reference, or subaccount does not settle the ride.
- After live verification, rotate any test credentials and never reuse test subaccount codes in production.
