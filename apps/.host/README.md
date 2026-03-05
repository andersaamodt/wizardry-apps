# Wizardry Native Hosts

Native host implementations for desktop and mobile packaging.

- `macos/` Objective-C Cocoa + WebKit host
- `linux/` C GTK + WebKit host
- `ios/` Swift WKWebView host project template
- `android/` Kotlin WebView Gradle project
- `shared/` JS bridge loaded by app UIs

Shared JS API:

- `window.wizardry.rpc(method, params)`
- `window.wizardry.subscribe(event, fn)`
- `window.wizardry.unsubscribe(token)`

Bridge compatibility API:

- `window.wizardry.exec(argv)` maps to `bridge.exec` for desktop compatibility.
