# Docked Toolbox hosting

Paintbrush supports an opt-in docked Toolbox mode that embeds a Toolbox surface inside every document window as a fixed-width left sidebar. The preference is app-wide and persisted, while docked Toolbox visibility is app-wide for the current session only.

Floating Toolbox behavior remains the default and continues to use the app-wide Toolbox state from ADR-0003. Docked mode gives each document window its own window-session-only Toolbox state, including selected tool, stroke width, fill mode, selection transparency, foreground color, and background color.

When docked mode is enabled, currently open documents copy the app-wide floating Toolbox state and then diverge independently. New documents opened while docked use factory Toolbox defaults. When docked mode is disabled, the active document's Toolbox state is promoted back into the app-wide floating Toolbox state.

Per-document docked Toolbox state is not persisted into image files or app session restoration.
