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


#import "SWToolbox.h"
#import "SWToolList.h"
#import "SWToolboxController.h"
#import "SWToolboxState.h"
#import "SWPaintView.h"
#import "SWDocument.h"

@implementation SWToolbox

@synthesize currentTool;
@synthesize toolboxState;

- (id)initWithDocument:(SWDocument *)doc
{
	return [self initWithDocument:doc toolboxState:[SWToolboxState sharedToolboxState]];
}

- (id)initWithDocument:(SWDocument *)doc toolboxState:(SWToolboxState *)state
{
	self = [super init];
	
	document = doc;
	toolboxState = [state retain];
	
	// Create the dictionary
	toolList = [[NSMutableDictionary alloc] initWithCapacity:14];
	for (Class c in [SWToolbox toolClassList]) 
	{
		SWTool *tool = [[c alloc] initWithToolboxState:toolboxState];
		[tool setDocument:doc];
		[toolList setObject:tool forKey:[tool description]];
	}
	
	[toolboxState addObserver:self
					forKeyPath:@"currentTool"
					   options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial
					   context:NULL];
	
	// Set the initial tool info
	[toolboxState updateInfo];
	
	return self;
}


// Don't forget to remove my registration to the toolbox controller!
- (void)dealloc
{
	[toolboxState removeObserver:self forKeyPath:@"currentTool"];
	for (id key in toolList) {
		[[toolList objectForKey:key] release];
	}
	[toolList release];
	[toolboxState release];
	[currentTool release];
	[super dealloc];
}


// Here's the setter for the tool: make sure you wrap up loose ends for the previous tool!
- (void)setCurrentTool:(SWTool *)tool
{
	[currentTool tieUpLooseEnds];
	[tool retain];
	[currentTool release];
	currentTool = tool;
    
    
    SWDocument *cursorDocument = document;
    if (!cursorDocument) {
        SWToolboxController *controller = [SWToolboxController sharedToolboxPanelController];
        cursorDocument = [controller activeDocument];
    }
    SWPaintView *view = [cursorDocument paintView];
    [view cursorUpdate:nil];
    
}


// Something happened!
- (void)observeValueForKeyPath:(NSString *)keyPath 
					  ofObject:(id)object 
						change:(NSDictionary *)change 
					   context:(void *)context
{
	id thing = [change objectForKey:NSKeyValueChangeNewKey];
	
	if ([keyPath isEqualToString:@"currentTool"]) {
		SWTool *tool = [self toolForLabel:thing];
		if (tool) {
			[self setCurrentTool:tool];
		}
	}
}


// Which tool comes from which label?
- (SWTool *)toolForLabel:(NSString *)label
{
	return [toolList objectForKey:[NSString stringWithString:label]];
}


+ (NSArray *)toolClassList
{
	return [NSArray arrayWithObjects:[SWBrushTool class], [SWEraserTool class], [SWSelectionTool class], 
			[SWAirbrushTool class], [SWFillTool class], [SWBombTool class], [SWLineTool class], 
			[SWCurveTool class], [SWRectangleTool class], [SWEllipseTool class], [SWRoundedRectangleTool class], 
			[SWTextTool class], [SWEyeDropperTool class], [SWZoomTool class], nil];
}


- (void)tieUpLooseEndsForCurrentTool
{
	[currentTool tieUpLooseEnds];
}


@end
