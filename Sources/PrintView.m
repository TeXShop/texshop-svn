//
//  PrintView.m
//  TeXShop
//
//  Originally part of MyDocument. Broken out by dirk on Tue Jan 09 2001.
//

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
