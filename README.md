# SehatRoute AI — Complete Flutter UI

Complete responsive Flutter conversion of the supplied SehatRoute AI web UI. It includes every source route, all original demo content, responsive desktop/mobile navigation, shared interactive state, dialogs, filters, tabs, progress transitions, page fade/slide motion and processing animations.

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=https://api.example.com/api
```

The Flutter Web bootstrap is included. For Android, iOS, macOS, Windows or Linux, run `flutter create .` once to generate the requested native platform folders; the command keeps the existing `lib` source.

Recommended toolchain: Flutter 3.38 or newer and Dart 3.10 or newer.

## Real login and registration

The project now contains a production-oriented Node.js + MySQL authentication API in `backend/`. Flutter calls that HTTPS API; it never connects to MySQL directly. Registration, login, hashed passwords, JWT sessions, secure on-device token storage, profile display and logout are wired into the existing UI.

Follow `HOSTINGER_AUTH_SETUP.md` to deploy the API and connect the Flutter build.

## Verification

```bash
flutter analyze
flutter test
```

See `ROUTE_PARITY.md` for the full source-to-Flutter page map and preserved interaction list.

This build uses fictional demo content only. It does not diagnose, prescribe, or modify treatment.
