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


#import "SWToolboxSurfaceController.h"
#import "SWToolbox.h"
#import "SWToolList.h"
#import "SWTool.h"
#import "SWColorSelector.h"
#import "SWButtonCell.h"
#import "SWMatrix.h"

// Heights for the panel, based on what is shown
#define LARGE_HEIGHT 467
#define SMALL_HEIGHT 367

static void *SWToolboxSurfaceCurrentToolContext = &SWToolboxSurfaceCurrentToolContext;
static void *SWToolboxSurfaceBoundKeyContext = &SWToolboxSurfaceBoundKeyContext;

// Shared-state keys whose changes must be re-broadcast on this controller so the
// Cocoa bindings in the nib (stroke slider, color wells) that target File's Owner
// refresh when the state is mutated through another channel (eyedropper, scroll wheel).
static NSString * const SWToolboxSurfaceBoundStateKeys[] = { @"foregroundColor", @"backgroundColor", @"lineWidth" };

@interface SWToolboxVisualOverlay : NSView {
	SWToolboxSurfaceController *controller;
	SWMatrix *toolMatrix;
	SWMatrix *transparencyMatrix;
	SWMatrix *fillMatrix;
}

- (id)initWithFrame:(NSRect)frame
		 controller:(SWToolboxSurfaceController *)aController
		 toolMatrix:(SWMatrix *)aToolMatrix
 transparencyMatrix:(SWMatrix *)aTransparencyMatrix
		 fillMatrix:(SWMatrix *)aFillMatrix;

@end

@implementation SWToolboxVisualOverlay

- (id)initWithFrame:(NSRect)frame
		 controller:(SWToolboxSurfaceController *)aController
		 toolMatrix:(SWMatrix *)aToolMatrix
 transparencyMatrix:(SWMatrix *)aTransparencyMatrix
		 fillMatrix:(SWMatrix *)aFillMatrix
{
	if (self = [super initWithFrame:frame]) {
		controller = aController;
		toolMatrix = aToolMatrix;
		transparencyMatrix = aTransparencyMatrix;
		fillMatrix = aFillMatrix;
	}
	return self;
}

- (BOOL)isOpaque
{
	return YES;
}

- (NSView *)hitTest:(NSPoint)point
{
#pragma unused(point)
	return nil;
}

- (void)drawMatrix:(SWMatrix *)matrix
{
	if (!matrix || [matrix isHidden])
		return;

	for (NSInteger row = 0; row < [matrix numberOfRows]; row++) {
		for (NSInteger column = 0; column < [matrix numberOfColumns]; column++) {
			NSCell *cell = [matrix cellAtRow:row column:column];
			NSImage *image = [cell image];
			if ([cell isKindOfClass:[NSButtonCell class]]) {
				NSButtonCell *buttonCell = (NSButtonCell *)cell;
				if ([buttonCell state] == NSOnState && [buttonCell alternateImage])
					image = [buttonCell alternateImage];
			}
			if (!image)
				continue;

			NSRect cellFrame = [matrix convertRect:[matrix cellFrameAtRow:row column:column] toView:self];
			NSSize imageSize = [image size];
			NSRect imageFrame = NSMakeRect(NSMidX(cellFrame) - imageSize.width / 2.0,
										   NSMidY(cellFrame) - imageSize.height / 2.0,
										   imageSize.width,
										   imageSize.height);
			[image drawInRect:imageFrame
					 fromRect:NSZeroRect
					operation:NSCompositingOperationSourceOver
					 fraction:[cell isEnabled] ? 1.0 : 0.4
			   respectFlipped:YES
						hints:nil];
		}
	}
}

