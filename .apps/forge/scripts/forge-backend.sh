#!/bin/sh

# Wizardry Forge backend: shell-first control plane for wizardry-apps.

case "${1-}" in
--help|--usage|-h)
  cat <<'USAGE'
Usage: forge-backend.sh COMMAND [ARGS...]

Commands:
  doctor [ROOT_HINT]
  list-apps [ROOT_HINT]
  list-templates [ROOT_HINT]
  build-desktop [ROOT_HINT] APP_SLUG
  run-desktop [ROOT_HINT] APP_SLUG
  stage-mobile [ROOT_HINT] APP_SLUG
  build-ios-smoke [ROOT_HINT] APP_SLUG
  build-android-debug [ROOT_HINT] APP_SLUG
  scaffold-app [ROOT_HINT] APP_SLUG APP_NAME TEMPLATE [SOURCE_APP]
  scaffold-site [ROOT_HINT] SITE_NAME TEMPLATE [DEST_ROOT]
  run-task [ROOT_HINT] TASK

TASK values:
  validate-manifest | test-core | test-adapters | test-release-tools

TEMPLATE values for scaffold-app:
  minimal | panel | clone
USAGE
  exit 0
  ;;
esac

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)

is_workspace_root() {
  root=${1-}
  [ -n "$root" ] || return 1
  [ -f "$root/config/apps.manifest.json" ] || return 1
  [ -f "$root/config/templates.manifest.json" ] || return 1
  [ -d "$root/.apps" ] || return 1
  [ -d "$root/.web" ] || return 1
}

find_root_from() {
  start=${1-}
  [ -n "$start" ] || return 1
  dir=$start
  while :; do
    if is_workspace_root "$dir"; then
      printf '%s\n' "$dir"
      return 0
    fi
    [ "$dir" = "/" ] && break
    dir=$(dirname "$dir")
  done
  return 1
}

root_from_file() {
  file=${1-}
  [ -n "$file" ] || return 1
  [ -f "$file" ] || return 1

  root=$(head -n 1 "$file" 2>/dev/null | tr -d '\r')
  [ -n "$root" ] || return 1

  if is_workspace_root "$root"; then
    printf '%s\n' "$root"
    return 0
  fi

  return 1
}

resolve_root() {
  hint=${1-}
  user_root_file="${XDG_CONFIG_HOME:-$HOME/.config}/wizardry-apps/forge-root"

  if [ -n "$hint" ] && is_workspace_root "$hint"; then
    printf '%s\n' "$hint"
    return 0
  fi

  if [ -n "${WIZARDRY_APPS_ROOT-}" ] && is_workspace_root "$WIZARDRY_APPS_ROOT"; then
    printf '%s\n' "$WIZARDRY_APPS_ROOT"
    return 0
  fi

  if root=$(root_from_file "$SCRIPT_DIR/../../wizardry-apps-root.txt" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  if root=$(root_from_file "$SCRIPT_DIR/../wizardry-apps-root.txt" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  if root=$(root_from_file "$user_root_file" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  if root=$(find_root_from "$SCRIPT_DIR" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  if pwd_now=$(pwd -P 2>/dev/null); then
    if root=$(find_root_from "$pwd_now" 2>/dev/null); then
      printf '%s\n' "$root"
      return 0
    fi
  fi

  return 1
}

require_root() {
  hint=${1-}
  if root=$(resolve_root "$hint" 2>/dev/null); then
    printf '%s\n' "$root"
    return 0
  fi

  printf '%s\n' "forge-backend: unable to resolve wizardry-apps root (set WIZARDRY_APPS_ROOT or provide ROOT_HINT)" >&2
  exit 1
}

require_tool() {
  tool=$1
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf '%s\n' "forge-backend: required tool not found: $tool" >&2
    exit 1
  fi
}

os_id() {
  case "$(uname -s)" in
    Darwin) printf '%s\n' "darwin" ;;
    Linux) printf '%s\n' "linux" ;;
    *) printf '%s\n' "unknown" ;;
  esac
}

validate_slug() {
  slug=${1-}
  case "$slug" in
    [a-z][a-z0-9-]*) ;;
    *)
      printf '%s\n' "forge-backend: invalid slug '$slug' (expected [a-z][a-z0-9-]*)" >&2
      exit 2
      ;;
  esac

  case "$slug" in
    *-|*--*)
      printf '%s\n' "forge-backend: invalid slug '$slug' (no trailing or consecutive hyphens)" >&2
      exit 2
      ;;
  esac
}

