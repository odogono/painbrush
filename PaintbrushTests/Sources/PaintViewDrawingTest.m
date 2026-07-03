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


#import "PaintViewDrawingTest.h"
#import "SWBrushTool.h"
#import "SWImageDataSource.h"
#import "SWImageTools.h"
#import "SWButtonCell.h"
#import "SWSelectionTool.h"

static unsigned char *PBPixelAt(NSBitmapImageRep *image, NSInteger x, NSInteger y)
{
    return [image bitmapData] + (y * [image bytesPerRow]) + (x * [image samplesPerPixel]);
}

static void PBSetPixel(NSBitmapImageRep *image, NSInteger x, NSInteger y, unsigned char red, unsigned char green, unsigned char blue, unsigned char alpha)
{
    unsigned char *pixel = PBPixelAt(image, x, y);
    pixel[0] = red;
    pixel[1] = green;
    pixel[2] = blue;
    pixel[3] = alpha;
}

static NSInteger PBBitmapYForDisplayY(NSBitmapImageRep *image, NSInteger y)
{
    return [image pixelsHigh] - y - 1;
}

static void PBSetDisplayPixel(NSBitmapImageRep *image, NSInteger x, NSInteger y, unsigned char red, unsigned char green, unsigned char blue, unsigned char alpha)
{
    PBSetPixel(image, x, PBBitmapYForDisplayY(image, y), red, green, blue, alpha);
}

static void PBAssertPixelEquals(NSBitmapImageRep *image, NSInteger x, NSInteger y, unsigned char red, unsigned char green, unsigned char blue, unsigned char alpha)
{
    unsigned char *pixel = PBPixelAt(image, x, y);
    XCTAssertEqual(pixel[0], red, @"red channel mismatch at (%ld, %ld)", (long)x, (long)y);
    XCTAssertEqual(pixel[1], green, @"green channel mismatch at (%ld, %ld)", (long)x, (long)y);
    XCTAssertEqual(pixel[2], blue, @"blue channel mismatch at (%ld, %ld)", (long)x, (long)y);
    XCTAssertEqual(pixel[3], alpha, @"alpha channel mismatch at (%ld, %ld)", (long)x, (long)y);
}

static void PBAssertDisplayPixelEquals(NSBitmapImageRep *image, NSInteger x, NSInteger y, unsigned char red, unsigned char green, unsigned char blue, unsigned char alpha)
{
    PBAssertPixelEquals(image, x, PBBitmapYForDisplayY(image, y), red, green, blue, alpha);
}

static NSData *PBCanvasData(SWImageDataSource *dataSource)
{
    return [[dataSource mainImage] TIFFRepresentation];
}

static BOOL PBImageHasPixelWithAlpha(NSBitmapImageRep *image, unsigned char alpha)
{
    for (NSInteger y = 0; y < [image pixelsHigh]; y++) {
        for (NSInteger x = 0; x < [image pixelsWide]; x++) {
            if (PBPixelAt(image, x, y)[3] == alpha) {
                return YES;
            }
        }
    }
    return NO;
}

static BOOL PBImageHasOpaquePixelInRect(NSBitmapImageRep *image, NSRect rect)
{
    NSInteger minX = MAX(0, (NSInteger)floor(NSMinX(rect)));
    NSInteger minY = MAX(0, (NSInteger)floor(NSMinY(rect)));
    NSInteger maxX = MIN([image pixelsWide], (NSInteger)ceil(NSMaxX(rect)));
    NSInteger maxY = MIN([image pixelsHigh], (NSInteger)ceil(NSMaxY(rect)));
    for (NSInteger y = minY; y < maxY; y++) {
        for (NSInteger x = minX; x < maxX; x++) {
            if (PBPixelAt(image, x, y)[3] != 0) {
                return YES;
            }
        }
    }
    return NO;
}

static NSImage *PBImageWithTransparentCorners(NSSize size)
{
    NSImage *image = [[[NSImage alloc] initWithSize:size] autorelease];
    [image lockFocus];
    [[NSColor clearColor] setFill];
    NSRectFillUsingOperation(NSMakeRect(0.0, 0.0, size.width, size.height), NSCompositingOperationClear);
    [[NSColor blackColor] setFill];
    NSRectFill(NSMakeRect(8.0, 8.0, size.width - 16.0, size.height - 16.0));
    [image unlockFocus];
    return image;
}

