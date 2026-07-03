# Toolbox surfaces share state

Paintbrush keeps `SWToolboxState` separate from Toolbox window-controller ownership so multiple Toolbox surfaces can be backed by an explicit state object. The floating Toolbox uses the app-wide shared Toolbox state, preserving the long-standing cross-document behavior when the Toolbox is a floating panel.

Docked document-window Toolbox surfaces are the exception recorded in ADR-0004: they use a document-owned Toolbox state for the current window session. Per-document docked state is not written into image files.
