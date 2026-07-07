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
import XCTest

final class SWSelectionTest: XCTestCase {
    func testSelectionFromCanvasCopiesPixelsAndClearsSourceRect() {
        let canvas = makeImage(width: 3, height: 3)
        setDisplayPixel(canvas, x: 1, y: 1, red: 255, green: 0, blue: 0, alpha: 255)

        let selection = SWSelection(
            canvasImage: canvas,
            rect: NSRect(x: 1, y: 1, width: 1, height: 1),
            backgroundColor: .white,
            omitBackground: false
        )

        XCTAssertTrue(selection.hasOriginalCanvasImage)
        assertDisplayPixel(selection.selectedImage, x: 0, y: 0, red: 255, green: 0, blue: 0, alpha: 255)
        assertDisplayPixel(canvas, x: 1, y: 1, red: 255, green: 255, blue: 255, alpha: 255)
    }

    func testSelectionMovesAndCommitsToCanvas() {
        let canvas = makeImage(width: 3, height: 3)
        setDisplayPixel(canvas, x: 0, y: 0, red: 0, green: 255, blue: 0, alpha: 255)

        let selection = SWSelection(
            canvasImage: canvas,
            rect: NSRect(x: 0, y: 0, width: 1, height: 1),
            backgroundColor: .white,
            omitBackground: false
        )
        selection.moveBy(deltaX: 2, y: 1)
        selection.commit(toCanvasImage: canvas)

        assertDisplayPixel(canvas, x: 0, y: 0, red: 255, green: 255, blue: 255, alpha: 255)
        assertDisplayPixel(canvas, x: 2, y: 1, red: 0, green: 255, blue: 0, alpha: 255)
    }

    func testSelectionCanToggleBackgroundOmission() {
        let canvas = makeImage(width: 2, height: 1)
        setDisplayPixel(canvas, x: 0, y: 0, red: 255, green: 255, blue: 255, alpha: 255)
        setDisplayPixel(canvas, x: 1, y: 0, red: 0, green: 0, blue: 0, alpha: 255)

        let selection = SWSelection(
            canvasImage: canvas,
            rect: NSRect(x: 0, y: 0, width: 2, height: 1),
            backgroundColor: .white,
            omitBackground: false
        )
        assertDisplayPixel(selection.selectedImage, x: 0, y: 0, red: 255, green: 255, blue: 255, alpha: 255)

        selection.setShouldOmitBackground(true)

        assertDisplayPixel(selection.selectedImage, x: 0, y: 0, red: 0, green: 0, blue: 0, alpha: 0)
        assertDisplayPixel(selection.selectedImage, x: 1, y: 0, red: 0, green: 0, blue: 0, alpha: 255)
    }

    func testPastedSelectionCommitsWithoutOriginalCanvasSnapshot() {
        let canvas = makeImage(width: 3, height: 3)
        let pastedImage = makeImage(width: 1, height: 1)
        setDisplayPixel(pastedImage, x: 0, y: 0, red: 0, green: 0, blue: 255, alpha: 255)

        let selection = SWSelection(
            pastedImage: pastedImage,
            origin: NSPoint(x: 1, y: 1),
            backgroundColor: .white,
            omitBackground: false
        )

        XCTAssertFalse(selection.hasOriginalCanvasImage)
        selection.commit(toCanvasImage: canvas)

        assertDisplayPixel(canvas, x: 1, y: 1, red: 0, green: 0, blue: 255, alpha: 255)
    }

    func testPastedSelectionTransparentPixelsDoNotOverwriteCanvasOnCommit() {
        let canvas = makeImage(width: 2, height: 1)
        setDisplayPixel(canvas, x: 0, y: 0, red: 0, green: 255, blue: 0, alpha: 255)
        setDisplayPixel(canvas, x: 1, y: 0, red: 255, green: 255, blue: 255, alpha: 255)
        let pastedImage = makeImage(width: 2, height: 1)
        setDisplayPixel(pastedImage, x: 0, y: 0, red: 0, green: 0, blue: 0, alpha: 0)
        setDisplayPixel(pastedImage, x: 1, y: 0, red: 0, green: 0, blue: 255, alpha: 128)

        let selection = SWSelection(
            pastedImage: pastedImage,
            origin: .zero,
            backgroundColor: .white,
            omitBackground: false
        )
        selection.commit(toCanvasImage: canvas)

        assertDisplayPixel(canvas, x: 0, y: 0, red: 0, green: 255, blue: 0, alpha: 255)
        assertDisplayPixel(canvas, x: 1, y: 0, red: 0, green: 0, blue: 255, alpha: 128)
    }

    func testPastedSelectionBackgroundOmissionDoesNotReplaceRealTransparency() {
        let canvas = makeImage(width: 3, height: 1)
        setDisplayPixel(canvas, x: 0, y: 0, red: 0, green: 255, blue: 0, alpha: 255)
        setDisplayPixel(canvas, x: 1, y: 0, red: 32, green: 64, blue: 96, alpha: 255)
        setDisplayPixel(canvas, x: 2, y: 0, red: 255, green: 255, blue: 255, alpha: 255)
        let pastedImage = makeImage(width: 3, height: 1)
        setDisplayPixel(pastedImage, x: 0, y: 0, red: 255, green: 255, blue: 255, alpha: 255)
        setDisplayPixel(pastedImage, x: 1, y: 0, red: 0, green: 0, blue: 0, alpha: 0)
        setDisplayPixel(pastedImage, x: 2, y: 0, red: 255, green: 0, blue: 0, alpha: 255)

        let selection = SWSelection(
            pastedImage: pastedImage,
            origin: .zero,
            backgroundColor: .white,
            omitBackground: true
        )
        selection.commit(toCanvasImage: canvas)

        assertDisplayPixel(canvas, x: 0, y: 0, red: 0, green: 255, blue: 0, alpha: 255)
        assertDisplayPixel(canvas, x: 1, y: 0, red: 32, green: 64, blue: 96, alpha: 255)
        assertDisplayPixel(canvas, x: 2, y: 0, red: 255, green: 0, blue: 0, alpha: 255)
    }

