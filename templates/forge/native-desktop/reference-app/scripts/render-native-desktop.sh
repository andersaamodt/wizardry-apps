#!/bin/sh

set -eu

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)
project_dir=$(CDPATH= cd -- "$script_dir/.." && pwd -P)
ir_path="$project_dir/ir/app.ir.yaml"
schema_path="$project_dir/schemas/native-desktop-ir-v1.json"
generated_root="$project_dir/generated"
macos_dir="$generated_root/macos"
linux_dir="$generated_root/linux"

sh "$script_dir/validate-native-desktop-ir.sh" "$ir_path" "$schema_path" >/dev/null

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
	import AppKit
	import SwiftUI
	import UniformTypeIdentifiers

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
        Button("Import Supporting Document…") {
          chooseImportDocument(model: model)
        }
        .keyboardShortcut("o")
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
      CommandMenu("Find") {
        Button("Find in Document") {
          model.status = "Find is handled by the toolbar NSSearchField."
        }
        .keyboardShortcut("f")
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
  @Published var find = ""
  @Published var showInspector = true
  @Published var selectedSection: SectionDraft.ID? = SectionDraft.samples.first?.id
  @Published var editingSection: SectionDraft.ID?
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

	private final class SourceListItem: NSObject {
	  let identifier: String
	  let title: String
	  let subtitle: String?
	  let symbolName: String?
	  let isGroup: Bool
	  let children: [SourceListItem]

	  init(identifier: String, title: String, subtitle: String?, symbolName: String?, isGroup: Bool = false, children: [SourceListItem] = []) {
	    self.identifier = identifier
	    self.title = title
	    self.subtitle = subtitle
	    self.symbolName = symbolName
	    self.isGroup = isGroup
	    self.children = children
	    super.init()
	  }
	}

	private struct NativeSourceList: NSViewRepresentable {
	  @Binding var selection: String?

	  private var nodes: [SourceListItem] {
	    [
	      SourceListItem(
	        identifier: "group:documents",
	        title: "Documents",
	        subtitle: nil,
	        symbolName: nil,
	        isGroup: true,
	        children: [
	          SourceListItem(identifier: "constitution", title: "Reference Constitution", subtitle: "Document", symbolName: "doc.text"),
	          SourceListItem(identifier: "proposals", title: "Proposals", subtitle: "Review queue", symbolName: "checklist"),
	          SourceListItem(identifier: "people", title: "Collaborators", subtitle: "People", symbolName: "person.2")
	        ]
	      )
	    ]
	  }

	  func makeCoordinator() -> Coordinator {
	    Coordinator(selection: \$selection)
	  }

	  func makeNSView(context: Context) -> NSScrollView {
	    context.coordinator.makeScrollView()
	  }

	  func updateNSView(_ scrollView: NSScrollView, context: Context) {
	    context.coordinator.selection = \$selection
	    context.coordinator.update(nodes: nodes, selectedIdentifier: selection)
	  }

	  @MainActor
	  final class Coordinator: NSObject, NSOutlineViewDataSource, NSOutlineViewDelegate {
	    private static let columnIdentifier = NSUserInterfaceItemIdentifier("source")
	    private var outlineView: NSOutlineView?
	    private var nodes: [SourceListItem] = []
	    private var programmaticSelection = false
	    var selection: Binding<String?>

	    init(selection: Binding<String?>) {
	      self.selection = selection
	    }

	    func makeScrollView() -> NSScrollView {
	      let outlineView = NSOutlineView()
	      outlineView.headerView = nil
	      outlineView.backgroundColor = .clear
	      outlineView.usesAlternatingRowBackgroundColors = false
	      outlineView.rowSizeStyle = .default
	      outlineView.allowsEmptySelection = false
	      outlineView.allowsMultipleSelection = false
	      outlineView.floatsGroupRows = false
	      outlineView.indentationPerLevel = 0
	      outlineView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
	      outlineView.autoresizesOutlineColumn = true
	      outlineView.dataSource = self
	      outlineView.delegate = self
	      if #available(macOS 11.0, *) {
	        outlineView.style = .sourceList
	      }

	      let column = NSTableColumn(identifier: Self.columnIdentifier)
	      column.minWidth = 180
	      column.width = 240
	      column.resizingMask = .autoresizingMask
	      outlineView.addTableColumn(column)
	      outlineView.outlineTableColumn = column

	      let scrollView = NSScrollView()
	      scrollView.borderType = .noBorder
	      scrollView.drawsBackground = false
	      scrollView.hasVerticalScroller = true
	      scrollView.autohidesScrollers = true
	      scrollView.documentView = outlineView
	      self.outlineView = outlineView
	      return scrollView
	    }

	    func update(nodes: [SourceListItem], selectedIdentifier: String?) {
	      guard let outlineView else { return }
	      self.nodes = nodes
	      programmaticSelection = true
	      outlineView.reloadData()
	      nodes.forEach { outlineView.expandItem(\$0) }
	      outlineView.sizeLastColumnToFit()
	      if let selectedIdentifier {
	        select(identifier: selectedIdentifier)
	      }
	      programmaticSelection = false
	    }

	    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
	      guard let item = item as? SourceListItem else { return nodes.count }
	      return item.children.count
	    }

	    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
	      guard let item = item as? SourceListItem else { return nodes[index] }
	      return item.children[index]
	    }

	    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
	      (item as? SourceListItem)?.children.isEmpty == false
	    }

	    func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
	      (item as? SourceListItem)?.isGroup == true
	    }

	    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
	      (item as? SourceListItem)?.isGroup == false
	    }

	    func outlineViewSelectionDidChange(_ notification: Notification) {
	      guard !programmaticSelection, let outlineView else { return }
	      let row = outlineView.selectedRow
	      guard row >= 0, let item = outlineView.item(atRow: row) as? SourceListItem, !item.isGroup else { return }
	      selection.wrappedValue = item.identifier
	    }

	    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
	      guard let item = item as? SourceListItem else { return 30 }
	      return item.isGroup ? 28 : 44
	    }

	    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
	      guard let item = item as? SourceListItem else { return nil }
	      return item.isGroup ? groupCell(for: item) : rowCell(for: item)
	    }

	    private func select(identifier: String) {
	      guard let outlineView, let item = item(withIdentifier: identifier, in: nodes) else { return }
	      let row = outlineView.row(forItem: item)
	      guard row >= 0 else { return }
	      outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
	    }

	    private func item(withIdentifier identifier: String, in items: [SourceListItem]) -> SourceListItem? {
	      for item in items {
	        if item.identifier == identifier { return item }
	        if let match = self.item(withIdentifier: identifier, in: item.children) { return match }
	      }
	      return nil
	    }

	    private func groupCell(for item: SourceListItem) -> NSTableCellView {
	      let cell = NSTableCellView()
	      let title = label(item.title, font: .systemFont(ofSize: 11, weight: .semibold), color: .secondaryLabelColor)
	      let stack = horizontalStack()
	      stack.addArrangedSubview(title)
	      attach(stack, to: cell)
	      return cell
	    }

	    private func rowCell(for item: SourceListItem) -> NSTableCellView {
	      let cell = NSTableCellView()
	      let stack = horizontalStack()
	      if let symbolName = item.symbolName {
	        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: item.title) ?? NSImage()
	        let imageView = NSImageView(image: image)
	        imageView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
	        imageView.contentTintColor = .secondaryLabelColor
	        imageView.translatesAutoresizingMaskIntoConstraints = false
	        imageView.widthAnchor.constraint(equalToConstant: 16).isActive = true
	        imageView.heightAnchor.constraint(equalToConstant: 16).isActive = true
	        stack.addArrangedSubview(imageView)
	      }

	      let textStack = NSStackView()
	      textStack.orientation = .vertical
	      textStack.alignment = .leading
	      textStack.spacing = 1
	      let title = label(item.title, font: .systemFont(ofSize: 13), color: .labelColor)
	      cell.textField = title
	      textStack.addArrangedSubview(title)
	      if let subtitle = item.subtitle {
	        textStack.addArrangedSubview(label(subtitle, font: .systemFont(ofSize: 11), color: .secondaryLabelColor))
	      }
	      stack.addArrangedSubview(textStack)
	      attach(stack, to: cell)
	      return cell
	    }

	    private func horizontalStack() -> NSStackView {
	      let stack = NSStackView()
	      stack.orientation = .horizontal
	      stack.alignment = .centerY
	      stack.spacing = 8
	      stack.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
	      return stack
	    }

	    private func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
	      let field = NSTextField(labelWithString: text)
	      field.font = font
	      field.textColor = color
	      field.maximumNumberOfLines = 1
	      field.lineBreakMode = .byTruncatingTail
	      return field
	    }

	    private func attach(_ view: NSView, to cell: NSTableCellView) {
	      view.translatesAutoresizingMaskIntoConstraints = false
	      cell.addSubview(view)
	      NSLayoutConstraint.activate([
	        view.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
	        view.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
	        view.topAnchor.constraint(equalTo: cell.topAnchor),
	        view.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
	      ])
	    }
	  }
	}

	private struct RootView: View {
  @ObservedObject var model: NativeReferenceModel

  var body: some View {
    NavigationSplitView {
      VStack(spacing: 0) {
        NativeSearchField(text: \$model.search, placeholder: "Search")
          .frame(height: 28)
          .padding([.horizontal, .top], 12)
          .padding(.bottom, 8)
	        NativeSourceList(selection: \$model.selection)
      }
      .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 360)
    } detail: {
      DetailView(model: model)
        .navigationTitle(model.title)
        .toolbar {
          ToolbarItem(placement: .automatic) {
            NativeSearchField(text: \$model.find, placeholder: "Find in Document")
              .frame(width: 220)
          }
          ToolbarItemGroup(placement: .primaryAction) {
            Button {
              chooseImportDocument(model: model)
            } label: {
              Label("Import", systemImage: "doc.badge.plus")
            }
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
          ToolbarItem(placement: .status) {
            Text(model.status)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
    }
  }
}

@MainActor
private func chooseImportDocument(model: NativeReferenceModel) {
  let panel = NSOpenPanel()
  panel.title = "Import Supporting Document"
  panel.prompt = "Import"
  panel.canChooseFiles = true
  panel.canChooseDirectories = false
  panel.allowsMultipleSelection = false
  panel.allowedContentTypes = [.plainText, .text, .pdf, .rtf, .data]
  if panel.runModal() == .OK, let url = panel.url {
    model.status = "Imported \(url.lastPathComponent) with a native file panel."
  } else {
    model.status = "Import cancelled."
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
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          Text("Reference Constitution")
            .font(.system(size: 22, weight: .semibold, design: .serif))
          ForEach(model.sections) { section in
            DocumentSectionRow(model: model, section: section)
          }
        }
        .frame(maxWidth: 760, alignment: .leading)
        .padding(24)
      }
      .frame(minWidth: 420, maxWidth: .infinity)

      if model.showInspector {
        InspectorView()
          .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
      }
    }
  }
}

