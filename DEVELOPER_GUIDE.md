# 🚀 TRYP Developer Quick Start Guide

## Project Overview

**TRYP** is a Flutter-based ride-sharing application for Android and iOS with role-based access (Passenger & Driver).

## System Requirements

- **Flutter:** 3.10.4 or higher
- **Dart:** 3.10.4 or higher
- **Android:** SDK 21+ (Android 5.0)
- **iOS:** 12.0+
- **IDE:** VS Code or Android Studio
- **Git:** Version control

## Initial Setup

### 1. Clone & Install

```bash
# Navigate to project
cd /home/ubuntu/APPS/tryp

# Install dependencies
flutter pub get

# Get code generation (if using Riverpod code gen)
dart run build_runner build
```

### 2. Environment Configuration

Create `.env` file in project root:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
MAPBOX_ACCESS_TOKEN=your-public-mapbox-token
# Optional client-safe Paystack public key for legacy checkout flows.
# Never place PAYSTACK_SECRET_KEY here.
PAYSTACK_PUBLIC_KEY=pk_live_your-live-public-key
IS_PRODUCTION=false
IS_STAGING=false

# Optional Firebase Web push configuration. Required for browser push.
# Get these values from Firebase Console > Project settings > Your web app.
FIREBASE_WEB_API_KEY=your-firebase-web-api-key
FIREBASE_WEB_AUTH_DOMAIN=your-project.firebaseapp.com
FIREBASE_WEB_PROJECT_ID=your-project-id
FIREBASE_WEB_STORAGE_BUCKET=your-project.firebasestorage.app
FIREBASE_WEB_MESSAGING_SENDER_ID=your-messaging-sender-id
FIREBASE_WEB_APP_ID=your-firebase-web-app-id
FIREBASE_WEB_MEASUREMENT_ID=G-your-measurement-id
FIREBASE_WEB_VAPID_KEY=your-web-push-vapid-public-key

# Paystack live Edge Function setup is documented in PAYSTACK_LIVE_SETUP.md.
```

### 3. Run the App

```bash
# Development
flutter run

# With environment variables
flutter run --dart-define-from-file=.env

# Specific device
flutter run -d <device-id>
```

## Production Passenger Web Deployment

The passenger web app uses GitHub Actions to test and build Flutter Web, then
uploads the prebuilt `build/web` artifact to Vercel. The deployment workflow is:

```text
Push to main → flutter test → flutter analyze → flutter build web → Vercel
```

Required GitHub Actions secrets:

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

`SUPABASE_ANON_KEY`, Mapbox, and Firebase Web values are client-side values;
never add a Supabase service-role key or Firebase server credential to these
secrets or to the Flutter web build. Configure the production custom domain in
Vercel, then add that domain to Supabase redirect URLs and Firebase authorized
domains. Mapbox URL restrictions should include both production and staging
domains.

The Vercel project reads `vercel.json` for Flutter SPA fallback and cache
headers. `index.html`, `flutter_bootstrap.js`, and the Firebase messaging
service worker are not cached, while Flutter assets are cached immutably.

## Project Structure

```
lib/
├── main.dart                    # Entry point
├── app/
│   ├── app.dart               # Root widget
│   ├── router.dart            # Navigation
│   └── theme.dart             # Design system
├── config/
│   └── environment.dart       # Environment config
├── core/
│   ├── constants/             # App constants
│   ├── errors/                # Exception classes
│   ├── extensions/            # Dart extensions
│   ├── services/              # Backend services
│   ├── utils/                 # Utilities
│   └── widgets/               # Reusable components
├── features/
│   ├── authentication/        # Auth feature
│   ├── passenger/             # Passenger features
│   ├── driver/                # Driver features
│   └── trips/                 # Trip features
└── shared/
    ├── models/                # Shared data models
    ├── providers/             # Shared Riverpod providers
    └── widgets/               # Shared UI components
