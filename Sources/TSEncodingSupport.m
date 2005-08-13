/* TeXShop - TeX editor for Mac OS 
 * Copyright (C) 2000-2005 Richard Koch
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * $Id$
 *
 * Created by Mitsuhiro Shishikura on Fri Dec 13 2002.
 *
 */

#import "TSEncodingSupport.h"
#import "TSDocument.h" // mitsu 1.29 (P)
#import "globals.h"
#define SUD [NSUserDefaults standardUserDefaults]

static NSString *yenString = nil;

@implementation TSEncodingSupport

// Pointer to the TSEncodingSupport singleton
static id sharedEncodingSupport = nil;

// We pair CFStringEncoding with custom names
typedef struct {
	CFStringEncoding	encoding;
	NSString			*name;
} TSEncoding;

// List of the supported encodings.
static const TSEncoding _availableEncodings[] = {
	{ kCFStringEncodingMacRoman,			@"MacOSRoman" },
	{ kCFStringEncodingISOLatin1,			@"IsoLatin" },
	{ kCFStringEncodingISOLatin2,			@"IsoLatin2" },
	{ kCFStringEncodingISOLatin5,			@"IsoLatin5" },
	{ kCFStringEncodingMacJapanese,			@"MacJapanese" },
	{ kCFStringEncodingDOSJapanese,			@"DOSJapanese" },
	{ kCFStringEncodingShiftJIS_X0213_00,	@"SJIS_X0213" },
	{ kCFStringEncodingEUC_JP,				@"EUC_JP" },
	{ kCFStringEncodingISO_2022_JP,			@"JISJapanese" },
	{ kCFStringEncodingMacKorean,			@"MacKorean" },
	{ kCFStringEncodingUTF8,				@"UTF-8 Unicode" },
	{ kCFStringEncodingUnicode,				@"Standard Unicode" },
	{ kCFStringEncodingMacCyrillic,			@"Mac Cyrillic" },
	{ kCFStringEncodingDOSCyrillic,			@"DOS Cyrillic" },
	{ kCFStringEncodingDOSRussian,			@"DOS Russian" },
	{ kCFStringEncodingWindowsCyrillic,		@"Windows Cyrillic" },
	{ kCFStringEncodingKOI8_R,				@"KOI8_R" },
	{ kCFStringEncodingMacChineseTrad,		@"Mac Chinese Traditional" },
	{ kCFStringEncodingMacChineseSimp,		@"Mac Chinese Simplified" },
	{ kCFStringEncodingDOSChineseTrad,		@"DOS Chinese Traditional" },
	{ kCFStringEncodingDOSChineseSimplif,	@"DOS Chinese Simplified" },
	{ kCFStringEncodingGBK_95,				@"GBK" },
	{ kCFStringEncodingGB_2312_80,			@"GB 2312" },
	{ kCFStringEncodingGB_18030_2000,		@"GB 18030" },
};

//------------------------------------------------------------------------------
+ (id)sharedInstance 
//------------------------------------------------------------------------------
{
    if (sharedEncodingSupport == nil) 
	{
#if 1
		// FIXME/HACK: Some test code follows
		int i;
		NSStringEncoding enc;
		for (i = 0; i < ARRAYSIZE(_availableEncodings); ++i) {
			enc = CFStringConvertEncodingToNSStringEncoding(_availableEncodings[i].encoding);
			NSLog(@"0x%04x: '%@' / '%@' / '%@'", (short)enc,
				[NSString localizedNameOfStringEncoding:enc],
				(NSString *)CFStringGetNameOfEncoding(CFStringConvertNSStringEncodingToEncoding(enc)),
				NSLocalizedStringFromTable(_availableEncodings[i].name, @"Encodings", @"Fetch localized encoding name")
				);
		}
#endif
        sharedEncodingSupport = [[TSEncodingSupport alloc] init];
    }
    return sharedEncodingSupport;
}

//------------------------------------------------------------------------------
- (id)init 
//------------------------------------------------------------------------------
{
    if (sharedEncodingSupport) 
	{
        [super dealloc];
	}
	else
	{
		sharedEncodingSupport = [super init];
		
		g_shouldFilter = kNoFilterMode;
		// initialize yen string
		unichar yenChar = 0x00a5;
		yenString = [[NSString stringWithCharacters: &yenChar length:1] retain];
		
		// register for encoding changed notification
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(encodingChanged:) 
				name:@"EncodingChangedNotification" object:nil];

// Here preferences are set for the state of the pasteboard conversion facility, which is only used with Japanese encoding.
		if ([SUD objectForKey: @"ConvertToBackslash"] == nil)
			[SUD setBool: NO forKey: @"ConvertToBackslash"];
		if ([SUD objectForKey: @"ConvertToYen"] == nil)
			[SUD setBool: YES forKey: @"ConvertToYen"];
	}
	return sharedEncodingSupport;
}

