#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
ir_path="$project_dir/ir/mobile.ir.yaml"
schema_path="$project_dir/schemas/native-mobile-ir-v1.json"
generated_root="$project_dir/generated/mobile"
android_dir="$generated_root/android"
ios_dir="$generated_root/ios"
version_file="$project_dir/VERSION"

"$script_dir/validate-native-mobile-ir.sh" "$ir_path" "$schema_path" >/dev/null

app_name=$(jq -r '.app.name' "$ir_path")
app_id=$(jq -r '.app.id' "$ir_path")
package_part=$(printf '%s' "$app_id" | tr '-' '_')
android_package="app.wizardry.generated.$package_part"
ios_bundle="app.wizardry.generated.$package_part"
if [ -f "$version_file" ]; then
  app_version=$(tr -d ' \t\r\n' <"$version_file")
else
  app_version=0.1.0
fi
version_code=$(printf '%s' "$app_version" | cksum | awk '{ print $1 }')
[ -n "$version_code" ] || version_code=1

mkdir -p "$android_dir/app/src/main/java/app/wizardry/generated/$package_part" "$ios_dir/Host"

screen_titles=$(jq -r '.app.screens[].title' "$ir_path")
primary_title=$(printf '%s\n' "$screen_titles" | sed -n '1p')
[ -n "$primary_title" ] || primary_title="$app_name"
android_items=$(jq -r '.app.screens[] | "        items.add(\"" + (.title | gsub("\\\\";"\\\\\\") | gsub("\"";"\\\"")) + "\");"' "$ir_path")
ios_items=$(jq -r '.app.screens[] | "        \"" + (.title | gsub("\\\\";"\\\\\\\\") | gsub("\"";"\\\"")) + "\","' "$ir_path")

cat >"$android_dir/settings.gradle" <<GRADLE
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement { repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS); repositories { google(); mavenCentral() } }
rootProject.name = "$app_id-native-mobile"
include ':app'
GRADLE

cat >"$android_dir/build.gradle" <<'GRADLE'
plugins {
    id 'com.android.application' version '8.5.2' apply false
}
GRADLE

cat >"$android_dir/app/build.gradle" <<GRADLE
plugins { id 'com.android.application' }

android {
    namespace '$android_package'
    compileSdk 35

    defaultConfig {
        applicationId '$android_package'
        minSdk 23
        targetSdk 35
        versionCode $version_code
        versionName '$app_version'
    }
}
GRADLE

cat >"$android_dir/app/src/main/AndroidManifest.xml" <<XML
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application android:theme="@style/AppTheme" android:label="$app_name" android:allowBackup="false" android:supportsRtl="true">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
XML

mkdir -p "$android_dir/app/src/main/res/values"
cat >"$android_dir/app/src/main/res/values/styles.xml" <<'XML'
<resources>
    <style name="AppTheme" parent="android:style/Theme.Material.Light.NoActionBar">
        <item name="android:fontFamily">sans</item>
        <item name="android:windowLightStatusBar">true</item>
        <item name="android:navigationBarColor">#F7F7F2</item>
        <item name="android:colorAccent">#2F6F6A</item>
    </style>
</resources>
XML

cat >"$android_dir/app/src/main/java/app/wizardry/generated/$package_part/MainActivity.java" <<JAVA
package $android_package;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.TextView;
import java.util.ArrayList;

public final class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(28, 28, 28, 28);
        root.setBackgroundColor(Color.rgb(247, 247, 242));

        TextView title = new TextView(this);
        title.setText("$primary_title");
        title.setTextSize(24);
        title.setTextColor(Color.rgb(24, 33, 35));
        root.addView(title, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        ArrayList<String> items = new ArrayList<>();
$android_items
        ListView list = new ListView(this);
        list.setAdapter(new ArrayAdapter<String>(this, android.R.layout.simple_list_item_1, items));
        root.addView(list, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1));

        EditText composer = new EditText(this);
        composer.setHint("Message");
        composer.setSingleLine(false);
        root.addView(composer, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));

        Button send = new Button(this);
        send.setText("Send");
        root.addView(send, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        setContentView(root);
    }
}
JAVA

cat >"$ios_dir/project.yml" <<YAML
name: $app_id-native-mobile
options:
  bundleIdPrefix: app.wizardry.generated
targets:
  $app_id:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - Host
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: $ios_bundle
      INFOPLIST_KEY_CFBundleDisplayName: "$app_name"
      CURRENT_PROJECT_VERSION: "$version_code"
      MARKETING_VERSION: "$app_version"
YAML

cat >"$ios_dir/Host/App.swift" <<SWIFT
import SwiftUI

@main
struct GeneratedNativeMobileApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
SWIFT

cat >"$ios_dir/Host/ContentView.swift" <<SWIFT
import SwiftUI

struct ContentView: View {
    private let items = [
$ios_items
    ]
    @State private var message = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Screens") {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                    }
                }
                Section("Compose") {
                    TextField("Message", text: \$message, axis: .vertical)
                    Button("Send") { message = "" }
                }
            }
            .navigationTitle("$primary_title")
        }
    }
}
SWIFT

cat >"$generated_root/README.md" <<README
# $app_name Native Mobile Build

Generated from \`ir/mobile.ir.yaml\`.

- Android output is a plain Gradle Android project with no Play Services dependency.
- Android direct distribution is the primary release route; Play upload is optional.
- iOS output is a SwiftUI project generated through XcodeGen.
README

printf 'status=ok\n'
printf 'ir=%s\n' "$ir_path"
printf 'android=%s\n' "$android_dir"
printf 'ios=%s\n' "$ios_dir"
