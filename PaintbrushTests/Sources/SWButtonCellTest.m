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

#import <XCTest/XCTest.h>
#import "SWButtonCell.h"

static NSMutableArray *PBTestNamedImages;

static NSImage *PBTransparentImage(NSSize size)
{
    NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                     pixelsWide:size.width
                                                                     pixelsHigh:size.height
                                                                  bitsPerSample:8
                                                                samplesPerPixel:4
                                                                       hasAlpha:YES
                                                                       isPlanar:NO
                                                                 colorSpaceName:NSCalibratedRGBColorSpace
                                                                    bytesPerRow:0
                                                                   bitsPerPixel:32] autorelease];
    memset([rep bitmapData], 0, [rep bytesPerRow] * [rep pixelsHigh]);

    NSImage *image = [[[NSImage alloc] initWithSize:size] autorelease];
    [image addRepresentation:rep];
    return image;
}

static NSImage *PBToolImage(void)
{
    NSImage *image = PBTransparentImage(NSMakeSize(32.0, 32.0));
    [image lockFocus];
    [[NSColor redColor] setFill];
    NSRectFill(NSMakeRect(12.0, 12.0, 8.0, 8.0));
    [image unlockFocus];
    return image;
}

static NSBitmapImageRep *PBBitmapRep(NSImage *image)
{
    XCTAssertNotNil(image);
    NSSize size = [image size];
    XCTAssertGreaterThan(size.width, 0.0);
    XCTAssertGreaterThan(size.height, 0.0);
    if (size.width <= 0.0 || size.height <= 0.0) {
        return nil;
    }
    NSBitmapImageRep *rep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
                                                                     pixelsWide:size.width
                                                                     pixelsHigh:size.height
                                                                  bitsPerSample:8
                                                                samplesPerPixel:4
                                                                       hasAlpha:YES
                                                                       isPlanar:NO
                                                                 colorSpaceName:NSCalibratedRGBColorSpace
                                                                    bytesPerRow:0
                                                                   bitsPerPixel:32] autorelease];
    memset([rep bitmapData], 0, [rep bytesPerRow] * [rep pixelsHigh]);

    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:rep]];
    [image drawInRect:NSMakeRect(0.0, 0.0, size.width, size.height)
             fromRect:NSZeroRect
            operation:NSCompositingOperationSourceOver
             fraction:1.0];
    [NSGraphicsContext restoreGraphicsState];

    return rep;
}

static unsigned char *PBPixelAt(NSBitmapImageRep *image, NSInteger x, NSInteger y)
{
    return [image bitmapData] + (y * [image bytesPerRow]) + (x * [image samplesPerPixel]);
}

@interface SWButtonCellTest : XCTestCase

@end

@implementation SWButtonCellTest

- (void)setUp
{
    [super setUp];
    if (!PBTestNamedImages) {
        PBTestNamedImages = [[NSMutableArray alloc] init];
    }

    NSImage *pressedImage = PBTransparentImage(NSMakeSize(32.0, 32.0));
    [pressedImage setName:@"pressedsmall.png"];
    [PBTestNamedImages addObject:pressedImage];

    NSImage *hoverImage = PBTransparentImage(NSMakeSize(32.0, 32.0));
    [hoverImage setName:@"hoveredsmall.png"];
    [PBTestNamedImages addObject:hoverImage];
}

- (void)testGeneratedStateImagesPreserveTransparentCorners
{
    NSImage *toolImage = PBToolImage();
    XCTAssertEqual([toolImage size].width, 32.0);
    XCTAssertEqual([toolImage size].height, 32.0);

    SWButtonCell *cell = [[[SWButtonCell alloc] init] autorelease];
    [cell setImage:toolImage];
    XCTAssertNotNil([cell image]);
    XCTAssertEqual([[cell image] size].width, 32.0);
    XCTAssertEqual([[cell image] size].height, 32.0);

    NSImage *alternateImage = [cell alternateImage];
    XCTAssertNotNil(alternateImage, @"pressed state image should be generated");
    NSBitmapImageRep *alternateRep = PBBitmapRep(alternateImage);
    unsigned char *alternateCorner = PBPixelAt(alternateRep, 0, 0);

    XCTAssertEqual(alternateCorner[3], 0, @"pressed button artwork should not introduce an opaque black corner");

    [cell setIsHovered:YES];
    NSImage *hoverImage = [cell image];
    XCTAssertNotNil(hoverImage, @"hover state image should be generated");
    NSBitmapImageRep *hoverRep = PBBitmapRep(hoverImage);
    unsigned char *hoverCorner = PBPixelAt(hoverRep, 0, 0);

    XCTAssertEqual(hoverCorner[3], 0, @"hover button artwork should not introduce an opaque black corner");
}

@end