static unsigned char PBImageCornerAlpha(NSImage *image)
{
    NSData *data = [image TIFFRepresentation];
    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:data];
    return PBPixelAt(rep, 0, 0)[3];
}

static NSMutableArray *PBRegisteredTestImages(void)
{
    static NSMutableArray *images;
    if (!images) {
        images = [[NSMutableArray alloc] init];
    }
    return images;
}

static void PBRegisterTestImageNamed(NSString *name)
{
    NSString *path = [[NSBundle bundleForClass:[PaintViewDrawingTest class]] pathForResource:[name stringByDeletingPathExtension]
                                                                                      ofType:[name pathExtension]];
    NSImage *image = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
    XCTAssertNotNil(image);
    [image setName:name];
    [PBRegisteredTestImages() addObject:image];
}

@interface PBFlippedImageRenderView : NSView
{
    NSBitmapImageRep *image;
}

- (id)initWithImage:(NSBitmapImageRep *)anImage;

@end

@implementation PBFlippedImageRenderView

- (id)initWithImage:(NSBitmapImageRep *)anImage
{
    self = [super initWithFrame:NSMakeRect(0.0, 0.0, [anImage pixelsWide], [anImage pixelsHigh])];
    if (self)
        image = [anImage retain];
    return self;
}

- (void)dealloc
{
    [image release];
    [super dealloc];
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)drawRect:(NSRect)rect
{
#pragma unused(rect)
    CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort],
                       NSRectToCGRect((NSRect){ NSZeroPoint, [image size] }),
                       [image CGImage]);
}

@end

@interface PBCanvasUndoHost : NSObject
{
    SWImageDataSource *dataSource;
    NSUndoManager *undoManager;
}

- (id)initWithDataSource:(SWImageDataSource *)aDataSource;
- (NSUndoManager *)undoManager;
- (void)registerDrawingUndo;
- (void)registerCanvasResizeUndo;
- (void)restoreCanvasHistorySnapshot:(SWCanvasHistorySnapshot *)snapshot
                           actionName:(NSString *)actionName;
- (NSBitmapImageRep *)updateSelectionExtentForSelectionRect:(NSRect)selectionRect;
- (void)resetSelectionExtent;

@end

@implementation PBCanvasUndoHost

- (id)initWithDataSource:(SWImageDataSource *)aDataSource
{
    self = [super init];
    if (self) {
        dataSource = [aDataSource retain];
        undoManager = [[NSUndoManager alloc] init];
    }
    return self;
}

- (void)dealloc
{
    [dataSource release];
    [undoManager release];
    [super dealloc];
}

- (NSUndoManager *)undoManager
{
    return undoManager;
}

- (void)registerCanvasUndoWithActionName:(NSString *)actionName
{
    SWCanvasHistorySnapshot *snapshot = [dataSource canvasHistorySnapshot];
    [[undoManager prepareWithInvocationTarget:self] restoreCanvasHistorySnapshot:snapshot
                                                                      actionName:actionName];
    [undoManager setActionName:actionName];
}

- (void)registerDrawingUndo
{
    [self registerCanvasUndoWithActionName:@"Drawing"];
}

- (void)registerCanvasResizeUndo
{
    [self registerCanvasUndoWithActionName:@"Resize"];
}

- (void)restoreCanvasHistorySnapshot:(SWCanvasHistorySnapshot *)snapshot
                           actionName:(NSString *)actionName
{
    SWCanvasHistorySnapshot *currentSnapshot = [dataSource canvasHistorySnapshot];
    [[undoManager prepareWithInvocationTarget:self] restoreCanvasHistorySnapshot:currentSnapshot
                                                                      actionName:actionName];
    [undoManager setActionName:actionName];
    [dataSource restoreCanvasHistorySnapshot:snapshot];
}

- (NSBitmapImageRep *)updateSelectionExtentForSelectionRect:(NSRect)selectionRect
{
    #pragma unused(selectionRect)
    [dataSource resizeBufferToSize:[dataSource size]];
    return [dataSource bufferImage];
}

- (void)resetSelectionExtent
{
    [dataSource resizeBufferToSize:[dataSource size]];
}

@end

static SWSelectionTool *PBMakeSelectionTool(void)
{
    SWSelectionTool *tool = [[[SWSelectionTool alloc] initWithController:nil] autorelease];
    [tool setBackColor:[NSColor whiteColor]];
    return tool;
}

