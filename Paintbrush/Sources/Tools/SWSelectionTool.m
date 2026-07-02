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


#import "SWSelectionTool.h"
#import "SWToolboxController.h"
#import "SWDocument.h"
#if __has_include("Paintbrush-Swift.h")
#import "Paintbrush-Swift.h"
#else
#import "Test-Swift.h"
#endif

static NSPoint SWPointConstrainedToImage(NSPoint point, NSBitmapImageRep *image)
{
	NSSize size = [image size];
	point.x = fmin(fmax(point.x, 0.0), size.width);
	point.y = fmin(fmax(point.y, 0.0), size.height);
	return point;
}

@implementation SWSelectionTool

- (void)updateSelectionExtent
{
	if (selection && document)
		_bufferImage = [document updateSelectionExtentForSelectionRect:[self clippingRect]];
}

- (id)initWithController:(SWToolboxController *)controller;
{
	if (self = [super initWithController:controller]) {
		[controller addObserver:self
					 forKeyPath:@"selectionTransparency" 
						options:NSKeyValueObservingOptionNew 
						context:NULL];
		dottedLineOffset = 0;
		dottedLineArray[0] = 5.0;
		dottedLineArray[1] = 3.0;
		marqueeRect = NSZeroRect;
	}
	return self;
}

// The tools will observe several values set by the toolbox
- (void)observeValueForKeyPath:(NSString *)keyPath 
					  ofObject:(id)object 
						change:(NSDictionary *)change 
					   context:(void *)context
{
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	
	id thing = [change objectForKey:NSKeyValueChangeNewKey];
	
	if ([keyPath isEqualToString:@"selectionTransparency"]) 
	{
		shouldOmitBackground = [thing boolValue];
		[self updateBackgroundOmission];
	}
}

- (NSBezierPath *)pathFromPoint:(NSPoint)begin toPoint:(NSPoint)end
{
#pragma unused(begin, end)
	path = [NSBezierPath bezierPath];
	[path setLineWidth:1.0];
	[path setLineDash:dottedLineArray count:2 phase:dottedLineOffset];
	[path setLineCapStyle:NSSquareLineCapStyle];	
	
	// The 0.5s help because the width is 1, and that does weird stuff
	NSRect rect = [self clippingRect];
	[path appendBezierPathWithRect:
		NSMakeRect(rect.origin.x+0.5, rect.origin.y+0.5, rect.size.width-1, rect.size.height-1)];

	return path;	
}

- (NSColor *)selectionBackgroundColor
{
	if ([backColor isKindOfClass:[NSColor class]])
		return backColor;

	if ([toolboxController respondsToSelector:@selector(backgroundColor)]) {
		NSColor *color = [toolboxController backgroundColor];
		if ([color isKindOfClass:[NSColor class]])
			return color;
	}

	return [NSColor whiteColor];
}

