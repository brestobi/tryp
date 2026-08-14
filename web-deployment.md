# TRYP Passenger Web Deployment

This guide deploys the passenger Flutter Web app through GitHub Actions to Vercel, while using Supabase for the backend, Mapbox for maps, and Firebase Cloud Messaging for browser push notifications.

## 1. Push the deployment files to GitHub

From the project root:

```bash
git status
```

Make sure these files exist:

```text
vercel.json
.github/workflows/deploy-passenger-web.yml
```

Confirm your local `.env` is ignored:

```bash
git check-ignore .env
```

Stage only the deployment files and any passenger web code you intend to deploy:

```bash
git add vercel.json .github/workflows/deploy-passenger-web.yml
```

If you also want to include the documentation update:

```bash
git add DEVELOPER_GUIDE.md web-deployment.md
```

Commit and push:

```bash
git commit -m "ci: deploy passenger web to Vercel"
git push origin main
```

Do not run `git add .` if you have unrelated mobile or driver changes.

## 2. Create or link the Vercel project

Install the Vercel CLI:

```bash
npm install --global vercel
```

Log in:

```bash
vercel login
```

From the TRYP project root, link the project:

```bash
vercel link
```

When prompted:

1. Select your Vercel account or team.
2. Select **Create New Project** if the project does not exist.
3. Use a name such as:

```text
tryp-passenger-web
```

After linking, inspect the generated project file:

```bash
cat .vercel/project.json
```

It will look similar to:

```json
{
  "orgId": "team_xxxxxxxxx",
  "projectId": "prj_xxxxxxxxx"
}
```

Use the values as follows:

```text
orgId     → VERCEL_ORG_ID
projectId → VERCEL_PROJECT_ID
```

Do not commit the `.vercel` directory.

## 3. Create a Vercel access token

Open:

```text
https://vercel.com/account/tokens
```

Create a token and copy it immediately.

Use it as:

```text
VERCEL_TOKEN
```

Do not paste this token into the repository or into chat.

## 4. Get the Supabase values

Open your Supabase project dashboard and go to:

```text
Project Settings → Data API
```

Copy the following:

```text
Project URL          → SUPABASE_URL
Publishable/anon key → SUPABASE_ANON_KEY
```

Use the public anon/publishable key only.

Never use `SUPABASE_SERVICE_ROLE_KEY` in the Flutter Web app.

## 5. Get the Mapbox public token

Open:

```text
https://account.mapbox.com/access-tokens/
```

Copy or create a public token with the required Maps and Search permissions.

Use it as:

```text
MAPBOX_ACCESS_TOKEN
```

For production, restrict the token to your production domain after deployment. Example:

```text
https://app.yourdomain.co.za/*
```

## 6. Configure Firebase Web

Open Firebase Console and select the TRYP project.

Go to:

```text
Project settings → General → Your apps
```

If no Web app exists:

1. Click **Add app**.
2. Select the Web icon.
3. Register the app.
4. Copy the Firebase configuration.

Map the Firebase configuration as follows:

```text
apiKey             → FIREBASE_WEB_API_KEY
authDomain         → FIREBASE_WEB_AUTH_DOMAIN
projectId          → FIREBASE_WEB_PROJECT_ID
storageBucket      → FIREBASE_WEB_STORAGE_BUCKET
messagingSenderId  → FIREBASE_WEB_MESSAGING_SENDER_ID
appId              → FIREBASE_WEB_APP_ID
measurementId      → FIREBASE_WEB_MEASUREMENT_ID
```

The measurement ID is optional.

### Get the Web Push VAPID key

In Firebase Console, go to:

```text
Project settings → Cloud Messaging → Web configuration
```

Under **Web Push certificates**:

1. Click **Generate key pair** if one does not exist.
2. Copy the public key.

Use it as:

```text
FIREBASE_WEB_VAPID_KEY
```

## 7. Add GitHub Actions secrets

Open the GitHub repository and go to:

```text
Settings → Secrets and variables → Actions
```

Create a new repository secret for each of these:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
MAPBOX_ACCESS_TOKEN

FIREBASE_WEB_API_KEY
FIREBASE_WEB_AUTH_DOMAIN
FIREBASE_WEB_PROJECT_ID
FIREBASE_WEB_STORAGE_BUCKET
FIREBASE_WEB_MESSAGING_SENDER_ID
FIREBASE_WEB_APP_ID
FIREBASE_WEB_MEASUREMENT_ID
FIREBASE_WEB_VAPID_KEY

VERCEL_TOKEN
VERCEL_ORG_ID
VERCEL_PROJECT_ID
```

`FIREBASE_WEB_MEASUREMENT_ID` may be left empty if the Firebase Web app does not use Analytics.

## 8. Configure Supabase URLs

In Supabase, go to:

```text
Authentication → URL Configuration
```

Set the **Site URL** to your production URL, for example:

```text
https://app.yourdomain.co.za
```

Add this to **Redirect URLs**:

```text
https://app.yourdomain.co.za/**
```

If you will test using the Vercel URL, also add:

```text
https://tryp-passenger-web.vercel.app/**
```

Use your actual Vercel project URL.

## 9. Configure Firebase authorized domains

In Firebase Console, go to:

```text
Authentication → Settings → Authorized domains
```

Add:

```text
app.yourdomain.co.za
```

Also add the Vercel domain if you will test there:

```text
tryp-passenger-web.vercel.app
```

Do not include `https://` in the Firebase authorized-domain field.

## 10. Deploy the first version

Once all GitHub secrets are configured, trigger the workflow by pushing to `main`:

```bash
git commit --allow-empty -m "ci: trigger passenger web deployment"
git push origin main
```

Or run it manually:

```text
GitHub repository → Actions → Deploy passenger web → Run workflow
```

The workflow will:

1. Install Flutter `3.38.5`.
2. Run `flutter test`.
3. Run static analysis.
4. Build the production Flutter Web bundle.
5. Inject Firebase service-worker configuration.
6. Build the Vercel artifact.
7. Deploy to Vercel production.

Watch the result under:

```text
GitHub repository → Actions
```

## 11. Add your custom domain

In Vercel, go to:

```text
Project → Settings → Domains → Add
```

Enter your domain, for example:

```text
app.yourdomain.co.za
```

Vercel will show the exact DNS record to add at your domain provider.

After DNS propagates:

1. Open the custom domain.
2. Confirm the padlock/HTTPS is active.
3. Test login.
4. Test Mapbox.
5. Test passenger onboarding.
6. Test ride requests.
7. Test browser notification permission.
8. Test receiving a notification while the tab is closed.

The production deployment is ready once the GitHub workflow completes successfully and the custom domain passes those tests.
