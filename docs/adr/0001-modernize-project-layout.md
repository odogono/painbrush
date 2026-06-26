# Modernize project layout

Paintbrush now uses a modern app repository layout instead of keeping all source and resource files at the repository root. The main app target vendors Sparkle 2.9.3 and builds against macOS 10.13 or newer because Sparkle 2.9.3 supports macOS 10.13+ and the legacy flat Xcode project could not build on current Xcode without updating its project paths, XIB metadata, and SDK settings.
