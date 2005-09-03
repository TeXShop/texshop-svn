/*
 * TeXShop - TeX editor for Mac OS
 * Copyright (C) 2000-2005 Richard Koch
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * $Id$
 *
 * Created by dirk on Tue Jan 23 2001.
 *
 */

#import "TSAppDelegate.h"

#import "globals.h"

#import "TSDocumentController.h"
#import "TSEncodingSupport.h"
#import "MyPDFView.h"
#import "TSLaTeXPanelController.h"
#import "TSMacroMenuController.h"
#import "TSMatrixPanelController.h"
#import "TSPreferences.h"
#import "TSWindowManager.h"

#import "OgreKit/OgreTextFinder.h"
#import "TextFinder.h"

@class TSTextEditorWindow;


@interface TSAppDelegate (SetupTeXShopLibrary)

- (void)setupTeXShopLibrary;

- (BOOL)createDirectoryAtPath:(NSString *)directory;

- (void)configureTemplates;
- (void)configureBin;
- (void)configureEngine;

- (void)configureFile:(NSString *)filename atPath:(NSString *)directory;

@end


/*" This class is registered as the delegate of the TeXShop NSApplication object. We do various stuff here, e.g. registering factory defaults, dealing with keyboard shortcuts etc.
"*/
@implementation TSAppDelegate

- (void)dealloc
{
	[g_autocompletionDictionary release];
	[super dealloc];
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	NSString *folderPath, *filename;
	NSFileManager *fileManager = [NSFileManager defaultManager];
	folderPath = [[DraggedImagePath stringByStandardizingPath]
								stringByDeletingLastPathComponent];
	NSEnumerator *enumerator = [[fileManager directoryContentsAtPath: folderPath]
								objectEnumerator];
	while ((filename = [enumerator nextObject])) {
		if ([filename characterAtIndex: 0] != '.')
			[fileManager removeFileAtPath:[folderPath stringByAppendingPathComponent:
								filename] handler: nil];
	}
}


- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return [SUD boolForKey:MakeEmptyDocumentKey];
}


- (void)applicationWillFinishLaunching:(NSNotification *)aNotification
{
	NSString *fileName;
	NSDictionary *factoryDefaults;
//	OgreTextFinder *theFinder;
	id theFinder;

	// documentsHaveLoaded = NO;


	g_macroType = LatexEngine;

	g_taggedTeXSections = [[NSArray alloc] initWithObjects:
					@"\\chapter",
					@"\\section",
					@"\\subsection",
					@"\\subsubsection",
					nil];

	g_taggedTagSections = [[NSArray alloc] initWithObjects:
					@"Chapter: ",
					@"Section: ",
					@"Subsection: ",
					@"Subsubsection: ",
					nil];
	// if this is the first time the app is used, register a set of defaults to make sure
	// that the app is useable.
	if (([[NSUserDefaults standardUserDefaults] boolForKey:TSHasBeenUsedKey] == NO) ||
		([[NSUserDefaults standardUserDefaults] objectForKey:TetexBinPath] == nil)) {
		[[TSPreferences sharedInstance] registerFactoryDefaults];
	} else {
		// register defaults
		fileName = [[NSBundle mainBundle] pathForResource:@"FactoryDefaults" ofType:@"plist"];
		NSParameterAssert(fileName != nil);
		factoryDefaults = [[NSString stringWithContentsOfFile:fileName] propertyList];
		[SUD registerDefaults:factoryDefaults];
	}

	// Setup env vars for external programs.
	[self setupEnv];

	// Set up ~/Library/TeXShop; must come before dealing with TSEncodingSupport and MacoMenuController below
	[self setupTeXShopLibrary];

// Finish configuration of various pieces
	[[TSMacroMenuController sharedInstance] loadMacros];
	[self finishAutoCompletionConfigure];
	[self finishMenuKeyEquivalentsConfigure];
	[self configureExternalEditor];

	if ([[SUD stringForKey:EncodingKey] isEqualToString:@"MacJapanese"])
		g_texChar = YEN;
	else
		g_texChar = BACKSLASH;

// added by mitsu --(H) Macro menu and (G) TSEncodingSupport
	[[TSEncodingSupport sharedInstance] setupForEncoding];        // this must come after
	[[TSMacroMenuController sharedInstance] setupMainMacroMenu];
	[[TSDocumentController sharedDocumentController] initializeEncoding];  // so when first document is created, it has correct default
// end addition

	[self finishCommandCompletionConfigure]; // mitsu 1.29 (P) need to call after setupForEncoding

#ifdef MITSU_PDF
	// mitsu 1.29b check menu item for image format for copying and exporting
	int imageCopyType = [SUD integerForKey:PdfCopyTypeKey];
	if (!imageCopyType)
		imageCopyType = IMAGE_TYPE_JPEG_MEDIUM; // default PdfCopyTypeKey
	NSMenu *previewMenu = [[[NSApp mainMenu] itemWithTitle:
							NSLocalizedString(@"Preview", @"Preview")] submenu];
	id <NSMenuItem> item = [previewMenu itemWithTitle:
							NSLocalizedString(@"Copy Format", @"format")];
	if (item) {
		NSMenu *formatMenu = [item submenu];
		item = [formatMenu itemWithTag: imageCopyType];
		[item setState: NSOnState];
	}

	[NSColor setIgnoresAlpha:NO]; // it seesm necessary to call this to activate alpha
	// end mitsu 1.29b
#endif

	if ([SUD boolForKey:UseOgreKitKey])
		theFinder = [OgreTextFinder sharedTextFinder];
	else
		theFinder = [TextFinder sharedInstance];

	// documentsHaveLoaded = NO;
}