private struct DocumentSectionRow: View {
  @ObservedObject var model: NativeReferenceModel
  let section: SectionDraft

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline, spacing: 10) {
        Text(section.number)
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundStyle(.secondary)
          .frame(width: 34, alignment: .leading)
        Text(section.title)
          .font(.headline)
      }

      if model.editingSection == section.id {
        VStack(alignment: .leading, spacing: 8) {
          TextEditor(text: \$model.editorText)
            .font(.body)
            .frame(minHeight: 120)
          HStack(spacing: 8) {
            Button("Cancel") {
              model.editingSection = nil
              model.status = "Cancelled proposal edit."
            }
            Button("Save Proposal") {
              model.editingSection = nil
              model.status = "Saved \(section.title) as a proposal."
            }
            .buttonStyle(.borderedProminent)
          }
        }
        .padding(.leading, 44)
      } else {
        Button {
          model.selectedSection = section.id
          model.editingSection = section.id
          model.editorText = section.body
          model.status = "Editing \(section.title) as a proposal."
        } label: {
          Text(section.body)
            .font(.body)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.leading, 44)
        .contextMenu {
          Button("Edit as Proposal") {
            model.editingSection = section.id
            model.editorText = section.body
          }
          Button("Inspect Section") {
            model.selectedSection = section.id
            model.showInspector = true
          }
        }
      }

      Divider()
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