//------------------------------------------------------------------------------
- (void)dealloc
//------------------------------------------------------------------------------
{
	if (self != sharedEncodingSupport) [super dealloc];	// Don't free our shared instance
}

// Delegate method for text fields
//------------------------------------------------------------------------------
- (void)controlTextDidChange:(NSNotification *)note
//------------------------------------------------------------------------------
{
	NSText *fieldEditor = [[note userInfo] objectForKey: @"NSFieldEditor"];
	if (!fieldEditor)
		return;
	NSString *oldString = [fieldEditor string];
	NSRange selectedRange = [fieldEditor selectedRange];
	NSString *newString;
	
	if (g_shouldFilter == kMacJapaneseFilterMode)
	{
		newString = filterBackslashToYen(oldString);
		[fieldEditor setString: newString];
		[fieldEditor setSelectedRange: selectedRange];
	}
	else if (g_shouldFilter == kOtherJapaneseFilterMode)
	{
		newString = filterYenToBackslash(oldString);
		[fieldEditor setString: newString];
		[fieldEditor setSelectedRange: selectedRange];
	}		
}


// set up g_texChar, g_taggedTeXSections and menu item for tex character conversion
//------------------------------------------------------------------------------
- (void)setupForEncoding
//------------------------------------------------------------------------------
{
	NSString *currentEncoding;
	NSMenu *editMenu;
	id <NSMenuItem> item;
	NSMutableString *menuTitle;
	TSDocument *theDoc;
	
	currentEncoding = [SUD stringForKey:EncodingKey];
        
	editMenu = [[[NSApp mainMenu] itemWithTitle:NSLocalizedString(@"Edit", @"Edit")] submenu];
	if (editMenu)
	{
		int i = [editMenu indexOfItemWithTarget:self andAction:@selector(toggleTeXCharConversion:)];
		if (i >= 0)	// remove menu item
		{
			[editMenu removeItemAtIndex: i];
			if ([[editMenu itemAtIndex: i-1] isSeparatorItem])
				[editMenu removeItemAtIndex: i-1];
		}
	}

	if ([currentEncoding isEqualToString:@"MacJapanese"] ||
            [currentEncoding isEqualToString:@"SJIS_X0213"] )
	{
		g_texChar = 0x00a5; // yen
		[g_taggedTeXSections release];
		g_taggedTeXSections = [[NSArray alloc] initWithObjects:
							filterBackslashToYen(@"\\chapter"),
							filterBackslashToYen(@"\\section"),
							filterBackslashToYen(@"\\subsection"),
							filterBackslashToYen(@"\\subsubsection"),
							nil];
                // mitsu 1.29 (P)
		
		// If the command completion list already exists, and we are about to change the filter mode:
		// Update the command completion list to match the new filter mode.
		if (g_shouldFilter != kMacJapaneseFilterMode && g_commandCompletionList)
		{
			[g_commandCompletionList replaceOccurrencesOfString: @"\\" withString: yenString
						options: 0 range: NSMakeRange(0, [g_commandCompletionList length])];
			theDoc = [[NSDocumentController sharedDocumentController] 
				documentForFileName: [CommandCompletionPathKey stringByStandardizingPath]];
			if (theDoc)
				[[theDoc textView] setString: filterBackslashToYen([[theDoc textView] string])];
		}
		// end mitsu 1.29
		g_shouldFilter = kMacJapaneseFilterMode;
		// set up menu item
		if (editMenu)
		{
			[editMenu addItem: [NSMenuItem separatorItem]];
			menuTitle = [NSMutableString stringWithString:
                        NSLocalizedString(@"Convert \\yen to \\ in Pasteboard", @"Convert \\yen to \\ in Pasteboard")];
			[menuTitle replaceOccurrencesOfString: @"\\yen" withString: yenString
						options: 0 range: NSMakeRange(0, [menuTitle length])];
			item = [editMenu addItemWithTitle: menuTitle 
					action:@selector(toggleTeXCharConversion:) keyEquivalent: @""];
			[item setTarget: self];
			[item setState: [SUD boolForKey: @"ConvertToBackslash"]?NSOnState:NSOffState];		
		}
	}
	else 
	{
		g_texChar = 0x005c; // backslash
		[g_taggedTeXSections release];
		g_taggedTeXSections = [[NSArray alloc] initWithObjects:
							@"\\chapter",
							@"\\section",
							@"\\subsection",
							@"\\subsubsection",
							nil];
                // mitsu 1.29 (P)
		// If the command completion list already exists, and we are about to change the filter mode:
		// Update the command completion list to match the new filter mode.
		if (g_shouldFilter == kMacJapaneseFilterMode && g_commandCompletionList)
		{
			[g_commandCompletionList replaceOccurrencesOfString: yenString withString: @"\\"
						options: 0 range: NSMakeRange(0, [g_commandCompletionList length])];
			theDoc = [[NSDocumentController sharedDocumentController] 
				documentForFileName: [CommandCompletionPathKey stringByStandardizingPath]];
			if (theDoc)
				[[theDoc textView] setString: filterYenToBackslash([[theDoc textView] string])];
		}
		// end mitsu 1.29
	
		if ([currentEncoding isEqualToString:@"DOSJapanese"] ||
				[currentEncoding isEqualToString:@"EUC_JP"] || 
				[currentEncoding isEqualToString:@"JISJapanese"])
		{
			g_shouldFilter = kOtherJapaneseFilterMode;
			// set up menu item
			if (editMenu)
			{
				[editMenu addItem: [NSMenuItem separatorItem]];
				menuTitle = [NSMutableString stringWithString:
                                NSLocalizedString(@"Convert \\ to \\yen in Pasteboard", @"Convert \\ to \\yen in Pasteboard")]; 
				[menuTitle replaceOccurrencesOfString: @"\\yen" withString: yenString
							options: 0 range: NSMakeRange(0, [menuTitle length])];
				item = [editMenu addItemWithTitle: menuTitle 
						action:@selector(toggleTeXCharConversion:) keyEquivalent: @""];
				[item setTarget: self];
				[item setState: [SUD boolForKey: @"ConvertToYen"]?NSOnState:NSOffState];	
			}
		}
		else
		{
			g_shouldFilter = kNoFilterMode;
		}
	}
}

