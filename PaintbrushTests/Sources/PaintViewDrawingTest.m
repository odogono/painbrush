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
#import "SWCenteringClipView.h"
#import "SWEyeDropperTool.h"
#import "SWImageDataSource.h"
#import "SWImageTools.h"
#import "SWSelectionTool.h"
#import "SWSlider.h"
#import "SWToolboxState.h"

@interface PBToolboxControllerDouble : NSObject
@property (assign) NSInteger lineWidth;
@property (retain) NSColor *foregroundColor;
@property (retain) NSColor *backgroundColor;
@property (assign) NSInteger fillStyle;
@property (assign) BOOL selectionTransparency;
@property (assign) NSInteger lineWidthDisplay;
@end

@implementation PBToolboxControllerDouble
@synthesize lineWidth;
@synthesize foregroundColor;
@synthesize backgroundColor;
@synthesize fillStyle;
@synthesize selectionTransparency;
@synthesize lineWidthDisplay;

- (void)dealloc
{
    [foregroundColor release];
    [backgroundColor release];
    [super dealloc];
}

@end

@interface PBOffCanvasMouseViewDouble : NSView
@property (assign) BOOL receiveOffCanvasMouseEvents;
@property (assign) NSInteger mouseDownCount;
@end

@implementation PBOffCanvasMouseViewDouble
@synthesize receiveOffCanvasMouseEvents;
@synthesize mouseDownCount;

- (BOOL)shouldReceiveOffCanvasMouseEvents
{
    return receiveOffCanvasMouseEvents;
}

- (void)mouseDown:(NSEvent *)event
{
#pragma unused(event)
    mouseDownCount++;
}

@end

static unsigned char *PBPixelAt(NSBitmapImageRep *image, NSInteger x, NSInteger y)
{
    return [image bitmapData] + (y * [image bytesPerRow]) + (x * [image samplesPerPixel]);
}

static unsigned char *PBDisplayPixelAt(NSBitmapImageRep *image, NSInteger x, NSInteger y)
{
    return PBPixelAt(image, x, [image pixelsHigh] - y - 1);
}

static void PBSetPixel(NSBitmapImageRep *image, NSInteger x, NSInteger y, unsigned char red, unsigned char green, unsigned char blue, unsigned char alpha)
{
    unsigned char *pixel = PBPixelAt(image, x, y);
    pixel[0] = red;
    pixel[1] = green;
	pixel[2] = blue;
	pixel[3] = alpha;
}

static void PBSetDisplayPixel(NSBitmapImageRep *image, NSInteger x, NSInteger y, unsigned char red, unsigned char green, unsigned char blue, unsigned char alpha)
{
    unsigned char *pixel = PBDisplayPixelAt(image, x, y);
    pixel[0] = red;
    pixel[1] = green;
    pixel[2] = blue;
    pixel[3] = alpha;
}

