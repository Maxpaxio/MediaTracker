# tv_trackerios

An application in which you can track TV Shows in.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
hhhhhhhchnges

## Google Drive (iOS) setup

To enable Google Drive sync on iOS for App Store builds:

- In Google Cloud Console:
	- Enable the Drive API.
	- Create an OAuth client for iOS with your app's bundle ID.
	- Note the Client ID.
- Redirect scheme:
	- Pick a URL scheme like `com.your.bundle.id:/oauthredirect` and add it to Info.plist (CFBundleURLTypes).
- Update the app:
	- In `lib/pages/sync_connect_page.dart`, replace the `redirect` Uri placeholder with your scheme.
	- Ensure `flutter_appauth` is present in pubspec (already added).
- CocoaPods:
	- From `ios/`, run `pod install` after changing Info.plist.

The app will then use PKCE on iOS and store a refresh token for silent renewal.