// called when the encoding is changed in Preferences dialog
//------------------------------------------------------------------------------
- (void)encodingChanged: (NSNotification *)note
//------------------------------------------------------------------------------
{
	[self setupForEncoding];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"ResetTagsMenuNotification" object:self];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"DocumentSyntaxColorNotification" object:self];
	//[[NSNotificationCenter defaultCenter] postNotificationName:@"ReloadMacrosNotification" object:self];
}


// action for "Convert * to * in Pasteboard"
//------------------------------------------------------------------------------
- (IBAction)toggleTeXCharConversion:(id)sender
//------------------------------------------------------------------------------
{
	NSString *currentEncoding;
	NSString *theKey;
	
	currentEncoding = [SUD stringForKey:EncodingKey];
	if ([currentEncoding isEqualToString:@"MacJapanese"] ||
            [currentEncoding isEqualToString:@"SJIS_X0213"])
		theKey = @"ConvertToBackslash";
	else if ([currentEncoding isEqualToString:@"DOSJapanese"] ||
		[currentEncoding isEqualToString:@"EUC_JP"] || 
		[currentEncoding isEqualToString:@"JISJapanese"])
		theKey = @"ConvertToYen";
	else
		return;	
	[SUD setBool: ![SUD boolForKey: theKey]  forKey: theKey];
	[SUD synchronize];
	[(NSMenuItem *)sender setState: [SUD boolForKey: theKey]?NSOnState:NSOffState];
}

// NOTE: To add new encodings, it is only necessary to add items to the next
// three items, and add items to the preference nib and the document nib
// and the menu nib; these additional items need appropriate tags.

- (int)tagForEncodingPreference
{
    NSString	*currentEncoding;
    
    currentEncoding = [SUD stringForKey:EncodingKey];
    return [self tagForEncoding: currentEncoding];
}