- (void)drawLineWidthControls
{
	NSString *label = [NSString stringWithFormat:@"Stroke: %ld", (long)[controller lineWidthDisplay]];
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
								[NSFont boldSystemFontOfSize:9.0], NSFontAttributeName,
								[NSColor colorWithCalibratedWhite:0.78 alpha:1.0], NSForegroundColorAttributeName,
								nil];
	[label drawAtPoint:NSMakePoint(5.0, 101.0) withAttributes:attributes];

	NSRect track = NSMakeRect(15.0, 84.0, 43.0, 4.0);
	[[NSColor colorWithCalibratedWhite:0.52 alpha:1.0] setFill];
	NSRectFill(track);

	NSInteger value = fmax(1, fmin(10, [controller lineWidthDisplay]));
	CGFloat knobX = NSMinX(track) + ((CGFloat)value - 1.0) / 9.0 * NSWidth(track);
	NSImage *knobImage = [NSImage imageNamed:@"knob.png"];
	if (knobImage) {
		NSSize knobSize = [knobImage size];
		NSRect knobFrame = NSMakeRect(knobX - knobSize.width / 2.0,
									  NSMidY(track) - knobSize.height / 2.0,
									  knobSize.width,
									  knobSize.height);
		[knobImage drawInRect:knobFrame
					 fromRect:NSZeroRect
					operation:NSCompositingOperationSourceOver
					 fraction:1.0
			   respectFlipped:YES
						hints:nil];
	} else {
		[[NSColor colorWithCalibratedWhite:0.82 alpha:1.0] setFill];
		[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(knobX - 4.0, 80.0, 8.0, 12.0)] fill];
	}
}

- (void)drawColorWellWithFrame:(NSRect)frame color:(NSColor *)color
{
	NSRect wellFrame = NSInsetRect(frame, 4.0, 4.0);
	NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:wellFrame xRadius:4.0 yRadius:4.0];
	NSColor *displayColor = color ? color : [NSColor clearColor];
	[[displayColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] setFill];
	[path fill];
	[[NSColor colorWithCalibratedWhite:0.72 alpha:1.0] setStroke];
	[path setLineWidth:1.0];
	[path stroke];
}

- (void)drawColorSelector
{
	[self drawColorWellWithFrame:NSMakeRect(20.0, 4.0, 48.0, 48.0) color:[controller backgroundColor]];
	[self drawColorWellWithFrame:NSMakeRect(4.0, 21.0, 48.0, 48.0) color:[controller foregroundColor]];

	NSImage *arrow = [NSImage imageNamed:@"arrow.png"];
	if (arrow) {
		[arrow drawInRect:NSMakeRect(50.0, 52.0, 15.0, 22.0)
				 fromRect:NSZeroRect
				operation:NSCompositingOperationSourceOver
				 fraction:1.0
		   respectFlipped:YES
					hints:nil];
	}
}

- (void)drawRect:(NSRect)dirtyRect
{
#pragma unused(dirtyRect)
	[[NSColor colorWithCalibratedWhite:0.16 alpha:1.0] setFill];
	NSRectFill([self bounds]);

	[self drawMatrix:toolMatrix];
	[self drawMatrix:fillMatrix];
	[self drawMatrix:transparencyMatrix];
	[self drawLineWidthControls];
	[self drawColorSelector];
}

@end

@implementation SWToolboxSurfaceController

@synthesize toolboxState;

- (NSView *)toolboxSurfaceView
{
	if (!toolboxSurfaceView)
		toolboxSurfaceView = [[[self window] contentView] retain];
	return toolboxSurfaceView;
}

- (NSView *)detachedToolboxViewForEmbedding
{
	NSView *surfaceView = [[self toolboxSurfaceView] retain];
	if ([[self window] contentView] == surfaceView) {
		NSView *emptyView = [[[NSView alloc] initWithFrame:[surfaceView frame]] autorelease];
		[[self window] setContentView:emptyView];
	}
	embeddedSurface = YES;
	[[self window] orderOut:nil];
	return [surfaceView autorelease];
}

- (id)initWithWindowNibName:(NSString *)windowNibName
{
	return [self initWithToolboxState:[SWToolboxState sharedToolboxState]
						windowNibName:windowNibName];
}

- (id)initWithToolboxState:(SWToolboxState *)state
			 windowNibName:(NSString *)windowNibName
{
	if (self = [super initWithWindowNibName:windowNibName]) {
		toolboxState = [state retain];
		[toolboxState addObserver:self
						forKeyPath:@"currentTool"
						   options:NSKeyValueObservingOptionNew
						   context:SWToolboxSurfaceCurrentToolContext];
		for (NSUInteger i = 0; i < sizeof(SWToolboxSurfaceBoundStateKeys) / sizeof(NSString *); i++) {
			[toolboxState addObserver:self
							forKeyPath:SWToolboxSurfaceBoundStateKeys[i]
							   options:0
							   context:SWToolboxSurfaceBoundKeyContext];
		}
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(toolboxVisualStateChanged:)
													 name:SWToolboxVisualStateChangedNotification
												   object:nil];

		[NSBezierPath setDefaultLineCapStyle:NSRoundLineCapStyle];
		[NSBezierPath setDefaultLineJoinStyle:NSRoundLineJoinStyle];
		[NSBezierPath setDefaultWindingRule:NSEvenOddWindingRule];
	}

	return self;
}