- (void)setForPreview: (BOOL)value
{
	_forPreview = value;
}

- (BOOL)forPreview
{
	return _forPreview;
}

- (void)setupEnv
{
	// get copy of environment and add the preferences paths
	[g_environment release];
	g_environment = [[NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]] retain];


	// Customize 'PATH'
	NSMutableString *path;
	path = [NSMutableString stringWithString: [g_environment objectForKey:@"PATH"]];
	[path appendString:@":"];
	[path appendString:[SUD stringForKey:TetexBinPath]];
	[path appendString:@":"];
	[path appendString:[SUD stringForKey:GSBinPath]];
	[g_environment setObject: path forKey: @"PATH"];


	// Set 'TEXEDIT' env var (see the 'tex' man page for details). We construct a simple shell
	// command, which first (re)opens the document, and then uses osascript to run an AppleScript
	// which selects the right line. The AppleScript looks like this:
	//   tell application "TeXShop"
	//       goto document 1 line %d
	//       activate
	//   end tell
	NSMutableString *script = [NSMutableString string];

	[script appendFormat:@"open -a '%@' '%%s' &&", [[NSBundle mainBundle] bundlePath]];
	[script appendString:@" osascript"];
	[script appendString:@" -e 'tell application \"TeXShop\"'"];
	[script appendString:@" -e     'goto document 1 line %d'"];
	[script appendString:@" -e     'activate'"];
	[script appendString:@" -e 'end tell'"];

	[g_environment setObject: script forKey:@"TEXEDIT"];
}

// Added by Greg Landweber to load the autocompletion dictionary
// This code is modified from the code to load the LaTeX panel
- (void) finishAutoCompletionConfigure
{
	NSString	*autocompletionPath;
	
	autocompletionPath = [AutoCompletionPath stringByStandardizingPath];
	autocompletionPath = [autocompletionPath stringByAppendingPathComponent:@"autocompletion"];
	autocompletionPath = [autocompletionPath stringByAppendingPathExtension:@"plist"];
	if ([[NSFileManager defaultManager] fileExistsAtPath: autocompletionPath])
		g_autocompletionDictionary = [NSDictionary dictionaryWithContentsOfFile:autocompletionPath];
	else
		g_autocompletionDictionary = [NSDictionary dictionaryWithContentsOfFile:
			[[NSBundle mainBundle] pathForResource:@"autocompletion" ofType:@"plist"]];
	[g_autocompletionDictionary retain];
	// end of code added by Greg Landweber
}


