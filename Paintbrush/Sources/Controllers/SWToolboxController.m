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
#import "SWDocument.h"

@implementation SWToolboxController

@synthesize activeDocument;

+ (id)sharedToolboxPanelController
{
	static SWToolboxController *sharedController;

	if (!sharedController) {
		sharedController = [[SWToolboxController alloc] initWithWindowNibName:@"ToolboxSurface"];
	}

	return sharedController;
}

- (id)initWithWindowNibName:(NSString *)windowNibName
{
	if (self = [super initWithWindowNibName:windowNibName]) {
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(windowDidBecomeKey:)
													 name:NSWindowDidBecomeKeyNotification
												   object:nil];
	}

	return self;
}

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

@end
