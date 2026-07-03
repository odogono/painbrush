# Toolbox surfaces share state

Paintbrush supports multiple Toolbox surfaces backed by one app-wide Toolbox state, so the existing floating panel and any future embedded document-window surface show and edit the same active tool, stroke, fill, transparency, and color choices. This preserves the current cross-document drawing behavior while removing the floating panel window controller as the logical owner of Toolbox state; per-document Toolbox state is intentionally left for a separate behavior-changing decision.