@implementation PaintViewDrawingTest

- (void)testInitImageRepCreatesTransparentBitmap
{
    NSBitmapImageRep *image = nil;
    [SWImageTools initImageRep:&image withSize:NSMakeSize(3.0, 2.0)];

    XCTAssertNotNil(image);
    XCTAssertEqual([image pixelsWide], 3);
    XCTAssertEqual([image pixelsHigh], 2);
    XCTAssertEqual([image bitsPerSample], 8);
    XCTAssertEqual([image samplesPerPixel], 4);
    PBAssertPixelEquals(image, 0, 0, 0, 0, 0, 0);

    [image release];
}

- (void)testClearImageClearsEveryPixel
{
    NSBitmapImageRep *image = nil;
    [SWImageTools initImageRep:&image withSize:NSMakeSize(2.0, 2.0)];
    PBSetPixel(image, 0, 0, 255, 0, 0, 255);
    PBSetPixel(image, 1, 1, 0, 0, 255, 255);

    [SWImageTools clearImage:image];

    PBAssertPixelEquals(image, 0, 0, 0, 0, 0, 0);
    PBAssertPixelEquals(image, 1, 1, 0, 0, 0, 0);

    [image release];
}

- (void)testDrawToImageCopiesSourcePixels
{
    NSBitmapImageRep *source = nil;
    NSBitmapImageRep *destination = nil;
    [SWImageTools initImageRep:&source withSize:NSMakeSize(2.0, 2.0)];
    [SWImageTools initImageRep:&destination withSize:NSMakeSize(2.0, 2.0)];
    PBSetPixel(source, 0, 0, 255, 0, 0, 255);
    PBSetPixel(source, 1, 1, 0, 0, 255, 255);

    [SWImageTools drawToImage:destination fromImage:source withComposition:NO];

    PBAssertPixelEquals(destination, 0, 0, 255, 0, 0, 255);
    PBAssertPixelEquals(destination, 1, 1, 0, 0, 255, 255);

    [source release];
    [destination release];
}

- (void)testFlipImageHorizontalMirrorsPixels
{
    NSBitmapImageRep *image = nil;
    [SWImageTools initImageRep:&image withSize:NSMakeSize(2.0, 1.0)];
    PBSetPixel(image, 0, 0, 255, 0, 0, 255);
    PBSetPixel(image, 1, 0, 0, 0, 255, 255);

    [SWImageTools flipImageHorizontal:image];

    PBAssertPixelEquals(image, 0, 0, 0, 0, 255, 255);
    PBAssertPixelEquals(image, 1, 0, 255, 0, 0, 255);

    [image release];
}

- (void)testFlipImageVerticalMirrorsPixels
{
    NSBitmapImageRep *image = nil;
    [SWImageTools initImageRep:&image withSize:NSMakeSize(1.0, 2.0)];
    PBSetPixel(image, 0, 0, 255, 0, 0, 255);
    PBSetPixel(image, 0, 1, 0, 0, 255, 255);

    [SWImageTools flipImageVertical:image];

    PBAssertPixelEquals(image, 0, 0, 0, 0, 255, 255);
    PBAssertPixelEquals(image, 0, 1, 255, 0, 0, 255);

    [image release];
}

