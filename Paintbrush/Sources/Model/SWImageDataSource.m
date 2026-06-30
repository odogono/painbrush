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


#import "SWImageDataSource.h"

static NSColor *SWCanvasBackgroundColor(void)
{
	Class toolboxControllerClass = NSClassFromString(@"SWToolboxController");
	SEL sharedControllerSelector = @selector(sharedToolboxPanelController);
	SEL backgroundColorSelector = @selector(backgroundColor);
	if (![toolboxControllerClass respondsToSelector:sharedControllerSelector])
		return [NSColor clearColor];

	id toolboxController = [toolboxControllerClass performSelector:sharedControllerSelector];
	if (![toolboxController respondsToSelector:backgroundColorSelector])
		return [NSColor clearColor];

	NSColor *backgroundColor = [toolboxController performSelector:backgroundColorSelector];
	return [backgroundColor isKindOfClass:[NSColor class]] ? backgroundColor : [NSColor clearColor];
}


@implementation SWCanvasHistorySnapshot

@synthesize canvasSize;
@synthesize mainImageData;

- (id)initWithCanvasSize:(NSSize)sizeIn
		   mainImageData:(NSData *)data
{
	self = [super init];
	if (self)
	{
		canvasSize = sizeIn;
		// TIFFRepresentation hands back an immutable NSData, so retain rather than copy the buffer
		mainImageData = [data retain];
	}
	return self;
}

- (void)dealloc
{
	[mainImageData release];
	[super dealloc];
}

@end


@implementation SWImageDataSource

// -----------------------------------------------------------------------------
//  Initializers
// -----------------------------------------------------------------------------


- (id)initWithSize:(NSSize)sizeIn
{
	self = [super init];
	if (self)
	{
		// Save the size
		size = sizeIn;
		
		// Create the two images we'll be using
		[SWImageTools initImageRep:&mainImage withSize:size];
		[SWImageTools initImageRep:&bufferImage withSize:size];
		
		// New Image: gotta paint the background color
		SWLockFocus(mainImage);

		NSColor *bgColor = SWCanvasBackgroundColor();
		[bgColor setFill];

		NSRect newRect = (NSRect) { NSZeroPoint, sizeIn };
		NSRectFill(newRect);
		
		SWUnlockFocus(mainImage);		
	}
	return self;
}


- (id)initWithURL:(NSURL *)url
{
	// Temporary image to get dimensions
	NSBitmapImageRep *tempImage = (NSBitmapImageRep *)[NSBitmapImageRep imageRepWithContentsOfURL:url];
	
	if (!tempImage)	// failure case
		return nil;
	
	// Run baseline initializer
	[self initWithSize:NSMakeSize([tempImage pixelsWide], [tempImage pixelsHigh])];
	
	// Copy the image to the mainImage
	[SWImageTools drawToImage:mainImage fromImage:tempImage withComposition:NO];
	
	// Flip it, since our views are all flipped
	if (mainImage)
		[SWImageTools flipImageVertical:mainImage];		
	
	return self;
}


- (id)initWithPasteboard
{
	NSBitmapImageRep *tempImage = (NSBitmapImageRep *)[NSBitmapImageRep imageRepWithPasteboard:[NSPasteboard generalPasteboard]];
	
	NSAssert(tempImage, @"We can't initialize with a pasteboard without an image on it!");
	if (!tempImage)	// failure case
		return nil;
	
	// Run baseline initializer
	[self initWithSize:NSMakeSize([tempImage pixelsWide], [tempImage pixelsHigh])];

	// Copy the image to the mainImage
	[SWImageTools drawToImage:mainImage fromImage:tempImage withComposition:NO];
	
	// Flip it, since our views are all flipped
	if (mainImage)
		[SWImageTools flipImageVertical:mainImage];
	
	return self;
}


- (void)dealloc
{
	// Clean up a bit after ourselves
	[imageArray release];
	[mainImage release];
	[bufferImage release];
	
	[super dealloc];
}


// -----------------------------------------------------------------------------
//  Mutators
// -----------------------------------------------------------------------------

