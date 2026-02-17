# iOS Host (WKWebView)

Native iOS WKWebView host for wizardry apps.

## Targets

- iOS 16+
- In-process JS bridge (`window.wizardry.rpc/subscribe/unsubscribe`)
- Embedded HTML/CSS/JS assets from `.apps/<slug>`

## Build

Use the release helper script:

```sh
# Unsigned simulator smoke build
sh tools/release/build-ios-app.sh artificer dist/ios smoke

# Signed App Store IPA build
sh tools/release/build-ios-app.sh artificer dist/ios release
```

The script generates an Xcode project via `xcodegen` from `.apps/.host/ios/project-template.yml`.
