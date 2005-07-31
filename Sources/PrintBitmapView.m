//
//  PrintBitmapView.m
//  TeXShop
//

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