validate_site_name() {
  site=${1-}
  case "$site" in
    [A-Za-z0-9][A-Za-z0-9._-]*) ;;
    *)
      printf '%s\n' "forge-backend: invalid site name '$site'" >&2
      exit 2
      ;;
  esac
}

app_exists() {
  root=$1
  slug=$2
  [ -d "$root/.apps/$slug" ]
}

require_jq() {
  require_tool jq
}

app_name_from_manifest() {
  root=$1
  slug=$2
  sh "$root/tools/release/get-app-name.sh" "$slug"
}

bundle_id_from_manifest() {
  root=$1
  platform=$2
  slug=$3
  sh "$root/tools/release/get-app-bundle-id.sh" "$platform" "$slug"
}

ensure_macos_host() {
  root=$1
  require_tool clang

  host_bin="$root/_tmp/workbench/bin/wizardry-host-macos"
  host_src="$root/.apps/.host/macos/main.m"
  module_cache="$root/_tmp/workbench/clang-module-cache"

  mkdir -p "$(dirname "$host_bin")"
  if [ ! -x "$host_bin" ] || [ "$host_src" -nt "$host_bin" ]; then
    mkdir -p "$module_cache"
    CLANG_MODULE_CACHE_PATH="$module_cache" \
      clang -O2 -fobjc-arc -fmodules "$host_src" -o "$host_bin" -framework Cocoa -framework WebKit
  fi
  printf '%s\n' "$host_bin"
}

ensure_linux_host() {
  root=$1
  require_tool cc
  require_tool pkg-config

  host_bin="$root/_tmp/workbench/bin/wizardry-host-linux"
  host_src="$root/.apps/.host/linux/main.c"

  mkdir -p "$(dirname "$host_bin")"
  cc -O2 "$host_src" -o "$host_bin" $(pkg-config --cflags --libs gtk+-3.0 webkit2gtk-4.1)
  printf '%s\n' "$host_bin"
}

cmd_doctor() {
  root_hint=${1-}
  root=''

  if resolved=$(resolve_root "$root_hint" 2>/dev/null); then
    root=$resolved
  fi

  printf 'root=%s\n' "$root"
  printf 'os=%s\n' "$(os_id)"
  printf 'home=%s\n' "$HOME"

  for t in jq clang cc gcc xcodebuild xcodegen pkg-config gradle java open xdg-open appimagetool; do
    if command -v "$t" >/dev/null 2>&1; then
      printf '%s=%s\n' "$t" "1"
    else
      printf '%s=%s\n' "$t" "0"
    fi
  done

  if [ -n "$root" ] && command -v jq >/dev/null 2>&1; then
    printf 'apps_manifest=%s\n' "$root/config/apps.manifest.json"
    printf 'templates_manifest=%s\n' "$root/config/templates.manifest.json"
    printf 'apps_total=%s\n' "$(jq -r '.apps | length' "$root/config/apps.manifest.json")"
    printf 'apps_production=%s\n' "$(jq -r '[.apps[] | select(.production == true)] | length' "$root/config/apps.manifest.json")"
    printf 'templates_total=%s\n' "$(jq -r '.templates | length' "$root/config/templates.manifest.json")"
  fi
}

cmd_list_apps() {
  root=$(require_root "${1-}")
  require_jq

  manifest="$root/config/apps.manifest.json"
  jq -r '.apps[] | [.slug, .name, (if .production then "true" else "false" end)] | @tsv' "$manifest" |
  while IFS="$(printf '\t')" read -r slug name production; do
    exists=0
    app_exists "$root" "$slug" && exists=1
    printf '%s\t%s\t%s\t%s\n' "$slug" "$name" "$production" "$exists"
  done
}

cmd_list_templates() {
  root=$(require_root "${1-}")
  require_jq

  manifest="$root/config/templates.manifest.json"
  jq -r '.templates[] | [.slug, (if .publish then "true" else "false" end)] | @tsv' "$manifest" |
  while IFS="$(printf '\t')" read -r slug publish; do
    exists=0
    [ -d "$root/.web/$slug" ] && exists=1
    printf '%s\t%s\t%s\n' "$slug" "$publish" "$exists"
  done
}