private struct NativeSearchField: NSViewRepresentable {
  @Binding var text: String
  let placeholder: String

  func makeNSView(context: Context) -> NSSearchField {
    let searchField = NSSearchField(frame: .zero)
    searchField.placeholderString = placeholder
    searchField.delegate = context.coordinator
    searchField.sendsSearchStringImmediately = true
    searchField.sendsWholeSearchString = false
    return searchField
  }

  func updateNSView(_ nsView: NSSearchField, context: Context) {
    nsView.placeholderString = placeholder
    if nsView.stringValue != text {
      nsView.stringValue = text
    }
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(text: \$text)
  }

  final class Coordinator: NSObject, NSSearchFieldDelegate {
    @Binding var text: String

    init(text: Binding<String>) {
      _text = text
    }

    func controlTextDidChange(_ notification: Notification) {
      guard let searchField = notification.object as? NSSearchField else { return }
      text = searchField.stringValue
    }
  }
}
EOF

linux_ir_literal=$(printf '%s' "$pretty_ir" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n')

cat > "$linux_dir/meson.build" <<EOF
# Generated from ir/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh.
project('$app_id', 'c', version: '0.1.0')

gtk_dep = dependency('gtk4')
json_dep = dependency('json-glib-1.0')

executable(
  '$app_id',
  ['src/main.c'],
  dependencies: [gtk_dep, json_dep],
  install: false,
)
EOF

cat > "$linux_dir/src/main.c" <<EOF
/* Generated from ir/app.ir.yaml. Regenerate with scripts/render-native-desktop.sh. */
#include <gtk/gtk.h>
#include <json-glib/json-glib.h>

static const char *wizardry_app_ir =
  "$linux_ir_literal";

static const char *reference_snapshot_json =
  "{"
  "\\"documents\\":["
  "{\\"title\\":\\"Reference Constitution\\",\\"subtitle\\":\\"Live backend snapshot row\\"},"
  "{\\"title\\":\\"Supporting Memo\\",\\"subtitle\\":\\"Full-row selectable supporting document\\"}"
  "]"
  "}";

typedef struct {
  GtkWindow *window;
  GtkStack *main_stack;
  GtkListBox *document_list;
  GtkLabel *status_label;
} AppState;

static void set_margin(GtkWidget *widget, int margin) {
  gtk_widget_set_margin_top(widget, margin);
  gtk_widget_set_margin_bottom(widget, margin);
  gtk_widget_set_margin_start(widget, margin);
  gtk_widget_set_margin_end(widget, margin);
}

static void append_label(GtkWidget *box, const char *text) {
  GtkWidget *label = gtk_label_new(text);
  gtk_label_set_xalign(GTK_LABEL(label), 0.0f);
  gtk_label_set_wrap(GTK_LABEL(label), TRUE);
  gtk_box_append(GTK_BOX(box), label);
}

static GtkWidget *make_icon_button(const char *icon_name, const char *tooltip) {
  GtkWidget *button = gtk_button_new_from_icon_name(icon_name);
  gtk_widget_set_tooltip_text(button, tooltip);
  return button;
}

static GtkWidget *make_password_entry(const char *placeholder) {
  GtkWidget *entry = gtk_entry_new();
  gtk_entry_set_visibility(GTK_ENTRY(entry), FALSE);
  gtk_entry_set_placeholder_text(GTK_ENTRY(entry), placeholder);
  gtk_widget_set_hexpand(entry, TRUE);
  return entry;
}

static void file_chooser_response(GtkNativeDialog *dialog, int response, gpointer user_data) {
  (void)user_data;
  if (response == GTK_RESPONSE_ACCEPT) {
    GtkFileChooser *chooser = GTK_FILE_CHOOSER(dialog);
    GFile *file = gtk_file_chooser_get_file(chooser);
    if (file != NULL) {
      g_object_unref(file);
    }
  }
  g_object_unref(dialog);
}

static void choose_file(GtkWindow *parent, GtkFileChooserAction action, const char *title, const char *accept_label) {
  GtkFileChooserNative *dialog = gtk_file_chooser_native_new(title, parent, action, accept_label, "Cancel");
  if (action == GTK_FILE_CHOOSER_ACTION_SAVE) {
    gtk_file_chooser_set_current_name(GTK_FILE_CHOOSER(dialog), "reference-document.pdf");
  }
  g_signal_connect(dialog, "response", G_CALLBACK(file_chooser_response), NULL);
  gtk_native_dialog_show(GTK_NATIVE_DIALOG(dialog));
}

static void import_document_action(GSimpleAction *action, GVariant *parameter, gpointer user_data) {
  AppState *state = user_data;
  (void)action;
  (void)parameter;
  choose_file(state->window, GTK_FILE_CHOOSER_ACTION_OPEN, "Import Supporting Document", "Import");
}

static void export_document_action(GSimpleAction *action, GVariant *parameter, gpointer user_data) {
  AppState *state = user_data;
  (void)action;
  (void)parameter;
  choose_file(state->window, GTK_FILE_CHOOSER_ACTION_SAVE, "Export Reference Document", "Export");
}

static void new_section_action(GSimpleAction *action, GVariant *parameter, gpointer user_data) {
  AppState *state = user_data;
  (void)action;
  (void)parameter;
  gtk_stack_set_visible_child_name(state->main_stack, "document");
}

static void review_proposals_action(GSimpleAction *action, GVariant *parameter, gpointer user_data) {
  AppState *state = user_data;
  (void)action;
  (void)parameter;
  gtk_stack_set_visible_child_name(state->main_stack, "proposals");
}

static void append_sidebar_row(GtkListBox *list, const char *page_name, const char *title, const char *subtitle) {
  GtkWidget *row = gtk_list_box_row_new();
  GtkWidget *content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
  set_margin(content, 8);
  append_label(content, title);
  append_label(content, subtitle);
  g_object_set_data_full(G_OBJECT(row), "native-page", g_strdup(page_name), g_free);
  gtk_list_box_row_set_child(GTK_LIST_BOX_ROW(row), content);
  gtk_list_box_append(list, row);
}

static const char *json_string_member(JsonObject *object, const char *name, const char *fallback) {
  if (object == NULL || !json_object_has_member(object, name)) {
    return fallback;
  }
  JsonNode *node = json_object_get_member(object, name);
  if (node == NULL || json_node_get_node_type(node) != JSON_NODE_VALUE || json_node_get_value_type(node) != G_TYPE_STRING) {
    return fallback;
  }
  return json_node_get_string(node);
}

static void clear_list_box(GtkListBox *list) {
  GtkWidget *child = gtk_widget_get_first_child(GTK_WIDGET(list));
  while (child != NULL) {
    gtk_list_box_remove(list, child);
    child = gtk_widget_get_first_child(GTK_WIDGET(list));
  }
}

static void apply_reference_snapshot(AppState *state, const char *json_text) {
  JsonParser *parser = json_parser_new();
  JsonNode *root_node;
  JsonObject *root;
  JsonArray *documents;
  if (state->document_list == NULL || !json_parser_load_from_data(parser, json_text, -1, NULL)) {
    g_object_unref(parser);
    return;
  }
  root_node = json_parser_get_root(parser);
  if (root_node == NULL || json_node_get_node_type(root_node) != JSON_NODE_OBJECT) {
    g_object_unref(parser);
    return;
  }
  root = json_node_get_object(root_node);
  documents = json_object_get_array_member(root, "documents");
  if (documents == NULL) {
    g_object_unref(parser);
    return;
  }
  clear_list_box(state->document_list);
  for (guint index = 0; index < json_array_get_length(documents); index++) {
    JsonObject *document = json_array_get_object_element(documents, index);
    append_sidebar_row(
      state->document_list,
      "document",
      json_string_member(document, "title", "Untitled document"),
      json_string_member(document, "subtitle", "Live document")
    );
  }
  if (state->status_label != NULL) {
    gtk_label_set_text(state->status_label, "Loaded native JSON snapshot into GTK list rows.");
  }
  gtk_list_box_select_row(state->document_list, gtk_list_box_get_row_at_index(state->document_list, 0));
  g_object_unref(parser);
}

static void sidebar_row_selected(GtkListBox *list, GtkListBoxRow *row, gpointer user_data) {
  AppState *state = user_data;
  const char *page_name;
  (void)list;
  if (row == NULL) {
    return;
  }
  page_name = g_object_get_data(G_OBJECT(row), "native-page");
  if (page_name != NULL) {
    gtk_stack_set_visible_child_name(state->main_stack, page_name);
  }
}

static GtkWidget *make_text_editor(const char *text) {
  GtkWidget *scroller = gtk_scrolled_window_new();
  GtkWidget *text_view = gtk_text_view_new();
  GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(text_view));
  gtk_text_view_set_wrap_mode(GTK_TEXT_VIEW(text_view), GTK_WRAP_WORD_CHAR);
  gtk_text_buffer_set_text(buffer, text, -1);
  gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(scroller), text_view);
  gtk_widget_set_size_request(scroller, -1, 160);
  gtk_widget_set_hexpand(scroller, TRUE);
  return scroller;
}

