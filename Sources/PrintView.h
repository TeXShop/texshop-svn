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

#import <AppKit/NSView.h>

@interface PrintView : NSView 
{
    NSPDFImageRep	*myRep;
}
    
- (PrintView *) initWithRep: (NSPDFImageRep *) aRep;
- (BOOL) knowsPageRange:(NSRangePointer)range;
@end
