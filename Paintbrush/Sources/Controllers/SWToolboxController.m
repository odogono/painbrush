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


#import "SWToolboxController.h"
#import "SWToolbox.h"
#import "SWToolList.h"
#import "SWColorSelector.h"
#import "SWDocument.h"
#import "SWButtonCell.h"
#import "SWMatrix.h"

// Heights for the panel, based on what is shown
#define LARGE_HEIGHT 467
#define SMALL_HEIGHT 367

NSString * const SWToolboxVisualStateChangedNotification = @"SWToolboxVisualStateChanged";

@interface SWToolboxVisualOverlay : NSView {
	SWToolboxController *controller;
	SWMatrix *toolMatrix;
	SWMatrix *transparencyMatrix;
	SWMatrix *fillMatrix;
}

- (id)initWithFrame:(NSRect)frame
		 controller:(SWToolboxController *)aController
		 toolMatrix:(SWMatrix *)aToolMatrix
 transparencyMatrix:(SWMatrix *)aTransparencyMatrix
		 fillMatrix:(SWMatrix *)aFillMatrix;

@end

@implementation SWToolboxVisualOverlay

- (id)initWithFrame:(NSRect)frame
		 controller:(SWToolboxController *)aController
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
	[[color colorUsingColorSpaceName:NSCalibratedRGBColorSpace] setFill];
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
	[[NSColor colorWithCalibratedWhite:0.16 alpha:1.0] setFill];
	NSRectFill([self bounds]);

	[self drawMatrix:toolMatrix];
	[self drawMatrix:fillMatrix];
	[self drawMatrix:transparencyMatrix];
	[self drawLineWidthControls];
	[self drawColorSelector];
}

@end

@implementation SWToolboxController

@synthesize lineWidth;
@synthesize selectionTransparency;
@synthesize currentTool;
@synthesize fillStyle;
@synthesize foregroundColor;
@synthesize backgroundColor;
@synthesize activeDocument;
//@synthesize toolListArray;

- (void)setForegroundColor:(NSColor *)color
{
	if (foregroundColor != color) {
		[foregroundColor release];
		foregroundColor = [color retain];
		[self toolboxVisualStateChanged:nil];
	}
}

- (void)setBackgroundColor:(NSColor *)color
{
	if (backgroundColor != color) {
		[backgroundColor release];
		backgroundColor = [color retain];
		[self toolboxVisualStateChanged:nil];
	}
}

- (void)setFillStyle:(SWFillStyle)style
{
	if (fillStyle != style) {
		fillStyle = style;
		[self toolboxVisualStateChanged:nil];
	}
}

- (void)setSelectionTransparency:(BOOL)flag
{
	if (selectionTransparency != flag) {
		selectionTransparency = flag;
		[self toolboxVisualStateChanged:nil];
	}
}

- (void)captureOriginalToolboxLayout
{
	if (originalContentHeight > 0.0)
		return;

	originalContentHeight = NSHeight([[[self window] contentView] bounds]);
	originalToolMatrixFrame = [toolMatrix frame];
	originalTransparencyMatrixFrame = [transparencyMatrix frame];
	originalFillMatrixFrame = [fillMatrix frame];
}

- (void)pinToolboxMatricesToTop
{
	if (originalContentHeight <= 0.0)
		return;

	CGFloat yDelta = NSHeight([[[self window] contentView] bounds]) - originalContentHeight;
	[toolMatrix setFrame:NSOffsetRect(originalToolMatrixFrame, 0.0, yDelta)];
	[transparencyMatrix setFrame:NSOffsetRect(originalTransparencyMatrixFrame, 0.0, yDelta)];
	[fillMatrix setFrame:NSOffsetRect(originalFillMatrixFrame, 0.0, yDelta)];
	[self toolboxVisualStateChanged:nil];
}

- (void)installToolboxVisualOverlay
{
	NSView *contentView = [[self window] contentView];
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
	[toolboxVisualOverlay setNeedsDisplay:YES];
}


// Curiosity...!
- (void)windowDidBecomeKey:(NSNotification *)notification
{
	NSWindow *window = [notification object];

	NSDocumentController *controller = [NSDocumentController sharedDocumentController];
	id document = [controller documentForWindow:window];
	if (document && [document class] == [SWDocument class]) {
        activeDocument = document;
		DebugLog(@"Key window is %@", document);		
	}
}


+ (id)sharedToolboxPanelController
{
	// By calling it static, a second instance of the pointer will never be created
	static SWToolboxController *sharedController;
	
	if (!sharedController) {
		sharedController = [[SWToolboxController alloc] initWithWindowNibName:@"Toolbox"];
	}
	
	return sharedController;
}


