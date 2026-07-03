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

typedef enum {
	STROKE_ONLY,
	FILL_ONLY,
	FILL_AND_STROKE
} SWFillStyle;

// Posted when any toolbox control state changes so the visual overlay repaints.
extern NSString * const SWToolboxVisualStateChangedNotification;

@interface SWToolboxState : NSObject
{
	NSColor *foregroundColor;
	NSColor *backgroundColor;
	NSString *currentTool;
	NSInteger lineWidth;
	SWFillStyle fillStyle;
	BOOL selectionTransparency;
}

+ (id)sharedToolboxState;
- (void)updateInfo;

@property (assign) NSInteger lineWidthDisplay;
@property (assign, nonatomic) NSInteger lineWidth;
@property (assign) BOOL selectionTransparency;
@property (copy, nonatomic) NSString *currentTool;
@property (assign) SWFillStyle fillStyle;
@property (retain) NSColor *foregroundColor;
@property (retain) NSColor *backgroundColor;

@end