- (void)awakeFromNib
{
	[self captureOriginalToolboxLayout];
	[self installToolboxVisualOverlay];

	toolbox = [[SWToolbox alloc] initWithDocument:nil toolboxState:toolboxState];
	[self selectCellForCurrentTool];
	[self updateSurfaceForCurrentTool];
	[self toolboxVisualStateChanged:nil];
}

- (NSInteger)lineWidth
{
	return [toolboxState lineWidth];
}

- (void)setLineWidth:(NSInteger)width
{
	[toolboxState setLineWidth:width];
}

- (NSInteger)lineWidthDisplay
{
	return [toolboxState lineWidthDisplay];
}

- (void)setLineWidthDisplay:(NSInteger)width
{
	[toolboxState setLineWidthDisplay:width];
}

- (BOOL)selectionTransparency
{
	return [toolboxState selectionTransparency];
}

- (void)setSelectionTransparency:(BOOL)flag
{
	[toolboxState setSelectionTransparency:flag];
}

- (NSString *)currentTool
{
	return [toolboxState currentTool];
}

- (void)setCurrentTool:(NSString *)tool
{
	if (tool && ![tool isEqualToString:@""])
		[toolboxState setCurrentTool:tool];
	[self updateSurfaceForCurrentTool];
}

- (SWFillStyle)fillStyle
{
	return [toolboxState fillStyle];
}

- (void)setFillStyle:(SWFillStyle)style
{
	[toolboxState setFillStyle:style];
}

- (NSColor *)foregroundColor
{
	return [toolboxState foregroundColor];
}

- (void)setForegroundColor:(NSColor *)color
{
	[toolboxState setForegroundColor:color];
}

- (NSColor *)backgroundColor
{
	return [toolboxState backgroundColor];
}

- (void)setBackgroundColor:(NSColor *)color
{
	[toolboxState setBackgroundColor:color];
}

- (void)captureOriginalToolboxLayout
{
	if (originalContentHeight > 0.0)
		return;

	originalContentHeight = NSHeight([[self toolboxSurfaceView] bounds]);
	originalToolMatrixFrame = [toolMatrix frame];
	originalTransparencyMatrixFrame = [transparencyMatrix frame];
	originalFillMatrixFrame = [fillMatrix frame];
}

- (void)pinToolboxMatricesToTop
{
	if (originalContentHeight <= 0.0)
		return;

	CGFloat yDelta = NSHeight([[self toolboxSurfaceView] bounds]) - originalContentHeight;
	[toolMatrix setFrame:NSOffsetRect(originalToolMatrixFrame, 0.0, yDelta)];
	[transparencyMatrix setFrame:NSOffsetRect(originalTransparencyMatrixFrame, 0.0, yDelta)];
	[fillMatrix setFrame:NSOffsetRect(originalFillMatrixFrame, 0.0, yDelta)];
	[self toolboxVisualStateChanged:nil];
}

