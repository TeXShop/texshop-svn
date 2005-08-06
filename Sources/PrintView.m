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
#import "PrintView.h"

@implementation PrintView : NSView

- (PrintView *) initWithRep: (NSPDFImageRep *) aRep;
{
    NSRect	frame;
    
    frame.origin.x = 0;
	frame.origin.y = 0;
    frame.size = [aRep size];
    if ((self = [super initWithFrame: frame]))
	{
		myRep = [aRep retain];
	}
    // end
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
//    NSEraseRect([self bounds]);
    NSRect  myRect;
    
    myRect = [self bounds];
    NSPrintInfo *pi = [[NSPrintOperation currentOperation] printInfo];
    float scale = [[[pi dictionary] objectForKey:NSPrintScalingFactor]
                    floatValue];
    myRect.size.height = myRect.size.height * scale;
    myRect.size.width = myRect.size.width * scale;
    
	[myRep drawInRect: myRect];
}


- (BOOL) knowsPageRange:(NSRangePointer)range;
{
    (*range).location = 1;
    (*range).length = [myRep pageCount];
    return YES;
}

- (NSRect)rectForPage:(int)pageNumber;
{
    int		thePage;
    NSRect	aRect;

    thePage = pageNumber;
    if (thePage < 1) thePage = 1;
    if (thePage > [myRep pageCount]) thePage = [myRep pageCount];
    [myRep setCurrentPage: thePage - 1];
    // mitsu; see above
    // aRect = [myRep bounds];
    aRect.origin.x = 0; aRect.origin.y = 0;
    aRect.size = [myRep bounds].size;
    
    NSPrintInfo *pi = [[NSPrintOperation currentOperation] printInfo];
    float scale = [[[pi dictionary] objectForKey:NSPrintScalingFactor]
                    floatValue];
    aRect.size.height = aRect.size.height * scale;
    aRect.size.width = aRect.size.width * scale;
    
    return aRect;
}

@end
