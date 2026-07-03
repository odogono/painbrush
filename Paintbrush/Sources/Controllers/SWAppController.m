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


#import "SWAppController.h"
#import "SWSizeWindowController.h"
#import "SWPreferenceController.h"
#import "SWToolboxController.h"
#import "SWDocument.h"
#ifndef APPSTORE
#import "PFMoveApplication.h"
#import <Sparkle/Sparkle.h>
#endif // APPSTORE

NSString * const kSWUndoKey = @"UndoLevels";
NSString * const kSWDockToolboxInDocumentWindowsKey = @"DockToolboxInDocumentWindows";
NSString * const kSWDockedToolboxPreferenceChangedNotification = @"SWDockedToolboxPreferenceChanged";
NSString * const kSWDockedToolboxVisibilityChangedNotification = @"SWDockedToolboxVisibilityChanged";

static BOOL kSWDockedToolboxVisible = YES;

@implementation SWAppController

+ (void)registerDefaultPreferences
{
	NSMutableDictionary *defaultValues = [NSMutableDictionary dictionary];
	[defaultValues setObject:[NSNumber numberWithInt:640] forKey:@"HorizontalSize"];
	[defaultValues setObject:[NSNumber numberWithInt:480] forKey:@"VerticalSize"];
	[defaultValues setObject:[NSNumber numberWithInt:10] forKey:kSWUndoKey];
	[defaultValues setObject:@"PNG" forKey:@"FileType"];
	[defaultValues setObject:[NSNumber numberWithBool:NO] forKey:kSWDockToolboxInDocumentWindowsKey];
	[[NSUserDefaults standardUserDefaults] registerDefaults:defaultValues];
}

+ (BOOL)dockedToolboxModeEnabled
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:kSWDockToolboxInDocumentWindowsKey];
}

+ (NSArray *)paintbrushDocuments
{
	NSMutableArray *documents = [NSMutableArray array];
	for (id document in [[NSDocumentController sharedDocumentController] documents]) {
		if ([document isKindOfClass:[SWDocument class]])
			[documents addObject:document];
	}
	return documents;
}

+ (SWDocument *)activePaintbrushDocument
{
	NSWindow *keyWindow = [NSApp keyWindow];
	id document = keyWindow ? [[NSDocumentController sharedDocumentController] documentForWindow:keyWindow] : nil;
	if ([document isKindOfClass:[SWDocument class]])
		return document;

	document = [[SWToolboxController sharedToolboxPanelController] activeDocument];
	if ([document isKindOfClass:[SWDocument class]])
		return document;

	return [[self paintbrushDocuments] lastObject];
}

+ (void)applyToolboxHostingTransitionFromDockedMode:(BOOL)wasDocked toDockedMode:(BOOL)isDocked
{
	if (!wasDocked && isDocked) {
		for (SWDocument *document in [self paintbrushDocuments])
			[document copySharedToolboxStateIntoDocumentState];
	} else if (wasDocked && !isDocked) {
		SWDocument *document = [self activePaintbrushDocument];
		[document copyDocumentToolboxStateIntoSharedState];
	}

	for (SWDocument *document in [self paintbrushDocuments])
		[document useCurrentToolboxHostingState];
}

+ (void)setDockedToolboxModeEnabled:(BOOL)enabled
{
	BOOL wasDocked = [self dockedToolboxModeEnabled];
	if (wasDocked == enabled)
		return;

	[[NSUserDefaults standardUserDefaults] setBool:enabled
											forKey:kSWDockToolboxInDocumentWindowsKey];

	[self applyToolboxHostingTransitionFromDockedMode:wasDocked toDockedMode:enabled];
	[self applyToolboxHostingPreferenceChanged];
}

+ (BOOL)dockedToolboxVisible
{
	return kSWDockedToolboxVisible;
}

+ (void)setDockedToolboxVisible:(BOOL)visible
{
	if (kSWDockedToolboxVisible == visible)
		return;

	kSWDockedToolboxVisible = visible;
	[[NSNotificationCenter defaultCenter] postNotificationName:kSWDockedToolboxVisibilityChangedNotification
														object:self];
}

+ (void)applyToolboxHostingPreferenceChanged
{
	BOOL isDocked = [self dockedToolboxModeEnabled];
	SWToolboxController *toolboxPanel = [SWToolboxController sharedToolboxPanelController];
	if (isDocked) {
		[toolboxPanel close];
	} else {
		[toolboxPanel showWindow:self];
	}

	[[NSNotificationCenter defaultCenter] postNotificationName:kSWDockedToolboxPreferenceChangedNotification
														object:self];
}