static GtkWidget *make_document_page(AppState *state) {
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12);
  GtkWidget *document_list = gtk_list_box_new();
  GtkWidget *section = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  GtkWidget *section_heading = gtk_label_new("Editable Section");
  GtkWidget *expander = gtk_expander_new("Edit as Proposal");
  GtkWidget *section_box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  GtkWidget *status = gtk_label_new("Waiting for native document state.");
  set_margin(box, 18);
  gtk_label_set_xalign(GTK_LABEL(section_heading), 0.0f);
  gtk_widget_add_css_class(section_heading, "heading");
  gtk_label_set_xalign(GTK_LABEL(status), 0.0f);
  gtk_list_box_set_selection_mode(GTK_LIST_BOX(document_list), GTK_SELECTION_SINGLE);
  append_sidebar_row(GTK_LIST_BOX(document_list), "document", "Reference Constitution", "Native document list row");
  append_sidebar_row(GTK_LIST_BOX(document_list), "document", "Supporting Memo", "Full-row selectable supporting document");
  state->document_list = GTK_LIST_BOX(document_list);
  state->status_label = GTK_LABEL(status);
  gtk_box_append(GTK_BOX(box), document_list);
  gtk_box_append(GTK_BOX(box), status);
  gtk_box_append(GTK_BOX(section), section_heading);
  append_label(section, "Each section behaves like an independently editable mini-document while resting as readable document text.");
  gtk_box_append(GTK_BOX(section_box), make_text_editor("Edit this section in place, then save it as a proposal."));
  gtk_box_append(GTK_BOX(section_box), gtk_button_new_with_label("Save Proposal"));
  gtk_expander_set_child(GTK_EXPANDER(expander), section_box);
  gtk_box_append(GTK_BOX(section), expander);
  gtk_box_append(GTK_BOX(box), section);
  return box;
}