cmd_build_desktop() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: build-desktop requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"

  app_dir="$root/.apps/$slug"
  [ -d "$app_dir" ] || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  require_jq
  os=$(os_id)

  case "$os" in
    darwin)
      host_bin=$(ensure_macos_host "$root")
      app_name=$(app_name_from_manifest "$root" "$slug")
      bundle_id=$(bundle_id_from_manifest "$root" macos "$slug")
      dist_dir="$root/_tmp/workbench/dist/macos"
      bundle="$dist_dir/$app_name.app"
      zip_path="$dist_dir/$app_name.zip"

      rm -rf "$bundle"
      mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources/$slug" "$bundle/Contents/Resources/wizardry-apps/core"

      cp -R "$app_dir"/. "$bundle/Contents/Resources/$slug/"
      mkdir -p "$bundle/Contents/Resources/$slug/.host"
      cp -R "$root/.apps/.host/shared" "$bundle/Contents/Resources/$slug/.host/"
      cp -R "$root/core/include" "$bundle/Contents/Resources/wizardry-apps/core/"
      cp -R "$root/core/src" "$bundle/Contents/Resources/wizardry-apps/core/"
      cp "$host_bin" "$bundle/Contents/MacOS/wizardry-host"

      cat > "$bundle/Contents/MacOS/$slug" <<APP
#!/bin/sh
set -eu
APPDIR=\$(CDPATH= cd -- "\$(dirname "\$0")/.." && pwd -P)
exec "\$APPDIR/MacOS/wizardry-host" "\$APPDIR/Resources/$slug"
APP
      chmod +x "$bundle/Contents/MacOS/$slug"

      cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$app_name</string>
<key>CFBundleDisplayName</key><string>$app_name</string>
<key>CFBundleIdentifier</key><string>$bundle_id</string>
<key>CFBundleVersion</key><string>1.0</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleExecutable</key><string>$slug</string>
</dict></plist>
PLIST

      if command -v ditto >/dev/null 2>&1; then
        rm -f "$zip_path"
        ditto -c -k --sequesterRsrc --keepParent "$bundle" "$zip_path"
      else
        zip_path=''
      fi

      printf 'host=%s\n' "$host_bin"
      printf 'artifact=%s\n' "$bundle"
      [ -n "$zip_path" ] && printf 'zip=%s\n' "$zip_path"
      ;;

    linux)
      host_bin=$(ensure_linux_host "$root")
      dist_dir="$root/_tmp/workbench/dist/linux"
      appdir="$dist_dir/AppDir-$slug"
      artifact=''

      rm -rf "$appdir"
      mkdir -p "$appdir/usr/bin" "$appdir/usr/share/$slug" "$appdir/usr/share/wizardry-apps/core"

      cp -R "$app_dir"/. "$appdir/usr/share/$slug/"
      mkdir -p "$appdir/usr/share/$slug/.host"
      cp -R "$root/.apps/.host/shared" "$appdir/usr/share/$slug/.host/"
      cp -R "$root/core/include" "$appdir/usr/share/wizardry-apps/core/"
      cp -R "$root/core/src" "$appdir/usr/share/wizardry-apps/core/"
      cp "$host_bin" "$appdir/usr/bin/wizardry-host"

      cat > "$appdir/AppRun" <<APP
#!/bin/sh
set -eu
HERE=\$(CDPATH= cd -- "\$(dirname "\$0")" && pwd -P)
exec "\$HERE/usr/bin/wizardry-host" "\$HERE/usr/share/$slug"
APP
      chmod +x "$appdir/AppRun"

      if command -v appimagetool >/dev/null 2>&1; then
        mkdir -p "$dist_dir"
        ARCH=x86_64 appimagetool "$appdir" "$dist_dir/wizardry-$slug-x86_64.AppImage" >/dev/null 2>&1
        artifact="$dist_dir/wizardry-$slug-x86_64.AppImage"
      else
        mkdir -p "$dist_dir"
        tar_path="$dist_dir/wizardry-$slug-linux.tar.gz"
        rm -f "$tar_path"
        (cd "$dist_dir" && tar -czf "$tar_path" "AppDir-$slug")
        artifact="$tar_path"
      fi

      printf 'host=%s\n' "$host_bin"
      printf 'artifact=%s\n' "$artifact"
      ;;

    *)
      printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
      exit 1
      ;;
  esac
}

