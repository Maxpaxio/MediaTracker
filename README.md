# MediaTracker

Track your movies and TV shows, and instantly see where they’re streaming.

Live app: https://maxpaxio.github.io/MediaTracker

Made 100% by AI with GitHub Copilot and ChatGPT.

## Features

- Track across categories: `Watchlist`, `Ongoing`, `Completed`, and `Abandoned`.
- Region-aware streaming availability (Netflix, Disney+, Prime Video, etc.).
- Provider Filter Bar at the top of grid pages to quickly filter by streaming service.
- Automatic fetching of missing provider info (region-aware) with in-memory caching and minimal UI jank.
- Quick sorting and dynamic counts in titles; responsive grids.
- Deep links and explicit routes for details (e.g., `/tv/<id>`, `/movie/<id>`).
- Sync to the cloud via Google Drive or WebDAV.
- Robust sync UX: global sync button available on all pages, rotates while syncing, re-entrant queue with coalescing (changes during a sync trigger follow-up syncs).

## Metadata & Providers

- Metadata and watch-provider information are powered by The Movie Database (TMDB).
- Region handling is automatic (best-effort detection) and can be overridden in settings.

Important: This product uses the TMDB API but is not endorsed or certified by TMDB.

Logos and trademarks (e.g., TMDB, Netflix, Disney+) are the property of their respective owners and used for identification purposes only.

## Getting Started (Local Development)

Requirements:
- Flutter SDK installed (Windows)
- Chrome for running the web app locally

Install dependencies and analyze:

```powershell
C:\flutter\bin\flutter.bat pub get
C:\flutter\bin\flutter.bat analyze lib
```

Run the web app in Chrome:

```powershell
C:\flutter\bin\flutter.bat run -d chrome
```

Build for the web (release):

```powershell
C:\flutter\bin\flutter.bat build web
```

VS Code tasks are included for convenience (e.g., `Run app in Chrome (web)`, `flutter analyze lib`, `flutter build web`).

## Using the Hosted App

Open: https://maxpaxio.github.io/MediaTracker

- Add shows and movies to your `Watchlist` or start tracking progress.
- Use the Provider Filter Bar on grid pages to show items available on selected services.
- Click the sync button in the top app bar to synchronize.

## Sync Setup

MediaTracker supports syncing via Google Drive and WebDAV.

### Google Drive

1. Open Settings → Sync.
2. Select `Google Drive` and follow the sign-in/consent flow.
3. After connecting, press the sync button. Your data will be saved to your Drive.

### WebDAV

1. Open Settings → Sync.
2. Select `WebDAV` and enter your server URL, username, and password/app token.
3. Press the sync button to upload/download your data.

Notes:
- Your library is stored locally in the browser (for the web build) and optionally synced to your cloud provider.
- If you change items while a sync is running, a follow-up sync will automatically trigger to keep everything consistent.

## Privacy

- Your data lives locally and only syncs to the provider you choose (Google Drive or WebDAV) when enabled.
- No analytics or tracking are built into the app.

## Acknowledgements

- Flutter and the open-source community.
- The Movie Database (TMDB) for metadata and watch-provider data.
- Logos are property of their respective owners (e.g., Netflix, Disney+, TMDB) and used here for identification.

## Built with AI

This project was created end-to-end with AI assistance (GitHub Copilot and ChatGPT), including architecture, code, and UX.

---

If you run into issues or have ideas, feel free to open an issue or PR.

