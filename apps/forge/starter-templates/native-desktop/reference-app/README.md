# __APP_NAME__

This Forge starter is the canonical Wizardry Native Desktop Reference App.

It is the native counterpart to the cross-platform `web/reference-app` starter: both demonstrate the same starting workflow shape, while this template converts chrome, sidebars, menus, settings, search, file actions, and editable content into platform-owned controls.

The generated macOS app intentionally demonstrates platform-owned controls:

- `NavigationSplitView` with an AppKit-backed `NSOutlineView` source list for grouped sidebar selection.
- SwiftUI toolbar items, including a native `NSSearchField`, instead of a custom in-window top bar.
- macOS `Commands`, standard menu placement, and a `Settings` scene/window for menu and preferences behavior.
- Platform-owned titlebar/window chrome with no hidden transparent titlebar.
- `Form`, `GroupBox`, `List`, and `Table` instead of card-heavy custom selectors.
- A document surface that treats independently editable sections as first-class native document parts with in-place proposal editing.
- A proposal table for review queues instead of custom button cards.
- A collaborators list using native rows instead of isolated bubbles.
- Settings content in the Settings scene, with compact native form controls.
- Native file panels for document import/export-style commands.
- Visible status feedback in the toolbar/status area.
- Domain labels in user-facing copy, with implementation terms kept out of visible UI.

The generated GTK/Linux app demonstrates the equivalent native idiom:

- `GtkHeaderBar` icon buttons with tooltips for window actions.
- `GtkSearchEntry` in the headerbar for app/document search.
- `GtkListBox` sidebars and document/supporting-document lists with full-row selection.
- `GtkStack` and `GtkStackSwitcher` for center navigation and right-side inspector modes instead of duplicating sidebar state with `GtkNotebook`.
- `GtkStackSidebar` for preferences-style settings categories.
- Readable mini-document text that expands into `GtkTextView` proposal edits on demand.
- Flat GTK sections, form rows, native file choosers, password entries, and app accelerators instead of custom card/chrome patterns.

Native conversion checklist covered by this reference:

1. Source lists use `NavigationSplitView` with native `List(selection:)` or AppKit `NSOutlineView` controls, depending on interaction complexity.
2. Document sections remain readable as a document while mini-doc sections are explicit editable parts.
3. Window actions live in `.toolbar`/`NSToolbar` on macOS and `GtkHeaderBar` on Linux.
4. Creation/settings surfaces use `Form`, `Section`, `LabeledContent`, `GtkStackSidebar`, and bounded controls.
5. Dense data uses `List`, `Table`, `NSOutlineView`, or `GtkListBox`, not card grids.
6. Sidebars are native source lists/listboxes, not custom scroll/button stacks.
7. Menu commands carry app state through Commands/native actions and validated toggles.
8. Preferences live in `Settings`, app-owned windows, or GTK stack/sidebar preference layouts.
9. UI labels use domain concepts rather than implementation/product terms.
10. Custom drawing is reserved for domain content; platform controls own chrome, lists, forms, and tables.
11. Backend/process work belongs on async tasks/subprocess callbacks, not AppKit/GTK main loops.
12. Import/export/path flows use native open/save panels or GTK file chooser dialogs.

Keep this starter updated whenever Wizardry native desktop guidance changes.

This project is licensed under GNU AGPL-3.0-or-later.
Additional terms apply; see WIZARDRY_ADDENDUM.md.