- (void)testPasteboardImageDataConvertsToCanvasDisplayOrientation
{
    NSBitmapImageRep *externalImage = nil;
    [SWImageTools initImageRep:&externalImage withSize:NSMakeSize(2.0, 2.0)];
    PBSetPixel(externalImage, 0, 0, 255, 0, 0, 255);
    PBSetPixel(externalImage, 1, 0, 0, 255, 0, 255);
    PBSetPixel(externalImage, 0, 1, 0, 0, 255, 255);
    PBSetPixel(externalImage, 1, 1, 255, 255, 0, 255);

    NSBitmapImageRep *internalImage = [SWImageTools imageRepWithPasteboardImageData:[externalImage TIFFRepresentation]];

    PBAssertDisplayPixelEquals(internalImage, 0, 0, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals(internalImage, 1, 0, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals(internalImage, 0, 1, 0, 0, 255, 255);
    PBAssertDisplayPixelEquals(internalImage, 1, 1, 255, 255, 0, 255);

    [externalImage release];
}

- (void)testPaintViewRendersBufferImageInDisplayOrientation
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(2.0, 2.0)] autorelease];
    PBSetDisplayPixel([dataSource bufferImage], 0, 0, 255, 0, 0, 255);
    PBSetDisplayPixel([dataSource bufferImage], 1, 0, 0, 255, 0, 255);
    PBSetDisplayPixel([dataSource bufferImage], 0, 1, 0, 0, 255, 255);
    PBSetDisplayPixel([dataSource bufferImage], 1, 1, 255, 255, 0, 255);
    PBFlippedImageRenderView *paintView = [[[PBFlippedImageRenderView alloc] initWithImage:[dataSource bufferImage]] autorelease];

    NSBitmapImageRep *rendered = [paintView bitmapImageRepForCachingDisplayInRect:[paintView bounds]];
    [paintView cacheDisplayInRect:[paintView bounds] toBitmapImageRep:rendered];

    PBAssertPixelEquals(rendered, 0, 0, 255, 0, 0, 255);
    PBAssertPixelEquals(rendered, 1, 0, 0, 255, 0, 255);
    PBAssertPixelEquals(rendered, 0, 1, 0, 0, 255, 255);
    PBAssertPixelEquals(rendered, 1, 1, 255, 255, 0, 255);
}

- (void)testCropImageCopiesRequestedRect
{
    NSBitmapImageRep *source = nil;
    [SWImageTools initImageRep:&source withSize:NSMakeSize(3.0, 3.0)];
    PBSetPixel(source, 1, 1, 0, 255, 0, 255);
    PBSetPixel(source, 2, 1, 0, 0, 255, 255);

    NSBitmapImageRep *cropped = [SWImageTools cropImage:source toRect:NSMakeRect(1.0, 1.0, 2.0, 1.0)];

    XCTAssertEqual([cropped pixelsWide], 2);
    XCTAssertEqual([cropped pixelsHigh], 1);
    PBAssertPixelEquals(cropped, 0, 0, 0, 255, 0, 255);
    PBAssertPixelEquals(cropped, 1, 0, 0, 0, 255, 255);

    [source release];
    [cropped release];
}

- (void)testStripImageOfColorClearsOnlyMatchingPixels
{
    NSBitmapImageRep *image = nil;
    [SWImageTools initImageRep:&image withSize:NSMakeSize(2.0, 1.0)];
    PBSetPixel(image, 0, 0, 255, 255, 255, 255);
    PBSetPixel(image, 1, 0, 0, 0, 0, 255);

    [SWImageTools stripImage:image ofColor:[NSColor whiteColor]];

    PBAssertPixelEquals(image, 0, 0, 0, 0, 0, 0);
    PBAssertPixelEquals(image, 1, 0, 0, 0, 0, 255);

    [image release];
}

- (void)testToolButtonGeneratedStateImagesPreserveTransparentCorners
{
    NSImage *normalImage = PBImageWithTransparentCorners(NSMakeSize(32.0, 32.0));
    PBRegisterTestImageNamed(@"hoveredsmall.png");
    PBRegisterTestImageNamed(@"pressedsmall.png");
    SWButtonCell *cell = [[[SWButtonCell alloc] initTextCell:@""] autorelease];
    [cell setImage:normalImage];

    [cell generateAltImage];
    [cell generateHovImage];
    [cell setIsHovered:YES];

    NSImage *alternateImage = [cell alternateImage];
    NSImage *hoveredImage = [cell image];
    XCTAssertNotNil(alternateImage);
    XCTAssertNotNil(hoveredImage);
    if (!alternateImage || !hoveredImage)
        return;

    XCTAssertEqual(PBImageCornerAlpha(alternateImage), 0);
    XCTAssertEqual(PBImageCornerAlpha(hoveredImage), 0);
}

- (void)testConvertFileTypeMapsSavePanelLabelsToExtensions
{
    XCTAssertEqualObjects([SWImageTools convertFileType:@"PNG"], @"png");
    XCTAssertEqualObjects([SWImageTools convertFileType:@"TIFF"], @"tif");
    XCTAssertEqualObjects([SWImageTools convertFileType:@"JPEG"], @"jpg");
    XCTAssertEqualObjects([SWImageTools convertFileType:@"Paintbrush"], @"");
}

