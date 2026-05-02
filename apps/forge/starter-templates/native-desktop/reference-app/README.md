# Native Desktop Reference App

This Forge starter is the canonical native-style reference for Wizardry native desktop apps.

The generated macOS app intentionally demonstrates platform-owned controls:

- `NavigationSplitView` with `List(selection:)` for source-list selection.
- SwiftUI toolbar items instead of a custom in-window top bar.
- macOS `Commands` and a `Settings` scene for menu and preferences behavior.
- `Form`, `GroupBox`, `List`, and `Table` instead of card-heavy custom selectors.
- A document surface that treats independently editable sections as first-class native document parts.
- A proposal table for review queues instead of custom button cards.
- A collaborators list using native rows instead of isolated bubbles.
- Settings content in the Settings scene, with compact native form controls.
- Domain labels in user-facing copy, with implementation terms kept out of visible UI.

Native conversion checklist covered by this reference:

1. Source lists use `NavigationSplitView` and `List(selection:)`.
2. Document sections remain readable as a document while mini-doc sections are explicit editable parts.
3. Window actions live in `.toolbar` and Commands.
4. Creation/settings surfaces use `Form`, `Section`, `LabeledContent`, and bounded controls.
5. Dense data uses `List` or `Table`, not card grids.
6. Sidebars are native source lists, not custom scroll/button stacks.
7. Menu commands carry app state through Commands and native toggles.
8. Preferences live in `Settings`.
9. UI labels use domain concepts rather than implementation/product terms.
10. Custom drawing is reserved for domain content; platform controls own chrome, lists, forms, and tables.

Keep this starter updated whenever Wizardry native desktop guidance changes.