static GtkWidget *make_proposals_page(void) {
  GtkWidget *list = gtk_list_box_new();
  set_margin(list, 18);
  gtk_list_box_set_selection_mode(GTK_LIST_BOX(list), GTK_SELECTION_SINGLE);
  append_sidebar_row(GTK_LIST_BOX(list), "proposals", "Notice and hearing", "Review queue");
  append_sidebar_row(GTK_LIST_BOX(list), "proposals", "Archive duty", "Draft proposal");
  return list;
}

static GtkWidget *make_collaborators_page(void) {
  GtkWidget *list = gtk_list_box_new();
  set_margin(list, 18);
  gtk_list_box_set_selection_mode(GTK_LIST_BOX(list), GTK_SELECTION_SINGLE);
  append_sidebar_row(GTK_LIST_BOX(list), "people", "Aster Vale", "Editor");
  append_sidebar_row(GTK_LIST_BOX(list), "people", "Lin Arbor", "Reviewer");
  return list;
}

static GtkWidget *make_inspector_section(const char *title, const char *body) {
  GtkWidget *section = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  GtkWidget *heading = gtk_label_new(title);
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  gtk_label_set_xalign(GTK_LABEL(heading), 0.0f);
  gtk_widget_add_css_class(heading, "heading");
  gtk_box_append(GTK_BOX(section), heading);
  append_label(box, body);
  gtk_box_append(GTK_BOX(section), box);
  return section;
}