- (void)testCanvasHistorySnapshotRestoresSizePixelsAndClearsBuffer
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(2.0, 2.0)] autorelease];
    PBSetPixel([dataSource mainImage], 1, 1, 255, 0, 0, 255);
    PBSetPixel([dataSource bufferImage], 0, 0, 0, 0, 255, 255);
    SWCanvasHistorySnapshot *snapshot = [dataSource canvasHistorySnapshot];

    [dataSource resizeToSize:NSMakeSize(3.0, 2.0) scaleImage:NO];
    PBSetPixel([dataSource mainImage], 1, 1, 0, 255, 0, 255);

    [dataSource restoreCanvasHistorySnapshot:snapshot];

    XCTAssertEqual([dataSource size].width, 2.0);
    XCTAssertEqual([dataSource size].height, 2.0);
    PBAssertPixelEquals([dataSource mainImage], 1, 1, 255, 0, 0, 255);
    XCTAssertFalse(PBImageHasPixelWithAlpha([dataSource bufferImage], 255));
}

- (void)testResizeBufferToSizeDoesNotResizeCanvas
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(3.0, 3.0)] autorelease];

    [dataSource resizeBufferToSize:NSMakeSize(6.0, 4.0)];

    XCTAssertEqual([dataSource size].width, 3.0);
    XCTAssertEqual([dataSource size].height, 3.0);
    XCTAssertEqual([[dataSource mainImage] pixelsWide], 3);
    XCTAssertEqual([[dataSource mainImage] pixelsHigh], 3);
    XCTAssertEqual([[dataSource bufferImage] pixelsWide], 6);
    XCTAssertEqual([[dataSource bufferImage] pixelsHigh], 4);
}

- (void)testOversizedPastedSelectionClipsTransientBufferAndCopiesFullSelection
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(3.0, 3.0)] autorelease];
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    NSBitmapImageRep *pastedImage = nil;
    [SWImageTools initImageRep:&pastedImage withSize:NSMakeSize(5.0, 4.0)];
    PBSetDisplayPixel(pastedImage, 2, 2, 0, 0, 255, 255);
    PBSetDisplayPixel(pastedImage, 4, 3, 0, 255, 0, 255);
    SWSelectionTool *tool = PBMakeSelectionTool();
    [tool setDocument:(SWDocument *)undoHost];

    [tool setClippingRect:NSMakeRect(0.0, 0.0, 5.0, 4.0)
                 forImage:pastedImage
              bufferImage:[dataSource bufferImage]
            withMainImage:[dataSource mainImage]];

    XCTAssertTrue([tool isSelected]);
    XCTAssertEqual([dataSource size].width, 3.0);
    XCTAssertEqual([dataSource size].height, 3.0);
    XCTAssertEqual([[dataSource bufferImage] pixelsWide], 3);
    XCTAssertEqual([[dataSource bufferImage] pixelsHigh], 3);
    XCTAssertEqual([tool clippingRect].size.width, 5.0);
    XCTAssertEqual([tool clippingRect].size.height, 4.0);
    PBAssertDisplayPixelEquals([dataSource bufferImage], 2, 2, 0, 0, 255, 255);

    NSBitmapImageRep *copiedImage = [[[NSBitmapImageRep alloc] initWithData:[tool imageData]] autorelease];
    XCTAssertEqual([copiedImage pixelsWide], 5);
    XCTAssertEqual([copiedImage pixelsHigh], 4);
    PBAssertPixelEquals(copiedImage, 4, 3, 0, 255, 0, 255);

    [pastedImage release];
}

