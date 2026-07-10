# Move-style Selection transfer

Paintbrush treats cross-document Selection transfer as a move rather than a copy: a successful drop clears the source Selection and creates a live Selection in the target document. This is deliberately different from clipboard copy/paste because the user gesture removes the Selection from the source window; source undo therefore needs to restore transient live Selection state, not just committed Canvas pixels.
