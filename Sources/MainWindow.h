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

#import <AppKit/NSWindow.h>
#import "MyDocument.h"


@interface MainWindow : NSWindow 
{
    MyDocument	*myDocument;
}

// added by mitsu --(H) Macro menu; used to detect the document from a window
- (MyDocument *)document;
// end addition
- (void) doChooseMethod: sender;
- (void) makeKeyAndOrderFront:(id)sender;
- (void) becomeMainWindow;
//- (void) sendEvent:(NSEvent *)theEvent;
- (void) associatedWindow:(id)sender;
// forsplit
- (BOOL)makeFirstResponder:(NSResponder *)aResponder;
- (void)close;
// end forsplit
@end
