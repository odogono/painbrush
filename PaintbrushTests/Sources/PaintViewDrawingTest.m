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

static void PBAssertPixelEquals(NSBitmapImageRep *image, NSInteger x, NSInteger y, unsigned char red, unsigned char green, unsigned char blue, unsigned char alpha)
{
    unsigned char *pixel = PBPixelAt(image, x, y);
    XCTAssertEqual(pixel[0], red, @"red channel mismatch at (%ld, %ld)", (long)x, (long)y);
    XCTAssertEqual(pixel[1], green, @"green channel mismatch at (%ld, %ld)", (long)x, (long)y);
    XCTAssertEqual(pixel[2], blue, @"blue channel mismatch at (%ld, %ld)", (long)x, (long)y);
    XCTAssertEqual(pixel[3], alpha, @"alpha channel mismatch at (%ld, %ld)", (long)x, (long)y);
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

@end

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