static void PBFillImage(NSBitmapImageRep *image, unsigned char red, unsigned char green, unsigned char blue, unsigned char alpha)
{
    for (NSInteger y = 0; y < [image pixelsHigh]; y++) {
        for (NSInteger x = 0; x < [image pixelsWide]; x++) {
            PBSetPixel(image, x, y, red, green, blue, alpha);
        }
    }
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
    unsigned char *pixel = PBDisplayPixelAt(image, x, y);
    XCTAssertEqual(pixel[0], red, @"red channel mismatch at display (%ld, %ld)", (long)x, (long)y);
    XCTAssertEqual(pixel[1], green, @"green channel mismatch at display (%ld, %ld)", (long)x, (long)y);
    XCTAssertEqual(pixel[2], blue, @"blue channel mismatch at display (%ld, %ld)", (long)x, (long)y);
    XCTAssertEqual(pixel[3], alpha, @"alpha channel mismatch at display (%ld, %ld)", (long)x, (long)y);
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

static SWSelectionTool *PBMakeSelectionToolWithBackgroundColor(NSColor *backgroundColor)
{
    PBToolboxControllerDouble *controller = [[PBToolboxControllerDouble alloc] init];
    SWSelectionTool *tool = [[[SWSelectionTool alloc] initWithToolboxState:(SWToolboxState *)controller] autorelease];
    [controller setLineWidth:1];
    [controller setForegroundColor:[NSColor blackColor]];
    if (backgroundColor)
        [controller setBackgroundColor:backgroundColor];
    [controller setFillStyle:0];
    [controller setSelectionTransparency:NO];
    return tool;
}

static SWSelectionTool *PBMakeSelectionTool(void)
{
    return PBMakeSelectionToolWithBackgroundColor([NSColor whiteColor]);
}

static SWSelectionTool *PBMakeSelectionToolWithoutBackgroundColor(void)
{
    return PBMakeSelectionToolWithBackgroundColor(nil);
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

@implementation PaintViewDrawingTest

- (void)testToolboxStateDefaultsMatchExistingToolboxBehavior
{
    SWToolboxState *state = [[[SWToolboxState alloc] init] autorelease];

    XCTAssertEqualObjects([state currentTool], @"Brush");
    XCTAssertEqual([state lineWidthDisplay], 3);
    XCTAssertEqual([state lineWidth], 4);
    XCTAssertEqual([state fillStyle], STROKE_ONLY);
    XCTAssertFalse([state selectionTransparency]);
    XCTAssertTrue([SWImageTools color:[state foregroundColor] isEqualToColor:[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0]]);
    XCTAssertTrue([SWImageTools color:[state backgroundColor] isEqualToColor:[NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0]]);
}

- (void)testMultipleToolboxConsumersTrackSharedState
{
    SWToolboxState *state = [[[SWToolboxState alloc] init] autorelease];
    SWBrushTool *firstTool = [[[SWBrushTool alloc] initWithToolboxState:state] autorelease];
    SWBrushTool *secondTool = [[[SWBrushTool alloc] initWithToolboxState:state] autorelease];
    NSColor *red = [NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:1.0];

    [state setLineWidthDisplay:5];
    [state setForegroundColor:red];

    XCTAssertEqual([firstTool lineWidth], 8);
    XCTAssertEqual([secondTool lineWidth], 8);
    XCTAssertTrue([SWImageTools color:[firstTool drawingColor] isEqualToColor:red]);
    XCTAssertTrue([SWImageTools color:[secondTool drawingColor] isEqualToColor:red]);
}

- (void)testToolboxStateCopiesEveryToolboxSetting
{
    SWToolboxState *source = [[[SWToolboxState alloc] init] autorelease];
    NSColor *foreground = [NSColor colorWithCalibratedRed:0.2 green:0.4 blue:0.6 alpha:1.0];
    NSColor *background = [NSColor colorWithCalibratedRed:0.7 green:0.5 blue:0.3 alpha:1.0];

    [source setCurrentTool:@"Eraser"];
    [source setLineWidth:12];
    [source setFillStyle:FILL_AND_STROKE];
    [source setSelectionTransparency:YES];
    [source setForegroundColor:foreground];
    [source setBackgroundColor:background];

    SWToolboxState *copy = [[[SWToolboxState alloc] initWithToolboxState:source] autorelease];

    XCTAssertEqualObjects([copy currentTool], @"Eraser");
    XCTAssertEqual([copy lineWidth], 12);
    XCTAssertEqual([copy fillStyle], FILL_AND_STROKE);
    XCTAssertTrue([copy selectionTransparency]);
    XCTAssertTrue([SWImageTools color:[copy foregroundColor] isEqualToColor:foreground]);
    XCTAssertTrue([SWImageTools color:[copy backgroundColor] isEqualToColor:background]);
}

- (void)testToolboxConsumersWithSeparateStatesDiverge
{
    SWToolboxState *firstState = [[[SWToolboxState alloc] init] autorelease];
    SWToolboxState *secondState = [[[SWToolboxState alloc] init] autorelease];
    SWBrushTool *firstTool = [[[SWBrushTool alloc] initWithToolboxState:firstState] autorelease];
    SWBrushTool *secondTool = [[[SWBrushTool alloc] initWithToolboxState:secondState] autorelease];
    NSColor *red = [NSColor colorWithCalibratedRed:1.0 green:0.0 blue:0.0 alpha:1.0];
    NSColor *blue = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:1.0 alpha:1.0];

    [firstState setLineWidthDisplay:2];
    [firstState setForegroundColor:red];
    [secondState setLineWidthDisplay:6];
    [secondState setForegroundColor:blue];

    XCTAssertEqual([firstTool lineWidth], 2);
    XCTAssertEqual([secondTool lineWidth], 10);
    XCTAssertTrue([SWImageTools color:[firstTool drawingColor] isEqualToColor:red]);
    XCTAssertTrue([SWImageTools color:[secondTool drawingColor] isEqualToColor:blue]);
}

- (void)testEyedropperWritesSampledColorToBoundToolboxState
{
    SWToolboxState *state = [[[SWToolboxState alloc] init] autorelease];
    SWToolboxState *sharedState = [SWToolboxState sharedToolboxState];
    NSColor *sharedForeground = [[sharedState foregroundColor] retain];
    NSColor *black = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0];
    NSColor *sampled = [NSColor colorWithCalibratedRed:(12.0 / 255.0)
                                                 green:(34.0 / 255.0)
                                                  blue:(56.0 / 255.0)
                                                 alpha:1.0];
    NSBitmapImageRep *image = nil;
    [SWImageTools initImageRep:&image withSize:NSMakeSize(1.0, 1.0)];
    PBSetDisplayPixel(image, 0, 0, 12, 34, 56, 255);
    [sharedState setForegroundColor:black];

    SWEyeDropperTool *tool = [[[SWEyeDropperTool alloc] initWithToolboxState:state] autorelease];
    [tool performDrawAtPoint:NSMakePoint(0.0, 0.0)
               withMainImage:image
                 bufferImage:nil
                  mouseEvent:MOUSE_DOWN];

    XCTAssertTrue([SWImageTools color:[state foregroundColor] isEqualToColor:sampled]);
    XCTAssertTrue([SWImageTools color:[sharedState foregroundColor] isEqualToColor:black]);

    [sharedState setForegroundColor:sharedForeground];
    [sharedForeground release];
    [image release];
}

