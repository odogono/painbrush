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


#import "SWButtonCell.h"

static NSImage *SWButtonHighlightImage(NSSize size, BOOL pressed)
{
	NSInteger width = lround(size.width);
	NSInteger height = lround(size.height);

	if (width == 32 && height == 32)
		return [NSImage imageNamed:(pressed ? @"pressedsmall.png" : @"hoveredsmall.png")];
	else if (width == 64 && height == 32)
		return [NSImage imageNamed:(pressed ? @"pressedwide.png" : @"hoveredwide.png")];
	else if (width == 64 && height == 48)
		return [NSImage imageNamed:(pressed ? @"pressedwidetall.png" : @"hoveredwidetall.png")];
	else
		return nil;
}

static NSImage *SWButtonCompositedImage(NSImage *normal, NSImage *highlight, BOOL drawsPressedShadow)
{
	NSSize size = [normal size];
	NSRect imageRect = NSMakeRect(0.0, 0.0, size.width, size.height);
	NSImage *image = [[NSImage alloc] initWithSize:size];

	[image lockFocus];
	NSRectFillUsingOperation(imageRect, NSCompositingOperationClear);
	[highlight drawInRect:imageRect
				 fromRect:NSZeroRect
				operation:NSCompositingOperationSourceOver
				 fraction:1.0];

	NSShadow *shadow = nil;
	if (drawsPressedShadow) {
		shadow = [[NSShadow alloc] init];
		[shadow setShadowBlurRadius:4.0];
		[shadow setShadowColor:[NSColor whiteColor]];
		[shadow set];
	}

	[normal drawInRect:imageRect
			  fromRect:NSZeroRect
			 operation:NSCompositingOperationSourceOver
			  fraction:1.0];

	[shadow release];
	[image unlockFocus];

	return image;
}


@implementation SWButtonCell

- (void)setAlternateImage:(NSImage *)image
{
	// We never want an alternate image other than ours to be set
	return;
}

- (id)initWithCoder:(NSCoder *)coder
{
	[super initWithCoder:coder];
	
	backupImage = [[self image] retain];
	
	// Generate the two images we'll use for the other states
	[self generateAltImage];
	[self generateHovImage];
	
	return self;
}

- (void)generateAltImage
{
	if (!altImage) 
	{
		NSImage *normal = [self image];
		NSImage *highlight = SWButtonHighlightImage([normal size], YES);
		if (!normal || !highlight)
			return;
		
		altImage = SWButtonCompositedImage(normal, highlight, YES);
	}
}

- (void)generateHovImage
{
	if (!hovImage)
	{
		NSImage *normal = [self image];
		NSImage *highlight = SWButtonHighlightImage([normal size], NO);
		if (!normal || !highlight)
			return;
		
		hovImage = SWButtonCompositedImage(normal, highlight, NO);
	}
}

- (void)setIsHovered:(BOOL)flag;
{
	if (flag) {
		if (!hovImage) {
			[self generateHovImage];
		}
		[self setImage:hovImage];
	} else {
		[self setImage:backupImage];
	}
}

- (NSImage *)alternateImage
{
	if (!altImage) {
		[self generateAltImage];
	}
	return altImage;
}

- (void)dealloc
{
	[altImage release];
	[hovImage release];
	[backupImage release];
	
	[super dealloc];
}


@end