- (NSBezierPath *)performDrawAtPoint:(NSPoint)point 
					   withMainImage:(NSBitmapImageRep *)mainImage 
						 bufferImage:(NSBitmapImageRep *)bufferImage 
						  mouseEvent:(SWMouseEvent)event
{	
	_bufferImage = bufferImage;
	_mainImage = mainImage;
	
	// Running the selection animator
	if (event == MOUSE_DOWN && animationTimer) 
	{
		[animationTimer invalidate];
		animationTimer = nil;
	}
	else if (event == MOUSE_UP && !NSEqualPoints(point, savedPoint)) 
	{
		// We are drawing the frame for the first time
		animationTimer = [NSTimer scheduledTimerWithTimeInterval:0.075 // 75 ms, or 13.33 Hz
														  target:self
														selector:@selector(drawNewBorder:)
														userInfo:nil
														 repeats:YES];		
	} 
	
	// If the rectangle has already been drawn
	if ([self isSelected])
	{
		BOOL pointIsInsideSelection = [[NSBezierPath bezierPathWithRect:[self clippingRect]] containsPoint:point];

		if (event == MOUSE_DOWN)
		{
			draggingSelection = pointIsInsideSelection;
			if (draggingSelection)
				previousPoint = point;
			else
				[self tieUpLooseEnds];
		}
		else if (event == MOUSE_DRAGGED || (event == MOUSE_UP && draggingSelection))
		{
			NSRect previousSelectionRect = [self clippingRect];

			CGFloat deltaX = point.x - previousPoint.x;
			CGFloat deltaY = point.y - previousPoint.y;
			previousPoint = point;
			
			// Do the moving thing
			[SWImageTools clearImage:bufferImage];
			[selection moveByDeltaX:deltaX y:deltaY];
			[self updateSelectionExtent];

			// The clipping rect is the new redraw rect
			[super addRectToRedrawRect:previousSelectionRect];
			[super addRectToRedrawRect:[self clippingRect]];
			
			// Finally, move the image and stroke it
			[self drawNewBorder:nil];

			if (event == MOUSE_UP)
				draggingSelection = NO;
		} 
		else if (!pointIsInsideSelection)
		{
			draggingSelection = NO;
			[self tieUpLooseEnds];
		}
	} 
	else
	{
		[SWImageTools clearImage:bufferImage];
		marqueeRect = NSZeroRect;
		
		NSPoint constrainedSavedPoint = SWPointConstrainedToImage(savedPoint, mainImage);
		point = SWPointConstrainedToImage(point, mainImage);
				
		// If this check fails, then they didn't draw a rectangle
		if (!NSEqualPoints(point, constrainedSavedPoint))
		{
			// Set the redraw rectangle
			[super addRedrawRectFromPoint:constrainedSavedPoint toPoint:point];
			
			NSRect rect = NSMakeRect(fmin(constrainedSavedPoint.x, point.x), fmin(constrainedSavedPoint.y, point.y),
									 fabs(point.x - constrainedSavedPoint.x), fabs(point.y - constrainedSavedPoint.y));
			marqueeRect = rect;

			// A straight horizontal/vertical drag yields a zero-area rect that still
			// differs from savedPoint; creating a 0-sized selection would crash.
			if (rect.size.width >= 1.0 && rect.size.height >= 1.0)
			{
				if (event == MOUSE_UP)
				{
					[SWImageTools clearImage:bufferImage];
					[selection release];
					selection = [[SWSelection alloc] initWithCanvasImage:mainImage
																	rect:rect
														 backgroundColor:[self selectionBackgroundColor]
														  omitBackground:shouldOmitBackground];
					marqueeRect = NSZeroRect;
					[self updateSelectionExtent];
				}
				else
					marqueeRect = rect;
			}
			
			// Finally, draw the image and the selection
			[self drawNewBorder:nil];
		}
	}
	return nil;
}

// Tick the timer!
- (void)drawNewBorder:(NSTimer *)timer
{
#pragma unused(timer)
	dottedLineOffset = (dottedLineOffset + 1) % 8;
	
	// Draw the backed image to the overlay
	if (_bufferImage) 
	{
		[SWImageTools clearImage:_bufferImage];
		SWLockFocus(_bufferImage);
		if (selection)
			[selection drawInImage:_bufferImage];
		
		// Next, stroke it
		[[NSGraphicsContext currentContext] setShouldAntialias:NO];
		[[NSColor darkGrayColor] setStroke];
		NSRect rect = [self clippingRect];
		[[self pathFromPoint:rect.origin
					 toPoint:NSMakePoint(rect.origin.x + rect.size.width,
										 rect.origin.y + rect.size.height)] stroke];
		SWUnlockFocus(_bufferImage);
	}
	
	// Get the view to perform a redraw to see the new border
	[NSApp sendAction:@selector(refreshImage:)
				   to:nil
				 from:self];
}

- (void)deleteKey
{
	// NB: don't reset the selection extent here. deleteKey is only reached via
	// -[SWPaintView clearOverlay], which resets the extent itself (both directly
	// and through tieUpLooseEnds). Resizing the buffer here would free the rep
	// that tieUpLooseEnds still clears via _bufferImage -> use-after-free.
	[selection clearSelectedImage];
}

- (void)cancelSelection
{
	// Escape cancels the selection. A Canvas-sourced selection filled its source
	// rect with the background color when it was created (lifting those pixels),
	// so restore them; a pasted selection has nothing on the Canvas to restore.
	if (selection && [selection hasOriginalCanvasImage])
		[selection restoreOriginalCanvasToImage:_mainImage];
	[self discardSelection];
}

- (void)updateBackgroundOmission
{
	[selection setShouldOmitBackground:shouldOmitBackground];
	
	// Update the UI with the new image
	[self drawNewBorder:nil];
}

