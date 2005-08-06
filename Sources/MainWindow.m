/* TeXShop - TeX editor for Mac OS 
 * Copyright (C) 2000-2005 Richard Koch
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * $Id$
 *
 * Originally part of MyDocument. Broken out by dirk on Tue Jan 09 2001.
 *
 */

#import <AppKit/AppKit.h>
#import "MainWindow.h"
#import "MyDocument.h" // for the definition of isTeX (move this to a separate file!!)
#import "globals.h"

#define SUD [NSUserDefaults standardUserDefaults]


@implementation MainWindow : NSWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask backing:(NSBackingStoreType)backingType defer:(BOOL)flag
{
    id  result;
    result = [super initWithContentRect:contentRect styleMask:styleMask backing:backingType defer:flag];
    float alpha = [SUD floatForKey: SourceWindowAlphaKey];
    if (alpha < 0.999)
         [self setAlphaValue:alpha];
    return result;
}


- (void) becomeMainWindow
{
    [super becomeMainWindow];
    [myDocument fixMacroMenuForWindowChange];
}

// added by mitsu --(H) Macro menu; used to detect the document from a window
- (MyDocument *)document
{
	return myDocument;
}
// end addition


- (void)makeKeyAndOrderFront:(id)sender;
{
   if (
   (! [myDocument externalEditor]) &&
    (([myDocument imageType] == isTeX) || ([myDocument imageType] == isOther))
    )
        [super makeKeyAndOrderFront: sender];
    [myDocument tryBadEncodingDialog:self];
}

/*
- (void)sendEvent:(NSEvent *)theEvent
{
    
    if (([theEvent type] == NSKeyDown) && ([theEvent modifierFlags] & NSControlKeyMask))
    if ([[theEvent charactersIgnoringModifiers] isEqualToString:@"1"]) {
            if (([myDocument imageType] == isTeX) && ([myDocument myTeXRep] != nil))
                [[myDocument pdfWindow] makeKeyAndOrderFront: self];
            return;
            }
    [super sendEvent: theEvent];
}
*/

- (void)associatedWindow:(id)sender;
{
//  if (([myDocument imageType] == isTeX) && ([myDocument myTeXRep] != nil))
//                [[myDocument pdfWindow] makeKeyAndOrderFront: self];
    if ([myDocument imageType] == isTeX) {
        [myDocument bringPdfWindowFront];
        }
}

- (void) doChooseMethod: sender;
{
    [myDocument doChooseMethod: sender];
}

// forsplit
- (BOOL)makeFirstResponder:(NSResponder *)aResponder
{
    BOOL	result;
    
    result = [super makeFirstResponder:aResponder];
    if (result && [[aResponder className] isEqualTo:@"MyTextView"]) {
        [myDocument setTextView:aResponder];
        }
    return result;
}
// end forsplit

- (void)close;
{
    [[NSNotificationCenter defaultCenter] removeObserver:[myDocument pdfView]]; // this fixes a bug; the application crashed when closing
    // the last window in multi-page mode; investigation shows that the
    // myPDFView "wasScrolled" method was called from the notification center before dealloc, but after other items in the window
    // were released
    NSArray *myDocuments = [[NSDocumentController sharedDocumentController] documents];
    if (myDocuments != nil) {
        NSEnumerator *enumerator = [myDocuments objectEnumerator];
        id anObject;
        while (anObject = [enumerator nextObject]) {
            if ([anObject getCallingWindow] == self)
                [anObject setCallingWindow: nil];
            }
        }
    [super close];
}

@end