- (id)init
{
	// Leopard's AppKit version is ≥ 949, while older versions of the OS hae a lower number. This 
	// program requires 10.5 or higher, so this checks to make sure. I'm sure there's an easier
	// way to do this, but whatever - this works fine

	// NOTE: 10.5.3 is version 949.33
	if (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_4) {
		// Pop up a warning dialog... 
		NSRunAlertPanel(@"Sorry, this program requires Mac OS X 10.5.3 or later", @"You are running %@", 
						@"OK", nil, nil, [[[NSProcessInfo alloc] operatingSystemVersionString] autorelease]);
		DebugLog(@"Failed to run: running version %lf", NSAppKitVersionNumber);
		// then quit the program
		[NSApp terminate:self]; 
		
	} else if (self = [super init]) {
		
		[SWAppController registerDefaultPreferences];

		[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
		[NSColorPanel setPickerMode:NSCrayonModeColorPanel];
		if (![SWAppController dockedToolboxModeEnabled])
			[[SWToolboxController sharedToolboxPanelController] showWindow:self];
	}
	
	return self;
}


// Override to ensure that the app is in the /Applications/ directory
- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	// Offer to the move the Application if necessary.
	// Note that if the user chooses to move the application,
	// this call will never return. Therefore you can suppress
	// any first run UI by putting it after this call.
	
	// Oh, and don't do it for debug or app store builds
#ifndef APPSTORE
#ifndef DEBUG
	PFMoveToApplicationsFolderIfNecessary();
#endif // !DEBUG
#endif // APPSTORE
}


// Makes the toolbox panel appear and disappear
- (IBAction)showToolboxPanel:(id)sender
{
	if ([SWAppController dockedToolboxModeEnabled]) {
		[SWAppController setDockedToolboxVisible:![SWAppController dockedToolboxVisible]];
		return;
	}

	SWToolboxController *toolboxPanel = [SWToolboxController sharedToolboxPanelController];
	if ([[toolboxPanel window] isVisible]) {
		[toolboxPanel close];
	} else {
		[toolboxPanel showWindow:self];
	}
}

- (IBAction)showPreferencePanel:(id)sender
{
	if (!preferenceController) {
		preferenceController = [[SWPreferenceController alloc] init];
	}
	[preferenceController showWindow:self];
}

- (void)killTheSheet:(id)sender
{
	for (NSWindow *window in [NSApp windows]) 
	{
		if ([window isSheet] && [[[window windowController] class] isEqualTo:[SWSizeWindowController class]]) 
		{
			// Close all the size sheets, but no other ones
			[window close];
			//[NSApp endSheet:window returnCode:NSCancelButton];
		}
	}
}

#ifndef APPSTORE
// Called immediately before relaunching by Sparkle
- (void)updaterWillRelaunchApplication:(SUUpdater *)updater
{
	[self killTheSheet:nil];
}
#endif // APPSTORE

- (IBAction)quit:(id)sender
{
	[self killTheSheet:nil];
	[NSApp terminate:self];
}

// Creates a new instance of SWDocument based on the image in the clipboard
- (IBAction)newFromClipboard:(id)sender
{
	NSData *data = [SWImageTools readImageFromPasteboard:[NSPasteboard generalPasteboard]];
	if (data) 
	{
		[SWDocument setWillShowSheet:NO];
		[[NSDocumentController sharedDocumentController] newDocument:self];
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	SEL action = [menuItem action];
	if (action == @selector(newFromClipboard:)) {
		return ([SWImageTools readImageFromPasteboard:[NSPasteboard generalPasteboard]] != nil);
	}
	if (action == @selector(showToolboxPanel:)) {
		if ([SWAppController dockedToolboxModeEnabled]) {
			[menuItem setState:([SWAppController dockedToolboxVisible] ? NSOnState : NSOffState)];
		} else {
			NSWindow *toolboxWindow = [[SWToolboxController sharedToolboxPanelController] window];
			[menuItem setState:([toolboxWindow isVisible] ? NSOnState : NSOffState)];
		}
	}
	return YES;
}


#pragma mark URLS to web pages/email addresses

////////////////////////////////////////////////////////////////////////////////
//////////		URLs to web pages/email addresses
////////////////////////////////////////////////////////////////////////////////


- (IBAction)donate:(id)sender
{	
	// Open the URL
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:
												   @"http://sourceforge.net/project/project_donations.php?group_id=191288"]];
}

- (IBAction)forums:(id)sender
{	
	// Open the URL
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://sourceforge.net/forum/?group_id=191288"]];
	
}

- (IBAction)contact:(id)sender
{	
	// Open the URL
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:soggywaffles@gmail.com"]];
}

- (void)dealloc
{
	[preferenceController release];
	[super dealloc];
}

@end