- (void)installToolboxVisualOverlay
{
	NSView *contentView = [self toolboxSurfaceView];
	if (toolboxVisualOverlay || !contentView)
		return;

	toolboxVisualOverlay = [[SWToolboxVisualOverlay alloc] initWithFrame:[contentView bounds]
															  controller:self
															  toolMatrix:toolMatrix
														transparencyMatrix:transparencyMatrix
															  fillMatrix:fillMatrix];
	[toolboxVisualOverlay setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	[contentView addSubview:toolboxVisualOverlay positioned:NSWindowAbove relativeTo:nil];
}

- (void)toolboxVisualStateChanged:(NSNotification *)notification
{
#pragma unused(notification)
	[toolboxVisualOverlay setNeedsDisplay:YES];
}

- (BOOL)selectToolCellWithTitle:(NSString *)title
{
	if (!title)
		return NO;

	for (NSCell *cell in [toolMatrix cells]) {
		if ([[cell title] isEqualToString:title]) {
			[toolMatrix selectCell:cell];
			return YES;
		}
	}
	return NO;
}

- (void)selectCellForCurrentTool
{
	[self selectToolCellWithTitle:[self currentTool]];
}

- (void)updateSurfaceForCurrentTool
{
	if (!toolbox)
		return;

	SWTool *tempTool = [toolbox toolForLabel:[self currentTool]];
	if (!tempTool)
		return;

	[fillMatrix setHidden:(![tempTool shouldShowFillOptions])];
	[transparencyMatrix setHidden:(![tempTool shouldShowTransparencyOptions])];

	// An embedded surface has no window of its own to resize; it just re-pins
	// its matrices to the top of whatever view is hosting it.
	if (!embeddedSurface) {
		CGFloat height = ([tempTool shouldShowFillOptions] || [tempTool shouldShowTransparencyOptions]) ? LARGE_HEIGHT : SMALL_HEIGHT;
		NSRect aRect = [[super window] frame];
		aRect.origin.y += (aRect.size.height - height);
		aRect.size.height = height;
		[[super window] setFrame:aRect display:YES animate:NO];
	}
	[self pinToolboxMatricesToTop];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
						change:(NSDictionary *)change
					   context:(void *)context
{
#pragma unused(object, change)
	if (context == SWToolboxSurfaceCurrentToolContext && [keyPath isEqualToString:@"currentTool"]) {
		[self selectCellForCurrentTool];
		[self updateSurfaceForCurrentTool];
		return;
	}

	if (context == SWToolboxSurfaceBoundKeyContext) {
		// Our accessors forward to the shared state without emitting KVO, so bridge
		// the state's change onto our matching bound key. lineWidthDisplay derives
		// from lineWidth, so a lineWidth change surfaces on lineWidthDisplay.
		NSString *boundKey = [keyPath isEqualToString:@"lineWidth"] ? @"lineWidthDisplay" : keyPath;
		[self willChangeValueForKey:boundKey];
		[self didChangeValueForKey:boundKey];
		return;
	}

	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (void)updateInfo
{
	[toolboxState updateInfo];
	[self selectCellForCurrentTool];
	[self updateSurfaceForCurrentTool];
}

- (void)keyDown:(NSEvent *)event
{
	NSUInteger modifiers = [event modifierFlags];

	if (modifiers & NSAlternateKeyMask) {
		if ([event keyCode] == 125) {
			[self setLineWidthDisplay:fmax([self lineWidthDisplay] - 1, 1)];
		} else if ([event keyCode] == 126) {
			[self setLineWidthDisplay:[self lineWidthDisplay] + 1];
		}
	} else {
		NSString *string = [[event characters] lowercaseString];

		switch([string characterAtIndex:0]) {
			case 'a':
				DebugLog(@"AAA");
				break;
		}
	}
}

- (IBAction)flipColors:(id)sender
{
#pragma unused(sender)
	NSColor *tempColor = [[self foregroundColor] retain];
	[self setForegroundColor:[self backgroundColor]];
	[self setBackgroundColor:tempColor];
	[tempColor release];
}

- (IBAction)changeCurrentTool:(id)sender
{
	NSString *string = [[sender selectedCell] title];
	if (string && ![string isEqualToString:@""])
		[self setCurrentTool:string];
}

- (IBAction)changeFillStyle:(id)sender
{
	[self setFillStyle:[sender selectedTag]];
}

- (IBAction)changeSelectionTransparency:(id)sender
{
	[self setSelectionTransparency:[sender selectedTag]];
}

- (void)switchToScissors:(id)sender
{
#pragma unused(sender)
	if ([self selectToolCellWithTitle:@"Selection"])
		[self changeCurrentTool:toolMatrix];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[toolboxState removeObserver:self forKeyPath:@"currentTool"];
	for (NSUInteger i = 0; i < sizeof(SWToolboxSurfaceBoundStateKeys) / sizeof(NSString *); i++) {
		[toolboxState removeObserver:self forKeyPath:SWToolboxSurfaceBoundStateKeys[i]];
	}
	[toolboxVisualOverlay removeFromSuperview];
	[toolboxVisualOverlay release];
	[toolboxSurfaceView release];
	[toolbox release];
	[toolboxState release];
	[super dealloc];
}

@end
