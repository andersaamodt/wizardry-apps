# Wizardry Native Hosts

Native host implementations for desktop and mobile packaging.

- `macos/` Objective-C Cocoa + WebKit host
- `linux/` C GTK + WebKit host
- `ios/` Swift WKWebView host project template
- `android/` Kotlin WebView Gradle project
- `shared/` JS bridge loaded by app UIs

Shared JS API:

- `window.wizardry.exec(argv)` (canonical desktop command bridge)
