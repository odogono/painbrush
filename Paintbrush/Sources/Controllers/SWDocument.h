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

@class SWPaintView;
@class SWScalingScrollView;
@class SWTool;
@class SWToolbox;
@class SWToolboxController;
@class SWToolboxSurfaceController;
@class SWToolboxState;
@class SWSizeWindowController;
@class SWResizeWindowController;
@class SWCenteringClipView;
@class SWTextToolWindowController;
@class SWSavePanelAccessoryViewController;
@class SWImageDataSource;
@class SWCanvasHistorySnapshot;
@class NSBitmapImageRep;

@interface SWDocument : NSDocument
{
	IBOutlet SWPaintView *paintView;
	IBOutlet SWScalingScrollView *scrollView;	/* ScrollView containing document */
	
	// The image data
	SWImageDataSource * dataSource;
	
	// A bunch of controllers and one view
	SWToolboxController *toolboxController;
	SWToolbox *toolbox;
	SWToolboxState *documentToolboxState;
	SWCenteringClipView *clipView;
	SWTextToolWindowController *textController;
	SWSizeWindowController *sizeController;
	SWResizeWindowController *resizeController;
	SWSavePanelAccessoryViewController *savePanelAccessoryViewController;
	SWToolboxSurfaceController *dockedToolboxController;
	NSView *dockedToolboxView;
	
	// Misc other member variables
	NSNotificationCenter *nc;
	NSString *currentFileType;
}

// Properties
@property (readonly) SWToolbox *toolbox;
@property (readonly) SWPaintView *paintView;


// Methods called by menu items
- (IBAction)flipHorizontal:(id)sender;
- (IBAction)flipVertical:(id)sender;
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (IBAction)actualSize:(id)sender;
//- (IBAction)fullScreen:(id)sender;
- (IBAction)crop:(id)sender;
- (IBAction)invertColors:(id)sender;
- (void)showTextSheet:(NSNotification *)n;
- (void)undoLevelChanged:(NSNotification *)n;

// Sheets for size!
- (void)sizeSheetDidEnd:(NSWindow *)sheet
			 returnCode:(NSInteger)returnCode
			contextInfo:(void *)contextInfo;
- (IBAction)raiseSizeSheet:(id)sender;
- (IBAction)raiseResizeSheet:(id)sender;
- (void)setUpPaintView;
- (void)updateToolboxHosting;
- (SWToolboxState *)documentToolboxState;
- (SWToolboxState *)activeToolboxState;
- (void)copySharedToolboxStateIntoDocumentState;
- (void)copyDocumentToolboxStateIntoSharedState;
- (void)useCurrentToolboxHostingState;

// Undo
- (void)registerDrawingUndo;
- (void)registerCanvasResizeUndo;
- (void)restoreCanvasHistorySnapshot:(SWCanvasHistorySnapshot *)snapshot
						   actionName:(NSString *)actionName;
- (NSBitmapImageRep *)updateSelectionExtentForSelectionRect:(NSRect)selectionRect;
- (void)resetSelectionExtent;

// For copy-and-paste
- (void)writeImageToPasteboard:(NSPasteboard *)pb;

+ (void)setWillShowSheet:(BOOL)showSheet;


@end