    func testPastedSelectionPreservesDisplayOrientationWhenCommitted() {
        let canvas = makeImage(width: 2, height: 2)
        let pastedImage = makeImage(width: 2, height: 2)
        setDisplayPixel(pastedImage, x: 0, y: 0, red: 255, green: 0, blue: 0, alpha: 255)
        setDisplayPixel(pastedImage, x: 1, y: 0, red: 0, green: 255, blue: 0, alpha: 255)
        setDisplayPixel(pastedImage, x: 0, y: 1, red: 0, green: 0, blue: 255, alpha: 255)
        setDisplayPixel(pastedImage, x: 1, y: 1, red: 255, green: 255, blue: 0, alpha: 255)

        let selection = SWSelection(
            pastedImage: pastedImage,
            origin: .zero,
            backgroundColor: .white,
            omitBackground: false
        )
        selection.commit(toCanvasImage: canvas)

        assertDisplayPixel(canvas, x: 0, y: 0, red: 255, green: 0, blue: 0, alpha: 255)
        assertDisplayPixel(canvas, x: 1, y: 0, red: 0, green: 255, blue: 0, alpha: 255)
        assertDisplayPixel(canvas, x: 0, y: 1, red: 0, green: 0, blue: 255, alpha: 255)
        assertDisplayPixel(canvas, x: 1, y: 1, red: 255, green: 255, blue: 0, alpha: 255)
    }

    func testSelectionPasteboardDataUsesExternalDisplayOrientation() {
        let pastedImage = makeImage(width: 2, height: 2)
        setDisplayPixel(pastedImage, x: 0, y: 0, red: 255, green: 0, blue: 0, alpha: 255)
        setDisplayPixel(pastedImage, x: 1, y: 0, red: 0, green: 255, blue: 0, alpha: 255)
        setDisplayPixel(pastedImage, x: 0, y: 1, red: 0, green: 0, blue: 255, alpha: 255)
        setDisplayPixel(pastedImage, x: 1, y: 1, red: 255, green: 255, blue: 0, alpha: 255)
        let selection = SWSelection(
            pastedImage: pastedImage,
            origin: .zero,
            backgroundColor: .white,
            omitBackground: false
        )

        let copiedImage = NSBitmapImageRep(data: selection.tiffRepresentationForPasteboard())!

        assertPixel(copiedImage, x: 0, y: 0, red: 255, green: 0, blue: 0, alpha: 255)
        assertPixel(copiedImage, x: 1, y: 0, red: 0, green: 255, blue: 0, alpha: 255)
        assertPixel(copiedImage, x: 0, y: 1, red: 0, green: 0, blue: 255, alpha: 255)
        assertPixel(copiedImage, x: 1, y: 1, red: 255, green: 255, blue: 0, alpha: 255)
    }

    private func makeImage(width: Int, height: Int) -> NSBitmapImageRep {
        let image = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        )!
        memset(image.bitmapData!, 0, image.bytesPerRow * image.pixelsHigh)
        return image
    }

    private func pixel(_ image: NSBitmapImageRep, x: Int, y: Int) -> UnsafeMutablePointer<UInt8> {
        image.bitmapData!.advanced(by: y * image.bytesPerRow + x * image.samplesPerPixel)
    }

    private func displayPixel(_ image: NSBitmapImageRep, x: Int, y: Int) -> UnsafeMutablePointer<UInt8> {
        pixel(image, x: x, y: image.pixelsHigh - y - 1)
    }

    private func setPixel(
        _ image: NSBitmapImageRep,
        x: Int,
        y: Int,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8
    ) {
        let pixel = pixel(image, x: x, y: y)
        pixel[0] = red
        pixel[1] = green
        pixel[2] = blue
        pixel[3] = alpha
    }

    private func setDisplayPixel(
        _ image: NSBitmapImageRep,
        x: Int,
        y: Int,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8
    ) {
        let pixel = displayPixel(image, x: x, y: y)
        pixel[0] = red
        pixel[1] = green
        pixel[2] = blue
        pixel[3] = alpha
    }

    private func assertPixel(
        _ image: NSBitmapImageRep,
        x: Int,
        y: Int,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pixel = pixel(image, x: x, y: y)
        XCTAssertEqual(pixel[0], red, "red channel mismatch at (\(x), \(y))", file: file, line: line)
        XCTAssertEqual(pixel[1], green, "green channel mismatch at (\(x), \(y))", file: file, line: line)
        XCTAssertEqual(pixel[2], blue, "blue channel mismatch at (\(x), \(y))", file: file, line: line)
        XCTAssertEqual(pixel[3], alpha, "alpha channel mismatch at (\(x), \(y))", file: file, line: line)
    }

    private func assertDisplayPixel(
        _ image: NSBitmapImageRep,
        x: Int,
        y: Int,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let pixel = displayPixel(image, x: x, y: y)
        XCTAssertEqual(pixel[0], red, "red channel mismatch at display (\(x), \(y))", file: file, line: line)
        XCTAssertEqual(pixel[1], green, "green channel mismatch at display (\(x), \(y))", file: file, line: line)
        XCTAssertEqual(pixel[2], blue, "blue channel mismatch at display (\(x), \(y))", file: file, line: line)
        XCTAssertEqual(pixel[3], alpha, "alpha channel mismatch at display (\(x), \(y))", file: file, line: line)
    }
}