```

## Key Files to Know

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point |
| `lib/app/theme.dart` | TRYP brand colors and typography |
| `lib/app/router.dart` | All navigation routes |
| `lib/core/constants/app_constants.dart` | App-wide constants and enums |
| `lib/core/services/supabase_service.dart` | Backend integration |
| `lib/core/extensions/common_extensions.dart` | String, DateTime, Number utilities |

## Common Tasks

### Adding a New Screen

1. Create file under `lib/features/[feature]/presentation/screens/`
2. Add route to `lib/app/router.dart`
3. Add navigation method if needed

### Adding a New Feature

1. Create folder under `lib/features/[feature_name]/`
2. Structure:
   ```
   lib/features/feature_name/
   ├── data/
   │   ├── datasources/
   │   ├── models/
   │   └── repositories/
   ├── domain/
   │   ├── entities/
   │   ├── repositories/
   │   └── usecases/
   └── presentation/
       ├── providers/
       ├── screens/
       └── widgets/
   ```

### Using Riverpod for State

```dart
// Create a provider
final counterProvider = StateProvider<int>((ref) => 0);

// Use in widget
Consumer(
  builder: (context, ref, child) {
    final count = ref.watch(counterProvider);
    return Text('Count: $count');
  },
)
```

### Making API Calls

```dart
final authService = ref.watch(authServiceProvider);
try {
  await authService.signInWithPhone('+1234567890');
} on AuthException catch (e) {
  print('Auth error: ${e.message}');
}
```

### Using Custom Widgets

```dart
// Buttons
PrimaryButton(
  label: 'Request Ride',
  onPressed: () {},
)

SecondaryButton(
  label: 'Cancel',
  onPressed: () {},
)

// Text Input
CustomTextField(
  label: 'Phone Number',
  hint: '+27 123 456 7890',
  keyboardType: TextInputType.phone,
)

// Loading
LoadingIndicator(message: 'Finding drivers...')

// Empty State
EmptyState(
  icon: Icons.history,
  title: 'No trips yet',
  subtitle: 'Your trip history will appear here',
)
```

## Development Workflow

### 1. Branch Strategy

```bash
# Create feature branch
git checkout -b feature/auth-login

# Create bugfix branch
git checkout -b bugfix/theme-colors

# Commit with meaningful messages
git commit -m "feat: add phone authentication"
```

### 2. Code Style

- Follow Dart conventions
- Format: `dart format lib/`
- Lint: `flutter analyze`
- Use meaningful variable names

### 3. Testing

```bash
# Run tests
flutter test

# Test coverage
flutter test --coverage
```

### 4. Build

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# iOS
flutter build ipa --release
```

## Debugging

### Enable Debug Logging

```dart
import 'package:logger/logger.dart';

final logger = Logger();
logger.d('Debug message');
logger.e('Error message');
```

### Use DevTools

```bash
flutter pub global activate devtools
devtools
```

Then visit `http://localhost:9101` in browser.

## Common Issues

### Issue: "Supabase not initialized"
**Solution:** Ensure `Supabase.initialize()` is called in `main()` before `runApp()`

### Issue: "Mapbox doesn't show"
**Solution:** Run with `--dart-define=MAPBOX_ACCESS_TOKEN=your-public-token` or add `MAPBOX_ACCESS_TOKEN` to the local `.env` file. Mapbox also requires iOS 14+ and Android API 21+.

### Issue: "Location permission denied"
**Solution:** Check `AndroidManifest.xml` and `Info.plist` for required permissions

## Database Access

Supabase Dashboard: `https://app.supabase.com`

### Create Tables

Use Supabase SQL Editor:

```sql
CREATE TABLE profiles (
  id UUID PRIMARY KEY,
  full_name TEXT,
  role TEXT CHECK (role IN ('passenger', 'driver')),
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Row Level Security

```sql
-- Passengers can only see own data
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON profiles
  FOR SELECT
  USING (auth.uid() = id);
```

## Useful Commands

```bash
# Clean build
flutter clean

# Upgrade dependencies
flutter pub upgrade

# Get specific package
flutter pub add package_name

# Format code
dart format lib/ -l 120

# Analyze
flutter analyze

# Generate code
dart run build_runner build

# Check outdated packages
flutter pub outdated
```

## Resources

- **Flutter Docs:** https://flutter.dev/docs
- **Dart Language:** https://dart.dev
- **Supabase Docs:** https://supabase.com/docs
- **GoRouter:** https://pub.dev/packages/go_router
- **Riverpod:** https://riverpod.dev

## Support

- **Issues:** Create GitHub issue with details
- **Questions:** Ask in team chat
- **Documentation:** Check IMPLEMENTATION_PLAN.md and PHASE_*.md files

## Current Phase

**Phase:** 0 - Foundation Setup ✅ COMPLETE

**Next:** Phase 1 - Authentication (Week 3-4)

---

**Last Updated:** July 24, 2026
