#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
ir_path="$project_dir/ir/app.ir.yaml"
schema_path="$project_dir/schemas/native-desktop-ir-v1.json"
generated_root="$project_dir/generated"
macos_dir="$generated_root/macos"
linux_dir="$generated_root/linux"

"$script_dir/validate-native-desktop-ir.sh" "$ir_path" "$schema_path" >/dev/null

app_name=$(jq -r '.app.name' "$ir_path")
app_id=$(jq -r '.app.id' "$ir_path")
window_title=$(jq -r '.app.window.title // .app.name' "$ir_path")
menu_json=$(jq -c '.app.window.menuBar // {}' "$ir_path")
toolbar_json=$(jq -c '.app.window.toolbar // {}' "$ir_path")
content_json=$(jq -c '.app.window.content // {}' "$ir_path")
status_json=$(jq -c '.app.window.statusBar // {}' "$ir_path")
targets_csv=$(jq -r '.app.targets | join(",")' "$ir_path")
pretty_ir=$(jq '.' "$ir_path")

mkdir -p "$macos_dir/Sources/App" "$linux_dir/src"

cat > "$macos_dir/Package.swift" <<EOF
// Generated from ir/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh.
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "$app_id",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "$app_id", targets: ["App"])
  ],
  targets: [
    .executableTarget(
      name: "App",
      path: "Sources/App"
    )
  ]
)
EOF

cat > "$macos_dir/Sources/App/App.swift" <<EOF
// Generated from ir/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh.
import SwiftUI

private let canonicalIR = """
$pretty_ir
"""

private let menuBarIR = #"$menu_json"#
private let toolbarIR = #"$toolbar_json"#
private let contentIR = #"$content_json"#
private let statusBarIR = #"$status_json"#

@main
struct GeneratedNativeDesktopApp: App {
  @StateObject private var model = NativeReferenceModel()

  var body: some Scene {
    WindowGroup("$window_title") {
      RootView(model: model)
        .frame(minWidth: 960, minHeight: 640)
    }
    .commands {
      CommandGroup(after: .newItem) {
        Button("Export Document…") {
          model.status = "Export prepared from the native File menu."
        }
        .keyboardShortcut("e")
      }
      CommandMenu("Review") {
        Button("Review All Proposals") {
          model.selection = "proposals"
          model.status = "Focused proposal review."
        }
        Toggle("Show Inspector", isOn: \$model.showInspector)
      }
    }

    Settings {
      SettingsView(model: model)
        .padding(20)
        .frame(width: 520)
    }
  }
}

private final class NativeReferenceModel: ObservableObject {
  @Published var selection: String? = "constitution"
  @Published var status = "Ready"
  @Published var search = ""
  @Published var showInspector = true
  @Published var selectedSection: SectionDraft.ID? = SectionDraft.samples.first?.id
  @Published var editorText = SectionDraft.samples.first?.body ?? ""
  @Published var autosave = true
  @Published var sync = true

  let sections = SectionDraft.samples
  let proposals = ProposalDraft.samples
  let collaborators = CollaboratorDraft.samples

  var title: String {
    switch selection {
    case "constitution": return "Reference Constitution"
    case "proposals": return "Proposals"
    case "people": return "Collaborators"
    default: return "$app_name"
    }
  }
}

private struct ProposalDraft: Identifiable {
  let id: String
  let clause: String
  let author: String
  let status: String

  static let samples = [
    ProposalDraft(id: "notice", clause: "Notice and hearing", author: "Aster Vale", status: "Review"),
    ProposalDraft(id: "archive", clause: "Archive duty", author: "Lin Arbor", status: "Draft")
  ]
}

private struct CollaboratorDraft: Identifiable {
  let id: String
  let name: String
  let handle: String
  let role: String

  static let samples = [
    CollaboratorDraft(id: "aster", name: "Aster Vale", handle: "@aster", role: "Editor"),
    CollaboratorDraft(id: "lin", name: "Lin Arbor", handle: "@lin", role: "Reviewer")
  ]
}

