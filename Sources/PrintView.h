//
//  PrintView.h
//  TeXShop
//
//  Originally part of MyDocument. Broken out by dirk on Tue Jan 09 2001.
//

#import <AppKit/NSView.h>

@interface PrintView : NSView 
{
    NSPDFImageRep	*myRep;
}
    
- (PrintView *) initWithRep: (NSPDFImageRep *) aRep;
- (BOOL) knowsPageRange:(NSRangePointer)range;
@end
