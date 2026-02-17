# Android Host (WebView)

Native Android WebView host for wizardry apps.

## Targets

- Android API 26+
- In-process JS bridge (`window.wizardry.rpc/subscribe/unsubscribe`)
- Embedded HTML/CSS/JS assets from `.apps/<slug>`

## Build

Use Gradle from repository root:

```sh
gradle -p .apps/.host/android :app:assembleDebug \
  -PwizardryApplicationId=com.wizardry.apps.artificer.android \
  -PwizardryAppName=Artificer
```

For release AABs:

```sh
gradle -p .apps/.host/android :app:bundleRelease \
  -PwizardryApplicationId=com.wizardry.apps.artificer.android \
  -PwizardryAppName=Artificer \
  -PandroidKeystorePath=/path/to/upload.jks \
  -PandroidKeystorePassword=... \
  -PandroidKeyAlias=... \
  -PandroidKeyPassword=...
```

## Assets

Stage app assets before build:

```sh
sh tools/release/stage-web-assets.sh artificer .apps/.host/android/app/src/main/assets
```
