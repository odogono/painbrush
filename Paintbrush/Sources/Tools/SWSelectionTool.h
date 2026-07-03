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


#import <Cocoa/Cocoa.h>
#import "SWTool.h"

@class SWSelection;

@interface SWSelectionTool : SWTool {
	NSTimer *animationTimer;
	CGFloat dottedLineArray[2];
	NSInteger dottedLineOffset;
	NSPoint previousPoint;
	NSRect marqueeRect;

	BOOL shouldOmitBackground;
	SWSelection *selection;
}

- (BOOL)isSelected;
- (NSRect)clippingRect;
- (NSBitmapImageRep *)selectedImage;
- (NSData *)imageData;
- (void)setClippingRect:(NSRect)rect
			   forImage:(NSBitmapImageRep *)image
			bufferImage:(NSBitmapImageRep *)bufferImage
		  withMainImage:(NSBitmapImageRep *)mainImage;
- (void)drawNewBorder:(NSTimer *)timer;
- (void)updateBackgroundOmission;
- (void)cancelSelection;
- (void)discardSelection;

@end
