/**
 * Paintbrush
 * Copyright (C) 2007-2019  Michael Schreiber
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import AppKit

@objcMembers
public final class SWSelectionSnapshot: NSObject {
    fileprivate let baseRect: NSRect
    fileprivate let delta: NSPoint
    fileprivate let omitBackground: Bool
    fileprivate let transparentImage: NSBitmapImageRep
    fileprivate let opaqueImage: NSBitmapImageRep
    fileprivate let originalCanvasImage: NSBitmapImageRep?

    fileprivate init(baseRect: NSRect, delta: NSPoint, omitBackground: Bool, transparentImage: NSBitmapImageRep, opaqueImage: NSBitmapImageRep, originalCanvasImage: NSBitmapImageRep?) {
        self.baseRect = baseRect
        self.delta = delta
        self.omitBackground = omitBackground
        self.transparentImage = SWSelection.copyImage(transparentImage)
        self.opaqueImage = SWSelection.copyImage(opaqueImage)
        if let originalCanvasImage {
            self.originalCanvasImage = SWSelection.copyImage(originalCanvasImage)
        } else {
            self.originalCanvasImage = nil
        }

        super.init()
    }
}

@objcMembers
public final class SWSelection: NSObject {
    private var baseRect: NSRect
    private var delta = NSPoint.zero
    private var omitBackground: Bool
    private let transparentImage: NSBitmapImageRep
    private let opaqueImage: NSBitmapImageRep
    private var activeImage: NSBitmapImageRep
    private let originalCanvasImage: NSBitmapImageRep?

    private init(baseRect: NSRect, delta: NSPoint, omitBackground: Bool, transparentImage: NSBitmapImageRep, opaqueImage: NSBitmapImageRep, originalCanvasImage: NSBitmapImageRep?) {
        self.baseRect = baseRect
        self.delta = delta
        self.omitBackground = omitBackground
        if let originalCanvasImage {
            self.originalCanvasImage = SWSelection.copyImage(originalCanvasImage)
        } else {
            self.originalCanvasImage = nil
        }
        self.opaqueImage = SWSelection.copyImage(opaqueImage)
        self.transparentImage = SWSelection.copyImage(transparentImage)
        self.activeImage = omitBackground ? self.transparentImage : self.opaqueImage

        super.init()
    }

    private convenience init(sourceImage: NSBitmapImageRep, baseRect: NSRect, originalCanvasImage: NSBitmapImageRep?, backgroundColor: NSColor, omitBackground: Bool) {
        let opaqueImage = SWSelection.copyImage(sourceImage)
        let transparentImage = SWSelection.copyImage(sourceImage)
        SWSelection.stripImage(transparentImage, of: backgroundColor)
        self.init(
            baseRect: baseRect,
            delta: .zero,
            omitBackground: omitBackground,
            transparentImage: transparentImage,
            opaqueImage: opaqueImage,
            originalCanvasImage: originalCanvasImage
        )
    }

    @objc(initWithCanvasImage:rect:backgroundColor:omitBackground:)
    public convenience init(canvasImage: NSBitmapImageRep, rect: NSRect, backgroundColor: NSColor, omitBackground: Bool) {
        // Snapshot and crop the unmodified canvas before filling the source rect below.
        self.init(
            sourceImage: SWSelection.cropImage(canvasImage, to: rect),
            baseRect: rect,
            originalCanvasImage: SWSelection.copyImage(canvasImage),
            backgroundColor: backgroundColor,
            omitBackground: omitBackground
        )

        SWSelection.fill(rect, in: canvasImage, with: backgroundColor)
    }

    @objc(initWithPastedImage:origin:backgroundColor:omitBackground:)
    public convenience init(pastedImage: NSBitmapImageRep, origin: NSPoint, backgroundColor: NSColor, omitBackground: Bool) {
        self.init(
            sourceImage: pastedImage,
            baseRect: NSRect(origin: origin, size: pastedImage.size),
            originalCanvasImage: nil,
            backgroundColor: backgroundColor,
            omitBackground: omitBackground
        )
    }

    @objc(initWithSelectionSnapshot:)
    public convenience init(selectionSnapshot snapshot: SWSelectionSnapshot) {
        self.init(
            baseRect: snapshot.baseRect,
            delta: snapshot.delta,
            omitBackground: snapshot.omitBackground,
            transparentImage: snapshot.transparentImage,
            opaqueImage: snapshot.opaqueImage,
            originalCanvasImage: snapshot.originalCanvasImage
        )
    }

    public var hasOriginalCanvasImage: Bool {
        originalCanvasImage != nil
    }

    public var selectedImage: NSBitmapImageRep {
        activeImage
    }

    public var clippingRect: NSRect {
        var rect = baseRect
        rect.origin = currentOrigin
        return rect
    }

    public var currentOrigin: NSPoint {
        NSPoint(x: baseRect.origin.x + delta.x, y: baseRect.origin.y + delta.y)
    }

    @objc(moveByDeltaX:y:)
    public func moveBy(deltaX: CGFloat, y deltaY: CGFloat) {
        delta.x += deltaX
        delta.y += deltaY
    }

    public func setShouldOmitBackground(_ shouldOmitBackground: Bool) {
        omitBackground = shouldOmitBackground
        activeImage = omitBackground ? transparentImage : opaqueImage
    }

    public func tiffRepresentationForPasteboard() -> Data {
        let image = SWSelection.copyImage(activeImage)
        SWSelection.flipImageVertically(image)
        return image.tiffRepresentation ?? Data()
    }

    public func selectionSnapshot() -> SWSelectionSnapshot {
        SWSelectionSnapshot(
            baseRect: baseRect,
            delta: delta,
            omitBackground: omitBackground,
            transparentImage: transparentImage,
            opaqueImage: opaqueImage,
            originalCanvasImage: originalCanvasImage
        )
    }

    public func clearSelectedImage() {
        activeImage = SWSelection.makeImage(size: activeImage.size)
    }

    @objc(drawInImage:)
    public func draw(in image: NSBitmapImageRep) {
        SWSelection.draw(activeImage, in: image, at: currentOrigin, compositingOver: true)
    }

    @objc(commitToCanvasImage:)
    public func commit(toCanvasImage canvasImage: NSBitmapImageRep) {
        draw(in: canvasImage)
    }

    @objc(restoreOriginalCanvasToImage:)
    public func restoreOriginalCanvas(to canvasImage: NSBitmapImageRep) {
        guard let originalCanvasImage else { return }
        SWSelection.draw(originalCanvasImage, in: canvasImage, at: .zero, compositingOver: false)
    }

    fileprivate static func makeImage(size: NSSize) -> NSBitmapImageRep {
        let image = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        )!
        clear(image)
        return image
    }

    fileprivate static func copyImage(_ image: NSBitmapImageRep) -> NSBitmapImageRep {
        cropImage(image, to: NSRect(origin: .zero, size: NSSize(width: image.pixelsWide, height: image.pixelsHigh)))
    }

    private static func cropImage(_ image: NSBitmapImageRep, to rect: NSRect) -> NSBitmapImageRep {
        let croppedImage = makeImage(size: rect.size)
        copyPixels(
            from: image,
            rect: bitmapRect(forDisplayRect: rect, in: image),
            to: croppedImage,
            at: .zero,
            compositingOver: false
        )
        return croppedImage
    }

    private static func clear(_ image: NSBitmapImageRep) {
        guard let data = image.bitmapData else { return }
        for row in 0..<image.pixelsHigh {
            let rowStart = data.advanced(by: row * image.bytesPerRow)
            memset(rowStart, 0, image.pixelsWide * image.samplesPerPixel)
        }
    }

    private static func draw(_ source: NSBitmapImageRep, in destination: NSBitmapImageRep, at point: NSPoint, compositingOver: Bool) {
        copyPixels(
            from: source,
            rect: NSRect(origin: .zero, size: NSSize(width: source.pixelsWide, height: source.pixelsHigh)),
            to: destination,
            at: bitmapPoint(forDisplayPoint: point, sourceHeight: source.pixelsHigh, in: destination),
            compositingOver: compositingOver
        )
    }

    private static func channelByte(_ component: CGFloat) -> UInt8 {
        UInt8(min(255.0, max(0.0, round(component * 255.0))))
    }

    private static func fill(_ rect: NSRect, in image: NSBitmapImageRep, with color: NSColor) {
        guard let convertedColor = color.usingColorSpaceName(.calibratedRGB),
              let bitmapData = image.bitmapData
        else { return }

        // Clamp before narrowing: converting a wide-gamut color to calibratedRGB
        // can yield components slightly outside [0, 1], which would trap UInt8(_:).
        let red = channelByte(convertedColor.redComponent)
        let green = channelByte(convertedColor.greenComponent)
        let blue = channelByte(convertedColor.blueComponent)
        let alpha = channelByte(convertedColor.alphaComponent)
        let bitmapRect = bitmapRect(forDisplayRect: rect, in: image)
        let minX = max(0, Int(bitmapRect.origin.x))
        let minY = max(0, Int(bitmapRect.origin.y))
        let maxX = min(image.pixelsWide, Int(bitmapRect.origin.x + bitmapRect.size.width))
        let maxY = min(image.pixelsHigh, Int(bitmapRect.origin.y + bitmapRect.size.height))

        for y in minY..<maxY {
            var pixel = bitmapData.advanced(by: y * image.bytesPerRow + minX * image.samplesPerPixel)
            for _ in minX..<maxX {
                pixel[0] = red
                pixel[1] = green
                pixel[2] = blue
                pixel[3] = alpha
                pixel = pixel.advanced(by: image.samplesPerPixel)
            }
        }
    }

    private static func bitmapRect(forDisplayRect rect: NSRect, in image: NSBitmapImageRep) -> NSRect {
        NSRect(
            x: rect.origin.x,
            y: CGFloat(image.pixelsHigh) - rect.origin.y - rect.size.height,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    private static func bitmapPoint(forDisplayPoint point: NSPoint, sourceHeight: Int, in image: NSBitmapImageRep) -> NSPoint {
        NSPoint(
            x: point.x,
            y: CGFloat(image.pixelsHigh - sourceHeight) - point.y
        )
    }

    private static func copyPixels(
        from source: NSBitmapImageRep,
        rect: NSRect,
        to destination: NSBitmapImageRep,
        at point: NSPoint,
        compositingOver: Bool
    ) {
        guard let sourceData = source.bitmapData,
              let destinationData = destination.bitmapData
        else { return }

        let sourceMinX = Int(rect.origin.x)
        let sourceMinY = Int(rect.origin.y)
        let width = Int(rect.size.width)
        let height = Int(rect.size.height)
        let destinationMinX = Int(point.x)
        let destinationMinY = Int(point.y)

        // Clamp the X span once instead of bounds-checking every pixel in the inner loop.
        let xStart = max(0, -sourceMinX, -destinationMinX)
        let xEnd = min(width, source.pixelsWide - sourceMinX, destination.pixelsWide - destinationMinX)
        if xStart >= xEnd {
            return
        }

        for y in 0..<height {
            let sourceY = sourceMinY + y
            let destinationY = destinationMinY + y
            if sourceY < 0 || sourceY >= source.pixelsHigh || destinationY < 0 || destinationY >= destination.pixelsHigh {
                continue
            }

            for x in xStart..<xEnd {
                let sourceX = sourceMinX + x
                let destinationX = destinationMinX + x

                let sourcePixel = sourceData.advanced(by: sourceY * source.bytesPerRow + sourceX * source.samplesPerPixel)
                if compositingOver && sourcePixel[3] == 0 {
                    continue
                }

                let destinationPixel = destinationData.advanced(by: destinationY * destination.bytesPerRow + destinationX * destination.samplesPerPixel)
                destinationPixel[0] = sourcePixel[0]
                destinationPixel[1] = sourcePixel[1]
                destinationPixel[2] = sourcePixel[2]
                destinationPixel[3] = sourcePixel[3]
            }
        }
    }

    private static func stripImage(_ image: NSBitmapImageRep, of color: NSColor) {
        guard let convertedColor = color.usingColorSpaceName(.calibratedRGB),
              let bitmapData = image.bitmapData
        else { return }

        let red = Int(round(convertedColor.redComponent * 255.0))
        let green = Int(round(convertedColor.greenComponent * 255.0))
        let blue = Int(round(convertedColor.blueComponent * 255.0))
        let alpha = Int(round(convertedColor.alphaComponent * 255.0))

        for row in 0..<image.pixelsHigh {
            var pixel = bitmapData.advanced(by: row * image.bytesPerRow)
            for _ in 0..<image.pixelsWide {
                let pixelRed = Int(pixel[0])
                let pixelGreen = Int(pixel[1])
                let pixelBlue = Int(pixel[2])
                let pixelAlpha = Int(pixel[3])

                if (pixelAlpha == 0 && alpha == 0) ||
                    (pixelRed == red && pixelGreen == green && pixelBlue == blue && pixelAlpha == alpha) {
                    pixel[0] = 0
                    pixel[1] = 0
                    pixel[2] = 0
                    pixel[3] = 0
                }

                pixel = pixel.advanced(by: image.samplesPerPixel)
            }
        }
    }

    private static func flipImageVertically(_ image: NSBitmapImageRep) {
        guard let data = image.bitmapData else { return }

        let bytesPerRow = image.bytesPerRow
        let scratch = UnsafeMutablePointer<UInt8>.allocate(capacity: bytesPerRow)
        defer { scratch.deallocate() }

        for y in 0..<(image.pixelsHigh / 2) {
            let topRow = data.advanced(by: y * bytesPerRow)
            let bottomRow = data.advanced(by: (image.pixelsHigh - y - 1) * bytesPerRow)
            memcpy(scratch, topRow, bytesPerRow)
            memcpy(topRow, bottomRow, bytesPerRow)
            memcpy(bottomRow, scratch, bytesPerRow)
        }
    }
}
