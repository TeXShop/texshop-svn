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
 * Created by koch in July, 2000.
 *
 */

#import "UseMitsu.h"
#import <Carbon/Carbon.h>

#import "TSDocument.h"
#import <OgreKit/OgreKit.h> // zenitani 1.35 (A)

#import "MyPDFView.h"
#import "MyPDFKitView.h"

#import "globals.h"

#import "TSPrintView.h"
#import "TSPreferences.h"
#import "TSWindowManager.h"
#import "TSLaTeXPanelController.h"
#import "TSMatrixPanelController.h" // Matrix panel addition by Jonas
#import "TSToolbarController.h"
#import "TSAppDelegate.h"
#import "TSTextView.h"
#import "TSEncodingSupport.h"
#import "TSMacroMenuController.h"
#import "TSDocumentController.h"


#define Mcomment 1
#define Muncomment 2
#define Mindent 3
#define Munindent 4

#define COLORTIME  0.02
#define COLORLENGTH 5000

// #define COLORTIME  .02
// #define COLORLENGTH 500000



@implementation TSDocument

- (id)init
{
	[super init];

	errorNumber = 0;
	whichError = 0;
	makeError = NO;

	colorStart = 0;
	colorEnd = 0;
	regularColorAttribute = 0;
	commandColorAttribute = 0;
	commentColorAttribute = 0;
	markerColorAttribute = 0;

	tagLine = NO;
	texRep = nil;
	fileIsTex = YES;
	mSelection = nil;
	rootDocument = nil;
	warningGiven = NO;
	omitShellEscape = NO;
	taskDone = YES;
	_pdfLastModDate = nil;
	_pdfRefreshTimer = nil;
	typesetContinuously = NO;
	_pdfRefreshTryAgain = NO;
	useTempEngine = NO;
	callingWindow = nil;
	_badEncoding = 0;
	showBadEncodingDialog = NO;
	PDFfromKit = NO;
	textSelectionYellow = NO;

	_encoding = [[TSDocumentController sharedDocumentController] encoding];

	_textStorage = [[NSTextStorage alloc] init];

	return self;
}

- (void)dealloc
{


	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[NSNotificationCenter defaultCenter] removeObserver:pdfView];// mitsu 1.29 (O) need to remove here, otherwise updateCurrentPage fails
	if (tagTimer != nil)
	{
		[tagTimer invalidate];
		[tagTimer release];
	}

	[_pdfRefreshTimer invalidate];
	[_pdfRefreshTimer release];
	_pdfRefreshTimer = nil;

	[regularColorAttribute release];
	[commentColorAttribute release];
	[commandColorAttribute release];
	[markerColorAttribute release];

	[mSelection release];
	[_textStorage release];

/* toolbar stuff */
	[typesetButton release];
	[programButton release];
	[typesetButtonEE release];
	[programButtonEE release];
	[tags release];
	[popupButton release];
	[previousButton release];
	[nextButton release];
	[gotopageOutlet release];
	[magnificationOutlet release];
	[macroButton release]; // mitsu 1.29 -- I for got this
	[macroButtonEE release];
	[mouseModeMatrix release]; // mitsu 1.29 (O)

	[_pdfLastModDate release];

	[super dealloc];
}

- (void)setupTextView:(TSTextView *)aTextView
{
	NSColor		*backgroundColor, *insertionpointColor;

	backgroundColor = [NSColor colorWithCalibratedRed: [SUD floatForKey:background_RKey]
												green: [SUD floatForKey:background_GKey]
												 blue: [SUD floatForKey:background_BKey]
												alpha:1.0];

	insertionpointColor = [NSColor colorWithCalibratedRed: [SUD floatForKey:insertionpoint_RKey]
													green: [SUD floatForKey:insertionpoint_GKey]
													 blue: [SUD floatForKey:insertionpoint_BKey]
													alpha:1.0];

	[aTextView setAutoresizingMask: NSViewWidthSizable];
	[[aTextView textContainer] setWidthTracksTextView:YES];
	[aTextView setDelegate:self];
	[aTextView setAllowsUndo:YES];
	[aTextView setRichText:NO];
	[aTextView setUsesFontPanel:YES];
	[aTextView setFont:[NSFont userFontOfSize:12.0]];
	[aTextView setBackgroundColor: backgroundColor];
	[aTextView setInsertionPointColor: insertionpointColor];
	[aTextView setAcceptsGlyphInfo: YES]; // suggested by Itoh 1.35 (A)
	[aTextView setDocument: self];
}

#pragma mark NSDocument interface

- (NSString *)windowNibName
{
	// Override returning the nib file name of the document
	return @"TSDocument";
}


// this method gives a name "Untitled-n" for new documents
-(NSString *)displayName
{
	if ([self fileName] == nil) // file is a new one
	{
		NSString *displayString = [super displayName];
		if (displayString == nil) // these two lines fix a Panther problem
			return displayString;
		else {
			NSMutableString *newString = [NSMutableString stringWithString: displayString];
			[newString replaceOccurrencesOfString: @" " withString: @"-"
										  options: 0 range: NSMakeRange(0, [newString length])];
			// mitsu 1.29 (V)
			if ([[[[[NSBundle mainBundle] pathForResource:@"MainMenu" ofType:@"nib"]
				stringByDeletingLastPathComponent] lastPathComponent]
				isEqualToString: @"Japanese.lproj"] && [newString length]==5)
				[newString appendString: @"-1"];
			// end mitsu 1.29
			return newString;
		}
	}
	return [super displayName];
}


// FIXME/TODO: Obviously windowControllerDidLoadNib is *way* too big. Need to simplify it,
// and possibly move code to other functions.
- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
	BOOL                spellExists;
	NSString		*imagePath;
	NSString		*theSource;
	NSString		*fileExtension;
	NSRange		myRange;
	BOOL		imageFound;
	NSString		*theFileName;
	int			defaultcommand;
	NSSize		contentSize;
	NSDictionary	*myAttributes;
		int                 i;
	BOOL                done;
	NSString            *defaultCommand;

	[super windowControllerDidLoadNib:aController];


	// the code below exists because the spell checker sometimes did not exist
	// in Panther developer releases; it is probably not necessary for
	// the final release
	NS_DURING
		NSSpellChecker *myChecker = [NSSpellChecker sharedSpellChecker];
		spellExists = (myChecker != 0);
	NS_HANDLER
		spellExists = NO;
	NS_ENDHANDLER


	/* New forsplit */


	contentSize = [scrollView contentSize];
	textView1 = [[TSTextView alloc] initWithFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)];
	[self setupTextView:textView1];
	[scrollView setDocumentView:textView1];
	[textView1 release];
	textView = textView1;
	/* End of New */
	// forsplit

	contentSize = [scrollView2 contentSize];
	textView2 = [[TSTextView alloc] initWithFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)];
	[self setupTextView:textView2];
	if (spellExists)
		[textView2 setContinuousSpellCheckingEnabled:[SUD boolForKey:SpellCheckEnabledKey]];
	[scrollView2 setDocumentView:textView2];
	[textView2 release];

	// Create a custom NSTextStorage and make sure the two NSTextViews both use it.
	[[textView1 layoutManager] replaceTextStorage:_textStorage];
	[[textView2 layoutManager] replaceTextStorage:_textStorage];

	[scrollView2 retain];
	[scrollView2 removeFromSuperview];
	windowIsSplit = NO;
	//  endforsplit


	_externalEditor = [[[NSApplication sharedApplication] delegate] forPreview];
	theFileName = [self fileName];

	[self configureTypesetButton];
	[self setupToolbar];

	if ([SUD boolForKey:ShowSyncMarksKey])
		[syncBox setState:1];

	[self setupColors];

	doAutoComplete = [SUD boolForKey:AutoCompleteEnabledKey];
	[self fixAutoMenu];


	/* when opening an empty document, must open the source editor */
	if ((theFileName == nil) && _externalEditor)
		_externalEditor = NO;

	[self registerForNotifications];
	[self setupFromPreferencesUsingWindowController:aController];

	[pdfView setDocument: self]; /* This was commented out!! Don't do it; needed by Ghostscript; Dick */
	[textView setDelegate: self];
	// the next line caused jpg and tiff files to fail, so we do it later
	//   [pdfView resetMagnification];


	whichScript = [SUD integerForKey:DefaultScriptKey];
	[self fixTypesetMenu];

	_documentType = isTeX;
	fileExtension = [[self fileName] pathExtension];

	if (( ! [fileExtension isEqualToString: @"tex"]) && ( ! [fileExtension isEqualToString: @"TEX"])
		&& ( ! [fileExtension isEqualToString: @"dtx"]) && ( ! [fileExtension isEqualToString: @"ins"])
		&& ( ! [fileExtension isEqualToString: @"sty"]) && ( ! [fileExtension isEqualToString: @"cls"])
		// added by mitsu --(N) support for .def, .fd, .ltx. .clo
		&& ( ! [fileExtension isEqualToString: @"def"]) && ( ! [fileExtension isEqualToString: @"fd"])
		&& ( ! [fileExtension isEqualToString: @"ltx"]) && ( ! [fileExtension isEqualToString: @"clo"])
		// end addition
		&& ( ! [fileExtension isEqualToString: @""]) && ( ! [fileExtension isEqualToString: @"mp"])
		&& ( ! [fileExtension isEqualToString: @"mf"])
		&& ( ! [fileExtension isEqualToString: @"bib"])
		&& ( ! [fileExtension isEqualToString: @"ly"])
		&& ([[NSFileManager defaultManager] fileExistsAtPath: [self fileName]]))
	{
		[self setFileType: fileExtension];
		[typesetButton setEnabled: NO];
		[typesetButtonEE setEnabled: NO];
		_documentType = isOther;
		fileIsTex = NO;
	}

	/* handle images */

	// mitsu 1.29 (S4)-- flipped clip view
	// the following code allows the window to be anchored at top left when scrolled
	[pdfView retain]; // hold it when clipView is released
	NSScrollView *pdfScrollView = [pdfView enclosingScrollView];
	NSClipView *pdfClipView = [pdfScrollView contentView];
	NSRect clipFrame = [pdfClipView frame];
	pdfClipView = [[FlippedClipView alloc] initWithFrame: clipFrame];	// it returns YES for isFlipped
	[pdfScrollView setContentView: pdfClipView];
	[pdfClipView setBackgroundColor: [NSColor windowBackgroundColor]];
	[pdfClipView setDrawsBackground: YES];
	[pdfClipView release];
	[pdfScrollView setDocumentView: pdfView];
	[pdfView release];
	[pdfView setAutoresizingMask: NSViewNotSizable];
	// notification for scroll
	[[NSNotificationCenter defaultCenter] addObserver:pdfView selector:@selector(wasScrolled:)
												 name:NSViewBoundsDidChangeNotification object:[pdfView superview]];
	// end mitsu 1.29

	[pdfView setImageType: _documentType];

	if (!fileIsTex) {
		imageFound = NO;
		imagePath = [self fileName];

		if ([fileExtension isEqualToString: @"pdf"]) {
			imageFound = YES;

			if ([[NSFileManager defaultManager] fileExistsAtPath: imagePath]) {
				myAttributes = [[NSFileManager defaultManager] fileAttributesAtPath: imagePath traverseLink:NO];
				_pdfLastModDate = [[myAttributes objectForKey:NSFileModificationDate] retain];
			}

			[pdfKitWindow setTitle: [[self fileName] lastPathComponent]];
			// [pdfWindow setRepresentedFilename: [self fileName]]; //mitsu July4;
			// supposed to allow command click of window title to lead to file, but doesn't
			_documentType = isPDF;
		} else if (([fileExtension isEqualToString: @"jpg"]) ||
				 ([fileExtension isEqualToString: @"jpeg"]) ||
				 ([fileExtension isEqualToString: @"JPG"])) {
			imageFound = YES;
			texRep = [[NSBitmapImageRep imageRepWithContentsOfFile: imagePath] retain];
			[pdfWindow setTitle: [[self fileName] lastPathComponent]];
			// [pdfWindow setRepresentedFilename: [self fileName]]; //mitsu July4
			_documentType = isJPG;
			[previousButton setEnabled:NO];
			[nextButton setEnabled:NO];
		} else if (([fileExtension isEqualToString: @"tiff"]) ||
				 ([fileExtension isEqualToString: @"tif"])) {
			imageFound = YES;
			texRep = [[NSBitmapImageRep imageRepWithContentsOfFile: imagePath] retain];
			[pdfWindow setTitle: [[self fileName] lastPathComponent]];
			// [pdfWindow setRepresentedFilename: [self fileName]]; //mitsu July4
			_documentType = isTIFF;
			[previousButton setEnabled:NO];
			[nextButton setEnabled:NO];
		} else if (([fileExtension isEqualToString: @"dvi"]) ||
				 ([fileExtension isEqualToString: @"ps"]) ||
				 ([fileExtension isEqualToString:@"eps"]))
		{
			_documentType = isPDF;
			[pdfView setImageType: _documentType];
			// [pdfWindow setRepresentedFilename: [self fileName]]; //mitsu July4
			[self convertDocument];
			return;
		}

		if (imageFound) {
			if (_documentType == isPDF) {

				PDFfromKit = YES;
				[myPDFKitView showWithPath: imagePath];
				[pdfKitWindow setRepresentedFilename: imagePath];
				[pdfKitWindow setTitle: [imagePath lastPathComponent]];
				[pdfKitWindow makeKeyAndOrderFront: self];
				if ((_documentType == isPDF) && ([SUD boolForKey: PdfFileRefreshKey] == YES) && ([SUD boolForKey:PdfRefreshKey] == YES)) {
					_pdfRefreshTimer = [[NSTimer scheduledTimerWithTimeInterval: [SUD floatForKey: RefreshTimeKey]
																		target:self selector:@selector(refreshPDFWindow:) userInfo:nil repeats:YES] retain];
				}
			} else {
				[pdfView setImageType: _documentType];
				[pdfView setImageRep: texRep]; // this releases old one!

				if (texRep != nil)
					[pdfView display];
				[pdfWindow makeKeyAndOrderFront: self];

				if ((_documentType == isPDF) && ([SUD boolForKey: PdfFileRefreshKey] == YES) && ([SUD boolForKey:PdfRefreshKey] == YES)) {
					_pdfRefreshTimer = [[NSTimer scheduledTimerWithTimeInterval: [SUD floatForKey: RefreshTimeKey]
																		target:self selector:@selector(refreshPDFWindow:) userInfo:nil repeats:YES] retain];
				}
			}
			return;
		}
	}
	/* end of images */

	if (_externalEditor)
		[self setHasUndoManager: NO];  // so reporting no changes does not lead to error messages

	texTask = nil;
	bibTask = nil;
	indexTask = nil;
	metaFontTask = nil;
	detexTask = nil;
	detexPipe = nil;

	if (!_externalEditor) {
		myRange.location = 0;
		myRange.length = 0;
		[textView setSelectedRange: myRange];
		if (spellExists)
			[textView setContinuousSpellCheckingEnabled:[SUD boolForKey:SpellCheckEnabledKey]];
		[textWindow setInitialFirstResponder: textView];
		[textWindow makeFirstResponder: textView];
	}

	if (!fileIsTex)
		return;

	// changed by mitsu --(J) Typeset command and (J++) Program popup button indicating Program name
	defaultcommand = [SUD integerForKey:DefaultCommandKey];
	switch (defaultcommand) {
		case DefaultCommandTeX: [programButton selectItemWithTitle: @"Plain TeX"];
			[programButtonEE selectItemWithTitle: @"Plain TeX"];
			whichEngine = TexEngine;	// just remember the default command
			break;
		case DefaultCommandLaTeX:   [programButton selectItemWithTitle: @"LaTeX"];
			[programButtonEE selectItemWithTitle: @"LaTeX"];
			whichEngine = LatexEngine;	// just remember the default command
			break;
		case DefaultCommandConTEXt: [programButton selectItemWithTitle: @"ConTeXt"];
			[programButtonEE selectItemWithTitle: @"ConTeXt"];
			whichEngine = ContextEngine;	// just remember the default command
			break;
		case DefaultCommandUser:    i = UserEngine;
			done = NO;
			defaultCommand = [[SUD stringForKey: DefaultEngineKey] lowercaseString];
			while ((i <= [programButton numberOfItems]) && (! done)) {
				i++;
				if ([[[[programButton itemAtIndex: (i - 2)] title] lowercaseString] isEqualToString: defaultCommand]) {
					done = YES;
					[programButton selectItemAtIndex: (i - 2)];
					[programButtonEE selectItemAtIndex: (i - 2)];
					whichEngine = i - 1;
				}
			}
			if (!done) {
				[programButton selectItemWithTitle: @"LaTeX"];
				[programButtonEE selectItemWithTitle: @"LaTeX"];
				whichEngine = LatexEngine;	// just remember the default command
			}
			break;
	}
	[self fixMacroMenu];

	// end change


	theSource = [[self textView] string];
	if ([self checkMasterFile: theSource forTask:RootForOpening])
		return;
	if ([self checkRootFile_forTask: RootForOpening])
		return;

	imagePath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
	if ([[NSFileManager defaultManager] fileExistsAtPath: imagePath]) {

		PDFfromKit = YES;
		myAttributes = [[NSFileManager defaultManager] fileAttributesAtPath: imagePath traverseLink:NO];
		_pdfLastModDate = [[myAttributes objectForKey:NSFileModificationDate] retain];

		[myPDFKitView showWithPath: imagePath];
		[pdfKitWindow setRepresentedFilename: imagePath];
		[pdfKitWindow setTitle: [imagePath lastPathComponent]];
	} else if (_externalEditor) {

		PDFfromKit = YES;
		[pdfKitWindow setTitle: [imagePath lastPathComponent]];
		[pdfKitWindow makeKeyAndOrderFront: self];


		// [pdfWindow setTitle: [imagePath lastPathComponent]];
		// [pdfWindow makeKeyAndOrderFront: self];
	}
	// added by mitsu --(A) g_texChar filtering
	[texCommand setDelegate: [TSEncodingSupport sharedInstance]];
	// end addition

	if (_externalEditor && ([SUD boolForKey: PdfRefreshKey] == YES)) {

		_pdfRefreshTimer = [[NSTimer scheduledTimerWithTimeInterval: [SUD floatForKey: RefreshTimeKey] target:self selector:@selector(refreshPDFWindow:) userInfo:nil repeats:YES] retain];

	}

	if (_externalEditor && [SUD boolForKey: ExternalEditorTypesetAtStartKey]) {

		NSString *texName = [self fileName];
		if (texName && [[NSFileManager defaultManager] fileExistsAtPath:texName]) {
			myAttributes = [[NSFileManager defaultManager] fileAttributesAtPath: texName traverseLink:NO];
			NSDate *texDate = [myAttributes objectForKey:NSFileModificationDate];
			if ((_pdfLastModDate == nil) || ([texDate compare:_pdfLastModDate] == NSOrderedDescending))
				[self doTypeset:self];
		}
	}

}

