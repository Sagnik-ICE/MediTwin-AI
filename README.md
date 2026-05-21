# MediTwin AI

MediTwin AI is a preventive healthcare mobile assistant that combines personal health tracking, multi-session AI chat, and administrative tools for health resources. Built with Flutter (Material 3), Firebase (Auth, Firestore, Crashlytics), and a lightweight local cache for offline-first support.

Key features

- User onboarding and structured health profile
- Daily health logs with computed health score and insights
- Multi-session AI chat (configurable AI endpoint)
- Doctor directory, emergency resources, and blood donor registry (admin CRUD)
- Admin provisioning via `app_admins` Firestore collection
- Firestore-first persistence with local fallback and migration support
- Crash reporting via Firebase Crashlytics
- GitHub Actions workflows for CI, demo builds and release artifacts

Repository layout

- `lib/` — Flutter source code (providers, screens, services, models)
- `test/` — unit and widget tests
- `tools/` — helper scripts (e.g., `seed_admin.js`)
- `.github/workflows/` — CI, release, demo-build, and seed-admin workflows
- `firestore.rules` — Firestore security rules

Quick start (development)

1. Prerequisites
   - Flutter SDK (matching project: see `.github/workflows/ci.yml`), Dart SDK
   - Node.js (>=18) and npm for helper scripts and Firebase CLI if needed
   - Firebase project and credentials for cloud features

2. Get the code

```bash
git clone https://github.com/Sagnik-ICE/MediTwin-AI.git
cd MediTwin-AI
```

3. Install dependencies

```bash
flutter pub get
```

4. Run analyzer and tests

```bash
flutter analyze
flutter test
```

5. Run on device/emulator

```bash
flutter run
```

Debug/demo build

```bash
flutter build apk --debug
# or
flutter build apk --release
```

Admin seeding (local)

Create a Firebase service account JSON in the Firebase Console and run:

```bash
node tools/seed_admin.js --serviceAccount ./serviceAccount.json --project YOUR_FIREBASE_PROJECT --email admin@example.com --uid YOUR_ADMIN_UID --displayName "Main Admin"
```

CI / demos

- Use the `Demo build - Debug APK` workflow in GitHub Actions to produce a debug APK artifact if you don't want to build locally.
- Use the `Release - Android` workflow to produce AAB/APK artifacts for distribution. To sign in CI add the following GitHub secrets:
  - `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`
  - `SERVICE_ACCOUNT_JSON` (base64), `ADMIN_EMAIL`/`ADMIN_UID`, `FIREBASE_PROJECT` for seeding.

Security notes

- Do not commit service-account JSON or keystore files. Store sensitive keys as GitHub secrets.
- Firestore rules are in `firestore.rules`. Test them locally with the Firebase Emulator before deploying.

Troubleshooting & tips

- If PowerShell blocks npm scripts, either run commands in `cmd.exe` or set a temporary execution policy with: `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`.
- To test Crashlytics, enable it in Firebase and generate a test non-fatal error in a release build.

Contributing

This repo is prepared for demonstration and further development. Open issues or PRs with focused changes; follow existing code style and run `flutter analyze` and `flutter test` before submitting.

Maintainer

- Asus — update contact information here if you want to publish.

License

Include a LICENSE file or add one if required for your project.