cmd_run_desktop() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: run-desktop requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"

  app_dir="$root/.apps/$slug"
  [ -d "$app_dir" ] || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  os=$(os_id)
  host_bin=''
  case "$os" in
    darwin)
      host_bin=$(ensure_macos_host "$root")
      ;;
    linux)
      host_bin=$(ensure_linux_host "$root")
      ;;
    *)
      printf '%s\n' "forge-backend: unsupported desktop OS: $os" >&2
      exit 1
      ;;
  esac

  log_dir="$root/_tmp/workbench/log"
  mkdir -p "$log_dir"
  log_path="$log_dir/$slug-host.log"

  if command -v nohup >/dev/null 2>&1; then
    nohup "$host_bin" "$app_dir" >"$log_path" 2>&1 &
  else
    "$host_bin" "$app_dir" >"$log_path" 2>&1 &
  fi
  pid=$!

  printf 'launched=1\n'
  printf 'pid=%s\n' "$pid"
  printf 'log=%s\n' "$log_path"
}

cmd_stage_mobile() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: stage-mobile requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  dest="$root/_tmp/workbench/stage/mobile-$slug"
  sh "$root/tools/release/stage-web-assets.sh" "$slug" "$dest"
  printf 'staged=%s\n' "$dest"
}

cmd_build_ios_smoke() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: build-ios-smoke requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  [ "$(os_id)" = "darwin" ] || {
    printf '%s\n' "forge-backend: build-ios-smoke is supported on macOS only" >&2
    exit 1
  }

  out_dir="$root/_tmp/workbench/dist/ios"
  mkdir -p "$out_dir"
  sh "$root/tools/release/build-ios-app.sh" "$slug" "$out_dir" smoke
  printf 'out=%s\n' "$out_dir"
}

cmd_build_android_debug() {
  root=$(require_root "${1-}")
  slug=${2-}
  [ -n "$slug" ] || {
    printf '%s\n' "forge-backend: build-android-debug requires APP_SLUG" >&2
    exit 2
  }
  validate_slug "$slug"
  app_exists "$root" "$slug" || {
    printf '%s\n' "forge-backend: app not found: $slug" >&2
    exit 1
  }

  require_tool gradle
  require_tool java

  app_name=$(app_name_from_manifest "$root" "$slug")
  app_id=$(bundle_id_from_manifest "$root" android "$slug")

  sh "$root/tools/release/stage-web-assets.sh" "$slug" "$root/.apps/.host/android/app/src/main/assets"

  version_name="0.0.0-local"
  version_code=$(date +%s)

  gradle -p "$root/.apps/.host/android" :app:assembleDebug \
    -PwizardryApplicationId="$app_id" \
    -PwizardryAppName="$app_name" \
    -PwizardryVersionName="$version_name" \
    -PwizardryVersionCode="$version_code"

  apk=$(find "$root/.apps/.host/android/app/build/outputs/apk/debug" -type f -name '*.apk' | head -n 1)
  [ -n "$apk" ] || {
    printf '%s\n' "forge-backend: debug APK not found" >&2
    exit 1
  }

  out_dir="$root/_tmp/workbench/dist/android"
  mkdir -p "$out_dir"
  out_apk="$out_dir/wizardry-$slug-debug.apk"
  cp "$apk" "$out_apk"

  printf 'artifact=%s\n' "$out_apk"
}