- (void)testOversizedPasteboardSelectionShowsTopOfExternalImageWhenClipped
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(4.0, 4.0)] autorelease];
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    NSBitmapImageRep *externalImage = nil;
    [SWImageTools initImageRep:&externalImage withSize:NSMakeSize(4.0, 6.0)];
    PBSetPixel(externalImage, 1, 1, 255, 0, 0, 255);
    PBSetPixel(externalImage, 2, 1, 0, 255, 0, 255);
    PBSetPixel(externalImage, 1, 2, 0, 0, 255, 255);
    PBSetPixel(externalImage, 2, 2, 255, 255, 0, 255);
    PBSetPixel(externalImage, 1, 4, 255, 0, 255, 255);
    PBSetPixel(externalImage, 2, 4, 0, 255, 255, 255);
    PBSetPixel(externalImage, 1, 5, 32, 64, 96, 255);
    PBSetPixel(externalImage, 2, 5, 96, 64, 32, 255);
    NSBitmapImageRep *pastedImage = [SWImageTools imageRepWithPasteboardImageData:[externalImage TIFFRepresentation]];
    SWSelectionTool *tool = PBMakeSelectionTool();
    [tool setDocument:(SWDocument *)undoHost];

    [tool setClippingRect:NSMakeRect(0.0, 0.0, 4.0, 6.0)
                 forImage:pastedImage
              bufferImage:[dataSource bufferImage]
            withMainImage:[dataSource mainImage]];

    PBAssertDisplayPixelEquals([dataSource bufferImage], 1, 1, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals([dataSource bufferImage], 2, 1, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals([dataSource bufferImage], 1, 2, 0, 0, 255, 255);
    PBAssertDisplayPixelEquals([dataSource bufferImage], 2, 2, 255, 255, 0, 255);

    PBFlippedImageRenderView *paintView = [[[PBFlippedImageRenderView alloc] initWithImage:[dataSource bufferImage]] autorelease];
    NSBitmapImageRep *rendered = [paintView bitmapImageRepForCachingDisplayInRect:[paintView bounds]];
    [paintView cacheDisplayInRect:[paintView bounds] toBitmapImageRep:rendered];

    PBAssertPixelEquals(rendered, 1, 1, 255, 0, 0, 255);
    PBAssertPixelEquals(rendered, 2, 1, 0, 255, 0, 255);
    PBAssertPixelEquals(rendered, 1, 2, 0, 0, 255, 255);
    PBAssertPixelEquals(rendered, 2, 2, 255, 255, 0, 255);

    [externalImage release];
}

- (void)testLargePasteboardPNGImageDataConvertsRowsToCanvasOrientation
{
    NSBitmapImageRep *externalImage = nil;
    [SWImageTools initImageRep:&externalImage withSize:NSMakeSize(4.0, 6.0)];
    PBSetPixel(externalImage, 1, 1, 255, 0, 0, 255);
    PBSetPixel(externalImage, 2, 1, 0, 255, 0, 255);
    PBSetPixel(externalImage, 1, 4, 0, 0, 255, 255);
    PBSetPixel(externalImage, 2, 4, 255, 255, 0, 255);

    NSData *pngData = [externalImage representationUsingType:NSPNGFileType
                                                   properties:[NSDictionary dictionary]];
    NSBitmapImageRep *internalImage = [SWImageTools imageRepWithPasteboardImageData:pngData];

    PBAssertPixelEquals(internalImage, 1, 1, 0, 0, 255, 255);
    PBAssertPixelEquals(internalImage, 2, 1, 255, 255, 0, 255);
    PBAssertPixelEquals(internalImage, 1, 4, 255, 0, 0, 255);
    PBAssertPixelEquals(internalImage, 2, 4, 0, 255, 0, 255);

    [externalImage release];
}

- (void)testMovingOversizedPastedSelectionKeepsTransientBufferClippedToCanvas
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(3.0, 3.0)] autorelease];
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    NSBitmapImageRep *pastedImage = nil;
    [SWImageTools initImageRep:&pastedImage withSize:NSMakeSize(5.0, 4.0)];
    SWSelectionTool *tool = PBMakeSelectionTool();
    [tool setDocument:(SWDocument *)undoHost];
    [tool setClippingRect:NSMakeRect(0.0, 0.0, 5.0, 4.0)
                 forImage:pastedImage
              bufferImage:[dataSource bufferImage]
            withMainImage:[dataSource mainImage]];

    [tool performDrawAtPoint:NSMakePoint(1.0, 1.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(2.0, 2.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DRAGGED];

    XCTAssertEqual([tool clippingRect].origin.x, 1.0);
    XCTAssertEqual([tool clippingRect].origin.y, 1.0);
    XCTAssertEqual([[dataSource bufferImage] pixelsWide], 3);
    XCTAssertEqual([[dataSource bufferImage] pixelsHigh], 3);

    [pastedImage release];
}

- (void)testDiscardingOversizedPastedSelectionRestoresTransientBufferToCanvasSize
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(3.0, 3.0)] autorelease];
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    NSBitmapImageRep *pastedImage = nil;
    [SWImageTools initImageRep:&pastedImage withSize:NSMakeSize(5.0, 4.0)];
    SWSelectionTool *tool = PBMakeSelectionTool();
    [tool setDocument:(SWDocument *)undoHost];
    [tool setClippingRect:NSMakeRect(0.0, 0.0, 5.0, 4.0)
                 forImage:pastedImage
              bufferImage:[dataSource bufferImage]
            withMainImage:[dataSource mainImage]];

    [tool discardSelection];

    XCTAssertFalse([tool isSelected]);
    XCTAssertEqual([[dataSource bufferImage] pixelsWide], 3);
    XCTAssertEqual([[dataSource bufferImage] pixelsHigh], 3);

    [pastedImage release];
}

