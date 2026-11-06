# TidyMac update feed

`latest.json` is fetched by the in-app updater. The ZIP is the actual update.

Default feed URL:

```text
https://raw.githubusercontent.com/welefen/TidyMac/main/updates/latest.json
```

## Release a new version

1. Bump `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Run `./scripts/publish_update.sh --push`.
3. The script builds the app, writes `updates/latest.json`, copies the ZIP, commits and pushes.

The GitHub repository must be **public** for unauthenticated in-app downloads. If raw.githubusercontent.com is blocked, point `TIDYMAC_UPDATE_FEED` at a CDN mirror such as jsDelivr.
For a private repository, set `TIDYMAC_UPDATE_FEED` to a public mirror that serves the
same JSON, or add an authenticated proxy. Never embed a GitHub token in the app.
The app verifies the ZIP SHA-256 and the bundle identifier/version before installing.
