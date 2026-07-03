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


#import "SWToolboxState.h"

NSString * const SWToolboxVisualStateChangedNotification = @"SWToolboxVisualStateChanged";

@implementation SWToolboxState

@synthesize lineWidth;
@synthesize selectionTransparency;
@synthesize currentTool;
@synthesize fillStyle;
@synthesize foregroundColor;
@synthesize backgroundColor;

+ (SWToolboxState *)sharedToolboxState
{
	static SWToolboxState *sharedState;

	if (!sharedState) {
		sharedState = [[SWToolboxState alloc] init];
	}

	return sharedState;
}

- (id)init
{
	if (self = [super init]) {
		[self setLineWidthDisplay:3];
		[self setForegroundColor:[NSColor colorWithCalibratedRed:0.0 green:0.0 blue:0.0 alpha:1.0]];
		[self setBackgroundColor:[NSColor colorWithCalibratedRed:1.0 green:1.0 blue:1.0 alpha:1.0]];
		[self setFillStyle:STROKE_ONLY];
		[self setSelectionTransparency:NO];
		[self setCurrentTool:@"Brush"];
	}

	return self;
}

- (id)initWithToolboxState:(SWToolboxState *)state
{
	if (self = [self init]) {
		[self copyValuesFromToolboxState:state];
	}
	return self;
}

- (void)copyValuesFromToolboxState:(SWToolboxState *)state
{
	if (!state)
		return;

	[self setLineWidth:[state lineWidth]];
	[self setFillStyle:[state fillStyle]];
	[self setSelectionTransparency:[state selectionTransparency]];
	[self setCurrentTool:[state currentTool]];
	[self setForegroundColor:[state foregroundColor]];
	[self setBackgroundColor:[state backgroundColor]];
}

- (void)postVisualStateChanged
{
	[[NSNotificationCenter defaultCenter] postNotificationName:SWToolboxVisualStateChangedNotification object:self];
}

- (void)setForegroundColor:(NSColor *)color
{
	if (foregroundColor != color) {
		[foregroundColor release];
		foregroundColor = [color retain];
		[self postVisualStateChanged];
	}
}

- (void)setBackgroundColor:(NSColor *)color
{
	if (backgroundColor != color) {
		[backgroundColor release];
		backgroundColor = [color retain];
		[self postVisualStateChanged];
	}
}

- (void)setFillStyle:(SWFillStyle)style
{
	if (fillStyle != style) {
		fillStyle = style;
		[self postVisualStateChanged];
	}
}

- (void)setSelectionTransparency:(BOOL)flag
{
	if (selectionTransparency != flag) {
		selectionTransparency = flag;
		[self postVisualStateChanged];
	}
}

- (void)setCurrentTool:(NSString *)tool
{
	if (currentTool != tool && ![currentTool isEqualToString:tool]) {
		[currentTool release];
		currentTool = [tool copy];
		[self postVisualStateChanged];
	}
}

- (void)setLineWidth:(NSInteger)width
{
	if (lineWidth != width) {
		lineWidth = width;
		[self postVisualStateChanged];
	}
}

- (void)setLineWidthDisplay:(NSInteger)width
{
	[self setLineWidth:2 * width - 2];
}

- (NSInteger)lineWidthDisplay
{
	return (1 + lineWidth) / 2 + 1;
}

- (void)updateInfo
{
	// State is already current (the setters are change-guarded), so this just
	// forces the visual overlay to repaint against the latest values.
	[self postVisualStateChanged];
}

- (void)dealloc
{
	[foregroundColor release];
	[backgroundColor release];
	[currentTool release];
	[super dealloc];
}

@end