private struct SectionDraft: Identifiable {
  let id: String
  let number: String
  let title: String
  let body: String

  static let samples = [
    SectionDraft(
      id: "preamble",
      number: "0",
      title: "Preamble",
      body: "Each section behaves like an independently editable mini-document while the whole window reads as one native document."
    ),
    SectionDraft(
      id: "rights",
      number: "1",
      title: "Rights",
      body: "People may propose edits in place. Native selection, menus, and text editing remain available throughout the workflow."
    ),
    SectionDraft(
      id: "process",
      number: "2",
      title: "Amendment Process",
      body: "Review commands live in the toolbar and menu bar instead of a custom web-style overflow menu."
    )
  ]
}

private struct RootView: View {
  @ObservedObject var model: NativeReferenceModel

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        TextField("Search", text: \$model.search)
          .textFieldStyle(.roundedBorder)
          .padding([.horizontal, .top], 12)
          .padding(.bottom, 8)
        List(selection: \$model.selection) {
          Section("Documents") {
            Label("Reference Constitution", systemImage: "doc.text")
              .tag("constitution")
            Label("Proposals", systemImage: "checklist")
              .tag("proposals")
            Label("Collaborators", systemImage: "person.2")
              .tag("people")
          }
        }
        .listStyle(.sidebar)
      }
      .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 360)
    } detail: {
      DetailView(model: model)
        .navigationTitle(model.title)
        .toolbar {
          ToolbarItemGroup(placement: .primaryAction) {
            Button {
              model.status = "Created a native document section."
            } label: {
              Label("New Section", systemImage: "plus")
            }
            Button {
              model.status = "Proposal review opened."
            } label: {
              Label("Review", systemImage: "checklist")
            }
            Toggle(isOn: \$model.showInspector) {
              Label("Inspector", systemImage: "sidebar.right")
            }
          }
        }
    }
  }
}

private struct DetailView: View {
  @ObservedObject var model: NativeReferenceModel

  var body: some View {
    switch model.selection {
    case "proposals":
      ProposalReviewView(model: model)
    case "people":
      CollaboratorsView(model: model)
    default:
      DocumentView(model: model)
    }
  }
}

private struct DocumentView: View {
  @ObservedObject var model: NativeReferenceModel

  var body: some View {
    HSplitView {
      VStack(alignment: .leading, spacing: 0) {
        List(model.sections, selection: \$model.selectedSection) { section in
          VStack(alignment: .leading, spacing: 4) {
            Text("\(section.number). \(section.title)")
              .font(.headline)
            Text(section.body)
              .lineLimit(2)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
          .tag(section.id)
        }
        .listStyle(.inset)
        .onChange(of: model.selectedSection) { id in
          if let section = model.sections.first(where: { \$0.id == id }) {
            model.editorText = section.body
          }
        }

        Divider()
        Text(model.status)
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(8)
      }

      VStack(alignment: .leading, spacing: 12) {
        TextEditor(text: \$model.editorText)
          .font(.body)
          .scrollContentBackground(.hidden)
          .frame(minWidth: 360, maxWidth: .infinity, maxHeight: .infinity)
        HStack {
          Button("Save Proposal") {
            model.status = "Saved the current section as a proposal."
          }
          .buttonStyle(.borderedProminent)
          Button("Discard") {
            model.status = "Discarded local proposal text."
          }
        }
      }
      .padding(16)

      if model.showInspector {
        InspectorView()
          .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
      }
    }
  }
}

private struct ProposalReviewView: View {
  @ObservedObject var model: NativeReferenceModel
  @State private var selectedProposal: ProposalDraft.ID?

  var body: some View {
    Table(model.proposals, selection: \$selectedProposal) {
      TableColumn("Clause") { proposal in
        Text(proposal.clause)
      }
      TableColumn("Author") { proposal in
        Text(proposal.author)
      }
      TableColumn("Status") { proposal in
        Text(proposal.status)
      }
    }
  }
}

private struct CollaboratorsView: View {
  @ObservedObject var model: NativeReferenceModel