// This is further menuKey configuration assuming folder already created
- (void)finishMenuKeyEquivalentsConfigure
{
	NSString		*shortcutsPath, *theChar;
	NSDictionary	*shortcutsDictionary, *menuDictionary;
	NSEnumerator	*mainMenuEnumerator, *menuItemsEnumerator, *subMenuItemsEnumerator;
	NSMenu		*mainMenu, *theMenu, *subMenu;
	id <NSMenuItem>		theMenuItem;
	id			key, key1, key2, object;
	unsigned int	mask;
	int			value;
	
	// The code below is copied from Sarah Chambers' code
	
	shortcutsPath = [MenuShortcutsPath stringByStandardizingPath];
	shortcutsPath = [shortcutsPath stringByAppendingPathComponent:@"KeyEquivalents"];
	shortcutsPath = [shortcutsPath stringByAppendingPathExtension:@"plist"];
	if ([[NSFileManager defaultManager] fileExistsAtPath: shortcutsPath])
		shortcutsDictionary = [NSDictionary dictionaryWithContentsOfFile:shortcutsPath];
	else
		return;
	mainMenu = [NSApp mainMenu];
	mainMenuEnumerator = [shortcutsDictionary keyEnumerator];
	while ((key = [mainMenuEnumerator nextObject])) {
		menuDictionary = [shortcutsDictionary objectForKey: key];
		value = [key intValue];
		if (value == 0)
			theMenu = [[mainMenu itemWithTitle: key] submenu];
		else
			theMenu = [[mainMenu itemAtIndex: (value - 1)] submenu];
		
		if (theMenu && menuDictionary) {
			menuItemsEnumerator = [menuDictionary keyEnumerator];
			while ((key1 = [menuItemsEnumerator nextObject])) {
				value = [key1 intValue];
				if (value == 0)
					theMenuItem = [theMenu itemWithTitle: key1];
				else
					theMenuItem = [theMenu itemAtIndex: (value - 1)];
				object = [menuDictionary objectForKey: key1];
				if (([object isKindOfClass: [NSDictionary class]]) && ([theMenuItem hasSubmenu])) {
					subMenu = [theMenuItem submenu];
					subMenuItemsEnumerator = [object keyEnumerator];
					while ((key2 = [subMenuItemsEnumerator nextObject])) {
						value = [key2 intValue];
						if (value == 0)
							theMenuItem = [subMenu itemWithTitle: key2];
						else
							theMenuItem = [subMenu itemAtIndex: (value - 1)];
						object = [object objectForKey: key2];
						if ([object isKindOfClass: [NSArray class]]) {
							theChar = [object objectAtIndex: 0];
							mask = NSCommandKeyMask;
							if ([[object objectAtIndex: 1] boolValue])
								mask = (mask | NSAlternateKeyMask);
							if ([[object objectAtIndex: 2] boolValue])
								mask = (mask | NSControlKeyMask);
							[theMenuItem setKeyEquivalent: theChar];
							[theMenuItem setKeyEquivalentModifierMask: mask];
						}
					}
				} else if ([object isKindOfClass: [NSArray class]]) {
					theChar = [object objectAtIndex: 0];
					mask = (NSCommandKeyMask | NSFunctionKeyMask);
					if ([[object objectAtIndex: 1] boolValue])
						mask = (mask | NSAlternateKeyMask);
					if ([[object objectAtIndex: 2] boolValue])
						mask = (mask | NSControlKeyMask);
					[theMenuItem setKeyEquivalent: theChar];
					[theMenuItem setKeyEquivalentModifierMask: mask];
				}
			}
		}
	}
	
}

