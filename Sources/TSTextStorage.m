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
 */

#import "TSTextStorage.h"


@implementation TSTextStorage

- (id)init
{
    return [self initWithAttributedString:nil];
}

- (id)initWithAttributedString:(NSAttributedString *)attrStr
{
	if ((self = [super init])) {
		_colorEditLevel = 0;
		_attributedString = attrStr ? [attrStr mutableCopy] : [[NSMutableAttributedString alloc] init];
	}
	return self;
}

- (void)dealloc
{
    [_attributedString release];

    [super dealloc];
}

- (NSString *)string
{
    return [_attributedString string];
}

- (NSDictionary *)attributesAtIndex:(unsigned)index effectiveRange:(NSRangePointer)aRange
{
    return [_attributedString attributesAtIndex:index effectiveRange:aRange];
}

- (void)replaceCharactersInRange:(NSRange)aRange withString:(NSString *)str
{
    [_attributedString replaceCharactersInRange:aRange withString:str];

    int lengthChange = [str length] - aRange.length;
    [self edited:NSTextStorageEditedCharacters range:aRange changeInLength:lengthChange];
}

- (void)setAttributes:(NSDictionary *)attributes range:(NSRange)aRange
{
    [_attributedString setAttributes:attributes range:aRange];
    [self edited:NSTextStorageEditedAttributes range:aRange changeInLength:0];
}


// Private method which tells our layout managers that they need to redraw.
- (void)_invalidateDisplayForCharacterRange:(NSRange)aRange
{
	NSEnumerator *enumerator = [[self layoutManagers] objectEnumerator];
	id obj;
			
	while ((obj = [enumerator nextObject])) {
		[obj invalidateDisplayForCharacterRange:aRange];
	}
}

- (void)setTextColor:(NSColor *)aColor range:(NSRange)aRange
{
	// This method is the key to the fast syntax highlighting: We allow changing the
	// text color while bypassing the processEditing method. The idea here is that for
	// a simple color change, it is not necessary to re-layout the text; but the regular
	// NSTextStorage would cause exactly that. But it is completely sufficient to just
	// cause our layout managers to redraw (a relatively cheap operation).
    [_attributedString addAttribute:NSForegroundColorAttributeName value:aColor range:aRange];

	// Do NOT invoke edited:range:changeInLength: here for the above reasons!

	if (_colorEditLevel == 0) {
		// Tell the layout mangaers to invalidate their display.
		[self _invalidateDisplayForCharacterRange:aRange];
	} else {
		// Coalesce the change by updating _colorRange
		_colorRange.location = MIN(_colorRange.location, aRange.location);
		_colorRange.length = MAX(_colorRange.location + _colorRange.length, aRange.location + aRange.length) - _colorRange.location;
	}
}

- (void)beginEditing
{
	[super beginEditing];
	if (_colorEditLevel == 0) {
		_colorRange.location = NSNotFound;
		_colorRange.length = 0;
	}
	_colorEditLevel++;
}

- (void)endEditing;
{
	[super endEditing];

	NSAssert(_colorEditLevel > 0, @"endColorEditing invoked with non-positive _colorEditLevel");

	_colorEditLevel--;
	if (_colorEditLevel == 0) {
		[self _invalidateDisplayForCharacterRange:_colorRange];
	}
}


@end
