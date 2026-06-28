# Changelog

## 2.2.1 - 2026-06-28

- Replaced the legacy `Test` `.octest`/`SenTestingKit` target with a modern XCTest bundle and shared `Test` scheme.
- Added focused bitmap regression coverage for `SWImageTools` creation, clearing, drawing, flipping, cropping, transparency stripping, and file-type mapping.
- Updated the `Paintbrush-AppStore` target to build with the modern macOS SDK settings while preserving the `APPSTORE` variant behavior.
- Added `CONTEXT.md` with the canonical `Canvas` glossary term for the user-editable bitmap surface.

## 2.2.0 - 2026-06-26

- Reorganized the legacy flat repository into a modern app layout under `Paintbrush/`, `PaintbrushTests/`, `Frameworks/`, and `Archive/Unreferenced/`.
- Renamed `Paintbrush2.xcodeproj` to `Paintbrush.xcodeproj` and removed tracked legacy Xcode user metadata.
- Vendored Sparkle 2.9.3 as `Frameworks/Sparkle.framework` while keeping the transitional `SUUpdater` integration in place.
- Updated the main `Paintbrush` target to build on current Xcode with macOS SDK settings, a macOS 10.13 deployment target, updated app metadata paths, framework search paths, and Sparkle runpath support.
- Refreshed active localized XIB metadata so modern `ibtool` can compile the main app resources.
- Added repo-level agent documentation and an ADR recording the project-layout modernization decision.