- (void)runModalSavePanelForSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
	_tempencoding = _encoding;
	[super runModalSavePanelForSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
}


- (void)saveToFile:(NSString *)fileName saveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo
{
	if (fileName != nil)
		_encoding = _tempencoding;
	[super saveToFile: fileName saveOperation: saveOperation delegate: delegate didSaveSelector: didSaveSelector contextInfo: contextInfo];
}


- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	NSView	*accessoryView;

	// FIXME HACK: This can be removed once we converted all encoding menus to be generated on the fly.
	NSString *encName = [[TSEncodingSupport sharedInstance] keyForStringEncoding:_encoding];
	int tag = [[TSEncodingSupport sharedInstance] tagForEncoding:encName];

	[openSaveBox selectItemAtIndex: tag];
	accessoryView = [savePanel accessoryView];
	[openSaveView retain];	// FIXME: Why is this retain needed?

	// FIXME: Why do we loop over the subviews of the accessoryView of the savepanel and add them ?!?
	NSEnumerator *enumerator = [[accessoryView subviews] objectEnumerator];
	id	anObject;
	while ((anObject = [enumerator nextObject]))
		[openSaveView addSubview: anObject];
	[savePanel setAccessoryView: openSaveView];
	return YES;
}

/* A user reported that while working with an external editor, he quit TeXShop and was
asked if he wanted to save documents. When he did, the source file was replaced with an
empty file. He had used Page Setup, which marked the file as changed. The code below
insures that files opened with an external editor are never marked as changed.
WARNING: This causes stack problems if the undo manager is enabled, so it is disabled
in other code when an external editor is being used. */

- (BOOL)isDocumentEdited
{
	if (_externalEditor)
		return NO;
	else
		return [super isDocumentEdited];
}