- (void)testCommittingOversizedPastedSelectionClipsToCanvasWithoutResizingCanvas
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(3.0, 3.0)] autorelease];
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    NSBitmapImageRep *pastedImage = nil;
    [SWImageTools initImageRep:&pastedImage withSize:NSMakeSize(5.0, 4.0)];
    PBSetDisplayPixel(pastedImage, 2, 2, 255, 0, 0, 255);
    PBSetDisplayPixel(pastedImage, 4, 3, 0, 0, 255, 255);
    SWSelectionTool *tool = PBMakeSelectionTool();
    [tool setDocument:(SWDocument *)undoHost];
    [tool setClippingRect:NSMakeRect(0.0, 0.0, 5.0, 4.0)
                 forImage:pastedImage
              bufferImage:[dataSource bufferImage]
            withMainImage:[dataSource mainImage]];

    [tool tieUpLooseEnds];

    XCTAssertEqual([dataSource size].width, 3.0);
    XCTAssertEqual([dataSource size].height, 3.0);
    XCTAssertEqual([[dataSource bufferImage] pixelsWide], 3);
    XCTAssertEqual([[dataSource bufferImage] pixelsHigh], 3);
    PBAssertDisplayPixelEquals([dataSource mainImage], 2, 2, 255, 0, 0, 255);

    [pastedImage release];
}