// mitsu 1.29 (P)
- (void) finishCommandCompletionConfigure
{
	NSString            *completionPath;
	NSData              *myData;

	unichar esc = 0x001B; // configure the key in Preferences?
	if (!g_commandCompletionChar)
		g_commandCompletionChar = [[NSString stringWithCharacters: &esc length: 1] retain];

	[g_commandCompletionList release];
	g_commandCompletionList = nil;
	g_canRegisterCommandCompletion = NO;
	completionPath = [CommandCompletionPath stringByStandardizingPath];
	if ([[NSFileManager defaultManager] fileExistsAtPath: completionPath])
		myData = [NSData dataWithContentsOfFile:completionPath];
	else
		myData = [NSData dataWithContentsOfFile:
			[[NSBundle mainBundle] pathForResource:@"CommandCompletion" ofType:@"txt"]];
	if (!myData)
		return;

	NSStringEncoding myEncoding = NSUTF8StringEncoding;
	g_commandCompletionList = [[NSMutableString alloc] initWithData:myData encoding: myEncoding];
	if (! g_commandCompletionList) {
		myEncoding = [[TSEncodingSupport sharedInstance] defaultEncoding];
		g_commandCompletionList = [[NSMutableString alloc] initWithData:myData encoding: myEncoding];
	}

	if (!g_commandCompletionList)
		return;
	[g_commandCompletionList insertString: @"\n" atIndex: 0];
	if ([g_commandCompletionList characterAtIndex: [g_commandCompletionList length]-1] != '\n')
		[g_commandCompletionList appendString: @"\n"];
	g_canRegisterCommandCompletion = YES;
}
// end mitsu 1.29


- (void)configureExternalEditor
{
	NSString	*menuTitle;

	_forPreview =  [SUD boolForKey:UseExternalEditorKey];
	if (_forPreview)
		menuTitle = NSLocalizedString(@"Open for Editing...", @"Open for Editing...");
	else
		menuTitle = NSLocalizedString(@"Open for Preview...", @"Open for Preview...");
	[[[[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"File", @"File")] submenu]
		itemWithTag:110] setTitle:menuTitle];
}

- (IBAction)openForPreview:(id)sender
{
	int				i;
	NSArray			*myArray, *fileArray;
	NSDocumentController	*myController;
	BOOL			externalEditor;
	NSOpenPanel			*myPanel;
	
	externalEditor = [SUD boolForKey:UseExternalEditorKey];
	myController = [NSDocumentController sharedDocumentController];
	myPanel = [NSOpenPanel openPanel];
	
	if (externalEditor)
		_forPreview = NO;
	else
		_forPreview = YES;
	
	/* This code restricts files to tex files */
	myArray = [NSArray arrayWithObjects:
		@"tex",
		@"TEX",
		@"txt",
		@"TXT",
		@"bib",
		@"mp",
		@"ins",
		@"dtx",
		@"mf",
		nil];
	i = [myController runModalOpenPanel: myPanel forTypes: myArray];
	fileArray = [myPanel filenames];
	if (fileArray) {
		for(i = 0; i < [fileArray count]; ++i) {
			NSString*  myName = [fileArray objectAtIndex:i];
			[myController openDocumentWithContentsOfFile: myName display: YES];
		}
	}
	
	if (externalEditor)
		_forPreview = YES;
	else
		_forPreview = NO;
}


- (IBAction)displayLatexPanel:(id)sender
{
	if ([sender tag] == 0) {
		[[TSLaTeXPanelController sharedInstance] showWindow:self];
		[sender setTitle:NSLocalizedString(@"Close LaTeX Panel", @"Close LaTeX Panel")];
		[sender setTag:1];
	} else {
		[[TSLaTeXPanelController sharedInstance] hideWindow:self];
		[sender setTitle:NSLocalizedString(@"LaTeX Panel...", @"LaTeX Panel...")];
		[sender setTag:0];
	}
}

- (IBAction)displayMatrixPanel:(id)sender
{
	if ([sender tag] == 0) {
		[[TSMatrixPanelController sharedInstance] showWindow:self];
		[sender setTitle:NSLocalizedString(@"Close Matrix Panel", @"Close Matrix Panel")];
		[sender setTag:1];
	} else {
		[[TSMatrixPanelController sharedInstance] hideWindow:self];
		[sender setTitle:NSLocalizedString(@"Matrix Panel...", @"Matrix Panel...")];
		[sender setTag:0];
	}
}


- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	if ([anItem action] == @selector(displayLatexPanel:)) {
		return [[NSApp mainWindow] isKindOfClass:[TSTextEditorWindow class]];
	} else if ([anItem action] == @selector(displayMatrixPanel:)) {
		return [[NSApp mainWindow] isKindOfClass:[TSTextEditorWindow class]];
	} else
		return YES;
}

// mitsu 1.29 (P)
- (void)openCommandCompletionList: (id)sender
{
	if ([[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:
			[CommandCompletionPath stringByStandardizingPath] display: YES] != nil)
		g_canRegisterCommandCompletion = NO;
}
// end mitsu 1.29

#ifdef MITSU_PDF
// mitsu 1.29 (O)
- (void)changeImageCopyType: (id)sender
{
	id <NSMenuItem> item;

	if ([sender isKindOfClass: [NSMenuItem class]]) {
		int imageCopyType;

		imageCopyType = [SUD integerForKey:PdfCopyTypeKey]; // mitsu 1.29b
		item = [[sender menu] itemWithTag: imageCopyType];
		[item setState: NSOffState];

		imageCopyType = [sender tag];
		item = [[sender menu] itemWithTag: imageCopyType];
		[item setState: NSOnState];

		// mitsu 1.29b
		NSPopUpButton *popup = [[TSPreferences sharedInstance] imageCopyTypePopup];
		if (popup)
		{
			int index = [popup indexOfItemWithTag: imageCopyType];
			if (index != -1)
				[popup selectItemAtIndex: index];
		}
		// end mitsu 1.29b
		// save this to User Defaults
		[SUD setInteger:imageCopyType forKey:PdfCopyTypeKey];
	}
}
// end mitsu 1.29
#endif

- (void)ogreKitWillHackFindMenu:(OgreTextFinder*)textFinder
{
	[textFinder setShouldHackFindMenu:[[NSUserDefaults standardUserDefaults] boolForKey:@"UseOgreKit"]];
}

// begin Update Checker Nov 05 04; Martin Kerz
- (IBAction)checkForUpdate:(id)sender
{
	NSString *currentVersion = [[[NSBundle bundleForClass:[self class]]
		infoDictionary] objectForKey:@"CFBundleVersion"];

	NSDictionary *texshopVersionDictionary = [NSDictionary dictionaryWithContentsOfURL:
		[NSURL URLWithString:@"http://www.uoregon.edu/~koch/texshop/texshop-current.txt"]];

	NSString *latestVersion = [texshopVersionDictionary valueForKey:@"TeXShop"];

	int button;
	if(latestVersion == nil){
		NSRunAlertPanel(NSLocalizedString(@"Error",
										  @"Error"),
						NSLocalizedString(@"There was an error checking for updates.",
										  @"There was an error checking for updates."),
										  @"OK", nil, nil);
		return;
	}

	if([latestVersion caseInsensitiveCompare: currentVersion] != NSOrderedDescending)
	{
		NSRunAlertPanel(NSLocalizedString(@"Your copy of TeXShop is up-to-date",
										  @"Your copy of TeXShop is up-to-date"),
						NSLocalizedString(@"You have the most recent version of TeXShop.",
										  @"You have the most recent version of TeXShop."),
										  @"OK", nil, nil);
	}
	else
	{
		button = NSRunAlertPanel(NSLocalizedString(@"New version available",
													   @"New version available"),
									 [NSString stringWithFormat:
										 NSLocalizedString(@"A new version of TeXShop is available (version %@). Would you like to download it now?",
														   @"A new version of TeXShop is available (version %@). Would you like to download it now?"), latestVersion],
									 @"OK", @"Cancel", nil);
		if (button == NSOKButton) {
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.uoregon.edu/~koch/texshop/texshop.dmg"]];
		}
	}

}
// end update checker


@end


@implementation TSAppDelegate (SetupTeXShopLibrary)

// This method makes sure the ~/Library/TeXShop/ directory exists and is populated.
// TODO: It would be much more elegant to simply have a big 'TeXShop' folder
// inside our app bundle. Then, write a method which recursively traverses through
// this bundle directory, and mirrors all files and folders contained in it into
// ~/Library/TeXShop. That way it becomes trivial to add/remove/rename files we 
// want to add there.
- (void)setupTeXShopLibrary
{
	// First create TeXShop directory if it does not exist
	if (![self createDirectoryAtPath:TeXShopPath])
		return;

	[self configureTemplates];
	[self configureBin];
	[self configureEngine];

	[self configureFile:@"setname.scpt" atPath:ScriptsPath];
	[self configureFile:@"autocompletion.plist" atPath:AutoCompletionPath];
	[self configureFile:@"completion.plist" atPath:LatexPanelPath];
	[self configureFile:@"matrixpanel_1.plist" atPath:MatrixPanelPath];
	[self configureFile:@"KeyEquivalents.plist" atPath:MenuShortcutsPath];
	[self configureFile:@"Macros_Latex.plist" atPath:MacrosPath];
	[self configureFile:@"Macros_Context.plist" atPath:MacrosPath];

	[self configureFile:[CommandCompletionPath lastPathComponent] atPath:[CommandCompletionPath stringByDeletingLastPathComponent]];


#ifdef MITSU_PDF
	NSString *draggedImageFolder = [[DraggedImagePath stringByStandardizingPath]
										stringByDeletingLastPathComponent];
	[self createDirectoryAtPath:draggedImageFolder];
#endif
}

// Copy the file specified by srcPath into the target directory, unless a file with the same
// name already exists in the destination.
// Returns NO if an error occurred.
- (BOOL)safeCopyFile:(NSString *)srcPath toDirectory:(NSString *)directory cutExtension:(BOOL)cutExt
{
	NSFileManager	*fileManager;
	NSString		*dstPath;
	NSString		*filename;
	BOOL			result;
	
	if (!srcPath)
		return NO;
	
	fileManager = [NSFileManager defaultManager];
	filename = [srcPath lastPathComponent];
	dstPath = [directory stringByAppendingPathComponent:filename];
	if (cutExt)
		dstPath = [dstPath stringByDeletingPathExtension];
	
	// Check if that file already exists
	if ([fileManager fileExistsAtPath:dstPath] == NO) {
		NS_DURING
			// file doesn't exist -> copy it
			result = [fileManager copyPath:srcPath toPath:dstPath handler:nil];
		NS_HANDLER
			// For now we don't display an error message here, because this method is called for
			// a lot of files.
			result = NO;
		NS_ENDHANDLER
	} else {
		// The file already exists, so we are happy.
		result = YES;
	}
	
	return result;
}


// Create the specified directory, if it is missing.
// Returns YES if successful, NO if an error occurred.
- (BOOL)createDirectoryAtPath:(NSString *)directory
{
	NSFileManager	*fileManager;
	BOOL			result;
	NSString		*reason;
	BOOL			isDirectory;

	fileManager = [NSFileManager defaultManager];
	
	// Make sure to expand the directory path (so that e.g. ~ gets resolved).
	directory = [directory stringByStandardizingPath];
	
	if (!([fileManager fileExistsAtPath: directory isDirectory:&isDirectory])) {
		NS_DURING
			// create the missing directory
			result = [fileManager createDirectoryAtPath:directory attributes:nil];
		NS_HANDLER
			result = NO;
			reason = [localException reason];
		NS_ENDHANDLER
	} else {
		// Verify that 'directory' really points to a directory, and not an ordinary file.
		result = isDirectory;
	}

	if (!result) {
		NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"), reason,
			[NSString stringWithFormat: NSLocalizedString(@"Couldn't create folder:\n%@", @"Message when creating a directory failed"), directory],
			nil, nil);
	}
	
	return result;
}