static GtkWidget *make_inspector_pane(void) {
  GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  GtkWidget *switcher = gtk_stack_switcher_new();
  GtkWidget *stack = gtk_stack_new();
  GtkWidget *section = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  GtkWidget *preview = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  GtkWidget *review = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8);
  set_margin(box, 12);
  set_margin(section, 6);
  set_margin(preview, 6);
  set_margin(review, 6);
  gtk_box_append(GTK_BOX(section), make_inspector_section("Section", "Status: Draft\nReview: 2 proposals"));
  gtk_box_append(GTK_BOX(preview), make_inspector_section("Preview", "Show rendered document context without overlay drawers."));
  gtk_box_append(GTK_BOX(review), make_inspector_section("Review", "Use native right-pane modes for review support."));
  gtk_stack_add_titled(GTK_STACK(stack), section, "section", "Section");
  gtk_stack_add_titled(GTK_STACK(stack), preview, "preview", "Preview");
  gtk_stack_add_titled(GTK_STACK(stack), review, "review", "Review");
  gtk_stack_switcher_set_stack(GTK_STACK_SWITCHER(switcher), GTK_STACK(stack));
  gtk_box_append(GTK_BOX(box), switcher);
  gtk_box_append(GTK_BOX(box), stack);
  return box;
}

static GtkWidget *make_preferences_page(void) {
  GtkWidget *paned = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);
  GtkWidget *stack = gtk_stack_new();
  GtkWidget *sidebar = gtk_stack_sidebar_new();
  GtkWidget *general = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
  GtkWidget *review = gtk_box_new(GTK_ORIENTATION_VERTICAL, 10);
  set_margin(general, 18);
  set_margin(review, 18);
  append_label(general, "Autosave proposals");
  gtk_box_append(GTK_BOX(general), gtk_check_button_new_with_label("Sync review state"));
  append_label(review, "Review mode");
  gtk_box_append(GTK_BOX(review), gtk_check_button_new_with_label("Show inspector"));
  append_label(review, "Secret example");
  gtk_box_append(GTK_BOX(review), make_password_entry("token or local secret"));
  gtk_stack_add_titled(GTK_STACK(stack), general, "general", "General");
  gtk_stack_add_titled(GTK_STACK(stack), review, "review", "Review");
  gtk_stack_sidebar_set_stack(GTK_STACK_SIDEBAR(sidebar), GTK_STACK(stack));
  gtk_paned_set_start_child(GTK_PANED(paned), sidebar);
  gtk_paned_set_end_child(GTK_PANED(paned), stack);
  gtk_paned_set_position(GTK_PANED(paned), 160);
  return paned;
}

