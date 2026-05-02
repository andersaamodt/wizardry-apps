# Native Desktop Reference App

This Forge starter is the canonical native-style reference for Wizardry native desktop apps.

The generated macOS app intentionally demonstrates platform-owned controls:

- `NavigationSplitView` with an AppKit-backed `NSOutlineView` source list for grouped sidebar selection.
- SwiftUI toolbar items, including a native `NSSearchField`, instead of a custom in-window top bar.
- macOS `Commands` and a `Settings` scene/window for menu and preferences behavior.
- `Form`, `GroupBox`, `List`, and `Table` instead of card-heavy custom selectors.
- A document surface that treats independently editable sections as first-class native document parts with in-place proposal editing.
- A proposal table for review queues instead of custom button cards.
- A collaborators list using native rows instead of isolated bubbles.
- Settings content in the Settings scene, with compact native form controls.
- Domain labels in user-facing copy, with implementation terms kept out of visible UI.

The generated GTK/Linux app demonstrates the equivalent native idiom:

- `GtkHeaderBar` for window actions.
- `GtkSearchEntry` in the headerbar for app/document search.
- `GtkListBox` sidebars and document/supporting-document lists with full-row selection.
- `GtkStack` and `GtkStackSwitcher` for center navigation and right-side inspector modes instead of duplicating sidebar state with `GtkNotebook`.
- `GtkStackSidebar` for preferences-style settings categories.
- `GtkTextView` for editable mini-document text and proposal edits.
- `GtkFrame`/form groups for settings and inspector sections instead of custom cards.

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

Keep this starter updated whenever Wizardry native desktop guidance changes.