- (void)testCancelingCanvasSelectionRestoresLiftedPixels
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(4.0, 4.0)] autorelease];
    PBSetPixel([dataSource mainImage], 1, 1, 255, 0, 0, 255);
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    SWSelectionTool *tool = PBMakeSelectionTool();
    [tool setDocument:(SWDocument *)undoHost];

    // Rubber-band a selection over the painted pixel; creating it lifts the source
    // rect, filling it with the background color.
    [tool setSavedPoint:NSMakePoint(0.0, 0.0)];
    [tool performDrawAtPoint:NSMakePoint(0.0, 0.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(3.0, 3.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_UP];

    XCTAssertTrue([tool isSelected]);
    PBAssertPixelEquals([dataSource mainImage], 1, 1, 255, 255, 255, 255);

    [tool cancelSelection];

    // Canceling restores the lifted pixels instead of leaving a background-colored hole.
    XCTAssertFalse([tool isSelected]);
    PBAssertPixelEquals([dataSource mainImage], 1, 1, 255, 0, 0, 255);
}

- (void)testSelectionMarqueeIsVisibleWhileDraggingBeforeMouseUp
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(5.0, 5.0)] autorelease];
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    SWSelectionTool *tool = PBMakeSelectionTool();
    [tool setDocument:(SWDocument *)undoHost];
    [tool setSavedPoint:NSMakePoint(1.0, 1.0)];

    [tool performDrawAtPoint:NSMakePoint(1.0, 1.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(4.0, 4.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DRAGGED];

    XCTAssertFalse([tool isSelected]);
    XCTAssertTrue(PBImageHasOpaquePixelInRect([dataSource bufferImage], NSMakeRect(1.0, 1.0, 3.0, 3.0)));
}

- (void)testDraggingCanvasSelectionMovesSelectedBitmapPixels
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(5.0, 5.0)] autorelease];
    PBSetDisplayPixel([dataSource mainImage], 1, 1, 255, 0, 0, 255);
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    SWSelectionTool *tool = PBMakeSelectionTool();
    [tool setDocument:(SWDocument *)undoHost];

    [tool setSavedPoint:NSMakePoint(0.0, 0.0)];
    [tool performDrawAtPoint:NSMakePoint(0.0, 0.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(3.0, 3.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_UP];

    XCTAssertTrue([tool isSelected]);
    PBAssertDisplayPixelEquals([dataSource mainImage], 1, 1, 255, 255, 255, 255);

    [tool performDrawAtPoint:NSMakePoint(1.0, 1.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(2.0, 1.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DRAGGED];

    XCTAssertEqual([tool clippingRect].origin.x, 1.0);
    XCTAssertEqual([tool clippingRect].origin.y, 0.0);
    PBAssertDisplayPixelEquals([dataSource bufferImage], 2, 1, 255, 0, 0, 255);

    [tool tieUpLooseEnds];

    PBAssertDisplayPixelEquals([dataSource mainImage], 1, 1, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 2, 1, 255, 0, 0, 255);
}

- (void)testDraggingCanvasSelectionUsesDisplayCoordinatesWithoutVerticalDistortion
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(8.0, 8.0)] autorelease];
    PBSetDisplayPixel([dataSource mainImage], 1, 1, 255, 0, 0, 255);
    PBSetDisplayPixel([dataSource mainImage], 2, 1, 0, 255, 0, 255);
    PBSetDisplayPixel([dataSource mainImage], 1, 2, 0, 0, 255, 255);
    PBSetDisplayPixel([dataSource mainImage], 3, 2, 255, 255, 0, 255);
    PBSetDisplayPixel([dataSource mainImage], 2, 3, 255, 0, 255, 255);
    PBSetDisplayPixel([dataSource mainImage], 3, 3, 0, 255, 255, 255);
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    SWSelectionTool *tool = PBMakeSelectionTool();
    [tool setDocument:(SWDocument *)undoHost];

    [tool setSavedPoint:NSMakePoint(0.0, 0.0)];
    [tool performDrawAtPoint:NSMakePoint(0.0, 0.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(4.0, 5.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_UP];

    [tool performDrawAtPoint:NSMakePoint(1.0, 1.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(3.0, 2.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DRAGGED];
    [tool tieUpLooseEnds];

    PBAssertDisplayPixelEquals([dataSource mainImage], 1, 1, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 2, 1, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 1, 2, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 2, 3, 255, 255, 255, 255);

    PBAssertDisplayPixelEquals([dataSource mainImage], 3, 2, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 4, 2, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 3, 3, 0, 0, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 5, 3, 255, 255, 0, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 4, 4, 255, 0, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 5, 4, 0, 255, 255, 255);
}

- (void)testDrawingUndoAndRedoRestoreCanvasPixels
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(3.0, 2.0)] autorelease];
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    NSData *originalCanvasData = PBCanvasData(dataSource);

    SWBrushTool *tool = [[[SWBrushTool alloc] initWithController:nil] autorelease];
    [tool setDocument:(SWDocument *)undoHost];
    [tool setFrontColor:[NSColor blackColor]];
    [tool setBackColor:[NSColor whiteColor]];
    [tool setLineWidth:1.0];
    [tool setSavedPoint:NSMakePoint(0.0, 0.0)];
    [tool performDrawAtPoint:NSMakePoint(0.0, 0.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(2.0, 0.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DRAGGED];
    [tool performDrawAtPoint:NSMakePoint(2.0, 0.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_UP];
    NSData *drawnCanvasData = PBCanvasData(dataSource);

    XCTAssertNotEqualObjects(drawnCanvasData, originalCanvasData);
    [[undoHost undoManager] undo];
    XCTAssertEqualObjects(PBCanvasData(dataSource), originalCanvasData);
    [[undoHost undoManager] redo];
    XCTAssertEqualObjects(PBCanvasData(dataSource), drawnCanvasData);
}

- (void)testResizeUndoAndRedoRestoreCanvasSizeAndPixels
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(2.0, 2.0)] autorelease];
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    PBSetPixel([dataSource mainImage], 1, 1, 255, 0, 0, 255);
    NSData *originalCanvasData = PBCanvasData(dataSource);

    [undoHost registerCanvasResizeUndo];
    [dataSource resizeToSize:NSMakeSize(3.0, 2.0) scaleImage:NO];
    PBSetPixel([dataSource mainImage], 2, 1, 0, 255, 0, 255);
    NSData *resizedCanvasData = PBCanvasData(dataSource);

    [[undoHost undoManager] undo];
    XCTAssertEqual([dataSource size].width, 2.0);
    XCTAssertEqual([dataSource size].height, 2.0);
    XCTAssertEqualObjects(PBCanvasData(dataSource), originalCanvasData);

    [[undoHost undoManager] redo];
    XCTAssertEqual([dataSource size].width, 3.0);
    XCTAssertEqual([dataSource size].height, 2.0);
    XCTAssertEqualObjects(PBCanvasData(dataSource), resizedCanvasData);
}

@end