- (int)tagForEncoding: (NSString *)encoding
{

    if ([encoding isEqualToString:@"MacOSRoman"])
        return 0;
    else if ([encoding isEqualToString:@"IsoLatin"])
        return 1;
    else if ([encoding isEqualToString:@"IsoLatin2"])
        return 2;
    else if ([encoding isEqualToString:@"IsoLatin5"])
        return 3;
    else if ([encoding isEqualToString:@"MacJapanese"])
        return 4;
     // S. Zenitani Dec 13, 2002:
    else if ([encoding isEqualToString:@"DOSJapanese"])
        return 5;
    else if ([encoding isEqualToString:@"SJIS_X0213"])
        return 6;
    else if ([encoding isEqualToString:@"EUC_JP"])
        return 7;
    else if ([encoding isEqualToString:@"JISJapanese"])
        return 8;
    else if ([encoding isEqualToString:@"MacKorean"])
        return 9;
    // --- end
    else if ([encoding isEqualToString:@"UTF-8 Unicode"])
        return 10;
    else if ([encoding isEqualToString:@"Standard Unicode"])
        return 11;
     else if ([encoding isEqualToString:@"Mac Cyrillic"])
        return 12;
     else if ([encoding isEqualToString:@"DOS Cyrillic"])
        return 13;
     else if ([encoding isEqualToString:@"DOS Russian"])
        return 14;
     else if ([encoding isEqualToString:@"Windows Cyrillic"])
        return 15;
     else if ([encoding isEqualToString:@"KOI8_R"])
        return 16;
     else if ([encoding isEqualToString:@"Mac Chinese Traditional"])
        return 17;
     else if ([encoding isEqualToString:@"Mac Chinese Simplified"])
        return 18;
    else if ([encoding isEqualToString:@"DOS Chinese Traditional"])
        return 19;
    else if ([encoding isEqualToString:@"DOS Chinese Simplified"])
        return 20;
    else if ([encoding isEqualToString:@"GBK"])
        return 21;
    else if ([encoding isEqualToString:@"GB 2312"])
        return 22;
    else if ([encoding isEqualToString:@"GB 18030"])
        return 23;
    

     else 
        return 0;
}

- (NSString *)encodingForTag: (int)tag
{
    NSString *value;
    
    switch (tag) {
        case 0: value = [NSString stringWithString:@"MacOSRoman"];
                break;
        
        case 1: value = [NSString stringWithString:@"IsoLatin"];
                break;
                
        case 2: value = [NSString stringWithString:@"IsoLatin2"];
                break;
                
        case 3: value = [NSString stringWithString:@"IsoLatin5"];
                break;
                
        case 4: value = [NSString stringWithString:@"MacJapanese"];
                break;
                
        // S. Zenitani Dec 13, 2002:
        case 5: value = [NSString stringWithString:@"DOSJapanese"];
                break;
                
        case 6: value = [NSString stringWithString:@"SJIS_X0213"];
                break;
                
        case 7: value = [NSString stringWithString:@"EUC_JP"];
                break;
                
        // Mitsuhiro Shishikura Jan 4, 2003:
        case 8: value = [NSString stringWithString:@"JISJapanese"];
                break;
                
        case 9: value = [NSString stringWithString:@"MacKorean"];
                break;
        
        case 10: value = [NSString stringWithString:@"UTF-8 Unicode"];
                break;
                
        case 11: value = [NSString stringWithString:@"Standard Unicode"];
                break;
                
        case 12: value = [NSString stringWithString:@"Mac Cyrillic"];
                break;
                
        case 13: value = [NSString stringWithString:@"DOS Cyrillic"];
                break;
                
        case 14: value = [NSString stringWithString:@"DOS Russian"];
                break;
                
        case 15: value = [NSString stringWithString:@"Windows Cyrillic"];
                break;
                
        case 16: value = [NSString stringWithString:@"KOI8_R"];
                break;
                
        case 17: value = [NSString stringWithString:@"Mac Chinese Traditional"];
                break;
        
        case 18: value = [NSString stringWithString:@"Mac Chinese Simplified"];
                break;
        
        case 19: value = [NSString stringWithString:@"DOS Chinese Traditional"];
                break;
        
        case 20: value = [NSString stringWithString:@"DOS Chinese Simplified"];
                break;
        
        case 21: value = [NSString stringWithString:@"GBK"];
                break;
        
        case 22: value = [NSString stringWithString:@"GB 2312"];
                break;
        
        case 23: value = [NSString stringWithString:@"GB 18030"];
                break;
        
                
        default: value = [NSString stringWithString:@"MacOSRoman"];
                break;
        }
        
        [value retain];
        return value;
}