write_minimal_template() {
  app_dir=$1
  app_name=$2

  cat > "$app_dir/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$app_name</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main class="shell">
    <h1>$app_name</h1>
    <p>This app is scaffolded from Wizardry Forge.</p>
    <button id="ping">Ping bridge</button>
    <pre id="out">ready</pre>
  </main>

  <script>
    (function loadBridge() {
      var candidates = ['./.host/shared/wizardry-bridge.js', '../.host/shared/wizardry-bridge.js'];
      var i = 0;
      function tryNext() {
        if (i >= candidates.length) {
          return;
        }
        var s = document.createElement('script');
        s.src = candidates[i++];
        s.onerror = tryNext;
        document.head.appendChild(s);
      }
      tryNext();
    })();
  </script>
  <script>
    document.getElementById('ping').addEventListener('click', async function () {
      var out = document.getElementById('out');
      if (!window.wizardry || !window.wizardry.rpc) {
        out.textContent = 'wizardry bridge unavailable';
        return;
      }
      try {
        var res = await window.wizardry.rpc('core.ping', {});
        out.textContent = JSON.stringify(res, null, 2);
      } catch (err) {
        out.textContent = String(err && err.message ? err.message : err);
      }
    });
  </script>
</body>
</html>
HTML

  cat > "$app_dir/style.css" <<'CSS'
:root {
  --bg: #141821;
  --panel: #1b2230;
  --line: #2c3648;
  --fg: #eff6ff;
  --muted: #a6b7cc;
  --accent: #5dc2a6;
}

body {
  margin: 0;
  min-height: 100vh;
  background: radial-gradient(circle at 20% 0%, #253146 0%, #141821 55%);
  color: var(--fg);
  font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
}

.shell {
  max-width: 760px;
  margin: 5rem auto;
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 14px;
  padding: 1.2rem;
}

h1 {
  margin: 0 0 0.7rem;
}

p {
  margin: 0 0 1rem;
  color: var(--muted);
}

button {
  border: 1px solid transparent;
  background: var(--accent);
  color: #0b1715;
  border-radius: 10px;
  padding: 0.45rem 0.8rem;
  cursor: pointer;
  font-weight: 600;
}

pre {
  background: #0f141d;
  border: 1px solid #232f40;
  border-radius: 10px;
  margin: 1rem 0 0;
  padding: 0.75rem;
  min-height: 7rem;
  overflow: auto;
}
CSS
}

write_panel_template() {
  app_dir=$1
  app_name=$2

  cat > "$app_dir/index.html" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$app_name</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <header>
    <h1>$app_name</h1>
    <p>Control panel starter generated by Wizardry Forge.</p>
  </header>

  <section class="buttons">
    <button data-cmd="status">Status</button>
    <button data-cmd="build">Build Site</button>
    <button data-cmd="serve">Serve Site</button>
    <button data-cmd="stop">Stop Site</button>
  </section>

  <pre id="out">ready</pre>

  <script>
    (function loadBridge() {
      var candidates = ['./.host/shared/wizardry-bridge.js', '../.host/shared/wizardry-bridge.js'];
      var i = 0;
      function tryNext() {
        if (i >= candidates.length) {
          return;
        }
        var s = document.createElement('script');
        s.src = candidates[i++];
        s.onerror = tryNext;
        document.head.appendChild(s);
      }
      tryNext();
    })();
  </script>
  <script>
    var out = document.getElementById('out');
    var site = 'demo';
    var commands = {
      status: ['web-wizardry', 'status', site],
      build: ['web-wizardry', 'build', site],
      serve: ['web-wizardry', 'serve', site],
      stop: ['web-wizardry', 'stop', site]
    };

    document.querySelectorAll('button[data-cmd]').forEach(function (btn) {
      btn.addEventListener('click', async function () {
        var key = btn.getAttribute('data-cmd');
        var argv = commands[key];
        if (!window.wizardry || !window.wizardry.rpc) {
          out.textContent = 'wizardry bridge unavailable';
          return;
        }
        out.textContent = 'running: ' + argv.join(' ');
        try {
          var res = await window.wizardry.rpc('bridge.exec', { argv: argv });
          out.textContent = ['exit=' + res.exit_code, res.stdout || '', res.stderr || ''].filter(Boolean).join('\n');
        } catch (err) {
          out.textContent = String(err && err.message ? err.message : err);
        }
      });
    });
  </script>
</body>
</html>
HTML

  cat > "$app_dir/style.css" <<'CSS'
:root {
  --bg: #faf5ee;
  --line: #d7c7b2;
  --ink: #2f2314;
  --panel: #fff8f0;
  --action: #b16900;
}

body {
  margin: 0;
  min-height: 100vh;
  background: linear-gradient(160deg, #f2e7d9 0%, #f9f3ea 62%);
  color: var(--ink);
  font-family: "Avenir Next", "Segoe UI", sans-serif;
}

header {
  padding: 1rem 1.2rem;
  border-bottom: 1px solid var(--line);
}

header h1 {
  margin: 0;
  font-size: 1.25rem;
}

header p {
  margin: 0.35rem 0 0;
  color: #71553a;
}

.buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.6rem;
  padding: 1rem 1.2rem;
}

button {
  border: 1px solid transparent;
  background: var(--action);
  color: #fff;
  border-radius: 8px;
  padding: 0.45rem 0.75rem;
  font-weight: 600;
  cursor: pointer;
}

pre {
  margin: 0 1.2rem 1.2rem;
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 10px;
  min-height: 12rem;
  padding: 0.8rem;
  overflow: auto;
  white-space: pre-wrap;
}
CSS
}

append_manifest_app() {
  root=$1
  slug=$2
  name=$3

  manifest="$root/config/apps.manifest.json"
  tmp_manifest=$(mktemp "${TMPDIR:-/tmp}/wizardry-apps-manifest.XXXXXX")

  if jq -e --arg slug "$slug" '.apps[] | select(.slug == $slug)' "$manifest" >/dev/null 2>&1; then
    rm -f "$tmp_manifest"
    printf '%s\n' "forge-backend: app slug already exists in manifest: $slug" >&2
    exit 1
  fi

  jq --arg slug "$slug" --arg name "$name" '
    .apps += [{
      "slug": $slug,
      "name": $name,
      "production": false,
      "bundleIds": {
        "macos": ("com.wizardry.apps." + $slug + ".macos"),
        "ios": ("com.wizardry.apps." + $slug + ".ios"),
        "android": ("com.wizardry.apps." + $slug + ".android")
      }
    }]
  ' "$manifest" > "$tmp_manifest"

  mv "$tmp_manifest" "$manifest"
}

cmd_scaffold_app() {
  root=$(require_root "${1-}")
  slug=${2-}
  app_name=${3-}
  template=${4-}
  source_app=${5-}

  [ -n "$slug" ] || { printf '%s\n' "forge-backend: scaffold-app requires APP_SLUG" >&2; exit 2; }
  [ -n "$app_name" ] || { printf '%s\n' "forge-backend: scaffold-app requires APP_NAME" >&2; exit 2; }
  [ -n "$template" ] || { printf '%s\n' "forge-backend: scaffold-app requires TEMPLATE" >&2; exit 2; }

  validate_slug "$slug"
  require_jq

  app_dir="$root/.apps/$slug"
  [ ! -e "$app_dir" ] || {
    printf '%s\n' "forge-backend: app path already exists: $app_dir" >&2
    exit 1
  }

  case "$template" in
    minimal|panel) ;;
    clone)
      [ -n "$source_app" ] || {
        printf '%s\n' "forge-backend: scaffold-app clone requires SOURCE_APP" >&2
        exit 2
      }
      validate_slug "$source_app"
      source_dir="$root/.apps/$source_app"
      [ -d "$source_dir" ] || {
        printf '%s\n' "forge-backend: source app not found: $source_app" >&2
        exit 1
      }
      ;;
    *)
      printf '%s\n' "forge-backend: unknown app template: $template" >&2
      exit 2
      ;;
  esac

  mkdir -p "$app_dir"

  case "$template" in
    minimal)
      write_minimal_template "$app_dir" "$app_name"
      ;;
    panel)
      write_panel_template "$app_dir" "$app_name"
      ;;
    clone)
      rm -rf "$app_dir"
      mkdir -p "$app_dir"
      cp -R "$source_dir"/. "$app_dir/"
      ;;
  esac

  append_manifest_app "$root" "$slug" "$app_name"

  printf 'created=%s\n' "$app_dir"
  printf 'manifest=%s\n' "$root/config/apps.manifest.json"
}

