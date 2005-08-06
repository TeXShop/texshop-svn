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

#import <AppKit/AppKit.h>
#import "PrintBitmapView.h"

@implementation PrintBitmapView : NSView

- (PrintBitmapView *) initWithBitmapRep: (NSBitmapImageRep *) aRep;
{
    NSRect	frame;
    
    frame.origin.x = 0;
	frame.origin.y = 0;
    frame.size = [aRep size];
    if ((self = [super initWithFrame: frame]))
	{
		myRep = [aRep retain];
	}
    return self;
}

- (void)dealloc {
    [myRep release];
    [super dealloc];
}

- (BOOL)isVerticallyCentered;
{
    return YES;
}

- (BOOL)isHorizontallyCentered;
{
    return YES;
}

- (void)drawRect:(NSRect)aRect 
{
    NSEraseRect([self bounds]);
	[myRep draw];
}

@end