// ------------- these routines create ~/Library/TeXShop and folders and files if necessary ----------

- (void)configureTemplates
{
	NSArray			*files;
	NSEnumerator 	*fileEnumerator;
	NSString		*fileName;
	NSFileManager	*fileManager;
	NSString		*directory;

	fileManager = [NSFileManager defaultManager];

	// The code below was written by Sarah Chambers
	// if preferences folder doesn't exist already...

	// Next create Templates folder
	directory = [TexTemplatePath stringByStandardizingPath];
	if (!([fileManager fileExistsAtPath: directory])) {

		if (![self createDirectoryAtPath:directory])
			return;

		// fill in our templates
		files = [NSBundle pathsForResourcesOfType:@".tex" inDirectory:[[NSBundle mainBundle] resourcePath]];
		fileEnumerator = [files objectEnumerator];
		while ((fileName = [fileEnumerator nextObject])) {
			[self safeCopyFile:fileName toDirectory:directory cutExtension:NO];
		}

		// create the subdirectory "More"
		directory = [TexTemplateMorePath stringByStandardizingPath];
		if (![self createDirectoryAtPath:directory])
			return;

		// fill in our templates
		files = [NSBundle pathsForResourcesOfType:@"tex" inDirectory:[[[NSBundle mainBundle] resourcePath] stringByAppendingString: @"/More"]];
		fileEnumerator = [files objectEnumerator];
		while ((fileName = [fileEnumerator nextObject])) {	
			[self safeCopyFile:fileName toDirectory:directory cutExtension:NO];
		}
		
	}
}