- (void)discardSelection
{
	if (animationTimer)
	{
		[animationTimer invalidate];
		animationTimer = nil;
	}

	if (_bufferImage)
		[SWImageTools clearImage:_bufferImage];

	[selection release];
	selection = nil;
	marqueeRect = NSZeroRect;
	draggingSelection = NO;
	[document resetSelectionExtent];
	_bufferImage = nil;
	_mainImage = nil;
	[super resetRedrawRect];
}


- (void)tieUpLooseEnds
{
	[super tieUpLooseEnds];
	
	if (animationTimer) 
	{
		[animationTimer invalidate];
		animationTimer = nil;
	}
	
	// Before making an undo happen, copy _mainImage to mainImageCopy -- the undo-ing process will revert mainImage
	NSBitmapImageRep *mainImageCopy = nil;
	if (_mainImage)
	{
		[SWImageTools initImageRep:&mainImageCopy withSize:[_mainImage size]];
		[SWImageTools drawToImage:mainImageCopy fromImage:_mainImage withComposition:NO];
	}

	// Make an undo happen if the Selection came from existing Canvas pixels.
	if (selection && [selection hasOriginalCanvasImage])
	{
		[selection restoreOriginalCanvasToImage:_mainImage];
		[document registerDrawingUndo];
	}

	// Checking to see if references have been made; otherwise causes strange drawing bugs
	if (_mainImage && selection)
	{
		[selection commitToCanvasImage:mainImageCopy];

		// Redraw the entire image
		[super addRectToRedrawRect:NSMakeRect(0,0,[mainImageCopy size].width,[mainImageCopy size].height)];
		
		// Finally, move all of mainImageCopy to _mainImage
		[SWImageTools drawToImage:_mainImage fromImage:mainImageCopy withComposition:NO];
	} 
	else
		[super resetRedrawRect];
	
	// Now nuke the buffer image
	if (_bufferImage)
	{
		[SWImageTools clearImage:_bufferImage];
		_bufferImage = nil;
	}
	[document resetSelectionExtent];
	
	// Get rid of references to the selected image
	[selection release];
	selection = nil;
	marqueeRect = NSZeroRect;
	draggingSelection = NO;
	// Clean up after ourselves
	[mainImageCopy release];
	_mainImage = nil;
}

- (NSRect)clippingRect
{
	if (selection)
		return [selection clippingRect];
	if (!NSIsEmptyRect(marqueeRect))
		return marqueeRect;
	return NSZeroRect;
}

// Called from the PaintView when an image is pasted
- (void)setClippingRect:(NSRect)rect
			   forImage:(NSBitmapImageRep *)image
			bufferImage:(NSBitmapImageRep *)bufferImage
		  withMainImage:(NSBitmapImageRep *)mainImage
{
	_mainImage = mainImage;
	_bufferImage = bufferImage;
	[selection release];
	selection = [[SWSelection alloc] initWithPastedImage:image
												 origin:rect.origin
										backgroundColor:[self selectionBackgroundColor]
										 omitBackground:shouldOmitBackground];
	[self updateSelectionExtent];

	// Which one should we be using?  Let this method decide
	[self updateBackgroundOmission];
	
	// Draw the dotted line around the selected region
	[self drawNewBorder:nil];
	
	// Set the redraw rect!
	[super addRectToRedrawRect:[self clippingRect]];
	
	// Manually create the timer
	animationTimer = [NSTimer scheduledTimerWithTimeInterval:0.075 // 75 ms, or 13.33 Hz
													  target:self
													selector:@selector(drawNewBorder:)
													userInfo:nil
													 repeats:YES];	
}

- (NSData *)imageData
{
	return [selection tiffRepresentationForPasteboard];
}

- (NSBitmapImageRep *)selectedImage
{
	return [selection selectedImage];
}

- (BOOL)isSelected
{
	return selection != nil;
}

- (NSCursor *)cursor
{
	if (!customCursor) {
		customCursor = [[NSCursor crosshairCursor] retain];
	}
	return customCursor;
}

// We got better color accuracy in 2.1, so we flipped this back on
- (BOOL)shouldShowTransparencyOptions
{
	return YES;
}

// Overridden for right-click
- (BOOL)shouldShowContextualMenu
{
	return YES;
}

- (NSString *)description
{
	return @"Selection";
}

- (void)dealloc
{
	[toolboxController removeObserver:self forKeyPath:@"selectionTransparency"];
	[selection release];
	[super dealloc];
}

@end