// Override the initializer
- (id)initWithWindowNibName:(NSString *)windowNibName
{
	if (self = [super initWithWindowNibName:windowNibName]) {		
		// Curiosity...
		[[NSNotificationCenter defaultCenter] addObserver:self
			   selector:@selector(windowDidBecomeKey:)
				   name:NSWindowDidBecomeKeyNotification
				 object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
			   selector:@selector(toolboxVisualStateChanged:)
				   name:SWToolboxVisualStateChangedNotification
				 object:nil];
		
	
		// Do some other initialization stuff
		[NSBezierPath setDefaultLineCapStyle:NSRoundLineCapStyle];
		[NSBezierPath setDefaultLineJoinStyle:NSRoundLineJoinStyle];
		[NSBezierPath setDefaultWindingRule:NSEvenOddWindingRule];
	}
	
	return self;
}


// Alert the observers that something's going on
- (void)awakeFromNib
{	
	[self captureOriginalToolboxLayout];
	[self installToolboxVisualOverlay];

	// Mah toolbox!  MINE!
	toolbox = [[SWToolbox alloc] initWithDocument:nil];
	
	// Set the starting toolbox info
	[self setLineWidthDisplay:3];
	[self setForegroundColor:[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0]];
	[self setBackgroundColor:[NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0]];
	[self setFillStyle:STROKE_ONLY];
	[self setSelectionTransparency:NO];
	[self changeCurrentTool:toolMatrix];	
	[self toolboxVisualStateChanged:nil];
}


// Called externally at times
- (void)updateInfo
{
	[self setLineWidthDisplay:[self lineWidthDisplay]];
	[self setForegroundColor:[self foregroundColor]];
	[self setBackgroundColor:[self backgroundColor]];
	[self setFillStyle:[self fillStyle]];
	[self setSelectionTransparency:[self selectionTransparency]];
	[self changeCurrentTool:toolMatrix];	
}


// The slider moved, meaning the line width should change
- (void)setLineWidth:(NSInteger)width
{
	// Allows for more line widths with less tick marks
	lineWidth = 2*width - 2;

	//[currentTool setLineWidth:lineWidth];
}


- (void)setLineWidthDisplay:(NSInteger)width
{
	[self setLineWidth:width];
	[self toolboxVisualStateChanged:nil];
}


- (NSInteger)lineWidthDisplay
{
	return (1+lineWidth) / 2 + 1;
}


- (void)setCurrentTool:(NSString *)tool
{
	// Don't tie up loose ends if there's no tool!
	currentTool = tool;
	
	SWTool *tempTool = [toolbox toolForLabel:currentTool];
		
	[fillMatrix setHidden:(![tempTool shouldShowFillOptions])];
	[transparencyMatrix setHidden:(![tempTool shouldShowTransparencyOptions])];
	
	// Handle resizing of tool palette, based on which tool is selected
	NSRect aRect = [[super window] frame];
	if ([tempTool shouldShowFillOptions] || [tempTool shouldShowTransparencyOptions]) {
		aRect.origin.y += (aRect.size.height - LARGE_HEIGHT);
		aRect.size.height = LARGE_HEIGHT;
	} else {
		aRect.origin.y += (aRect.size.height - SMALL_HEIGHT);
		aRect.size.height = SMALL_HEIGHT;
	}
	[[super window] setFrame:aRect display:YES animate:NO];
	[self pinToolboxMatricesToTop];
}


- (void)keyDown:(NSEvent *)event
{
	// At the moment, most of the keyboard shortcuts are set in Interface Builder
	NSUInteger modifiers = [event modifierFlags];
	
	if (modifiers & NSAlternateKeyMask) {
		// They held option
		if ([event keyCode] == 125) {
			// They pressed down
			[self setLineWidthDisplay:fmax([self lineWidthDisplay]-1,1)];
		} else if ([event keyCode] == 126) {
			// They pressed up
			[self setLineWidthDisplay:[self lineWidthDisplay]+1];
		}
	} else {
		// Check the letter pressed
		NSString *string = [[event characters] lowercaseString];
		
		switch([string characterAtIndex:0]) {
			case 'a':
				DebugLog(@"AAA");
				break;
		}
	}
}

// The IBActions we'll need
// Replaces the front color with the back, and vice-versa
- (IBAction)flipColors:(id)sender 
{
	NSColor *tempColor = [foregroundColor copy];
	[self setForegroundColor:backgroundColor];
	[self setBackgroundColor:tempColor];
}


// We use the title of the cell to indicate which tool to use
//TODO: Make this localization-friendly
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


// If "Paste" or "Select All" is chosen, we should switch to the scissors tool
- (void)switchToScissors:(id)sender
{
	for (NSCell *cell in [toolMatrix cells])
	{
		if ([[cell title] isEqualToString:@"Selection"])
		{
			[toolMatrix selectCell:cell];
			[self changeCurrentTool:toolMatrix];
			break;
		}
	}
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[toolboxVisualOverlay removeFromSuperview];
	[toolboxVisualOverlay release];
	[toolbox release];
	[super dealloc];
}

@end