- (void)testSliderScrollWheelUpdatesBoundLineWidthOwner
{
    PBToolboxControllerDouble *controller = [[[PBToolboxControllerDouble alloc] init] autorelease];
    [controller setLineWidthDisplay:3];
    SWSlider *slider = [[[SWSlider alloc] initWithFrame:NSMakeRect(0.0, 0.0, 100.0, 20.0)] autorelease];
    [slider setMinValue:1.0];
    [slider setMaxValue:10.0];
    [slider bind:NSValueBinding
        toObject:controller
     withKeyPath:@"lineWidthDisplay"
         options:nil];
    [slider setIntegerValue:3];

    [slider setScrolledLineWidthDisplay:4];

    XCTAssertEqual([controller lineWidthDisplay], 4);
    [slider unbind:NSValueBinding];
}

- (void)testImageDataSourceCanUseExplicitBackgroundColor
{
    NSColor *background = [NSColor colorWithCalibratedRed:0.0 green:0.0 blue:1.0 alpha:1.0];
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(1.0, 1.0)
                                                             backgroundColor:background] autorelease];

    PBAssertPixelEquals([dataSource mainImage], 0, 0, 0, 0, 255, 255);
}

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

- (void)testSelectionMarqueeInvalidRectIsFiniteDuringDrag
{
    NSBitmapImageRep *mainImage = nil;
    NSBitmapImageRep *bufferImage = nil;
    [SWImageTools initImageRep:&mainImage withSize:NSMakeSize(6.0, 6.0)];
    [SWImageTools initImageRep:&bufferImage withSize:NSMakeSize(6.0, 6.0)];
    SWSelectionTool *tool = PBMakeSelectionTool();

    [tool setSavedPoint:NSMakePoint(1.0, 1.0)];
    [tool performDrawAtPoint:NSMakePoint(3.0, 3.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DRAGGED];

    NSRect invalidRect = [tool invalidRect];
    XCTAssertLessThan(NSMinX(invalidRect), 4.0);
    XCTAssertLessThan(NSMinY(invalidRect), 4.0);
    XCTAssertGreaterThan(NSWidth(invalidRect), 0.0);
    XCTAssertGreaterThan(NSHeight(invalidRect), 0.0);
    XCTAssertTrue(PBImageHasPixelWithAlpha(bufferImage, 255));

    [mainImage release];
    [bufferImage release];
}

- (void)testSelectionMarqueeStartPointIsClampedInsideCanvas
{
    NSBitmapImageRep *mainImage = nil;
    NSBitmapImageRep *bufferImage = nil;
    [SWImageTools initImageRep:&mainImage withSize:NSMakeSize(6.0, 6.0)];
    [SWImageTools initImageRep:&bufferImage withSize:NSMakeSize(6.0, 6.0)];
    SWSelectionTool *tool = PBMakeSelectionTool();

    [tool setSavedPoint:NSMakePoint(-4.0, -2.0)];
    [tool performDrawAtPoint:NSMakePoint(3.0, 4.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DRAGGED];

    NSRect marqueeRect = [tool clippingRect];
    XCTAssertEqualWithAccuracy(NSMinX(marqueeRect), 0.0, 0.001);
    XCTAssertEqualWithAccuracy(NSMinY(marqueeRect), 0.0, 0.001);
    XCTAssertEqualWithAccuracy(NSWidth(marqueeRect), 3.0, 0.001);
    XCTAssertEqualWithAccuracy(NSHeight(marqueeRect), 4.0, 0.001);

    [tool performDrawAtPoint:NSMakePoint(3.0, 4.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_UP];

    NSRect selectionRect = [tool clippingRect];
    XCTAssertEqualWithAccuracy(NSMinX(selectionRect), 0.0, 0.001);
    XCTAssertEqualWithAccuracy(NSMinY(selectionRect), 0.0, 0.001);
    XCTAssertEqualWithAccuracy(NSWidth(selectionRect), 3.0, 0.001);
    XCTAssertEqualWithAccuracy(NSHeight(selectionRect), 4.0, 0.001);

    [tool tieUpLooseEnds];
    [mainImage release];
    [bufferImage release];
}

- (void)testCenteringClipViewForwardsOffCanvasMouseDownWhenDocumentViewOptsIn
{
    SWCenteringClipView *clipView = [[[SWCenteringClipView alloc] initWithFrame:NSMakeRect(0.0, 0.0, 20.0, 20.0)] autorelease];
    PBOffCanvasMouseViewDouble *documentView = [[[PBOffCanvasMouseViewDouble alloc] initWithFrame:NSMakeRect(0.0, 0.0, 10.0, 10.0)] autorelease];
    [clipView setDocumentView:documentView];
    NSEvent *event = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown
                                        location:NSMakePoint(1.0, 1.0)
                                   modifierFlags:0
                                       timestamp:0
                                    windowNumber:0
                                         context:nil
                                     eventNumber:0
                                      clickCount:1
                                        pressure:1.0];

    [documentView setReceiveOffCanvasMouseEvents:YES];
    [clipView mouseDown:event];
    XCTAssertEqual([documentView mouseDownCount], 1);

    [documentView setReceiveOffCanvasMouseEvents:NO];
    [clipView mouseDown:event];
    XCTAssertEqual([documentView mouseDownCount], 1);
}

- (void)testSelectionToolMovesSelectedBitmapOnCommit
{
    NSBitmapImageRep *mainImage = nil;
    NSBitmapImageRep *bufferImage = nil;
    [SWImageTools initImageRep:&mainImage withSize:NSMakeSize(5.0, 5.0)];
    [SWImageTools initImageRep:&bufferImage withSize:NSMakeSize(5.0, 5.0)];
    PBSetDisplayPixel(mainImage, 1, 1, 255, 0, 0, 255);
    SWSelectionTool *tool = PBMakeSelectionTool();

    [tool setSavedPoint:NSMakePoint(1.0, 1.0)];
    [tool performDrawAtPoint:NSMakePoint(2.0, 2.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_UP];

    [tool setSavedPoint:NSMakePoint(1.0, 1.0)];
    [tool performDrawAtPoint:NSMakePoint(1.0, 1.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(3.0, 2.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DRAGGED];

    PBAssertDisplayPixelEquals(bufferImage, 3, 2, 255, 0, 0, 255);
    XCTAssertTrue(NSPointInRect(NSMakePoint(3.0, 2.0), [tool invalidRect]));

    [tool tieUpLooseEnds];

    PBAssertDisplayPixelEquals(mainImage, 1, 1, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 3, 2, 255, 0, 0, 255);

    [mainImage release];
    [bufferImage release];
}

- (void)testSelectionToolDragsLiveSelectedBitmapThroughMouseSequence
{
    NSBitmapImageRep *mainImage = nil;
    NSBitmapImageRep *bufferImage = nil;
    [SWImageTools initImageRep:&mainImage withSize:NSMakeSize(10.0, 10.0)];
    [SWImageTools initImageRep:&bufferImage withSize:NSMakeSize(10.0, 10.0)];
    PBSetDisplayPixel(mainImage, 3, 3, 255, 0, 0, 255);
    PBSetDisplayPixel(mainImage, 4, 3, 0, 255, 0, 255);
    PBSetDisplayPixel(mainImage, 3, 4, 0, 0, 255, 255);
    SWSelectionTool *tool = PBMakeSelectionTool();

    [tool setSavedPoint:NSMakePoint(1.0, 1.0)];
    [tool performDrawAtPoint:NSMakePoint(1.0, 1.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(6.0, 6.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DRAGGED];
    [tool performDrawAtPoint:NSMakePoint(6.0, 6.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_UP];

    PBAssertDisplayPixelEquals(mainImage, 3, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 4, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 3, 4, 255, 255, 255, 255);

    [tool setSavedPoint:NSMakePoint(3.0, 3.0)];
    [tool performDrawAtPoint:NSMakePoint(3.0, 3.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(6.0, 4.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DRAGGED];

    PBAssertDisplayPixelEquals(bufferImage, 6, 4, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals(bufferImage, 7, 4, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals(bufferImage, 6, 5, 0, 0, 255, 255);

    [tool performDrawAtPoint:NSMakePoint(6.0, 4.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_UP];

    PBAssertDisplayPixelEquals(bufferImage, 7, 4, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals(bufferImage, 6, 5, 0, 0, 255, 255);

    [tool tieUpLooseEnds];

    PBAssertDisplayPixelEquals(mainImage, 3, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 4, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 3, 4, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 6, 4, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals(mainImage, 7, 4, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals(mainImage, 6, 5, 0, 0, 255, 255);

    [mainImage release];
    [bufferImage release];
}

- (void)testSelectionToolAppliesMouseUpDeltaWhenReleaseIsOutsideSelection
{
    NSBitmapImageRep *mainImage = nil;
    NSBitmapImageRep *bufferImage = nil;
    [SWImageTools initImageRep:&mainImage withSize:NSMakeSize(10.0, 10.0)];
    [SWImageTools initImageRep:&bufferImage withSize:NSMakeSize(10.0, 10.0)];
    PBSetDisplayPixel(mainImage, 3, 3, 255, 0, 0, 255);
    PBSetDisplayPixel(mainImage, 4, 3, 0, 255, 0, 255);
    SWSelectionTool *tool = PBMakeSelectionTool();

    [tool setSavedPoint:NSMakePoint(2.0, 2.0)];
    [tool performDrawAtPoint:NSMakePoint(5.0, 5.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_UP];
    [tool setSavedPoint:NSMakePoint(3.0, 3.0)];
    [tool performDrawAtPoint:NSMakePoint(3.0, 3.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(7.0, 3.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_UP];

    PBAssertDisplayPixelEquals(bufferImage, 7, 3, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals(bufferImage, 8, 3, 0, 255, 0, 255);

    [tool tieUpLooseEnds];

    PBAssertDisplayPixelEquals(mainImage, 3, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 4, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 7, 3, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals(mainImage, 8, 3, 0, 255, 0, 255);

    [mainImage release];
    [bufferImage release];
}

- (void)testSelectionToolMovesDisplayPixelsWithoutVerticalDistortion
{
    NSBitmapImageRep *mainImage = nil;
    NSBitmapImageRep *bufferImage = nil;
    [SWImageTools initImageRep:&mainImage withSize:NSMakeSize(12.0, 12.0)];
    [SWImageTools initImageRep:&bufferImage withSize:NSMakeSize(12.0, 12.0)];
    PBSetDisplayPixel(mainImage, 3, 3, 255, 0, 0, 255);
    PBSetDisplayPixel(mainImage, 4, 4, 0, 255, 0, 255);
    PBSetDisplayPixel(mainImage, 5, 5, 0, 0, 255, 255);
    SWSelectionTool *tool = PBMakeSelectionTool();

    [tool setSavedPoint:NSMakePoint(2.0, 2.0)];
    [tool performDrawAtPoint:NSMakePoint(7.0, 7.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_UP];
    [tool setSavedPoint:NSMakePoint(3.0, 3.0)];
    [tool performDrawAtPoint:NSMakePoint(3.0, 3.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(3.0, 7.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DRAGGED];

    PBAssertDisplayPixelEquals(bufferImage, 3, 7, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals(bufferImage, 4, 8, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals(bufferImage, 5, 9, 0, 0, 255, 255);

    [tool tieUpLooseEnds];

    PBAssertDisplayPixelEquals(mainImage, 3, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 4, 4, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 5, 5, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 3, 7, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals(mainImage, 4, 8, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals(mainImage, 5, 9, 0, 0, 255, 255);

    [mainImage release];
    [bufferImage release];
}

- (void)testSelectionToolUndoRestoresMovedSelection
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(10.0, 10.0)] autorelease];
    PBCanvasUndoHost *undoHost = [[[PBCanvasUndoHost alloc] initWithDataSource:dataSource] autorelease];
    NSBitmapImageRep *mainImage = [dataSource mainImage];
    NSBitmapImageRep *bufferImage = [dataSource bufferImage];
    PBFillImage(mainImage, 255, 255, 255, 255);
    PBSetDisplayPixel(mainImage, 3, 3, 255, 0, 0, 255);
    PBSetDisplayPixel(mainImage, 4, 3, 0, 255, 0, 255);
    PBSetDisplayPixel(mainImage, 3, 4, 0, 0, 255, 255);
    SWSelectionTool *tool = PBMakeSelectionTool();
    [tool setDocument:(SWDocument *)undoHost];

    [tool setSavedPoint:NSMakePoint(1.0, 1.0)];
    [tool performDrawAtPoint:NSMakePoint(6.0, 6.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_UP];
    [tool setSavedPoint:NSMakePoint(3.0, 3.0)];
    [tool performDrawAtPoint:NSMakePoint(3.0, 3.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(6.0, 4.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DRAGGED];
    [tool tieUpLooseEnds];

    PBAssertDisplayPixelEquals([dataSource mainImage], 3, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 4, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 3, 4, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 6, 4, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 7, 4, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 6, 5, 0, 0, 255, 255);

    [[undoHost undoManager] undo];

    PBAssertDisplayPixelEquals([dataSource mainImage], 3, 3, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 4, 3, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 3, 4, 0, 0, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 6, 4, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 7, 4, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 6, 5, 255, 255, 255, 255);

    [[undoHost undoManager] redo];

    PBAssertDisplayPixelEquals([dataSource mainImage], 3, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 4, 3, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 3, 4, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 6, 4, 255, 0, 0, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 7, 4, 0, 255, 0, 255);
    PBAssertDisplayPixelEquals([dataSource mainImage], 6, 5, 0, 0, 255, 255);
}

- (void)testSelectionToolCanDiscardLiveSelectionBeforeCanvasRestore
{
    SWImageDataSource *dataSource = [[[SWImageDataSource alloc] initWithSize:NSMakeSize(8.0, 8.0)] autorelease];
    NSBitmapImageRep *originalBufferImage = [dataSource bufferImage];
    PBSetDisplayPixel([dataSource mainImage], 3, 3, 255, 0, 0, 255);
    SWCanvasHistorySnapshot *snapshot = [dataSource canvasHistorySnapshot];
    SWSelectionTool *tool = PBMakeSelectionTool();

    [tool setSavedPoint:NSMakePoint(1.0, 1.0)];
    [tool performDrawAtPoint:NSMakePoint(5.0, 5.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_UP];
    [tool setSavedPoint:NSMakePoint(3.0, 3.0)];
    [tool performDrawAtPoint:NSMakePoint(3.0, 3.0)
               withMainImage:[dataSource mainImage]
                 bufferImage:[dataSource bufferImage]
                  mouseEvent:MOUSE_DOWN];

    [tool discardSelection];
    [dataSource restoreCanvasHistorySnapshot:snapshot];
    XCTAssertNotEqual(originalBufferImage, [dataSource bufferImage]);

    [tool tieUpLooseEnds];
    PBAssertDisplayPixelEquals([dataSource mainImage], 3, 3, 255, 0, 0, 255);
}

- (void)testSelectionToolClearsOriginalPixelsWhenBackgroundColorIsMissing
{
    NSBitmapImageRep *mainImage = nil;
    NSBitmapImageRep *bufferImage = nil;
    [SWImageTools initImageRep:&mainImage withSize:NSMakeSize(5.0, 5.0)];
    [SWImageTools initImageRep:&bufferImage withSize:NSMakeSize(5.0, 5.0)];
    PBSetDisplayPixel(mainImage, 1, 1, 255, 0, 0, 255);
    PBSetDisplayPixel(mainImage, 2, 1, 255, 0, 0, 255);
    SWSelectionTool *tool = PBMakeSelectionToolWithoutBackgroundColor();

    [tool setSavedPoint:NSMakePoint(1.0, 1.0)];
    [tool performDrawAtPoint:NSMakePoint(3.0, 2.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_UP];
    [tool setSavedPoint:NSMakePoint(1.0, 1.0)];
    [tool performDrawAtPoint:NSMakePoint(1.0, 1.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DOWN];
    [tool performDrawAtPoint:NSMakePoint(3.0, 2.0)
               withMainImage:mainImage
                 bufferImage:bufferImage
                  mouseEvent:MOUSE_DRAGGED];

    PBAssertDisplayPixelEquals(mainImage, 1, 1, 255, 255, 255, 255);
    PBAssertDisplayPixelEquals(mainImage, 2, 1, 255, 255, 255, 255);

    [mainImage release];
    [bufferImage release];
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

    SWBrushTool *tool = [[[SWBrushTool alloc] initWithToolboxState:nil] autorelease];
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