static void activate(GtkApplication *app, gpointer user_data) {
  AppState *state = user_data;
  GtkWidget *window = gtk_application_window_new(app);
  GtkWidget *header = gtk_header_bar_new();
  GtkWidget *header_search = gtk_search_entry_new();
  GtkWidget *import_button = make_icon_button("document-open-symbolic", "Import supporting document");
  GtkWidget *new_button = make_icon_button("document-new-symbolic", "New section");
  GtkWidget *review_button = make_icon_button("view-list-symbolic", "Review proposals");
  GtkWidget *export_button = make_icon_button("document-save-as-symbolic", "Export document");
  GtkWidget *body = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);
  GtkWidget *sidebar = gtk_list_box_new();
  GtkWidget *center = gtk_paned_new(GTK_ORIENTATION_HORIZONTAL);
  GtkWidget *inspector = make_inspector_pane();
  const char *new_accels[] = {"<Primary>n", NULL};
  const char *export_accels[] = {"<Primary>e", NULL};
  const GActionEntry app_actions[] = {
    {"import-document", import_document_action, NULL, NULL, NULL},
    {"export-document", export_document_action, NULL, NULL, NULL},
    {"new-section", new_section_action, NULL, NULL, NULL},
    {"review-proposals", review_proposals_action, NULL, NULL, NULL}
  };

  (void)wizardry_app_ir;
  state->window = GTK_WINDOW(window);

  gtk_window_set_title(GTK_WINDOW(window), "$window_title");
  gtk_window_set_default_size(GTK_WINDOW(window), 960, 640);
  gtk_window_set_titlebar(GTK_WINDOW(window), header);
  g_action_map_add_action_entries(G_ACTION_MAP(app), app_actions, G_N_ELEMENTS(app_actions), state);
  gtk_application_set_accels_for_action(app, "app.new-section", new_accels);
  gtk_application_set_accels_for_action(app, "app.export-document", export_accels);
  gtk_widget_set_size_request(header_search, 220, -1);
  gtk_actionable_set_action_name(GTK_ACTIONABLE(import_button), "app.import-document");
  gtk_actionable_set_action_name(GTK_ACTIONABLE(new_button), "app.new-section");
  gtk_actionable_set_action_name(GTK_ACTIONABLE(review_button), "app.review-proposals");
  gtk_actionable_set_action_name(GTK_ACTIONABLE(export_button), "app.export-document");
  gtk_header_bar_pack_start(GTK_HEADER_BAR(header), import_button);
  gtk_header_bar_pack_start(GTK_HEADER_BAR(header), new_button);
  gtk_header_bar_pack_start(GTK_HEADER_BAR(header), review_button);
  gtk_header_bar_pack_end(GTK_HEADER_BAR(header), export_button);
  gtk_header_bar_pack_end(GTK_HEADER_BAR(header), header_search);

  state->main_stack = GTK_STACK(gtk_stack_new());
  gtk_stack_set_transition_type(state->main_stack, GTK_STACK_TRANSITION_TYPE_CROSSFADE);
  gtk_stack_add_titled(state->main_stack, make_document_page(state), "document", "Document");
  gtk_stack_add_titled(state->main_stack, make_proposals_page(), "proposals", "Proposals");
  gtk_stack_add_titled(state->main_stack, make_collaborators_page(), "people", "Collaborators");
  gtk_stack_add_titled(state->main_stack, make_preferences_page(), "preferences", "Preferences");
  gtk_stack_set_visible_child_name(state->main_stack, "document");

  set_margin(sidebar, 12);
  gtk_list_box_set_selection_mode(GTK_LIST_BOX(sidebar), GTK_SELECTION_BROWSE);
  append_sidebar_row(GTK_LIST_BOX(sidebar), "document", "Reference Constitution", "Document");
  append_sidebar_row(GTK_LIST_BOX(sidebar), "proposals", "Proposals", "Review queue");
  append_sidebar_row(GTK_LIST_BOX(sidebar), "people", "Collaborators", "People");
  append_sidebar_row(GTK_LIST_BOX(sidebar), "preferences", "Preferences", "Settings");
  g_signal_connect(sidebar, "row-selected", G_CALLBACK(sidebar_row_selected), state);
  gtk_list_box_select_row(GTK_LIST_BOX(sidebar), gtk_list_box_get_row_at_index(GTK_LIST_BOX(sidebar), 0));

  gtk_paned_set_start_child(GTK_PANED(center), GTK_WIDGET(state->main_stack));
  gtk_paned_set_end_child(GTK_PANED(center), inspector);
  gtk_paned_set_position(GTK_PANED(center), 620);
  gtk_paned_set_start_child(GTK_PANED(body), sidebar);
  gtk_paned_set_end_child(GTK_PANED(body), center);
  gtk_paned_set_position(GTK_PANED(body), 230);
  gtk_window_set_child(GTK_WINDOW(window), body);
  apply_reference_snapshot(state, reference_snapshot_json);
  gtk_window_present(GTK_WINDOW(window));
}

int main(int argc, char **argv) {
  AppState state = {0};
  GtkApplication *app = gtk_application_new("app.$app_id", G_APPLICATION_DEFAULT_FLAGS);
  g_signal_connect(app, "activate", G_CALLBACK(activate), &state);
  int status = g_application_run(G_APPLICATION(app), argc, argv);
  g_object_unref(app);
  return status;
}
EOF

printf 'status=ok\n'
printf 'ir=%s\n' "$ir_path"
printf 'macos=%s\n' "$macos_dir"
printf 'linux=%s\n' "$linux_dir"
