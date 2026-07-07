# Changelog

## 2.3.0 - 2026-07-03

- Added an opt-in Dock Toolbox preference that embeds the Toolbox as a fixed left sidebar in document windows while keeping the floating Toolbox as the default.
- Made docked Toolboxes use per-document, session-only Toolbox state so selected tool, stroke, fill, transparency, and colors can diverge between open documents.
- Preserved floating Toolbox behavior with the shared app-wide Toolbox state, including promoting the active document's docked state back to the floating Toolbox when undocking.
- Added drag-to-insert image support that creates movable Selections at the drop point while preserving paste-style transparency behavior.
- Raised the minimum supported macOS version to 11.0 and added native WebP import/drag support while keeping export formats unchanged.
- Updated Toolbox architecture ADRs and added regression coverage for Toolbox state copying, independent document state, eyedropper color targeting, slider scroll targeting, and document-specific new-canvas background color.

## 2.2.1 - 2026-06-28

- Replaced the legacy `Test` `.octest`/`SenTestingKit` target with a modern XCTest bundle and shared `Test` scheme.
- Added focused bitmap regression coverage for `SWImageTools` creation, clearing, drawing, flipping, cropping, transparency stripping, and file-type mapping.
- Extracted selection bitmap lifecycle into the Swift `SWSelection` model with regression coverage for canvas selections, pasted selections, movement, commit, copy, clear, and background omission.
- Made oversized pasted images remain usable as live Selections clipped to the Canvas extent without resizing the Canvas, with regression coverage for orientation, move, copy, cancel, and clipped commit behavior.
- Moved Canvas undo snapshots into `SWImageDataSource` with regression coverage for drawing and resize undo/redo.
- Extracted the Toolbox into a reusable surface backed by shared app-wide Toolbox state, preserving the existing floating panel while preparing for future embedded hosts.
- Updated the `Paintbrush-AppStore` target to build with the modern macOS SDK settings while preserving the `APPSTORE` variant behavior.
- Added `CONTEXT.md` with the canonical `Canvas` glossary term for the user-editable bitmap surface.

## 2.2.0 - 2026-06-26

- Reorganized the legacy flat repository into a modern app layout under `Paintbrush/`, `PaintbrushTests/`, `Frameworks/`, and `Archive/Unreferenced/`.
- Renamed `Paintbrush2.xcodeproj` to `Paintbrush.xcodeproj` and removed tracked legacy Xcode user metadata.
- Vendored Sparkle 2.9.3 as `Frameworks/Sparkle.framework` while keeping the transitional `SUUpdater` integration in place.
- Updated the main `Paintbrush` target to build on current Xcode with macOS SDK settings, a macOS 10.13 deployment target, updated app metadata paths, framework search paths, and Sparkle runpath support.
- Refreshed active localized XIB metadata so modern `ibtool` can compile the main app resources.
- Added repo-level agent documentation and an ADR recording the project-layout modernization decision.