- (NSData *)dataRepresentationOfType:(NSString *)aType {

	NSRange             encodingRange, newEncodingRange, myRange, theRange;
	unsigned            length;
	NSString            *encodingString, *text, *testString;
	BOOL                done;
	int                 linesTested;
	unsigned            start, end, irrelevant;

	// FIXME: Unify this with the code in readFromFile:
	if ((GetCurrentKeyModifiers() & optionKey) == 0) {
		text = [textView string];
		length = [text length];
		done = NO;
		linesTested = 0;
		myRange.location = 0;
		myRange.length = 1;

		while ((myRange.location < length) && (!done) && (linesTested < 20)) {
			[text getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
			myRange.location = end;
			myRange.length = 1;
			linesTested++;

			// FIXME: Simplify the following code
			theRange.location = start; theRange.length = (end - start);
			testString = [text substringWithRange: theRange];
			encodingRange = [testString rangeOfString:@"%!TEX encoding ="];
			if (encodingRange.location != NSNotFound) {
				done = YES;
				newEncodingRange.location = encodingRange.location + 16;
				newEncodingRange.length = [testString length] - newEncodingRange.location;
				if (newEncodingRange.length > 0) {
					encodingString = [[testString substringWithRange: newEncodingRange]
						stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
					_encoding = _tempencoding = [[TSEncodingSupport sharedInstance] stringEncodingForKey: encodingString];
				}
			} else if ([SUD boolForKey:UseOldHeadingCommandsKey]) {
				encodingRange = [testString rangeOfString:@"%&encoding="];
				if (encodingRange.location != NSNotFound) {
					done = YES;
					newEncodingRange.location = encodingRange.location + 11;
					newEncodingRange.length = [testString length] - newEncodingRange.location;
					if (newEncodingRange.length > 0) {
						encodingString = [[testString substringWithRange: newEncodingRange]
							stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
						_encoding = _tempencoding = [[TSEncodingSupport sharedInstance] stringEncodingForKey: encodingString];
					}
				}
			}
		}
	}



	// zenitani 1.35 (C) --- utf.sty output
	if( [SUD boolForKey:ptexUtfOutputEnabledKey] &&
		[[TSEncodingSupport sharedInstance] ptexUtfOutputCheck: [textView string] withEncoding: _encoding] ) {

		return [[TSEncodingSupport sharedInstance] ptexUtfOutput: textView withEncoding: _encoding];
	} else {
		return [[textView string] dataUsingEncoding: _encoding allowLossyConversion:YES];
	}
}


- (BOOL)readFromFile:(NSString *)fileName ofType:(NSString *)type {
	id 			myData;
	NSString            *firstBytes, *encodingString, *testString;
	NSRange             encodingRange, newEncodingRange, myRange, theRange;
	unsigned            length, start, end, irrelevant;
	BOOL                done;
	int                 linesTested;

	myData = [NSData dataWithContentsOfFile:fileName];

	// FIXME: Unify this with the code in dataRepresentationOfType:
	if ((GetCurrentKeyModifiers() & optionKey) == 0) {
		firstBytes = [[NSString alloc] initWithData:myData encoding:NSMacOSRomanStringEncoding];
		length = [firstBytes length];
		done = NO;
		linesTested = 0;
		myRange.location = 0;
		myRange.length = 1;

		while ((myRange.location < length) && (!done) && (linesTested < 20)) {
			[firstBytes getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
			myRange.location = end;
			myRange.length = 1;
			linesTested++;

			// FIXME: Simplify the following code
			theRange.location = start; theRange.length = (end - start);
			testString = [firstBytes substringWithRange: theRange];
			encodingRange = [testString rangeOfString:@"%!TEX encoding ="];
			if (encodingRange.location != NSNotFound) {
				done = YES;
				newEncodingRange.location = encodingRange.location + 16;
				newEncodingRange.length = [testString length] - newEncodingRange.location;
				if (newEncodingRange.length > 0) {
					encodingString = [[testString substringWithRange: newEncodingRange]
						stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
					_encoding = _tempencoding = [[TSEncodingSupport sharedInstance] stringEncodingForKey: encodingString];
				}
			} else if ([SUD boolForKey:UseOldHeadingCommandsKey]) {
				encodingRange = [testString rangeOfString:@"%&encoding="];
				if (encodingRange.location != NSNotFound) {
					done = YES;
					newEncodingRange.location = encodingRange.location + 11;
					newEncodingRange.length = [testString length] - newEncodingRange.location;
					if (newEncodingRange.length > 0) {
						encodingString = [[testString substringWithRange: newEncodingRange]
							stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceAndNewlineCharacterSet]];
						_encoding = _tempencoding = [[TSEncodingSupport sharedInstance] stringEncodingForKey: encodingString];
					}
				}
			}
		}

		[firstBytes release];
	}


	NSString *content;
	content = [[[NSString alloc] initWithData:myData encoding:_encoding] autorelease];
	if (!content) {
		_badEncoding = _encoding;
		showBadEncodingDialog = YES;
		content = [[[NSString alloc] initWithData:myData encoding:NSMacOSRomanStringEncoding] autorelease];
	}

	if (content) {
		if ([SUD boolForKey:ConvertLFKey]) {
			// zenitani 1.35 (A) -- normalizing newline character for regular expression
			content = [OGRegularExpression replaceNewlineCharactersInString:content
															  withCharacter:OgreLfNewlineCharacter];
		}
		[[_textStorage mutableString] setString:content];

		return YES;
	} else {
		return NO;
	}
}

- (BOOL)writeToFile:(NSString *)fileName ofType:(NSString *)docType
{
	BOOL		result;
	NSUndoManager	*myManager;

	result = [super writeToFile:fileName ofType:docType];
	if (result) {
		// We register a dummy undo operation here, to make sure that the undo stack
		// is properly synced to the actual editing state of the document.
		myManager = [self undoManager];
		[myManager registerUndoWithTarget:self selector:@selector(doNothing:) object: nil];
		[myManager setActionName:NSLocalizedString(@"Save Spot", @"Save Spot")];
		[[textWindow undoManager] undo];
	}
	return result;
}

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	BOOL	value;

	value = [super revertToContentsOfURL:absoluteURL ofType:typeName error:outError];
	if (value) {
		[self setupTags];
		[self colorizeAll];
	}
	
	// FIXME: Is the following even needed? Changin the textstorage should trigger a redraw anyway,
	// shouldn't it? But if we do have to call this, shouldn't we also do the same for textView2?
	[textView setNeedsDisplayInRect: [textView bounds]];
	
	return value;
}

- (void)printShowingPrintPanel:(BOOL)flag
{
	id				printView;
	NSPrintOperation	*printOperation;
	NSString		*imagePath;
	NSString		*theSource;
	id				aRep;
	int				result;
	
	if (_documentType == isTeX) {
		
		if (!_externalEditor) {
			theSource = [[self textView] string];
			if ([self checkMasterFile:theSource forTask:RootForPrinting])
				return;
			if ([self checkRootFile_forTask:RootForPrinting])
				return;
		}
		
		imagePath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
	}
	else if (_documentType == isPDF)
		imagePath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
	else if ((_documentType == isJPG) || (_documentType == isTIFF))
		imagePath = [self fileName];
	else
		imagePath = [self fileName];
	
	aRep = nil;
	if ([[NSFileManager defaultManager] fileExistsAtPath: imagePath]) {
		if ((_documentType == isTeX) || (_documentType == isPDF))
			aRep = [NSPDFImageRep imageRepWithContentsOfFile: imagePath];
		else if (_documentType == isJPG || _documentType == isTIFF)
			aRep = [NSImageRep imageRepWithContentsOfFile: imagePath];
		if (aRep == nil)
			return;
		printView = [[TSPrintView alloc] initWithImageRep: aRep];
		printOperation = [NSPrintOperation printOperationWithView:printView printInfo: [self printInfo]];
		[printOperation setShowPanels:flag];
		[printOperation runOperation];
		[printView release];
	} else if (_documentType == isTeX)
		result = [NSApp runModalForWindow: printRequestPanel];
}

- (BOOL)keepBackupFile
{
	return [SUD boolForKey:KeepBackupKey];
}

- (void)close
{
	[tagTimer invalidate];
	[tagTimer release];
	tagTimer = nil;

	[_pdfRefreshTimer invalidate];
	[_pdfRefreshTimer release];
	_pdfRefreshTimer = nil;

	[pdfWindow close];
	/* The next line fixes a crash bug in Jaguar; see notifyActiveTextWindowClosed for
	a description. */
	[[TSWindowManager sharedInstance] notifyActiveTextWindowClosed];

	// mitsu 1.29 (P)
	if (!fileIsTex && [[self fileName] isEqualToString:
		[CommandCompletionPath stringByStandardizingPath]])
		g_canRegisterCommandCompletion = YES;
	// end mitsu 1.29

	[super close];
}

- (NSDictionary *)fileAttributesToWriteToFile:(NSString *)fullDocumentPath ofType:(NSString *)documentTypeName saveOperation:(NSSaveOperationType)saveOperationType
{
	NSDictionary	*myDictionary;
	NSMutableDictionary	*aDictionary;
	NSNumber		*myNumber;

	myDictionary = [super fileAttributesToWriteToFile: fullDocumentPath ofType: documentTypeName
					saveOperation: saveOperationType];
	aDictionary = [NSMutableDictionary dictionaryWithDictionary: myDictionary];
	myNumber = [NSNumber numberWithLong:'TEXT'];
	[aDictionary setObject: myNumber forKey: NSFileHFSTypeCode];
	myNumber = [NSNumber numberWithLong:'TeXs'];
	[aDictionary setObject: myNumber forKey: NSFileHFSCreatorCode];
	return aDictionary;
}

- (void)saveDocument: (id)sender
{
	[super saveDocument: sender];
	// if CommandCompletion list is being saved, reload it.
	if (!fileIsTex && [[self fileName] isEqualToString:
				[CommandCompletionPath stringByStandardizingPath]])
		[[NSApp delegate] finishCommandCompletionConfigure];
}


#pragma mark Statistics dialog


- (void)showStatistics: sender
{
	NSDate          *myDate;
	NSString        *enginePath, *myFileName, *tetexBinPath;
	NSMutableArray  *args;
	
	[statisticsPanel setTitle:[self displayName]];
	[statisticsPanel makeKeyAndOrderFront:self];
	
	myFileName = [self fileName];
	if (! myFileName)
		return;
	
	if (detexTask != nil) {
		[detexTask terminate];
		myDate = [NSDate date];
		while (([detexTask isRunning]) && ([myDate timeIntervalSinceDate:myDate] < 0.5)) ;
		[detexTask release];
		[detexPipe release];
		detexTask = nil;
		detexPipe = nil;
	}
	
	detexTask = [[NSTask alloc] init];
	[detexTask setCurrentDirectoryPath: [myFileName stringByDeletingLastPathComponent]];
	[detexTask setEnvironment: [self environmentForSubTask]];
	enginePath = [[NSBundle mainBundle] pathForResource:@"detexwrap" ofType:nil];
	tetexBinPath = [[SUD stringForKey:TetexBinPath] stringByExpandingTildeInPath];
	args = [NSMutableArray array];
	[args addObject:tetexBinPath];
	[args addObject: [myFileName  stringByStandardizingPath]];
	detexPipe = [[NSPipe pipe] retain];
	detexHandle = [detexPipe fileHandleForReading];
	[detexHandle readInBackgroundAndNotify];
	[detexTask setStandardOutput: detexPipe];
	if ((enginePath != nil) && ([[NSFileManager defaultManager] fileExistsAtPath: enginePath])) {
		[detexTask setLaunchPath:enginePath];
		[detexTask setArguments:args];
		[detexTask launch];
	} else {
		if (detexPipe)
			[detexTask release];
		detexTask = nil;
	}
	
}

- (void)saveForStatistics: (NSDocument *)doc didSave:(BOOL)didSave contextInfo:(void *)contextInfo
{
	[self showStatistics:self];
}

- (void)updateStatistics: sender
{
	SEL		saveForStatistics;

	saveForStatistics = @selector(saveForStatistics:didSave:contextInfo:);
	[self saveDocumentWithDelegate: self didSaveSelector: saveForStatistics contextInfo: nil];
}


#pragma mark Encodings


// The next three methods implement the encoding button in the save panel

- (void) chooseEncoding: sender
{
	int tag = [[sender selectedCell] tag];
	_tempencoding = [[TSEncodingSupport sharedInstance] stringEncodingForTag: tag];
}

- (NSStringEncoding) encoding
{
	return _encoding;
}

- (void)tryBadEncodingDialog: (NSWindow *)theWindow
{
	if (showBadEncodingDialog) {
		NSString *theEncoding = [[TSEncodingSupport sharedInstance] localizedNameForStringEncoding: _badEncoding];
		NSBeginAlertSheet(NSLocalizedString(@"This file was opened with MacOSRoman encoding.", @"This file was opened with MacOSRoman encoding."),
						  nil, nil, nil, theWindow, nil, nil, nil, nil,
						  NSLocalizedString(@"The file could not be opened with %@ encoding because it was not saved with that encoding. If you wish to open in another encoding, close the window and open again.",
											@"The file could not be opened with %@ encoding because it was not saved with that encoding. If you wish to open in another encoding, close the window and open again."), theEncoding);
	}
	showBadEncodingDialog = FALSE;

}


#pragma mark -


- (void)configureTypesetButton
{
	NSFileManager   *fm;
	NSString        *basePath, *path, *title;
	NSArray         *fileList;
	BOOL            isDirectory;
	unsigned        i;

	fm       = [NSFileManager defaultManager];
	basePath = [EnginePath stringByStandardizingPath];
	fileList = [fm directoryContentsAtPath: basePath];
	for (i=0; i < [fileList count]; i++) {
		title = [fileList objectAtIndex: i];
		path  = [basePath stringByAppendingPathComponent: title];
		if ([fm fileExistsAtPath:path isDirectory: &isDirectory]) {
			if (!isDirectory && ( [ [[title pathExtension] lowercaseString] isEqualToString: @"engine"] )) {
				title = [title stringByDeletingPathExtension];
				[programButton addItemWithTitle: title];
				[programButtonEE addItemWithTitle: title];
			}
		}
	}
}

// forsplit

- (void) setTextView: (id)aView
{
	NSRange		theRange;

	textView = aView;
	if (textView == textView1) {
		theRange = [textView2 selectedRange];
		theRange.length = 0;
		[textView2 setSelectedRange: theRange];
	} else {
		theRange = [textView1 selectedRange];
		theRange.length = 0;
		[textView1 setSelectedRange: theRange];
	}
}

- (void) splitWindow: sender
{
	NSSize		newSize;
	NSRect		theFrame;
	NSRange		selectedRange;

	selectedRange = [textView selectedRange];
	newSize.width = 100;
	newSize.height = 100;
	if (windowIsSplit) {
//		[scrollView2 retain];	// FIXME: THis retain doesn't seem necessary and cause a leak, I believe...
		[scrollView2 removeFromSuperview];
		windowIsSplit = NO;
		textView = textView1;
		[textView scrollRangeToVisible: selectedRange];
		[textView setSelectedRange: selectedRange];
	} else {
		theFrame = [scrollView frame];
		newSize.width = theFrame.size.width;
		newSize.height = 100;
		[scrollView setFrameSize:newSize];
		[scrollView2 setFrameSize:newSize];
		[splitView addSubview: scrollView2];
		[splitView adjustSubviews];
		[textView1 scrollRangeToVisible: selectedRange];
		[textView2 scrollRangeToVisible: selectedRange];
		selectedRange.length = 0;
		[textView2 setSelectedRange: selectedRange];

		windowIsSplit = YES;
		textView = textView1;
	}
}


- (void)registerForNotifications
/*" This method registers all notifications that are necessary to work properly together with the other AppKit and TeXShop objects.
"*/
{
	// FIXME/TODO: A lot of these notifcations may become obsolete (or at least can be replaced by a better mechanism)
	// once we fix TSDocument to properly use multiple NSWindowController instances, one for each window associated
	// with the document.

	// register to learn when the document window becomes main so we can fix the Typeset script

	[[NSNotificationCenter defaultCenter] addObserver: self selector:@selector(newMainWindow:)
		name:NSWindowDidBecomeMainNotification object:nil];

	// register for notifications when the document window becomes key so we can remember which window was
	// the frontmost. This is needed for the preferences.
	[[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(textWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:textWindow];
	[[NSNotificationCenter defaultCenter] addObserver:[TSLaTeXPanelController sharedInstance] selector:@selector(textWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:textWindow];
	[[NSNotificationCenter defaultCenter] addObserver:[TSMatrixPanelController sharedInstance] selector:@selector(textWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:textWindow];
	[[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(documentWindowWillClose:) name:NSWindowWillCloseNotification object:textWindow];
// added by mitsu --(J+) check mark in "Typeset" menu
	[[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(documentWindowDidResignKey:) name:NSWindowDidResignKeyNotification object:textWindow];
// end addition


	// register for notifications when the pdf window becomes key so we can remember which window was the frontmost.
	[[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(pdfWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:pdfKitWindow];
	[[NSNotificationCenter defaultCenter] addObserver:[TSLaTeXPanelController sharedInstance] selector:@selector(pdfWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:pdfKitWindow];
	[[NSNotificationCenter defaultCenter] addObserver:[TSMatrixPanelController sharedInstance] selector:@selector(pdfWindowDidBecomeKey:) name:NSWindowDidBecomeKeyNotification object:pdfKitWindow];
	[[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(pdfWindowWillClose:) name:NSWindowWillCloseNotification object:pdfKitWindow];
// added by mitsu --(J+) check mark in "Typeset" menu
	[[NSNotificationCenter defaultCenter] addObserver:[TSWindowManager sharedInstance] selector:@selector(pdfWindowDidResignKey:) name:NSWindowDidResignKeyNotification object:pdfKitWindow];
// end addition


	// register for notification when the document font changes in preferences
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setDocumentFontFromPreferences:) name:DocumentFontChangedNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(revertDocumentFont:) name:DocumentFontRevertNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(rememberFont:) name:DocumentFontRememberNotification object:nil];

	// register for notification when the syntax coloring changes in preferences
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reColor:) name:DocumentSyntaxColorNotification object:nil];

	// register for notification when auto completion changes in preferences
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changePrefAutoComplete:) name:DocumentAutoCompleteNotification object:nil];

	// externalEditChange
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(externalEditorChange:) name:ExternalEditorNotification object:nil];

	// notifications for pdftex and pdflatex
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkATaskStatus:)
		name:NSTaskDidTerminateNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkPrefClose:)
		name:NSWindowWillCloseNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(writeTexOutput:)
		name:NSFileHandleReadCompletionNotification object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doCompletion:)
		name:@"completionpanel" object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(doMatrix:)
												 name:@"matrixpanel" object:nil]; // Matrix addition by Jonas

// added by mitsu --(D) reset tags when the encoding is switched
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetTagsMenu:)
		name:@"ResetTagsMenuNotification" object:nil];


	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resetMacroButton:)
		name:@"ResetMacroButtonNotification" object:nil];


// end addition

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(resetTagsMenu:)
		name:@"NSUndoManagerDidRedoChangeNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(resetTagsMenu:)
		name:@"NSUndoManagerDidUndoChangeNotification" object:nil];

	// Register for notifcations when the text view(s) get scrolled, so that syntax highlighting can be updated.
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(viewBoundsDidChange:)
												 name:NSViewBoundsDidChangeNotification
											   object:[scrollView contentView]];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(viewBoundsDidChange:)
												 name:NSViewBoundsDidChangeNotification
											   object:[scrollView2 contentView]];

	// Register for resizing
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(viewFrameDidChange:)
												 name:NSViewFrameDidChangeNotification
											   object:textView1];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(viewFrameDidChange:)
												 name:NSViewFrameDidChangeNotification
											   object:textView2];
}

- (void)setupFromPreferencesUsingWindowController:(NSWindowController *)windowController
/*" This method reads the NSUserDefaults and restores the settings before the document will actually be displayed.
"*/
{
	// inhibit ordering of windows by windowController.
	[windowController setShouldCascadeWindows:NO];

	// restore window position for the document window
	switch ([SUD integerForKey:DocumentWindowPosModeKey])
	{
		case DocumentWindowPosSave:
			[textWindow setFrameAutosaveName:DocumentWindowNameKey];
			break;

		case DocumentWindowPosFixed:
			[textWindow setFrameFromString:[SUD stringForKey:DocumentWindowFixedPosKey]];
			break;
	}

	// restore window position for the pdf window
	switch ([SUD integerForKey:PdfWindowPosModeKey])
	{
		case PdfWindowPosSave:
			[pdfWindow setFrameAutosaveName:PdfWindowNameKey];
			[pdfKitWindow setFrameAutosaveName:PdfKitWindowNameKey];
			break;

		case PdfWindowPosFixed:
			[pdfWindow setFrameFromString:[SUD stringForKey:PdfWindowFixedPosKey]];
			[pdfKitWindow setFrameFromString:[SUD stringForKey:PdfWindowFixedPosKey]];
	}

	// restore the font for document if desired
	if ([SUD boolForKey:SaveDocumentFontKey] == YES)
	{
		[self setDocumentFontFromPreferences:nil];
	}

/*
	// setup the popUp with all of our template names
	[popupButton addItemsWithTitles:[[TSPreferences sharedInstance] allTemplateNames]];
*/

	// FIXME/TODO: Unify the following code snippet with makeMenuFromDirectory:

	// new template menu (by S. Zenitani, Jan 31, 2003)
	NSFileManager *fm;
	NSString      *basePath, *path, *title;
	NSArray       *fileList;
	id <NSMenuItem>	  newItem;
	NSMenu 	  *submenu;
	BOOL	   isDirectory;
	unsigned i;
	unsigned lv = 3;

	fm       = [ NSFileManager defaultManager ];
	basePath = [ TexTemplatePath stringByStandardizingPath ];
	fileList = [ fm directoryContentsAtPath: basePath ];

	for (i = 0; i < [fileList count]; i++) {
		title = [ fileList objectAtIndex: i ];
		path  = [ basePath stringByAppendingPathComponent: title ];
		if ([fm fileExistsAtPath:path isDirectory: &isDirectory]) {
			if (isDirectory ){
				[popupButton addItemWithTitle: @""];
				newItem = [popupButton lastItem];
				[newItem setTitle: title];
				submenu = [[[NSMenu alloc] init] autorelease];
				[self makeMenuFromDirectory: submenu basePath: path
									 action: @selector(doTemplate:) level: lv];
				[newItem setSubmenu: submenu];
			} else if ([ [[title pathExtension] lowercaseString] isEqualToString: @"tex"]) {
				title = [title stringByDeletingPathExtension];
				[popupButton addItemWithTitle: @""];
				newItem = [popupButton lastItem];
				[newItem setTitle: title];
				[newItem setAction: @selector(doTemplate:)];
				[newItem setTarget: self];
				[newItem setRepresentedObject: path];
			}
		}
	}
	// end of addition
}