- (void)configureBin
{
	NSString		*fileName;
	NSFileManager	*fileManager;
	NSArray			*files;
	NSEnumerator 	*fileEnumerator;
	NSString		*directory;

	fileManager = [NSFileManager defaultManager];

	// The code below is copied from Sarah Chambers' code

	// if folder doesn't exist already...
	directory = [BinaryPath stringByStandardizingPath];
	if (!([fileManager fileExistsAtPath: directory])) {

		if (![self createDirectoryAtPath:directory])
			return;

		// fill in our binaries
		files = [NSBundle pathsForResourcesOfType:@"bxx" inDirectory:[[NSBundle mainBundle] resourcePath]];
		fileEnumerator = [files objectEnumerator];
		while ((fileName = [fileEnumerator nextObject])) {
			[self safeCopyFile:fileName toDirectory:directory cutExtension:YES];
		}

	}
}

- (void)configureEngine
{
	NSString		*fileName;
	NSFileManager	*fileManager;
	NSArray			*files;
	NSEnumerator 	*fileEnumerator;
	NSString		*directory;

	fileManager = [NSFileManager defaultManager];

	// The code below is copied from Sarah Chambers' code

	// if folder doesn't exist already...
	directory = [EnginePath stringByStandardizingPath];
	if (!([fileManager fileExistsAtPath: directory])) {

		if (![self createDirectoryAtPath:directory])
			return;

		// fill in our binaries
		files = [NSBundle pathsForResourcesOfType:@"engine" inDirectory:[[NSBundle mainBundle] resourcePath]];
		fileEnumerator = [files objectEnumerator];
		while ((fileName = [fileEnumerator nextObject])) {
			[self safeCopyFile:fileName toDirectory:directory cutExtension:NO];
		}

	}
}


- (void)configureFile:(NSString *)filename atPath:(NSString *)directory
{
	NSFileManager	*fileManager;
	NSString		*dstPath;
	NSString		*extension;
	NSString		*bundlePath;
	NSString		*reason;
	BOOL			result;
	
	directory = [directory stringByStandardizingPath];
	dstPath = [directory stringByAppendingPathComponent:filename];

	// Create the parent directory (if missing).
	if (![self createDirectoryAtPath:directory])
		return;

	// Now see if the file is inside; if not, copy it from the program bundle.
	fileManager = [NSFileManager defaultManager];
	if (![fileManager fileExistsAtPath:dstPath]) {
		NS_DURING
			result = NO;
			extension = [filename pathExtension];
			filename = [filename stringByDeletingPathExtension];
			bundlePath = [[NSBundle mainBundle] pathForResource:filename ofType:extension];
			if (bundlePath)
				result = [fileManager copyPath:bundlePath toPath:dstPath handler:nil];
		NS_HANDLER
			result = NO;
			reason = [localException reason];
		NS_ENDHANDLER
		if (!result) {
			NSRunAlertPanel(@"Error", reason,
							[NSString stringWithFormat: @"Couldn't create file:\n%@", dstPath], nil, nil);
			return;
		}
	}
}

@end