- (void)resizeToSize:(NSSize)newSize
		  scaleImage:(BOOL)shouldScale;
{
	// We'll be replacing the two images behind the scenes
	NSBitmapImageRep *newMainImage = nil;
	NSBitmapImageRep *newBufferImage = nil;
	[SWImageTools initImageRep:&newMainImage 
					  withSize:newSize];
	[SWImageTools initImageRep:&newBufferImage
					  withSize:newSize];
	
	NSRect newRect = (NSRect) { NSZeroPoint, newSize };
	SWLockFocus(newMainImage);
	if (shouldScale) 
	{
		// Stretch the image to the correct size
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
		[mainImage drawInRect:newRect];
	}
	else
	{
		NSColor *bgColor = SWCanvasBackgroundColor();
		[bgColor setFill];
		NSRectFill(newRect);
		[mainImage drawAtPoint:NSZeroPoint];
	}
	SWUnlockFocus(newMainImage);

	// Release and set (no need to retain: we already own the new images)
	[mainImage release];
	[bufferImage release];
	[imageArray release];
	mainImage = newMainImage;
	bufferImage = newBufferImage;
	imageArray = nil;

	// Finally, update our cached size
	size = newSize;
}


// -----------------------------------------------------------------------------
//  Accessors
// -----------------------------------------------------------------------------

@synthesize size;
@synthesize mainImage;
@synthesize bufferImage;


// Creates an array if none exists, and returns it
- (NSArray *)imageArray
{
	if (!imageArray)
		imageArray = [[NSArray alloc] initWithObjects:mainImage, bufferImage, nil];
	
	return imageArray;
}


// -----------------------------------------------------------------------------
//  Data
// -----------------------------------------------------------------------------

- (SWCanvasHistorySnapshot *)canvasHistorySnapshot
{
	return [[[SWCanvasHistorySnapshot alloc] initWithCanvasSize:size
												 mainImageData:[self copyMainImageData]] autorelease];
}


- (void)restoreCanvasHistorySnapshot:(SWCanvasHistorySnapshot *)snapshot
{
	if (!snapshot)
		return;

	[mainImage release];
	[bufferImage release];
	[imageArray release];
	mainImage = nil;
	bufferImage = nil;
	imageArray = nil;

	size = [snapshot canvasSize];
	// initImageRep: leaves both reps fully transparent; restoreMainImageFromData: then overwrites main
	[SWImageTools initImageRep:&mainImage withSize:size];
	[SWImageTools initImageRep:&bufferImage withSize:size];
	[self restoreMainImageFromData:[snapshot mainImageData]];
}


- (NSData *)copyMainImageData
{
	if (mainImage)
		return [mainImage TIFFRepresentation];
	
	// No image, no data
	return nil;
}


- (void)restoreMainImageFromData:(NSData *)tiffData
{
	if (!tiffData)
		return;
	
	NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithData:tiffData];
	[SWImageTools drawToImage:mainImage fromImage:imageRep withComposition:NO];
	[imageRep release];
}


- (void)restoreBufferImageFromData:(NSData *)tiffData
{
	if (!tiffData)
		return;
	
	NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithData:tiffData];
	
	// Unlike the main image, the buffer image can have its size change.  Do that here.
	NSRect bufferImageRect = NSMakeRect(0, 0, [bufferImage pixelsWide], [bufferImage pixelsHigh]);
	NSRect pastedImageRect = NSMakeRect(0, 0, [imageRep pixelsWide], [imageRep pixelsHigh]);
	NSRect finalRect = NSUnionRect(bufferImageRect, pastedImageRect);
	
	if (!NSEqualRects(bufferImageRect, finalRect))
	{
		// Pasting something bigger than the previous image, so create a new one with the new size
		[bufferImage release];
		[imageArray release];
		bufferImage = nil;
		imageArray = nil;

		[SWImageTools initImageRep:&bufferImage withSize:finalRect.size];
	}

	[SWImageTools drawToImage:bufferImage fromImage:imageRep withComposition:NO];
	[imageRep release];
}


@end