- (void) makeMenuFromDirectory: (NSMenu *)menu basePath: (NSString *)basePath action:(SEL)action level:(unsigned)level;
/* build a submenu from the specified directory (by S. Zenitani, Jan 31, 2003) */
{
	NSFileManager *fm;
	NSArray       *fileList;
	NSString      *path, *title;
	id <NSMenuItem>	  newItem;
	NSMenu 	  *submenu;
	BOOL	   isDirectory;
	unsigned i;

	level--;
	fm       = [ NSFileManager defaultManager ];
	fileList = [ fm directoryContentsAtPath: basePath ];

	for (i = 0; i < [fileList count]; i++) {
		title = [ fileList objectAtIndex: i ];
		path  = [ basePath stringByAppendingPathComponent: title ];
		if ([fm fileExistsAtPath:path isDirectory: &isDirectory]) {
			if (isDirectory) {
				newItem = [menu addItemWithTitle: title action: nil keyEquivalent: @""];
				if (level > 0) {
					submenu = [[[NSMenu alloc] init] autorelease];
					[self makeMenuFromDirectory: submenu basePath: path
										 action: action level: level];
					[newItem setSubmenu: submenu];
				}
			} else if ([[[title pathExtension] lowercaseString] isEqualToString: @"tex"]) {
				title = [title stringByDeletingPathExtension];
				newItem = [menu addItemWithTitle: title action: action keyEquivalent: @""];
				[newItem setTarget: self];
				[newItem setRepresentedObject: path];
			}
		}
	}
}

- (void)setDocumentFontFromPreferences:(NSNotification *)notification
/*" Changes the font of %textView to the one saved in the NSUserDefaults. This method is also registered with NSNotificationCenter and a notifictaion will be send whenever the font changes in the preferences panel.
"*/
{
	NSData	*fontData;
	NSFont 	*font;

	fontData = [SUD objectForKey:DocumentFontKey];
	if (fontData != nil)
	{
		font = [NSUnarchiver unarchiveObjectWithData:fontData];
		[textView setFont:font];
	}
	[self fixUpTabs];
}

- (void)externalEditorChange:(NSNotification *)notification
{
	[[[NSApplication sharedApplication] delegate] configureExternalEditor];
}


- (BOOL)externalEditor
{
	return _externalEditor;
}

- (void)rememberFont:(NSNotification *)notification
/*" Called when preferences starts to save current font "*/
{
	NSFont 	*font;

	if (previousFontData != nil)
			[previousFontData release];
	{
		font = [textView font];
		previousFontData = [[NSArchiver archivedDataWithRootObject: font] retain];
	}
}

- (void)revertDocumentFont:(NSNotification *)notification
/*" Changes the font of %textView to the one used before preferences called, in case the
preference change is cancelled. "*/
{
	NSFont 	*font;

	if (previousFontData != nil)
	{
		font = [NSUnarchiver unarchiveObjectWithData:previousFontData];
		[textView setFont:font];
	}
	[self fixUpTabs];
}


- (void) doNothing: (id) theDictionary
{
	;
}

- (id) magnificationPanel
{
	if ([self fromKit])
		return magnificationKitPanel;
	else
		return magnificationPanel;
}

- (id) pagenumberPanel
{
	if ([self fromKit])
		return pagenumberKitPanel;
	else
		return pagenumberPanel;
}

- (void) quitMagnificationPanel: sender
{
	[NSApp endSheet: magnificationPanel returnCode: 0];
}

- (void) quitPagenumberPanel: sender
{
	[NSApp endSheet: pagenumberPanel returnCode: 0];
}

- (void) printSource: sender
{

	NSPrintOperation            *printOperation;
	NSPrintInfo                 *myPrintInfo;
	NSPrintingPaginationMode    originalPaginationMode;
	BOOL                        originalVerticallyCentered;

	myPrintInfo = [self printInfo];
	originalPaginationMode = [myPrintInfo horizontalPagination];
	originalVerticallyCentered = [myPrintInfo isVerticallyCentered];

	[myPrintInfo setHorizontalPagination: NSFitPagination];
	[myPrintInfo setVerticallyCentered:NO];
	printOperation = [NSPrintOperation printOperationWithView:textView printInfo: myPrintInfo];
	[printOperation setShowPanels:YES];
	[printOperation runOperation];

	[myPrintInfo setHorizontalPagination: originalPaginationMode];
	[myPrintInfo setVerticallyCentered:originalVerticallyCentered];

}

- (void) doChooseMethod: sender
{
	NSMenu *menu;
	
	 menu = [[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"Typeset", @"Typeset")] submenu];
	
	[[menu itemWithTag:kTypesetViaPDFTeX] setState:NSOffState];
	[[menu itemWithTag:kTypesetViaGhostScript] setState:NSOffState];
	[[menu itemWithTag:kTypesetViaPersonalScript] setState:NSOffState];
	[sender setState:NSOnState];
	whichScript = [sender tag];
}

- (void) fixTypesetMenu
{
	NSMenu				*menu;

	menu = [[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"Typeset", @"Typeset")] submenu];

	[[menu itemWithTag:kTypesetViaPDFTeX] setState:NSOffState];
	[[menu itemWithTag:kTypesetViaGhostScript] setState:NSOffState];
	[[menu itemWithTag:kTypesetViaPersonalScript] setState:NSOffState];

	[[menu itemWithTag:whichScript] setState:NSOnState];
}

- (void)newMainWindow:(NSNotification *)notification
{
	id object = [notification object];
	if ((object == pdfWindow) || (object == textWindow) || (object == outputWindow))
		[self fixTypesetMenu];
}

- (void) chooseProgramFF: sender
{
	int i = [sender tag];
	[programButton selectItemAtIndex: i];
	[programButtonEE selectItemAtIndex: i];

	// Deselect the previous typeset command, and select the new one.
	[[TSWindowManager sharedInstance] checkProgramMenuItem: whichEngine checked: NO];
	whichEngine = i + 1;  // remember it
	[[TSWindowManager sharedInstance] checkProgramMenuItem: whichEngine checked: YES];
	[self fixMacroMenu];
}


- (void) chooseProgram: sender
{
	id		theItem;
	int		which;

	theItem = [sender selectedItem];
	which = [sender indexOfItem: theItem] + 1;
	[programButton selectItemAtIndex: (which - 1)];
	[programButtonEE selectItemAtIndex: (which - 1)];

	// Deselect the previous typeset command, and select the new one.
	[[TSWindowManager sharedInstance] checkProgramMenuItem: whichEngine checked: NO];
	whichEngine = which;  // remember it
	[[TSWindowManager sharedInstance] checkProgramMenuItem: whichEngine checked: YES];
	[self fixMacroMenu];
}

- (void) okProject: sender
{
	myPrefResult = 0;
	[projectPanel close];
}

- (void) quitProject: sender
{
	myPrefResult = 1;
	[projectPanel close];
}


- (void) okForRequest: sender
{
	myPrefResult = 0;
	[requestWindow close];
}

- (void) okForPrintRequest: sender
{
	myPrefResult = 0;
	[printRequestPanel close];
}


- (void) okLine: sender
{
	myPrefResult = 0;
	[linePanel close];
}

- (void) quitLine: sender
{
	myPrefResult = 1;
	[linePanel close];
}

- (void) setProjectFile: sender
{
	int		result;
	NSString		*project, *nameString; //, *anotherString;

	if (! [self fileName]) {
		result = [NSApp runModalForWindow: requestWindow];
	}
	else {

		myPrefResult = 2;
		project = [[[self fileName] stringByDeletingPathExtension]
			stringByAppendingString: @".texshop"];
		if ([[NSFileManager defaultManager] fileExistsAtPath: project]) {
			nameString = [NSString stringWithContentsOfFile: project];
			[projectName setStringValue: nameString];
		}
		else
			[projectName setStringValue: [[self fileName] lastPathComponent]];
		[projectName selectText: self];
		result = [NSApp runModalForWindow: projectPanel];
		if (result == 0) {
			nameString = [projectName stringValue];
			//            if ([nameString isAbsolutePath])
			[nameString writeToFile: project atomically: YES];
			//           else {
			//                anotherString = [[self fileName] stringByDeletingLastPathComponent];
			//                anotherString = [[anotherString stringByAppendingString:@"/"]
			//                        stringByAppendingString: nameString];
			//                nameString = [anotherString stringByStandardizingPath];
			//                [nameString writeToFile: project atomically: YES];
			//                }
		}
	}
}

- (void) doLine: sender
{
	int		result, line;

	myPrefResult = 2;
	result = [NSApp runModalForWindow: linePanel];
	if (result == 0) {
		line = [lineBox intValue];
		[self toLine: line];
	}
}

#pragma mark Templates

- (void) fixTemplate: (id) theDictionary
{
	NSRange		oldRange;
	NSString		*oldString, *newString;
	NSUndoManager	*myManager;
	NSMutableDictionary	*myDictionary;
	NSNumber		*theLocation, *theLength;
	unsigned		from, to;

	oldRange.location = [[theDictionary objectForKey: @"oldLocation"] unsignedIntValue];
	oldRange.length = [[theDictionary objectForKey: @"oldLength"] unsignedIntValue];
	newString = [theDictionary objectForKey: @"oldString"];
	oldString = [[textView string] substringWithRange: oldRange];
	[textView replaceCharactersInRange: oldRange withString: newString];

	myManager = [textView undoManager];
	myDictionary = [NSMutableDictionary dictionaryWithCapacity: 3];
	theLocation = [NSNumber numberWithInt: oldRange.location];
	theLength = [NSNumber numberWithInt: [newString length]];
	[myDictionary setObject: oldString forKey: @"oldString"];
	[myDictionary setObject: theLocation forKey: @"oldLocation"];
	[myDictionary setObject: theLength forKey: @"oldLength"];
	[myManager registerUndoWithTarget:self selector:@selector(fixTemplate:) object: myDictionary];
	[myManager setActionName:NSLocalizedString(@"Template", @"Template")];
	from = oldRange.location;
	to = from + [newString length];
	[self fixColor: from :to];
	[self setupTags];

}


// Modified by Martin Heusse
// Modified by Seiji Zenitani (Jan 31, 2003)
//==================================================================
- (void) doTemplate: sender
{
	NSString		*nameString, *oldString;
	id			theItem;
	unsigned		from, to;
	NSRange		myRange;
	NSUndoManager	*myManager;
	NSMutableDictionary	*myDictionary;
	NSNumber		*theLocation, *theLength;
	id			myData;
	NSStringEncoding	theEncoding;

	NSRange 		NewlineRange;
	int 		i, numTabs, numSpaces=0;
	NSMutableString	*templateString, *indentString = [NSMutableString stringWithString:@"\n"];

/*
	theItem = [sender selectedItem];
*/
	// for submenu items
	if ([sender isKindOfClass: [NSMenuItem class]])
	{
		nameString = [(NSMenuItem *)sender representedObject];
	}
	// for popup button
	else
	{
		theItem = [sender selectedItem];
		if ( theItem != nil ){
			nameString = [TexTemplatePath stringByStandardizingPath];
			nameString = [nameString stringByAppendingPathComponent:[theItem title]];
			nameString = [nameString stringByAppendingPathExtension:@"tex"];
		}else{
			return;
		}
	}

	// if ( theItem != nil )
	if ( [[NSFileManager defaultManager] fileExistsAtPath: nameString] )
	{
/*
		// The lines are moved (S. Zenitani, Jan 31, 2003)
		nameString = [TexTemplatePath stringByStandardizingPath];
		nameString = [nameString stringByAppendingPathComponent:[theItem title]];
		nameString = [nameString stringByAppendingPathExtension:@"tex"];
*/
		theEncoding = [[TSEncodingSupport sharedInstance] defaultEncoding];
		myData = [NSData dataWithContentsOfFile:nameString];
		templateString = [[[NSMutableString alloc] initWithData:myData encoding:theEncoding] autorelease];

		// check and rebuild the trailing string...
		numTabs = [self textViewCountTabs:textView andSpaces:(int *)&numSpaces];
		for (i = 0; i < numTabs; i++)
			[indentString appendString:@"\t"];
		for (i = 0; i < numSpaces; i++)
			[indentString appendString:@" "];

		// modify the template string and add the tabs & spaces...
		NewlineRange = [templateString rangeOfString: @"\n"
											 options: NSBackwardsSearch
											   range: NSMakeRange(0,[templateString length])];
		while(NewlineRange.location > 0 && NewlineRange.location != NSNotFound){
			// NSLog(@"%d", NewlineRange.location);
			[templateString replaceCharactersInRange: NewlineRange withString: indentString];
			NewlineRange = [templateString rangeOfString:@"\n"
												 options: NSBackwardsSearch
												   range: NSMakeRange(0,NewlineRange.location)];
		}

		if (templateString != nil)
		{
			myRange = [textView selectedRange];
			oldString = [[textView string] substringWithRange: myRange];
			[textView replaceCharactersInRange:myRange withString:templateString];

			myManager = [textView undoManager];
			myDictionary = [NSMutableDictionary dictionaryWithCapacity: 3];
			theLocation = [NSNumber numberWithUnsignedInt: myRange.location];
			theLength = [NSNumber numberWithUnsignedInt: [templateString length]];
			[myDictionary setObject: oldString forKey: @"oldString"];
			[myDictionary setObject: theLocation forKey: @"oldLocation"];
			[myDictionary setObject: theLength forKey: @"oldLength"];
			[myManager registerUndoWithTarget:self selector:@selector(fixTemplate:) object: myDictionary];
			 [myManager setActionName:NSLocalizedString(@"Template", @"Template")];

			from = myRange.location;
			to = from + [templateString length];
			[self fixColor:from :to];
			[self setupTags];
		}
	}
}


#pragma mark Tag menu

