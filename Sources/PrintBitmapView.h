//
//  PrintBitmapView.h
//  TeXShop
//

#import <AppKit/NSView.h>

@interface PrintBitmapView : NSView 
{
    NSBitmapImageRep	*myRep;
}
    
- (PrintBitmapView *) initWithBitmapRep: (NSBitmapImageRep *) aRep;

@end
