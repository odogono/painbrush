# Data-source-owned Canvas history

Paintbrush stores committed Canvas pixels and Canvas size in `SWImageDataSource`, so undo snapshots for drawing and resize operations are captured and restored there as typed Canvas history snapshots.

`SWDocument` still owns AppKit undo integration through `NSUndoManager`. This preserves menu behavior, localized action names, redo registration, and the existing undo-limit preference while keeping the bitmap state transition close to the object that owns the bitmap storage.
