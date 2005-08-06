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
 */

#import <Cocoa/Cocoa.h>
#import "MyDocument.h"

@interface MyTextView : NSTextView
{
    MyDocument		*document; 
}

- (NSRange)selectionRangeForProposedRange:(NSRange)proposedSelRange granularity:(NSSelectionGranularity)granularity;

// mitsu 1.29 (T2-4) added
- (void)setDocument: (MyDocument *)doc;
- (void)registerForCommandCompletion: (id)sender;
// end mitsu 1.29
- (NSString *)getDragnDropMacroString: (NSString *)fileExt; // zenitani 1.33
- (NSString *)readSourceFromEquationEditorPDF: (NSString *)filePath; // zenitani 1.33(2)
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent;
- (NSString *)resolveAlias: (NSString *)path;
@end
