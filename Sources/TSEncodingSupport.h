/*
 * TeXShop - TeX editor for Mac OS
 * Copyright (C) 2000-2005 Richard Koch
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 * $Id$
 *
 * Created by Mitsuhiro Shishikura on Fri Dec 13 2002.
 *
 */

#import <Cocoa/Cocoa.h>

@interface TSEncodingSupport : NSObject {

}

+ (id)sharedInstance;

- (void)setupForEncoding;
- (void)encodingChanged: (NSNotification *)note;
- (IBAction)toggleTeXCharConversion:(id)sender;

// Old encoding API: Uses 'tags' to enumerate the encodings, 'encoding' means a string used in the
// preference storage, and finally, NSStringEncodings to be passed to the Cocoa APIs
- (int)tagForEncodingPreference;
- (int)tagForEncoding: (NSString *)encoding;
- (NSString *)encodingForTag: (int)tag;
- (NSStringEncoding)stringEncodingForTag: (int)encoding;

// New encoding API: Uses NSStringEncoding for the menu tags
- (NSStringEncoding)defaultEncoding;
- (NSStringEncoding)stringEncodingForKey: (NSString *)key;
- (NSString *)keyForStringEncoding: (NSStringEncoding)encoding;
- (NSString *)localizedNameForKey: (NSString *)key;
- (NSString *)localizedNameForStringEncoding: (NSStringEncoding)encoding;

// Add a (localized) list of available encodings to the given menu. The tag of each menu item
// will equal the corresponding NSStringEncoding.
- (void)addEncodingsToMenu:(NSMenu *)menu withTarget:(id)aTarget action:(SEL)anAction;


- (BOOL)ptexUtfOutputCheck: (NSString *)dataString withEncoding: (NSStringEncoding)enc;
- (NSData *)ptexUtfOutput: (NSTextView *)dataView withEncoding: (NSStringEncoding)enc;
@end

NSMutableString *filterBackslashToYen(NSString *aString);
NSMutableString *filterYenToBackslash(NSString *aString);