- (NSStringEncoding)stringEncodingForTag: (int)encoding
{
    NSStringEncoding	theEncoding;
    
    switch (encoding) {

        case 0: theEncoding =  NSMacOSRomanStringEncoding;
                break;
        
        case 1: theEncoding =  NSISOLatin1StringEncoding;
                break;
                
        case 2: theEncoding =  NSISOLatin2StringEncoding;
                break;
                
        case 3: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISOLatin5);
                break;
                
        case 4: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese);
                break;
                
        // S. Zenitani Dec 13, 2002:
        case 5: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSJapanese);
                break;
                
        case 6: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingShiftJIS_X0213_00);
                break;
                
        case 7: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingEUC_JP);
                break;
                
        // Mitsuhiro Shishikura Jan 4, 2003:
        case 8: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP);
                break;
                
        case 9: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacKorean);
                break;
        
        case 10: theEncoding =  NSUTF8StringEncoding;
                break;
                
        case 11: theEncoding =  NSUnicodeStringEncoding;
                break;
                
        case 12: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacCyrillic);
                 break;
                
        case 13: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSCyrillic);
                 break;
                
        case 14: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSRussian);
                 break;
                
        case 15: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingWindowsCyrillic);
                 break;
                
        case 16: theEncoding =  CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingKOI8_R);
                break;
                
        case 17: theEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacChineseTrad);
                break;
        
        case 18: theEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacChineseSimp);
                break;
        
        case 19: theEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSChineseTrad);
                break;
       
        case 20: theEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSChineseSimplif);
                break;
       
        case 21: theEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGBK_95);
                break;
       
        case 22: theEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_2312_80);
                break;
       
        case 23: theEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingGB_18030_2000);
                break;
                
        default: theEncoding =  NSMacOSRomanStringEncoding;
                 break;
        }
        
    return theEncoding;
}

- (NSString *)keyForStringEncoding: (NSStringEncoding)encoding {
	int i;
	for (i = 0; i < ARRAYSIZE(_availableEncodings); ++i) {
		if (_availableEncodings[i].encoding == encoding)
			return _availableEncodings[i].name;
	}
	// If the encoding is unknown, use the first encoding in our list (MacOS Roman).
	return _availableEncodings[0].name;
}

- (NSStringEncoding)encodingForKey: (NSString *)key {
	int i;
	for (i = 0; i < ARRAYSIZE(_availableEncodings); ++i) {
		if ([key isEqualToString:_availableEncodings[i].name])
			return _availableEncodings[i].encoding;
	}
	// If the encoding is unknown, use the first encoding in our list (MacOS Roman).
	return _availableEncodings[0].encoding;
}


- (void)addEncodingsToMenu: (NSMenu *)menu
{
#if 1
	id <NSMenuItem> item;
	NSString *name;
	NSStringEncoding enc;
	int i;

	for (i = 0; i < ARRAYSIZE(_availableEncodings); ++i) {
		enc = CFStringConvertEncodingToNSStringEncoding(_availableEncodings[i].encoding);
		name = NSLocalizedStringFromTable(_availableEncodings[i].name, @"Encodings", @"Fetch localized encoding name");

		item = [[[NSMenuItem alloc] initWithTitle: name action:0 keyEquivalent:@""] autorelease];
		//[item setTarget: self];
		[item setTag: enc];
		[menu addItem: item];
	}
#endif
}

// zenitani and itoh, 1.35 (C) -- support for utf.sty
- (BOOL)ptexUtfOutputCheck: (NSString *)dataString withEncoding: (int)tag;
{
    NSString *currentEncoding;
    currentEncoding = [self encodingForTag:tag];

    if( ( [currentEncoding isEqualToString:@"MacJapanese"] ||
          [currentEncoding isEqualToString:@"DOSJapanese"] ||
          [currentEncoding isEqualToString:@"JISJapanese"] ||
          [currentEncoding isEqualToString:@"EUC_JP"] ) &&
        ![dataString canBeConvertedToEncoding: //[self stringEncodingForTag: tag]] ){
            CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP) ] ){
        return YES;
    }else if( [currentEncoding isEqualToString:@"SJIS_X0213"] &&
        ![dataString canBeConvertedToEncoding:
            CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingShiftJIS_X0213_00) ] ){
        return YES;
    }else{
        return NO;
    }
}