  var body: some View {
    List(model.collaborators) { collaborator in
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(collaborator.name)
            .font(.headline)
          Text(collaborator.handle)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text(collaborator.role)
          .foregroundStyle(.secondary)
      }
      .padding(.vertical, 4)
    }
    .listStyle(.inset)
  }
}

private struct InspectorView: View {
  var body: some View {
    Form {
      Section("Section") {
        LabeledContent("Status", value: "Draft")
        LabeledContent("Review", value: "2 proposals")
      }
      Section("Document") {
        LabeledContent("Toolbar IR", value: toolbarIR)
        LabeledContent("Targets", value: "$targets_csv")
      }
    }
    .formStyle(.grouped)
    .padding(12)
  }
}

private struct SettingsView: View {
  @ObservedObject var model: NativeReferenceModel

  var body: some View {
    Form {
      GroupBox("Document Review") {
        VStack(alignment: .leading, spacing: 8) {
          Text("Use GroupBox for bounded native preference groups instead of custom cards.")
            .foregroundStyle(.secondary)
          Toggle("Autosave proposals", isOn: \$model.autosave)
          Toggle("Sync review state", isOn: \$model.sync)
        }
      }
      Picker("Document style", selection: .constant("Native")) {
        Text("Native").tag("Native")
        Text("Compact").tag("Compact")
      }
      LabeledContent("IR version", value: "native-desktop-ir/v1")
    }
  }
}
EOF

linux_ir_literal=$(printf '%s' "$pretty_ir" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')

cat > "$linux_dir/meson.build" <<EOF
# Generated from ir/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh.
project('$app_id', 'c', version: '0.1.0')

gtk_dep = dependency('gtk4')

executable(
  '$app_id',
  ['src/main.c'],
  dependencies: [gtk_dep],
  install: false,
)
EOF

cat > "$linux_dir/src/main.c" <<EOF
/* Generated from ir/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh. */
#include <gtk/gtk.h>

static const char *wizardry_app_ir =
  "$linux_ir_literal";

static void activate(GtkApplication *app, gpointer user_data) {
  GtkWidget *window = gtk_application_window_new(app);
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
  GtkWidget *title = gtk_label_new("$app_name");
  GtkWidget *summary = gtk_label_new("Generated from the canonical native desktop IR.");
  GtkWidget *targets = gtk_label_new("Targets: $targets_csv");

  (void)user_data;
  (void)wizardry_app_ir;

  gtk_window_set_title(GTK_WINDOW(window), "$window_title");
  gtk_window_set_default_size(GTK_WINDOW(window), 960, 640);
  gtk_widget_set_margin_top(box, 20);
  gtk_widget_set_margin_bottom(box, 20);
  gtk_widget_set_margin_start(box, 20);
  gtk_widget_set_margin_end(box, 20);
  gtk_label_set_xalign(GTK_LABEL(title), 0.0f);
  gtk_label_set_xalign(GTK_LABEL(summary), 0.0f);
  gtk_label_set_xalign(GTK_LABEL(targets), 0.0f);
  gtk_box_append(GTK_BOX(box), title);
  gtk_box_append(GTK_BOX(box), summary);
  gtk_box_append(GTK_BOX(box), targets);
  gtk_window_set_child(GTK_WINDOW(window), box);
  gtk_window_present(GTK_WINDOW(window));
}

int main(int argc, char **argv) {
  GtkApplication *app = gtk_application_new("app.$app_id", G_APPLICATION_DEFAULT_FLAGS);
  g_signal_connect(app, "activate", G_CALLBACK(activate), NULL);
  int status = g_application_run(G_APPLICATION(app), argc, argv);
  g_object_unref(app);
  return status;
}
EOF

printf 'status=ok\n'
printf 'ir=%s\n' "$ir_path"
printf 'macos=%s\n' "$macos_dir"
printf 'linux=%s\n' "$linux_dir"