cmd_scaffold_site() {
  root=$(require_root "${1-}")
  site_name=${2-}
  template=${3-}
  dest_root=${4-}

  [ -n "$site_name" ] || { printf '%s\n' "forge-backend: scaffold-site requires SITE_NAME" >&2; exit 2; }
  [ -n "$template" ] || { printf '%s\n' "forge-backend: scaffold-site requires TEMPLATE" >&2; exit 2; }

  validate_site_name "$site_name"

  if [ -z "$dest_root" ]; then
    dest_root="$HOME/sites"
  fi

  template_dir="$root/.web/$template"
  [ -d "$template_dir" ] || {
    printf '%s\n' "forge-backend: template not found: $template" >&2
    exit 1
  }

  site_dir="$dest_root/$site_name"
  [ ! -e "$site_dir" ] || {
    printf '%s\n' "forge-backend: destination already exists: $site_dir" >&2
    exit 1
  }

  mkdir -p "$site_dir"
  cp -R "$template_dir"/. "$site_dir/"

  if [ -d "$site_dir/pages" ]; then
    mkdir -p "$site_dir/site"
    mv "$site_dir/pages" "$site_dir/site/"
  fi

  if [ -d "$site_dir/static" ]; then
    mkdir -p "$site_dir/site"
    mv "$site_dir/static" "$site_dir/site/"
  fi

  if [ -d "$site_dir/includes" ]; then
    mkdir -p "$site_dir/site"
    mv "$site_dir/includes" "$site_dir/site/"
  fi

  if [ -d "$root/.web/.themes" ]; then
    mkdir -p "$site_dir/site/static/themes"
    cp -f "$root/.web/.themes"/*.css "$site_dir/site/static/themes/" 2>/dev/null || true
  fi

  mkdir -p "$site_dir/site/uploads" "$site_dir/build"

  cat > "$site_dir/site.conf" <<CONF
# Site configuration for $site_name
site-name=$site_name
site-user=
template=$template
port=8080
domain=localhost
https=false
CONF

  cat > "$site_dir/site.allowlist" <<'ALLOW'
# List additional absolute paths this site may access.
# One path per line. Lines starting with # are ignored.
ALLOW

  printf 'created=%s\n' "$site_dir"
}

cmd_run_task() {
  root=$(require_root "${1-}")
  task=${2-}
  [ -n "$task" ] || {
    printf '%s\n' "forge-backend: run-task requires TASK" >&2
    exit 2
  }

  case "$task" in
    validate-manifest)
      sh "$root/tools/validate-manifest.sh"
      ;;
    test-core)
      sh "$root/core/tests/test_core.sh"
      sh "$root/.tests/core/test-core-rpc.sh"
      ;;
    test-adapters)
      sh "$root/.tests/adapters/test-http-cgi.sh"
      sh "$root/.tests/adapters/test-shell-parity.sh"
      sh "$root/.tests/adapters/test-core-shell-parity.sh"
      sh "$root/.tests/adapters/test-bridge-contract.sh"
      sh "$root/.tests/adapters/test-bridge-behavior.sh"
      ;;
    test-release-tools)
      sh "$root/.tests/release/test-release-tools.sh"
      ;;
    *)
      printf '%s\n' "forge-backend: unknown task: $task" >&2
      exit 2
      ;;
  esac
}

cmd=${1-}
case "$cmd" in
  doctor)
    cmd_doctor "${2-}"
    ;;
  list-apps)
    cmd_list_apps "${2-}"
    ;;
  list-templates)
    cmd_list_templates "${2-}"
    ;;
  build-desktop)
    cmd_build_desktop "${2-}" "${3-}"
    ;;
  run-desktop)
    cmd_run_desktop "${2-}" "${3-}"
    ;;
  stage-mobile)
    cmd_stage_mobile "${2-}" "${3-}"
    ;;
  build-ios-smoke)
    cmd_build_ios_smoke "${2-}" "${3-}"
    ;;
  build-android-debug)
    cmd_build_android_debug "${2-}" "${3-}"
    ;;
  scaffold-app)
    cmd_scaffold_app "${2-}" "${3-}" "${4-}" "${5-}" "${6-}"
    ;;
  scaffold-site)
    cmd_scaffold_site "${2-}" "${3-}" "${4-}" "${5-}"
    ;;
  run-task)
    cmd_run_task "${2-}" "${3-}"
    ;;
  *)
    printf '%s\n' "forge-backend: unknown command '$cmd' (use --help)" >&2
    exit 2
    ;;
esac