- (void) doTag: sender
{
	NSString	*text, *titleString, *matchString;
	unsigned	start, end, irrelevant;
	NSRange	myRange, nameRange, gotoRange;
	unsigned	length;
	unsigned	lineNumber = 0;
	unsigned	destLineNumber;

	titleString = [sender title];
	matchString = [sender representedObject];
	destLineNumber = [sender tag];

	if (!matchString)
		return;

	text = [textView string];
	length = [text length];
	myRange.location = 0;
	myRange.length = 1;

	// Search for the line with number 'destLineNumber'.
	while ((myRange.location < length) && (lineNumber < destLineNumber)) {
		[text getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
		myRange.location = end;
		lineNumber++;
	}

	nameRange.location	= start;
	nameRange.length	= [matchString length];
	if ((lineNumber == destLineNumber) && (start + nameRange.length < length)) {
		if (NSOrderedSame == [text compare:matchString options:0 range:nameRange]) {
			gotoRange.location = start;
			gotoRange.length = (end - start);
			[textView setSelectedRange: gotoRange];
			[textView scrollRangeToVisible: gotoRange];
		}
	}
}


- (void) setupTags
{
	if ([SUD boolForKey: TagSectionsKey]) {
		[tagTimer invalidate];
		[tagTimer release];
		tagTimer = nil;

		tagLocation = 0;
		tagLocationLine = 0;
		[tags removeAllItems];
		[tags addItemWithTitle:NSLocalizedString(@"Tags", @"Tags")];
		tagTimer = [[NSTimer scheduledTimerWithTimeInterval: .02 target:self selector:@selector(fixTags:) userInfo:nil repeats:YES] retain];
	}
}

- (void) fixTags:(NSTimer *)timer
{
	NSString	*text;
	unsigned	start, end, irrelevant;
	NSRange	myRange, nameRange;
	unsigned	length, index;
	unsigned	lineNumber;
	id <NSMenuItem> newItem;
	BOOL enableAutoTagSections;

	if (!fileIsTex) return;

	text = [textView string];
	length = [text length];
	index = tagLocation + 10000;
	lineNumber = tagLocationLine; // added
	myRange.location = tagLocation;
	myRange.length = 1;

	enableAutoTagSections = [SUD boolForKey: TagSectionsKey];

	// Iterate over all lines
	while ((myRange.location < length) && (myRange.location < index)) {
		[text getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
		myRange.location = end;
		lineNumber++;

		// Only consider lines which aren't too short...
		if (end-start > 3) {
			NSString *line, *titleString;
			nameRange.location = start;
			nameRange.length = end - start;
			line = [text substringWithRange: nameRange];
			titleString = 0;

			// Lines starting with '%:' are added to the tags menu.
			if ([line hasPrefix:@"%:"]) {
				titleString = [line substringFromIndex:2];
			}
			// Scan for lines containing a chapter/section/... command (any listed in g_taggedTeXSections).
			// To short-circuit the search, we only consider lines that start with a backslash (or yen) symbol.
			// TODO: Actually, that's kind of overly restrictive. After all, having spaces in front
			// of a \section command is valid. Might want to remove this limitation...
			else if (enableAutoTagSections && ([text characterAtIndex: start] == g_texChar)) {
				unsigned	i;
				for (i = 0; i < [g_taggedTeXSections count]; ++i) {
					NSString* tag = [g_taggedTeXSections objectAtIndex:i];

					if ([line hasPrefix:tag]) {
						// Extract the text after the 'section' command, then prefix it with a nice header
						// text taken from g_taggedTagSections.
						// This tries to only extract the text inside a matching pair of braces '{' and '}'.
						// To see why, consider this example:
						//   \section*{Section {\bf headers} are important} \label{a-section-label}

						int braceCount = 0;
						unichar c;

						titleString = [line substringFromIndex: [tag length]];
						tag = [g_taggedTagSections objectAtIndex:i];

						// Next we scan for braces. Note that a section command could
						// span more than one line, have embedded comments etc.. We can't
						// cope with all these cases in a sensible fashion, though. If
						// the user really wants to shoot himself into the foot, let 'em
						// do it, just make sure to act nicely and fail gracefully...
						nameRange.location = 0;
						nameRange.length = [titleString length];
						for (i = 0; i < nameRange.length; ++i) {
							c = [titleString characterAtIndex:i];
							if (c == '{') {
								if (braceCount == 0)
									nameRange.location = i + 1;
								braceCount++;
							} else if (c == '}') {
								braceCount--;
								if (braceCount == 0)
									break;
							}
						}
						nameRange.length = i - nameRange.location;

						titleString = [titleString substringWithRange:nameRange];
						titleString = [tag stringByAppendingString: titleString];
						break;
					}
				}
			}
			// TODO: Hierarchical menus would be cool. This could be achieved
			// by assiging the tags a 'level', maybe based on their position
			// in the g_taggedTagSections array (and '%:' markers would have
			// level = infinity). Then, we keep a stack of items of a given
			// level, and append new items to a submenu on the last previous
			// item which had a lower level... So sections would be subitems
			// of chapters, etc.
			if (titleString) {
				// Add new menu item. We do *not* use addItemWithTitle since that would
				// overwrite any existing item with the same title.
				[tags addItemWithTitle: @""];
				newItem = [tags lastItem];
				[newItem setAction: @selector(doTag:)];
				[newItem setTarget: self];
				[newItem setTag: lineNumber];
				[newItem setTitle: titleString];
				[newItem setRepresentedObject: line];
			}
		}
	}

	tagLocation = myRange.location;
	tagLocationLine = lineNumber;
	if (tagLocation >= length)
	{
		[tagTimer invalidate];
		[tagTimer release];
		tagTimer = nil;
	}

}

- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	// FIXME/TODO: Implementing this delegate method but not its close relative
	// textView:shouldChangeTextInRanges:replacementStrings: (notice the plural-s)
	// effectively disables multi-selection mode on 10.4 (triggered by pressing Cmd),
	// and also the nifty block selection feature (which is triggererd by Alt). Of
	// course we already map Cmd-Clicking to something else anyway.
	// Still, at least block selections would be useful for our users. But until the rest
	// of the code is not aware of this possibility, we better keep this disabled.

	NSRange			matchRange;
	NSString		*textString;
	int				i, j, count, uchar, leftpar, rightpar;
	NSDate			*myDate;

	// Record the modified range (for the syntax coloring code).
	colorStart = affectedCharRange.location;
	colorEnd = colorStart + [replacementString length];

#if 1
// FIXME HACK: Always rebuild the tags menu when things change...
	tagLine = YES;
#else
	NSRange			tagRange;
	unsigned 		start, end, end1;

	//
	// Trigger an update of the tags menu, if necessary
	//
	tagRange = [replacementString rangeOfString:@"%:"];
	if (tagRange.length != 0)
		tagLine = YES;

	// added by S. Zenitani -- "\n" increments tagLocationLine
	tagRange = [replacementString rangeOfString:@"\n"];
	if (tagRange.length != 0)
		tagLine = YES;
	// end


	textString = [textView string];
	[textString getLineStart:&start end:&end contentsEnd:&end1 forRange:affectedCharRange];
	tagRange.location = start;
	tagRange.length = end - start;
	matchRange = [textString rangeOfString:@"%:" options:0 range:tagRange];
	if (matchRange.length != 0)
		tagLine = YES;

	// FIXME: The following check is silly. *Every* line contains a newline, so the check will
	// *always* succeed! And thus we regenerate the tags menu after each key press...
	// OTOH, just removing this will cause lots of bugs related to tagging: For example,
	// if the user adds a ":" after an existing "%", this code wouldn't notice that there's
	// now a "%:" on the line. To catch all cases, it is necessary to check for a "%:" in the
	// textStorage both before the replacement and also after it. Checking replacementString
	// is rather pointless in most cases.

	// for tagLocationLine (2) Zenitani
	matchRange = [textString rangeOfString:@"\n" options:0 range:tagRange];
	if (matchRange.length != 0)
		tagLine = YES;

	//
	// Update the list of sections in the tag menu, if enabled
	//
	if ([SUD boolForKey: TagSectionsKey]) {

		for (i = 0; i < [g_taggedTeXSections count]; ++i) {
			tagRange = [replacementString rangeOfString:[g_taggedTeXSections objectAtIndex:i]];
			if (tagRange.length != 0) {
				tagLine = YES;
				break;
			}
		}

		if (!tagLine) {

			textString = [textView string];
			[textString getLineStart:&start end:&end
						 contentsEnd:&end1 forRange:affectedCharRange];
			tagRange.location	= start;
			tagRange.length		= end - start;

			for (i = 0; i < [g_taggedTeXSections count]; ++i) {
				matchRange = [textString rangeOfString: [g_taggedTeXSections objectAtIndex:i] options:0 range:tagRange];
				if (matchRange.length != 0) {
					tagLine = YES;
					break;
				}
			}

		}
	}
#endif

	if (replacementString == nil)
		return YES;


	if ([replacementString length] != 1)
		return YES;
	rightpar = [replacementString characterAtIndex:0];

	if ([SUD boolForKey:ParensMatchingEnabledKey]) {
		if ((rightpar != '}') &&  (rightpar != ')') &&  (rightpar != ']'))
			return YES;

		if (rightpar == '}')
			leftpar = '{';
		else if (rightpar == ')')
			leftpar = '(';
		else
			leftpar = '[';

		textString = [textView string];
		i = affectedCharRange.location;
		j = 1;
		count = 1;


		/* modified Jan 26, 2001, so we don't search entire text */
		while ((i > 0) && (j < 5000)) {
			i--; j++;
			uchar = [textString characterAtIndex:i];
			if (uchar == rightpar)
				count++;
			else if (uchar == leftpar)
				count--;
			if (count == 0) {
				matchRange.location = i;
				matchRange.length = 1;
				/* koch: here 'affinity' and 'stillSelecting' are necessary,
					else the wrong range is selected. */
				[textView setSelectedRange: matchRange
								  affinity: NSSelectByCharacter stillSelecting: YES];

	// TODO / FIXME: Replace the brace highlighting below with something better. See Smultron:
	//   [layoutManager addTemporaryAttributes:[self highlightColour] forCharacterRange:NSMakeRange(cursorLocation, 1)];
	//   [self performSelector:@selector(resetBackgroundColour:) withObject:NSStringFromRange(NSMakeRange(cursorLocation, 1)) afterDelay:0.12];

				[textView display];
				myDate = [NSDate date];
				/* Koch: Jan 26, 2001: changed -0.15 to -0.075 to speed things up */
				while ([myDate timeIntervalSinceNow] > - 0.075);
				[textView setSelectedRange: affectedCharRange];
				
				break;
			}
		}
	}

	return YES;
}


#pragma mark Task errors

- (int) errorLineFor: (int)theError{
	if (theError < errorNumber)
		return errorLine[theError];
	else
		return -1;
}

- (int) totalErrors{
	return errorNumber;
}


- (void) doError: sender
{
	NSDocument		*myRoot;
	NSArray 		*wlist;
	NSEnumerator	*en;
	id			obj;
	BOOL		doError;
	int			myErrorNumber;
	int			myErrorLine;

	myRoot = nil;
	doError = NO;

	if (rootDocument != nil) {
		wlist = [NSApp orderedDocuments];
		en = [wlist objectEnumerator];
		while ((obj = [en nextObject])) {
			if (obj == rootDocument)
				myRoot = rootDocument;
		}
	}

	if (rootDocument == nil) {
		if (errorNumber > 0) {
			doError = YES;
			if (whichError >= errorNumber)
				whichError = 0;			// warning; main.tex could be closed in the middle of error processing
			myErrorLine = errorLine[whichError];
			whichError++;
			if (whichError >= errorNumber)
				whichError = 0;
		}
	} else {
		myErrorNumber = [rootDocument totalErrors];
		if (myErrorNumber > 0) {
			doError = YES;
			if (whichError >= myErrorNumber)
				whichError = 0;
			myErrorLine = [rootDocument errorLineFor: whichError];
			whichError++;
			if (whichError >= myErrorNumber)
				whichError = 0;
		}
	}


	if (!_externalEditor && fileIsTex && doError) {
		[textWindow makeKeyAndOrderFront: self];
		[self toLine: myErrorLine];
	}
}

- (void) toLine: (int) line
{
	int		i;
	NSString	*text;
	unsigned	start, end, irrelevant, stringlength;
	NSRange	myRange;

	if (line < 1) return;
	text = [textView string];
	stringlength = [text length];
	myRange.location = 0;
	myRange.length = 1;
	i = 1;
	while ((i <= line) && (myRange.location < stringlength)) {
		[text getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
		myRange.location = end;
		i++;
	}
	if (i == (line + 1)) {
		myRange.location = start;
		myRange.length = (end - start);
		[textView setSelectedRange: myRange];
		[textView scrollRangeToVisible: myRange];
	}

}

#pragma mark -

- (id) pdfView
{
	return pdfView;
}

- (id) pdfKitView
{
	return myPDFKitView;
}

- (id) pdfWindow
{
	return pdfWindow;
}

- (id) pdfKitWindow
{
	return pdfKitWindow;
}

- (id) textWindow
{
	return textWindow;
}

- (id) textView
{
	return textView;
}


- (TSDocumentType) documentType
{
	return _documentType;
}

- (NSPDFImageRep *) myTeXRep
{
	return texRep;
}

- (BOOL)fileIsTex
{
	return fileIsTex;
}

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	if (!fileIsTex) {
		if ([anItem action] == @selector(saveDocument:) ||
			[anItem action] == @selector(printSource:))
			return (_documentType == isOther);
		if ([anItem action] == @selector(doTex:) ||
			[anItem action] == @selector(doLatex:) ||
			[anItem action] == @selector(doBibtex:) ||
			[anItem action] == @selector(doIndex:) ||
			[anItem action] == @selector(doMetapost:) ||
			[anItem action] == @selector(doContext:))
			return NO;
		if ([anItem action] == @selector(printDocument:))
			return ((_documentType == isPDF) ||
					(_documentType == isJPG) ||
					(_documentType == isTIFF));
		if ([anItem action] == @selector(setProjectFile:))
			return NO;

	}

	// forsplit
	if ([anItem action] == @selector(splitWindow:)) {
		if (windowIsSplit)
			[anItem setState:NSOnState];
		else
			[anItem setState:NSOffState];
		return YES;
	}
	// end forsplit

	return [super validateMenuItem: anItem];
}


- (void)bringPdfWindowFront{
	NSString		*theSource;

	if (!_externalEditor) {
		theSource = [[self textView] string];
		if ([self checkMasterFile:theSource forTask:RootForSwitchWindow])
			return;
		if ([self checkRootFile_forTask:RootForSwitchWindow])
			return;
		//if ([self myTeXRep] != nil)
		if ([self fromKit])
			[[self pdfKitWindow] makeKeyAndOrderFront: self];
		}
}

// Explanation: When this document is the root document for a chapter of a project and the user switched to
// the document pdf window from the chapter window using Command-1, the Calling Window is that window. Thus
// command-1 will take us back to the calling text window. If the calling text window is closed, any document
// with that calling window will have its calling window reset to nil. When the calling window is nil, command-1
// takes us to the text window of the document, usually the Main source

- (NSWindow *)getCallingWindow
{
	return callingWindow;
}

- (void)setCallingWindow: (NSWindow *)thisWindow
{
	callingWindow = thisWindow;
}

- (void)setPdfSyncLine:(int)line
{
	pdfSyncLine = line;
}

- (void)setCharacterIndex:(unsigned int)index
{
	pdfCharacterIndex = index;
}

- (void)doPreviewSyncWithFilename:(NSString *)fileName andLine:(int)line andCharacterIndex:(unsigned int)index andTextView:(id)aTextView
{
	int             pdfPage;
	BOOL            found, synclineFound;
	unsigned        start, end, irrelevant, stringlength;
	NSRange         myRange;
	NSString        *syncInfo;
	NSFileManager   *fileManager;
	NSRange         searchResultRange, newRange;
	NSString        *keyLine;
	int             syncNumber, syncLine;
	BOOL            skipping;
	int             skipdepth;
	NSString        *expectedFileName, *expectedString;
	BOOL			result;

	int syncMethod = [SUD integerForKey:SyncMethodKey];
	if ((syncMethod == SEARCHONLY) || (syncMethod == SEARCHFIRST)) {
		result = [self doNewPreviewSyncWithFilename:fileName andLine:line andCharacterIndex:index andTextView:aTextView];
		if (result)
			return;
	}
	if (syncMethod == SEARCHONLY)
		return;
	// get .sync file
	fileManager = [NSFileManager defaultManager];
	NSString *fileName1 = [self fileName];
	NSString *infoFile = [[fileName1 stringByDeletingPathExtension] stringByAppendingPathExtension: @"pdfsync"];
	if (![fileManager fileExistsAtPath: infoFile])
		return;
	
/*
	// worry that the user has tex + ghostscript and the sync file is out of date
	// to do that, test the date of mydoc.pdf and mydoc.pdfsync
	NSString *pdfName = [[fileName stringByDeletingPathExtension] stringByAppendingString: @".pdf"];
	NSDictionary *fattrs = [fileManager fileAttributesAtPath: pdfName traverseLink:NO];
	pdfDate = [fattrs objectForKey:NSFileModificationDate];
	fattrs = [fileManager fileAttributesAtPath: infoFile traverseLink:NO];
	pdfsyncDate = [fattrs objectForKey:NSFileModificationDate];
	if ([pdfDate timeIntervalSince1970] > [pdfsyncDate timeIntervalSince1970])
		return;
*/

	// get the contents of the sync file as a string
	NS_DURING
		syncInfo = [NSString stringWithContentsOfFile:infoFile];
	NS_HANDLER
		return;
	NS_ENDHANDLER

	if (! syncInfo)
		return;

	// remove the first two lines
	myRange.location = 0;
	myRange.length = 1;
	NS_DURING
	[syncInfo getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
	NS_HANDLER
	return;
	NS_ENDHANDLER
	syncInfo = [syncInfo substringFromIndex: end];
	NS_DURING
	[syncInfo getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
	NS_HANDLER
	return;
	NS_ENDHANDLER
	syncInfo = [syncInfo substringFromIndex: end];

	 // if fileName != nil, then find "(filename" in syncInfo and replace syncInfo by everything
	// after this line until the matching ")"

	if (fileName != nil) {
		NSString *initialPart = [[[self fileName] stringByStandardizingPath] stringByDeletingLastPathComponent]; //get root complete path, minus root name
		initialPart = [initialPart stringByAppendingString:@"/"];
		myRange = [fileName rangeOfString: initialPart options:NSCaseInsensitiveSearch]; //see if this forms the first part of the source file's path
		if ((myRange.location == 0) && (myRange.length <= [fileName length])) {
			expectedFileName = [fileName substringFromIndex: myRange.length]; //and remove it, so we have a relative path from root
			expectedFileName = [expectedFileName stringByDeletingPathExtension];
			expectedString = @"(";
			expectedString = [expectedString stringByAppendingString:expectedFileName];
		} else
			return;
		
		myRange = [syncInfo rangeOfString: expectedString];
		
		if (myRange.location == NSNotFound) {
			expectedString = @"(./";
			expectedString = [expectedString stringByAppendingString:expectedFileName];
			myRange = [syncInfo rangeOfString: expectedString];
			if (myRange.location == NSNotFound)
				return;
		}
		
		NS_DURING
			[syncInfo getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
		NS_HANDLER
			return;
		NS_ENDHANDLER
		syncInfo = [syncInfo substringFromIndex: end];
		
		// now search for matching ')'
		
		myRange.location = 0;
		myRange.length = 1;
		skipping = NO;
		skipdepth = 0;
		found = NO;
		while (!found && (myRange.location < stringlength)) {
			NS_DURING
				[syncInfo getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
			NS_HANDLER
				return;
			NS_ENDHANDLER
			if (skipping) {
				if ([syncInfo characterAtIndex: start] == ')') {
					skipdepth--;
					if (skipdepth == 0)
						skipping = NO;
				}
			} else if ([syncInfo characterAtIndex: start] == '(') {
				skipping = YES;
				skipdepth++;
			} else if ([syncInfo characterAtIndex: start] == ')')
				found = YES;
			myRange.location = end;
		}
		
		if (!found)
			return;
		
		myRange.length = myRange.location;
		myRange.location = 0;
		syncInfo = [syncInfo substringWithRange: myRange];
	}


	// Search through syncInfo to find the first "l" line greater than or equal
	// to our line; set syncNumber to the "pdfsync"-number of this entry
	// In this search, ignore any "(" and all lines between that and the matching
	// ")"

	stringlength = [syncInfo length];

	myRange.location = 0;
	myRange.length = 1;
	synclineFound = NO;
	skipping = NO;
	skipdepth = 0;
	while (myRange.location < stringlength) {
		NS_DURING
			[syncInfo getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
		NS_HANDLER
			return;
		NS_ENDHANDLER
		if (skipping) {
			if ([syncInfo characterAtIndex: start] == ')') {
				skipdepth--;
				if (skipdepth == 0)
					skipping = NO;
			}
		} else if ([syncInfo characterAtIndex: start] == '(') {
			skipping = YES;
			skipdepth++;
		} else if ([syncInfo characterAtIndex: start] == 'l') {
			newRange.location = start;
			newRange.length = end - start;
			keyLine = [syncInfo substringWithRange: newRange];
			// NSLog(keyLine);
			
			searchResultRange = [keyLine rangeOfCharacterFromSet: [NSCharacterSet decimalDigitCharacterSet]];
			if (searchResultRange.location == NSNotFound)
				return;
			newRange.location = searchResultRange.location;
			newRange.length = [keyLine length] - newRange.location;
			keyLine = [keyLine substringWithRange: newRange];
			//  NSLog(keyLine);
			// NSLog(@" ");
			syncNumber = [keyLine intValue]; // number of entry
			
			searchResultRange = [keyLine rangeOfString: @" "];
			if (searchResultRange.location == NSNotFound)
				return;
			newRange.location = searchResultRange.location;
			newRange.length = [keyLine length] - newRange.location;
			keyLine = [keyLine substringWithRange: newRange];
			searchResultRange = [keyLine rangeOfCharacterFromSet: [NSCharacterSet decimalDigitCharacterSet]];
			if (searchResultRange.location == NSNotFound)
				return;
			newRange.location = searchResultRange.location;
			newRange.length = [keyLine length] - newRange.location;
			keyLine = [keyLine substringWithRange: newRange];
			syncLine = [keyLine intValue]; //line number of entry
			synclineFound = YES;
			if (syncLine >= line)
				break;
		}
		myRange.location = end;
	}

	
	if (!synclineFound)
		return;
	
	
	// now syncNumber is the entry number of the item we want. We must next find the
	// entry "p syncNumber * *". This number will follow a page number, "s pageNumber"
	// and this pageNumber is the number we want
	
	// the technique is to go through the .pdfsync file line by line. If a line starts with "s" we
	// record that page number. If a line starts with "p number *  *" or "p* number * *" we see if number = syncNumber.
	// If so, then the current page number is the one we want. If we don't find it, we just return
	
	// But if the entry comes at the start of the file, it will not follow a page number.
	// So we must search for the first page in the syncInfo file and then back up one page
	
	// Debugging has caused me to discover that some "l" lines in the pdfsync file have no matching
	// "p" lines. So this code starts with an "l" line with a given syncNumber, and then iterates
	// the search 20 times with higher and higher syncNumbers before giving up
	
	NS_DURING
		syncInfo = [NSString stringWithContentsOfFile:infoFile];
	NS_HANDLER
		return;
	NS_ENDHANDLER
	
	// remove the first two lines
	myRange.location = 0;
	myRange.length = 1;
	NS_DURING
		[syncInfo getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
	NS_HANDLER
		return;
	NS_ENDHANDLER
	syncInfo = [syncInfo substringFromIndex: end];
	NS_DURING
		[syncInfo getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
	NS_HANDLER
		return;
	NS_ENDHANDLER
	syncInfo = [syncInfo substringFromIndex: end];
	
	
	found = NO;
	int i = 0;
	while (!found && (i < 20)) {
		i++;
		pdfPage = -1;
		stringlength = [syncInfo length];
		myRange.location = 0;
		myRange.length = 1;
		line = 0;
		found = NO;
		while ((! found) && (myRange.location < stringlength)) {
			NS_DURING
				[syncInfo getLineStart: &start end: &end contentsEnd: &irrelevant forRange: myRange];
			NS_HANDLER
				return;
			NS_ENDHANDLER
			if ([syncInfo characterAtIndex: start] == 's') {
				newRange.location = start + 1;
				newRange.length = end - start - 1;
				NS_DURING
					keyLine = [syncInfo substringWithRange: newRange];
				NS_HANDLER
					return;
				NS_ENDHANDLER
				pdfPage = [keyLine intValue];
				pdfPage--;
			} else if ([syncInfo characterAtIndex:start] == 'p') {
				if ([syncInfo characterAtIndex:(start + 1)] == ' ') {
					newRange.location = start + 1;
					newRange.length = end - start - 1;
				} else {
					newRange.location = start + 2;
					newRange.length = end - start - 2;
				}
				NS_DURING
					keyLine = [syncInfo substringWithRange: newRange];
				NS_HANDLER
					return;
				NS_ENDHANDLER
				if ([keyLine intValue] == syncNumber)
					found = YES;
			}
			myRange.location = end;
		}
		syncNumber++;
	}

	if (!found)
		return;

   // [pdfView displayPage:pdfPage];
   // [pdfWindow makeKeyAndOrderFront: self];
   pdfPage++;
   [myPDFKitView goToKitPageNumber: pdfPage];
   [pdfKitWindow makeKeyAndOrderFront: self];

}


- (BOOL)doNewPreviewSyncWithFilename:(NSString *)fileName andLine:(int)line andCharacterIndex:(unsigned int)index andTextView:(id)aTextView
{
	NSString			*theText, *searchText;
	unsigned int		theIndex;
	int					startIndex, endIndex, testIndex;
	NSRange				theRange;
	unsigned int		searchWindow, length;
	int					numberOfTests;
	NSArray				*searchResults;
	PDFSelection		*mySelection;
	NSArray				*myPages;
	PDFPage				*thePage;
	NSRect				selectionBounds;

// I now try a new method. We will pick a string of length 10, first surrounding the text where
// the click occurred. If it isn't found, we'll back up 5 characters at a time for 20 times, repeating
// the search. If that fails, we'll go forward 5 characters at a time for 20 times, repeating the
// search. If we still get nothing, we'll declare a failure.

	searchWindow = 10;

	theText = [aTextView string];
	length = [theText length];

	theIndex = index;
	testIndex = theIndex;
	numberOfTests = 1;

	while ((numberOfTests < 20) && (testIndex >= 0)) {

		// get surrounding letters back and forward
		if (testIndex >= searchWindow)
			startIndex = testIndex - searchWindow;
		else
			startIndex = 0;
		if (testIndex < (length - (searchWindow + 1)))
			endIndex = testIndex + searchWindow;
		else
			endIndex = length - 1;

		theRange.location = startIndex;
		theRange.length = endIndex - startIndex;
		searchText = [theText substringWithRange: theRange];
		testIndex = testIndex - 5;
		numberOfTests++;

	// search for this in the pdf
		searchResults = [[myPDFKitView document] findString: searchText withOptions: NSCaseInsensitiveSearch];
		if ([searchResults count] == 1) {
			mySelection = [searchResults objectAtIndex:0];
			myPages = [mySelection pages];
			if ([myPages count] == 0)
				return NO;
			thePage = [myPages objectAtIndex:0];
			selectionBounds = [mySelection boundsForPage: thePage];
			[myPDFKitView setIndexForMark: [[myPDFKitView document] indexForPage: thePage]];
			[myPDFKitView setBoundsForMark: selectionBounds];
			[myPDFKitView setDrawMark: YES];
			[myPDFKitView goToPage: thePage];
			[myPDFKitView display];
			[pdfKitWindow makeKeyAndOrderFront:self];
			return YES;
		}
	}

	testIndex = theIndex + 5;
	numberOfTests = 2;
	while ((numberOfTests < 20) && (testIndex < length)) {

		// get surrounding letters back and forward
		if (testIndex > searchWindow)
			startIndex = testIndex - searchWindow;
		else
			startIndex = 0;
		if (testIndex < (length - (searchWindow + 1)))
			endIndex = testIndex + searchWindow;
		else
			endIndex = length - 1;

		theRange.location = startIndex;
		theRange.length = endIndex - startIndex;
		searchText = [theText substringWithRange: theRange];
		testIndex = testIndex + 5;
		numberOfTests++;

	// search for this in the pdf
		searchResults = [[myPDFKitView document] findString: searchText withOptions: NSCaseInsensitiveSearch];
		if ([searchResults count] == 1) {
			mySelection = [searchResults objectAtIndex:0];
			myPages = [mySelection pages];
			if ([myPages count] == 0)
				return NO;
			thePage = [myPages objectAtIndex:0];
			selectionBounds = [mySelection boundsForPage: thePage];
			[myPDFKitView setIndexForMark: [[myPDFKitView document] indexForPage: thePage]];
			[myPDFKitView setBoundsForMark: selectionBounds];
			[myPDFKitView setDrawMark: YES];
			[myPDFKitView goToPage: thePage];
			[myPDFKitView display];
			return YES;
		}
	}

	return NO;

}

//=============================================================================
// nofification methods
//=============================================================================

// Reload the PDF file associated with this document (if any). This method is called
// at regular intervals by _pdfRefreshTimer.
- (void) refreshPDFWindow:(NSTimer *)timer
{
	NSString		*pdfPath;
	NSDate			*newDate;
	NSDictionary	*myAttributes;
	BOOL			front;

	pdfPath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
	
	// Check whether a PDF version of this document exists 
	if ([[NSFileManager defaultManager] fileExistsAtPath: pdfPath] && [[NSFileManager defaultManager] isReadableFileAtPath: pdfPath]) {
		// The PDF exists. Now check whether its modification date changed.
		myAttributes = [[NSFileManager defaultManager] fileAttributesAtPath: pdfPath traverseLink:NO];
		newDate = [myAttributes objectForKey:NSFileModificationDate];
		if ((_pdfLastModDate == nil) || ([newDate compare:_pdfLastModDate] == NSOrderedDescending) || _pdfRefreshTryAgain) {
			
			_pdfRefreshTryAgain = NO;
			[newDate retain];
			[_pdfLastModDate release];
			_pdfLastModDate = newDate;
			
			front = [SUD boolForKey: BringPdfFrontOnAutomaticUpdateKey];
			[self refreshPDFAndBringFront: front];
		}
	}
}


// the next routine is used by applescript; the previous routine should be
// rewritten to use this code
- (void)refreshPDFAndBringFront:(BOOL)front
{
	NSPDFImageRep	*tempRep;
	NSString		*pdfPath;

	pdfPath = [[[self fileName] stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];

	if ([[NSFileManager defaultManager] fileExistsAtPath: pdfPath]) {
		tempRep = [NSPDFImageRep imageRepWithContentsOfFile: pdfPath];
		if ((tempRep == nil) || ([tempRep pageCount] == 0)) {
			// Loading the PDF failed for some reason (e.g. maybe it is still being written),
			// so we should retry loading it a in a bit.
			_pdfRefreshTryAgain = YES;
		} else {
			PDFfromKit = YES;
			[myPDFKitView reShowWithPath: pdfPath];
			[pdfKitWindow setRepresentedFilename: pdfPath];
			[pdfKitWindow setTitle: [pdfPath lastPathComponent]];
			if (front) {
				[pdfKitWindow makeKeyAndOrderFront: self];
			}
		}
	}
}

// the next routine is used by applescript
- (void)refreshTEXT
{
	NSString		*textPath;
	NSRange			myRange;

	textPath = [self fileName];

	if ([[NSFileManager defaultManager] fileExistsAtPath: textPath]) {

		NSData *myData = [NSData dataWithContentsOfFile:textPath];
		NSString *theString = [[NSString alloc] initWithData:myData encoding:_encoding];

		if (theString != nil) {
			[textView setString: theString];
			[theString release];
			if (fileIsTex) {
				if (windowIsSplit)
					[self splitWindow: self];
				[self setupTags];
				[self colorizeAll];
			}

			myRange.location = 0;
			myRange.length = 0;
			[textView setSelectedRange: myRange];
			[textWindow setInitialFirstResponder: textView];
			[textWindow makeFirstResponder: textView];
		}
	}
}


- (void) checkPrefClose: (NSNotification *)aNotification
{
	int	finalResult;

	if (([aNotification object] == projectPanel) ||
		([aNotification object] == requestWindow) ||
		([aNotification object] == linePanel) ||
		([aNotification object] == printRequestPanel)) {
		finalResult = myPrefResult;
		if (finalResult == 2) finalResult = 0;
		[NSApp stopModalWithCode: finalResult];
	}
}

- (void) writeTexOutput: (NSNotification *)aNotification
{
	NSString		*newOutput, *numberOutput, *searchString, *tempString, *detexString;
	NSData		*myData, *detexData;
	NSRange		myRange, lineRange, searchRange;
	int			error;
	int                 lineCount, wordCount, charCount;
	unsigned int	myLength;
	unsigned		start, end, irrelevant;
	NSStringEncoding	theEncoding;
	BOOL                result;

	NSFileHandle *myFileHandle = [aNotification object];
	if (myFileHandle == readHandle) {
		myData = [[aNotification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"];
		if ([myData length]) {
			theEncoding = [[TSEncodingSupport sharedInstance] defaultEncoding];
			newOutput = [[NSString alloc] initWithData: myData encoding: theEncoding];
			
			// 1.35 (F) fix --- suggested by Kino-san
			if (newOutput == nil) {
				newOutput = [[NSString alloc] initWithData: myData encoding: NSMacOSRomanStringEncoding];
			}
			// 1.35 (F) end
			
			if ((makeError) && ([newOutput length] > 2) && (errorNumber < NUMBEROFERRORS)) {
				myLength = [newOutput length];
				searchString = @"l.";
				lineRange.location = 0;
				lineRange.length = 1;
				while (lineRange.location < myLength) {
					[newOutput getLineStart: &start end: &end contentsEnd: &irrelevant forRange: lineRange];
					lineRange.location = end;
					searchRange.location = start;
					searchRange.length = end - start;
					tempString = [newOutput substringWithRange: searchRange];
					myRange = [tempString rangeOfString: searchString];
					if ((myRange.location = 1) && (myRange.length > 0)) {
						numberOutput = [tempString substringFromIndex:(myRange.location + 1)];
						error = [numberOutput intValue];
						if ((error > 0) && (errorNumber < NUMBEROFERRORS)) {
							errorLine[errorNumber] = error;
							errorNumber++;
							[outputWindow makeKeyAndOrderFront: self];
						}
					}
				}
			}
			
			typesetStart = YES;
			
			[outputText replaceCharactersInRange: [outputText selectedRange] withString: newOutput];
			[outputText scrollRangeToVisible: [outputText selectedRange]];
			[newOutput release];
			[readHandle readInBackgroundAndNotify];
		}
	} else if (myFileHandle == detexHandle) {
		detexData = [[aNotification userInfo] objectForKey:@"NSFileHandleNotificationDataItem"];
		if ([detexData length]) {
			detexString = [[NSString alloc] initWithData: detexData encoding: NSMacOSRomanStringEncoding];
			NSScanner *myScanner = [NSScanner scannerWithString:detexString];
			result = [myScanner scanInt: &lineCount];
			if (result)
				result = [myScanner scanInt: &wordCount];
			if (result)
				result = [myScanner scanInt: &charCount];
			if (result) {
				NSNumber *lineNumber = [NSNumber numberWithInt:lineCount];
				NSNumber *wordNumber = [NSNumber numberWithInt:wordCount];
				NSNumber *charNumber = [NSNumber numberWithInt:charCount];
				[[statisticsForm cellAtIndex:0] setObjectValue:[wordNumber stringValue]];
				[[statisticsForm cellAtIndex:1] setObjectValue:[lineNumber stringValue]];
				[[statisticsForm cellAtIndex:2] setObjectValue:[charNumber stringValue]];
			}
		}
	}
}

// Code by Nicolas Ojeda Bar, modified by Martin Heusse
- (int) textViewCountTabs: (NSTextView *) aTextView andSpaces: (int *) spaces
{
	int startLocation = [aTextView selectedRange].location - 1, tabCount = 0;
	unichar currentChar;

	if (startLocation < 0)
		return 0;

	while ((currentChar = [[aTextView string] characterAtIndex: startLocation]) != '\n') {

		if (currentChar != '\t' && currentChar != ' ') {
			tabCount = 0;
			*spaces = 0;
		} else {
			if (currentChar == '\t')
				++ tabCount;

			if (currentChar == ' ' && tabCount == 0)
				++ *spaces;
		}
		startLocation --;
		if (startLocation < 0)
			break;
	}

	return tabCount;
}

// Code by Nicolas Ojeda Bar, slightly modified by Martin Heusse
- (BOOL) textView: (NSTextView *) aTextView doCommandBySelector: (SEL)
	aSelector
{

	if (aSelector == @selector (insertNewline:)) {
		int n, indentTab, indentSpace = 0;

		indentTab = [self textViewCountTabs: textView andSpaces: &indentSpace];
		[aTextView insertNewline: self];

		for (n = 0; n < indentTab; ++ n)
			[aTextView insertText: @"\t"];
		for (n = 0; n < indentSpace; ++ n)
			[aTextView insertText: @" "];

		return YES;
	}

	return NO;
}

- (void)doCompletion:(NSNotification *)notification
{
	if ([[self textWindow] isMainWindow]) {
		[self insertSpecial: [notification object]
					undoKey: NSLocalizedString(@"LaTeX Panel", @"LaTeX Panel")];
	}
}

- (void)doMatrix:(NSNotification *)notification
{
	if ([[self textWindow] isMainWindow]) {
		[self insertSpecial: [notification object]
					undoKey: NSLocalizedString(@"Matrix Panel", @"Matrix Panel")];
	}
}


- (void) changeAutoComplete: sender
{
	doAutoComplete = ! doAutoComplete;
	[self fixAutoMenu];
}

- (void) flipShowSync: sender
{
	int theState = [syncBox state];
	[syncBox setState: (1 - theState)];
	[myPDFKitView display];
}


- (void) fixMacroMenu
{
	g_macroType = whichEngine;
	[[TSMacroMenuController sharedInstance] reloadMacrosOnly];
	[self resetMacroButton: nil];
}

- (void) fixMacroMenuForWindowChange
{
	if (g_macroType != whichEngine) {
		g_macroType = whichEngine;
		[[TSMacroMenuController sharedInstance] reloadMacrosOnly];
	}
}

- (void) fixAutoMenu
{
	  [autoCompleteButton setState: doAutoComplete];
	  NSEnumerator* enumerator = [[[textWindow toolbar] items] objectEnumerator];
	  id anObject;
	  while ((anObject = [enumerator nextObject])) {
		if ([[anObject itemIdentifier] isEqual: @"AutoComplete"]) {
			if (doAutoComplete)
//                [[[[anObject menuFormRepresentation] submenu] itemAtIndex:0] setTitle: NSLocalizedString(@"Turn off", @"Turn off")];
				  [[[[anObject menuFormRepresentation] submenu] itemAtIndex:0] setState: NSOnState];
			else
//                [[[[anObject menuFormRepresentation] submenu] itemAtIndex:0] setTitle: NSLocalizedString(@"Turn on", @"Turn on")];
				  [[[[anObject menuFormRepresentation] submenu] itemAtIndex:0] setState: NSOffState];
			}
		}
}

- (void)changePrefAutoComplete:(NSNotification *)notification
{
	doAutoComplete = [SUD boolForKey:AutoCompleteEnabledKey];
	[autoCompleteButton setState: doAutoComplete];
}



// The code below is copied directly from Apple's TextEdit Example

static NSArray *tabStopArrayForFontAndTabWidth(NSFont *font, unsigned tabWidth) {
	static NSMutableArray *array = nil;
	static float currentWidthOfTab = -1;
	float charWidth;
	float widthOfTab;
	unsigned i;

	if ([font glyphIsEncoded:(NSGlyph)' ']) {
		charWidth = [font advancementForGlyph:(NSGlyph)' '].width;
	} else {
		charWidth = [font maximumAdvancement].width;
	}
	widthOfTab = (charWidth * tabWidth);

	if (!array) {
		array = [[NSMutableArray allocWithZone:NULL] initWithCapacity:100];
	}

	if (widthOfTab != currentWidthOfTab) {
		[array removeAllObjects];
		for (i = 1; i <= 100; i++) {
			NSTextTab *tab = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:widthOfTab * i];
			[array addObject:tab];
			[tab release];
		}
		currentWidthOfTab = widthOfTab;
	}

	return array;
}

// The code below is a modification of code from Apple's TextEdit example

- (void)fixUpTabs {
	BOOL			empty = NO;
	NSRange			myRange, theRange;
	unsigned			tabWidth;
	NSParagraphStyle 		*paraStyle;
	NSMutableParagraphStyle 	*newStyle;
	NSFont			*font = nil;
	NSData			*fontData;
	
	NSString *string = [_textStorage string];
	
	if ([SUD boolForKey:SaveDocumentFontKey] == NO) {
		font = [NSFont userFontOfSize:12.0];
	} else {
		fontData = [SUD objectForKey:DocumentFontKey];
		if (fontData != nil) {
			font = [NSUnarchiver unarchiveObjectWithData:fontData];
			[textView setFont:font];
		} else
			font = [NSFont userFontOfSize:12.0];
	}
	
	// I cannot figure out how to set the tabs if there is no text, so in that
	// case I insert text and later remove it; Koch, 11/28/2002
	if ([string length] == 0) {
		empty = YES;
		myRange.location = 0; myRange.length = 0;
		// empty files have a space, but the cursor is at the start
		[_textStorage replaceCharactersInRange: myRange withString:@" "];
	}
	
	tabWidth = [SUD integerForKey: tabsKey];
	
	NSArray *desiredTabStops = tabStopArrayForFontAndTabWidth(font, tabWidth);
	
	paraStyle = [NSParagraphStyle defaultParagraphStyle];
	newStyle = [paraStyle mutableCopyWithZone:[_textStorage zone]];
	[newStyle setTabStops:desiredTabStops];
	theRange.location = 0; theRange.length = [string length];
	[_textStorage addAttribute:NSParagraphStyleAttributeName value:newStyle range: theRange];
	[newStyle release];
	
	if (empty) {
		myRange.location = 0; myRange.length = 1;
		//        [[textView textStorage] replaceCharactersInRange: myRange withString:@""]; //was "\b"
	}
	
	[textView setFont:font];
	
}

// added by mitsu --(J) Typeset command, (D) Tags and (H) Macro
- (int)whichEngine
{
	return whichEngine;
}

- (void)resetTagsMenu:(NSNotification *)notification
{
	[self setupTags];
}

- (void)resetMacroButton:(NSNotification *)notification
{
	if (g_macroType == whichEngine) {
		[[TSMacroMenuController sharedInstance] addItemsToPopupButton: macroButton];
		[[TSMacroMenuController sharedInstance] addItemsToPopupButton: macroButtonEE];
	}
}
// end addition



// added by John A. Nairn
// check for linked files.
//	If %SourceDoc, typeset from there instead
//	If \input commands, save those documents if opened and changed

- (void)showInfo: (id)sender
{
	NSString *filePath, *fileInfo, *infoTitle, *infoText;
	NSDictionary *fileAttrs;
	NSNumber *fsize;
	NSDate *creationDate, *modificationDate;

	filePath = [self fileName];
	if (filePath &&
		(fileAttrs = [[NSFileManager defaultManager] fileAttributesAtPath:filePath traverseLink:YES])) {
		fsize = [fileAttrs objectForKey:NSFileSize];
		creationDate = [fileAttrs objectForKey:NSFileCreationDate];
		modificationDate = [fileAttrs objectForKey:NSFileModificationDate];
		fileInfo = [NSString stringWithFormat:
					NSLocalizedString(@"Path: %@\nFile size: %d bytes\nCreation date: %@\nModification date: %@", @"File Info"),
		filePath,
		fsize?[fsize intValue]:0,
		creationDate?[creationDate description]:@"",
		modificationDate?[modificationDate description]:@""];
	} else
		fileInfo = @"Not saved";

	infoTitle = [NSString stringWithFormat:
					NSLocalizedString(@"Info: %@", @"Info: %@"),
					[self displayName]];
	infoText = [NSString stringWithFormat:
					NSLocalizedString(@"%@\n\nCharacters: %d", @"InfoText"),
					fileInfo,
					[[textView string] length]];
	NSRunAlertPanel(infoTitle, infoText, nil, nil, nil);
}

- (BOOL)isDoAutoCompleteEnabled
{
	return doAutoComplete;
}

// to be used in LaTeX Panel/Macro/...
- (void)insertSpecial:(NSString *)theString undoKey:(NSString *)key
{
	NSRange		oldRange, searchRange;
	NSMutableString	*stringBuf;
	NSString *oldString, *newString;
	
	// mutably copy the replacement text
	stringBuf = [NSMutableString stringWithString: theString];
	
	// Determine the curent selection range and text
	oldRange = [textView selectedRange];
	oldString = [[textView string] substringWithRange: oldRange];
	
	// Substitute all occurances of #SEL# with the original text
	[stringBuf replaceOccurrencesOfString: @"#SEL#" withString: oldString
								  options: 0 range: NSMakeRange(0, [stringBuf length])];
	
	// Now search for #INS#, remember its position, and remove it. We will
	// Later position the insertion mark there. Defaults to end of string.
	searchRange = [stringBuf rangeOfString:@"#INS#" options:NSLiteralSearch];
	if (searchRange.location != NSNotFound)
		[stringBuf replaceCharactersInRange:searchRange withString:@""];
	
	// Filtering for Japanese
	newString = [self filterBackslashes:stringBuf];
	
	// Replace the text--
	// Follow Apple's guideline "Subclassing NSTextView/Notifying About Changes to the Text"
	// in "Text System User Interface Layer".
	// This means bracketing each batch of potential changes with
	// "shouldChangeTextInRange:replacementString:" and "didChangeText" messages
	if ([textView shouldChangeTextInRange:oldRange replacementString:newString]) {
		[textView replaceCharactersInRange:oldRange withString:newString];
		[textView didChangeText];
		
		if (key)
			[[textView undoManager] setActionName: key];
		
		// Place insertion mark
		if (searchRange.location != NSNotFound) {
			searchRange.location += oldRange.location;
			searchRange.length = 0;
			[textView setSelectedRange:searchRange];
		}
	}
}


// to be used in AutoCompletion
- (void)insertSpecialNonStandard:(NSString *)theString undoKey:(NSString *)key
{
	NSRange		oldRange, searchRange;
	NSMutableString	*stringBuf;
	NSString *oldString, *newString;
	unsigned from, to;

	// mutably copy the replacement text
	stringBuf = [NSMutableString stringWithString: theString];

	// Determine the curent selection range and text
	oldRange = [textView selectedRange];
	oldString = [[textView string] substringWithRange: oldRange];

	// Substitute all occurances of #SEL# with the original text
	[stringBuf replaceOccurrencesOfString: @"#SEL#" withString: oldString
					options: 0 range: NSMakeRange(0, [stringBuf length])];

	// Now search for #INS#, remember its position, and remove it. We will
	// Later position the insertion mark there. Defaults to end of string.
	searchRange = [stringBuf rangeOfString:@"#INS#" options:NSLiteralSearch];
	if (searchRange.location != NSNotFound)
		[stringBuf replaceCharactersInRange:searchRange withString:@""];

	// Filtering for Japanese
	newString = [self filterBackslashes:stringBuf];

	// Insert the new text
	[textView replaceCharactersInRange:oldRange withString:newString];

	// register undo
	[self registerUndoWithString:oldString location:oldRange.location
						length:[newString length] key:key];
	//[textView registerUndoWithString:oldString location:oldRange.location
	//					length:[newString length] key:key];

	from = oldRange.location;
	to = from + [newString length];
	[self fixColor:from :to];
	[self setupTags];

	// Place insertion mark
	if (searchRange.location != NSNotFound) {
		searchRange.location += oldRange.location;
		searchRange.length = 0;
		[textView setSelectedRange:searchRange];
	}
}


- (void)registerUndoWithString:(NSString *)oldString location:(unsigned)oldLocation
	length: (unsigned)newLength key:(NSString *)key
{
	NSUndoManager	*myManager;
	NSMutableDictionary	*myDictionary;
	NSNumber		*theLocation, *theLength;

	// Create & register an undo action
	myManager = [textView undoManager];
	myDictionary = [NSMutableDictionary dictionaryWithCapacity: 4];
	theLocation = [NSNumber numberWithUnsignedInt: oldLocation];
	theLength = [NSNumber numberWithUnsignedInt: newLength];
	[myDictionary setObject: oldString forKey: @"oldString"];
	[myDictionary setObject: theLocation forKey: @"oldLocation"];
	[myDictionary setObject: theLength forKey: @"oldLength"];
	[myDictionary setObject: key forKey: @"undoKey"];
	[myManager registerUndoWithTarget:self selector:@selector(undoSpecial:) object: myDictionary];
	[myManager setActionName:key];
}

- (void)undoSpecial:(id)theDictionary
{
	NSRange		undoRange;
	NSString	*oldString, *newString, *undoKey;
	unsigned	from, to;

	// Retrieve undo info
	undoRange.location = [[theDictionary objectForKey: @"oldLocation"] unsignedIntValue];
	undoRange.length = [[theDictionary objectForKey: @"oldLength"] unsignedIntValue];
	newString = [theDictionary objectForKey: @"oldString"];
	undoKey = [theDictionary objectForKey: @"undoKey"];

	if (undoRange.location+undoRange.length > [[textView string] length])
		return; // something wrong happened

	oldString = [[textView string] substringWithRange: undoRange];

	// Replace the text
	[textView replaceCharactersInRange:undoRange withString:newString];
	[self registerUndoWithString:oldString location:undoRange.location
						length:[newString length] key:undoKey];

	from = undoRange.location;
	to = from + [newString length];
	[self fixColor:from :to];
	[self setupTags];
}

// end mitsu 1.29

// mitsu 1.29 (T3)
- (void) doCommentOrIndent: (id)sender
{
	NSString		*text, *oldString;
	NSRange		myRange, modifyRange, tempRange, oldRange;
	unsigned		start, end, end1, changeStart, changeEnd;
	int			theChar;
	
	text = [textView string];
	myRange = [textView selectedRange];
	// get old string for Undo
	[text getLineStart:&start end:&end contentsEnd:&end1 forRange:myRange];
	oldRange.location = start;
	oldRange.length = end1 - start;
	oldString = [[textView string] substringWithRange: oldRange];
	
	changeStart = start;
	changeEnd = start;
	end = start;
	while (end < (myRange.location + myRange.length)) {
		modifyRange.location = end;
		modifyRange.length = 0;
		[text getLineStart:&start end:&end contentsEnd:&end1 forRange:modifyRange];
		changeEnd = end1;
		if ((end1 - start) > 0)
			theChar = [text characterAtIndex: start];
		
		switch ([sender tag]) {
			case Mcomment:
				tempRange.location = start;
				tempRange.length = 0;
				[textView replaceCharactersInRange:tempRange withString:@"%"];
				myRange.length++;
				oldRange.length++;
				changeEnd++;
				end++;
				break;
				
			case Muncomment:
				if ((end1 != start) && (theChar == '%')) {
					tempRange.location = start;
					tempRange.length = 1;
					[textView replaceCharactersInRange:tempRange withString:@""];
					myRange.length--;
					oldRange.length--;
					changeEnd--;
					end--;
				}
				break;
				
			case Mindent:
				tempRange.location = start;
				tempRange.length = 0;
				[textView replaceCharactersInRange:tempRange withString:@"\t"];
				myRange.length++;
				oldRange.length++;
				changeEnd++;
				end++;
				break;
				
			case Munindent:
			 	if ((end1 != start) && (theChar == '\t')) {
					tempRange.location = start;
					tempRange.length = 1;
					[textView replaceCharactersInRange:tempRange withString:@""];
					myRange.length--;
					oldRange.length--;
					changeEnd--;
					end--;
				}
				break;
				
		}
		end++;
	}
	[self fixColor:changeStart :changeEnd];
	tempRange.location = changeStart;
	tempRange.length = (changeEnd - changeStart);
	[textView setSelectedRange: tempRange];
	
	[self registerUndoWithString:oldString location:oldRange.location
						  length:oldRange.length key: [sender title]];
}

// end mitsu 1.29

- (void)newTag: (id)sender
{
	NSString		*text;
	NSRange		myRange, tempRange;
	unsigned		start, end, end1, changeStart, changeEnd;

	text = [textView string];
	myRange = [textView selectedRange];
	// get old string for Undo
	[text getLineStart:&start end:&end contentsEnd:&end1 forRange:myRange];
	tempRange.location = start;
	tempRange.length = 0;
	[textView replaceCharactersInRange:tempRange withString:@"%:\n"];
	changeStart = tempRange.location;
	changeEnd = changeStart + 2;
	[self fixColor:changeStart :changeEnd];
	[self registerUndoWithString:@"" location:tempRange.location
						length:3 key: @"New Tag"];
	tempRange.location = start+2;
	tempRange.length = 0;
	[textView setSelectedRange: tempRange];
}

- (void)trashAUXFiles: sender
{
	NSString        *theSource;
	
	aggressiveTrash = NO;
	if ((GetCurrentKeyModifiers() & optionKey) != 0)
		aggressiveTrash = YES;
	if ([SUD boolForKey:AggressiveTrashAUXKey])
		aggressiveTrash = YES;
	
	if (! fileIsTex)
		return;
	
	if (! [SUD boolForKey:AggressiveTrashAUXKey]) {
		[self trashAUX];
	} else {
		theSource = [[self textView] string];
		if ([self checkMasterFile:theSource forTask:RootForTrashAUX])
			return;
		if ([self fileName] == nil)
			return;
		if ([self checkRootFile_forTask:RootForTrashAUX])
			return;
		[self trashAUX];
	}
}


- (void)trashAUX
{
	NSString		*path, *path1, *path2;
	NSString		*extension;
	NSString        *fileName, *objectFileName;
	NSMutableArray  *pathsToBeMoved, *fileToBeMoved;
	id              anObject, stringObject;
	int             myTag;
	BOOL            doMove, isOneOfOther;
	NSEnumerator    *enumerator;
	NSArray         *otherExtensions;
	NSEnumerator    *arrayEnumerator;
	
	if (! fileIsTex)
		return;
	
	if ([self fileName] == nil)
		return;
	
	path = [[self fileName] stringByDeletingLastPathComponent];
	fileName = [[[self fileName] lastPathComponent] stringByDeletingPathExtension];
	NSFileManager *myFileManager = [NSFileManager defaultManager];
	
	if (aggressiveTrash) {
		enumerator = [myFileManager enumeratorAtPath: path];
		fileToBeMoved = [NSMutableArray arrayWithCapacity: 1];
		[fileToBeMoved addObject:@""];
	} else
		enumerator = [[myFileManager directoryContentsAtPath: path] objectEnumerator];
	
	pathsToBeMoved = [NSMutableArray arrayWithCapacity: 20];
	
	
	
	while ((anObject = [enumerator nextObject])) {
		doMove = YES;
		if (! aggressiveTrash) {
			objectFileName = [anObject stringByDeletingPathExtension];
			if (! [objectFileName isEqualToString:fileName])
				doMove = NO;
		}
		
		isOneOfOther = NO;
		
		extension = [anObject pathExtension];
		
		otherExtensions = [SUD stringArrayForKey: OtherTrashExtensionsKey];
		arrayEnumerator = [otherExtensions objectEnumerator];
		while ((stringObject = [arrayEnumerator nextObject])) {
			if ([extension isEqualToString:stringObject])
				isOneOfOther = YES;
		}
		
		if (doMove && (isOneOfOther ||
					   ([extension isEqualToString:@"aux"] ||
						[extension isEqualToString:@"blg"] ||
						[extension isEqualToString:@"brf"] ||
						[extension isEqualToString:@"glo"] ||
						[extension isEqualToString:@"idx"] ||
						[extension isEqualToString:@"ilg"] ||
						[extension isEqualToString:@"ind"] ||
						[extension isEqualToString:@"loa"] ||
						[extension isEqualToString:@"lof"] ||
						[extension isEqualToString:@"log"] ||
						[extension isEqualToString:@"lot"] ||
						[extension isEqualToString:@"mtc"] ||
						[extension isEqualToString:@"mlf"] ||
						[extension isEqualToString:@"out"] ||
						[extension isEqualToString:@"ttt"] ||
						[extension isEqualToString:@"fff"] ||
						[extension isEqualToString:@"ent"] ||
						[extension isEqualToString:@"css"] ||
						[extension isEqualToString:@"idv"] ||
						[extension isEqualToString:@"wrm"] ||
						[extension isEqualToString:@"4ct"] ||
						[extension isEqualToString:@"4tc"] ||
						[extension isEqualToString:@"lg"] ||
						[extension isEqualToString:@"xref"] ||
						[extension isEqualToString:@"pdfsync"] ||
						[extension isEqualToString:@"toc"])))
			[pathsToBeMoved addObject: anObject];
		
	}
	
	if (aggressiveTrash) {
		
		enumerator = [pathsToBeMoved objectEnumerator];
		while ((anObject = [enumerator nextObject])) {
			path1 = [path stringByAppendingPathComponent: anObject];
			path2 = [path1 stringByDeletingLastPathComponent];
			[fileToBeMoved replaceObjectAtIndex:0 withObject: [anObject lastPathComponent]];
			[[NSWorkspace sharedWorkspace]
					performFileOperation:NSWorkspaceRecycleOperation source:path2 destination:nil files:fileToBeMoved tag:&myTag];
		}
		
	} else {
		[[NSWorkspace sharedWorkspace]
			performFileOperation:NSWorkspaceRecycleOperation source:path destination:nil files:pathsToBeMoved tag:&myTag];
	}
	
}

- (void) showSyncMarks: sender
{
   [myPDFKitView display];
}

- (BOOL)syncState
{
	if ([syncBox state] == 1)
		return YES;
	else
		return NO;
}

- (BOOL)fromKit
{
	return PDFfromKit;
}

- (void)doBackForward:(id)sender
{
	switch ([sender selectedSegment]) {
		case 0:	[[self pdfKitView] goBack:sender];
			break;

		case 1: [[self pdfKitView] goForward:sender];
			break;
	}
}

- (void)doForward:(id)sender
{
	[[self pdfKitView] goForward:sender];
}

- (void)doBack:(id)sender
{
	[[self pdfKitView] goBack:sender];
}

- (id) mousemodeMenu
{
	return mouseModeMenuKit;
}

- (id) mousemodeMatrix
{
	return mouseModeMatrixKK;
}

- (BOOL) textSelectionYellow
{
	return textSelectionYellow;
}

- (void) setTextSelectionYellow:(BOOL)value
{
	textSelectionYellow = value;
}


- (NSString *)filterBackslashes:(NSString *)aString
{
	if (g_shouldFilter == kMacJapaneseFilterMode)
		return filterBackslashToYen(aString);
	else
		return aString;
}

@end
