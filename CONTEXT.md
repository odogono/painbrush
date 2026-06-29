# Paintbrush

Paintbrush is a simple bitmap editor for creating and editing images in a document window.

## Language

**Canvas**:
The user-editable bitmap surface in a Paintbrush document.
_Avoid_: Paint view, main image, buffer image

**Selection**:
The active movable bitmap region in a Paintbrush document, created from canvas pixels or pasted image data.
_Avoid_: Overlay selection, clipping rect