- (NSData *)ptexUtfOutput: (NSTextView *)dataView withEncoding: (int)tag;
{
    NSString *dataString = [dataView string];
    NSMutableString *utfString, *newString = [NSMutableString string];
    NSRange charRange, aCIDRange;
    NSString *subString;
    NSGlyphInfo *aGlyph;
    NSStringEncoding checkEncoding;
    unsigned startl, endl, end;

    if( [[self encodingForTag:tag] isEqualToString:@"SJIS_X0213"] ){
        checkEncoding = [self stringEncodingForTag: tag];
    }else{
        checkEncoding = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingISO_2022_JP);
    }

    charRange = NSMakeRange(0,1);
    endl = 0;
    while( charRange.location < [dataString length] ){
        if( charRange.location == endl ){
            [dataString getLineStart:&startl end:&endl contentsEnd:&end forRange:charRange];
//            NSLog( @"%d %d %d", startl, end, endl);
        }
//        NSLog( @"%d %d", charRange.length, charRange.location);
        charRange = [dataString rangeOfComposedCharacterSequenceAtIndex: charRange.location];
//        NSLog( @"%d %d", charRange.length, charRange.location);
        subString = [dataString substringWithRange: charRange];

        if( ![subString canBeConvertedToEncoding: checkEncoding] ){
            aGlyph = [[dataView textStorage] attribute:NSGlyphInfoAttributeName
                        atIndex:charRange.location effectiveRange:&aCIDRange];
            if( aGlyph ){
                // from rtf2tex (1.35)
/*                switch([aGlyph characterCollection]){
		case NSAdobeCNS1CharacterCollection:
                    utfString = [NSMutableString stringWithFormat:@"%cCIDC{%d}",
                                    g_texChar, [aGlyph characterIdentifier]];
                    break;
		case NSAdobeGB1CharacterCollection:
                    utfString = [NSMutableString stringWithFormat:@"%cCIDT{%d}",
                                    g_texChar, [aGlyph characterIdentifier]];
                    break;
		case NSAdobeKorea1CharacterCollection:
                    utfString = [NSMutableString stringWithFormat:@"%cCIDK{%d}",
                                    g_texChar, [aGlyph characterIdentifier]];
                    break;
		case NSAdobeJapan1CharacterCollection:
		case NSAdobeJapan2CharacterCollection:*/
                    utfString = [NSMutableString stringWithFormat:@"%CCID{%d}",
                                    g_texChar, [aGlyph characterIdentifier]];
/*                    break;
		case NSIdentityMappingCharacterCollection:
                default:
                    utfString = [NSMutableString stringWithFormat:@"?"];
                    break;
                }*/
            }else if( charRange.length > 1 ){
                NSLayoutManager *aLayout = [dataView layoutManager];
                utfString = [NSMutableString stringWithFormat:@"%CCID{%d}", g_texChar,
                    [aLayout glyphAtIndex:charRange.location]];
            // 0x2014,0x2015 fix (reported by Kino-san)
            }else if( ![[self encodingForTag:tag] isEqualToString:@"SJIS_X0213"] &&
                        [subString characterAtIndex: 0] == 0x2015 ){
                utfString = [NSMutableString stringWithFormat:@"%C", 0x2014];
            }else{
                utfString = [NSMutableString stringWithFormat:@"%CUTF{%04X}",
                    g_texChar, [subString characterAtIndex: 0]];
            }
            if( ( charRange.location + charRange.length ) == end ){
                [utfString appendString: @"%"];
            }
            [newString appendString: utfString];
        }else{
            [newString appendString: subString];
        }
        charRange.location += charRange.length;
        charRange.length = 1;
    }
    return [newString dataUsingEncoding:[self stringEncodingForTag:tag] allowLossyConversion:YES];
}
// end 1.35 (C)


@end

// replace backslashes by yens
NSMutableString *filterBackslashToYen(NSString *aString)
{
	NSMutableString *newString = [NSMutableString stringWithString: aString];
	[newString replaceOccurrencesOfString: @"\\" withString: yenString
						options: 0 range: NSMakeRange(0, [newString length])];
	return newString;
}

// replace yens by backslashes
NSMutableString *filterYenToBackslash(NSString *aString)
{
	NSMutableString *newString = [NSMutableString stringWithString: aString];
	[newString replaceOccurrencesOfString: yenString withString: @"\\"
						options: 0 range: NSMakeRange(0, [newString length])];
	return newString;
}

