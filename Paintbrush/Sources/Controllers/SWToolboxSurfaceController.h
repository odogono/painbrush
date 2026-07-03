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
#import "SWToolboxState.h"

@class SWMatrix;
@class SWToolbox;

@interface SWToolboxSurfaceController : NSWindowController
{
	SWToolboxState *toolboxState;

	IBOutlet SWMatrix *toolMatrix;
	IBOutlet SWMatrix *transparencyMatrix;
	IBOutlet SWMatrix *fillMatrix;
	NSRect originalToolMatrixFrame;
	NSRect originalTransparencyMatrixFrame;
	NSRect originalFillMatrixFrame;
	CGFloat originalContentHeight;
	NSView *toolboxVisualOverlay;

	// My toolbox -- used to decide which surface controls belong to each tool.
	SWToolbox *toolbox;
}

- (id)initWithToolboxState:(SWToolboxState *)state
			 windowNibName:(NSString *)windowNibName;

- (IBAction)changeCurrentTool:(id)sender;
- (IBAction)changeFillStyle:(id)sender;
- (IBAction)changeSelectionTransparency:(id)sender;
- (IBAction)flipColors:(id)sender;
- (void)switchToScissors:(id)sender;
- (void)updateInfo;

@property (readonly) SWToolboxState *toolboxState;
@property (assign) NSInteger lineWidthDisplay;
@property (assign, nonatomic) NSInteger lineWidth;
@property (assign) BOOL selectionTransparency;
@property (copy, nonatomic) NSString *currentTool;
@property (assign) SWFillStyle fillStyle;
@property (retain) NSColor *foregroundColor;
@property (retain) NSColor *backgroundColor;

@end
