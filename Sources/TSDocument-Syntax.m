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

#import "UseMitsu.h"

#import "TSDocument.h"
#import "globals.h"
#import "TSTextStorage.h"

#define SUD [NSUserDefaults standardUserDefaults]

static BOOL isValidTeXCommandChar(int c);

@implementation TSDocument (SyntaxHighlighting)

- (void)textDidChange:(NSNotification *)aNotification;
{
	[self fixColor :colorStart :colorEnd];
	if (tagLine)
		[self setupTags];
	colorStart = 0;
	colorEnd = 0;
	returnline = NO;
	tagLine = NO;
	// [self updateChangeCount: NSChangeDone];
}

BOOL isValidTeXCommandChar(int c)
{
	if ((c >= 'A') && (c <= 'Z'))
		return YES;
	else if ((c >= 'a') && (c <= 'z'))
		return YES;
	else
		return NO;
}

// Colorize ("perform syntax highlighting") all the characters of attrString in the given range.
// Can only recolor full lines, so the given range will be extended accordingly before the
// coloring takes place.
// This is an auxillary routine which is called by fixColor and fixColor2
- (void)colorizeStorage:(TSTextStorage *)attrString inRange:(NSRange)range
{
	NSString	*textString;
	unsigned	length;
	NSRange		colorRange;
	unsigned	location;
	int			theChar;
	unsigned	aLineStart;
	unsigned	aLineEnd;
	unsigned	end;
	
	// Fetch the underlying string.
	textString = [attrString string];
	length = [textString length];
	if (length == 0)
		return;
	
	// Clip the given range (call it paranoia, if you like :-).
	if (range.location >= length)
		return;
	if (range.location + range.length > length)
		range.length = length - range.location;

	// Call beginEditing; this allows the text storage to optimze a series of changes to its content and style.
	[attrString beginEditing];

	// We only perform coloring for full lines here, so extend the given range to full lines.
	// Note that aLineStart is the start of *a* line, but not necessarily the same line
	// for which aLineEnd marks the end! We may span many lines.
	[textString getLineStart:&aLineStart end:&aLineEnd contentsEnd:nil forRange:range];

	// We reset the color of all chars in the given range to the regular color; later, we'll
	// then only recolor anything which is supposed to have another color.
	colorRange.location = aLineStart;
	colorRange.length = aLineEnd - aLineStart;
	[attrString setTextColor:regularColor range:colorRange];

	// Now we iterate over the whole text and perform the actual recoloring.
	location = aLineStart;
	while (location < aLineEnd) {
		theChar = [textString characterAtIndex: location];

		if ((theChar == '{') || (theChar == '}') || (theChar == '$')) {
			// The three special characters { } $ get an extra color.
			colorRange.location = location;
			colorRange.length = 1;
			[attrString setTextColor:markerColor range:colorRange];
			location++;
		} else if (theChar == '%') {
			// Comments are started by %. Everything after that on the same line is a comment.
			colorRange.location = location;
			colorRange.length = 1;
			[textString getLineStart:nil end:nil contentsEnd:&end forRange:colorRange];
			colorRange.length = (end - location);
			[attrString setTextColor:commentColor range:colorRange];
			location = end;
		} else if (theChar == g_texChar) {
			// A backslash (or a yen): a new TeX command starts here.
			// There are two cases: Either a sequence of letters A-Za-z follow, and we color all of them.
			// Or a single non-alpha character follows. Then we color that, too, but nothing else.
			colorRange.location = location;
			colorRange.length = 1;
			location++;
			if ((location < aLineEnd) && (!isValidTeXCommandChar([textString characterAtIndex: location]))) {
				location++;
				colorRange.length = location - colorRange.location;
			} else {
				while ((location < aLineEnd) && (isValidTeXCommandChar([textString characterAtIndex: location]))) {
					location++;
					colorRange.length = location - colorRange.location;
				}
			}
			[attrString setTextColor:commandColor range:colorRange];
		} else
			location++;
	}

	// Tell the text storage that we are done with our changes.
	[attrString endEditing];
}

// fixColor2 is the old fixcolor, now only used when opening documents
- (void)fixColor2: (unsigned)from : (unsigned)to
{
	NSRange		colorRange;

	// No syntax coloring if the file is not TeX, or if it is disabled
	if (!fileIsTex || ![SUD boolForKey:SyntaxColoringEnabledKey])
		return;
	
	// Simply colorize everything.
	colorRange.location = 0;
	colorRange.length = [_textStorage length];
	[self colorizeStorage:_textStorage inRange:colorRange];
}


- (BOOL)textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString
{
	// FIXME/TODO: Implementing this delegate method but not its close relative
	// textView:shouldChangeTextInRanges:replacementStrings: (notice the plural-s)
	// effectively disables multi-selection mode on 10.4 (triggered by pressing Cmd),
	// and also the nifty block selection feature (which is triggererd by Alt). Of
	// course we already map Cmd-Clicking to something else anyway.
	// Still, at least block selections would be useful for our users. But until the rest
	// of the code is not aware of this possibility, we better keep this disabled.

	NSRange			matchRange, tagRange;
	NSString		*textString;
	int				i, j, count, uchar, leftpar, rightpar, aChar;
	BOOL			done;
	NSDate			*myDate;
	unsigned 		start, end, end1;

	fastColor = NO;
	if (affectedCharRange.length == 0)
		fastColor = YES;
	else if (affectedCharRange.length == 1) {
		aChar = [[textView string] characterAtIndex: affectedCharRange.location];
		if ((aChar != g_texChar) && (aChar != '%'))
			fastColor = YES;
	}

	colorStart = affectedCharRange.location;
	colorEnd = colorStart;


	tagRange = [replacementString rangeOfString:@"%:"];
	if (tagRange.length != 0)
		tagLine = YES;

	// added by S. Zenitani -- "\n" increments tagLocationLine
	tagRange = [replacementString rangeOfString:@"\n"];
	if (tagRange.length != 0)
		tagLine = YES;
	// end


	textString = [textView string];
	[textString getLineStart:&start end:&end contentsEnd:&end1 forRange:affectedCharRange];
	tagRange.location = start;
	tagRange.length = end - start;
	matchRange = [textString rangeOfString:@"%:" options:0 range:tagRange];
	if (matchRange.length != 0)
		tagLine = YES;

	// for tagLocationLine (2) Zenitani
	matchRange = [textString rangeOfString:@"\n" options:0 range:tagRange];
	if (matchRange.length != 0)
		tagLine = YES;

	/* code by Anton Leuski */
	if ([SUD boolForKey: TagSectionsKey]) {

		for(i = 0; i < [g_taggedTeXSections count]; ++i) {
			tagRange = [replacementString rangeOfString:[g_taggedTeXSections objectAtIndex:i]];
			if (tagRange.length != 0) {
				tagLine = YES;
				break;
			}
		}

		if (!tagLine) {

			textString = [textView string];
			[textString getLineStart:&start end:&end
						 contentsEnd:&end1 forRange:affectedCharRange];
			tagRange.location	= start;
			tagRange.length		= end - start;

			for(i = 0; i < [g_taggedTeXSections count]; ++i) {
				matchRange = [textString rangeOfString: [g_taggedTeXSections objectAtIndex:i] options:0 range:tagRange];
				if (matchRange.length != 0) {
					tagLine = YES;
					break;
				}
			}

		}
	}

	if (replacementString == nil)
		return YES;

	colorEnd = colorStart + [replacementString length];

	if ([replacementString length] != 1)
		return YES;
	rightpar = [replacementString characterAtIndex:0];

	if (rightpar == 0x000a)
		returnline = YES;

	if (![SUD boolForKey:ParensMatchingEnabledKey])
		return YES;
	if ((rightpar != '}') &&  (rightpar != ')') &&  (rightpar != ']'))
		return YES;

	if (rightpar == '}')
		leftpar = '{';
	else if (rightpar == ')')
		leftpar = '(';
	else
		leftpar = '[';

	textString = [textView string];
	i = affectedCharRange.location;
	j = 1;
	count = 1;
	done = NO;
	/* modified Jan 26, 2001, so we don't search entire text */
	while ((i > 0) && (j < 5000) && (! done)) {
		i--; j++;
		uchar = [textString characterAtIndex:i];
		if (uchar == rightpar)
			count++;
		else if (uchar == leftpar)
			count--;
		if (count == 0) {
			done = YES;
			matchRange.location = i;
			matchRange.length = 1;
			/* koch: here 'affinity' and 'stillSelecting' are necessary,
				else the wrong range is selected. */
			[textView setSelectedRange: matchRange
							  affinity: NSSelectByCharacter stillSelecting: YES];
			[textView display];
			myDate = [NSDate date];
			/* Koch: Jan 26, 2001: changed -0.15 to -0.075 to speed things up */
			while ([myDate timeIntervalSinceNow] > - 0.075);
			[textView setSelectedRange: affectedCharRange];
		}
	}
	return YES;
}


// This is the main syntax coloring routine, used for everything except opening documents

- (void)fixColor: (unsigned)from : (unsigned)to
{
	NSRange			colorRange, lineRange, wordRange;
	NSString		*textString;
	unsigned		length;
	unsigned		lineStart, end1;
	int				theChar, aChar, i;
	unsigned		end;
	
	bool			DONE = NO;

	// No syntax coloring if the file is not TeX, or if it is disabled
	if (!fileIsTex || ![SUD boolForKey:SyntaxColoringEnabledKey])
		return;

	textString = [textView string];
	if (textString == nil)
		return;
	length = [textString length];
	if (length == 0)
		return;

	if (returnline) {
		colorRange.location = from + 1;
		colorRange.length = 0;
	} else {
		// This is an attempt to be safe: we perform some clipping on the color range.
		// TODO: Consider replacing this by a NSAssert or so. It *shouldn't* happen, and if it
		// does anyway, then due to a bug in our code, which we'd like to know about so that we
		// can fix it... right?
		if (from >= length)
			from = length - 1;
		if (to > length)
			to = length;

		colorRange.location = from;
		colorRange.length = to - from;
	}

	// We try to color simple character changes directly.
	// TODO/FIXME: For now disable the fast color mode, it doesn't work quite correct at this point.
	if (0 && fastColor) {
		NSColor			*previousColor;
		NSDictionary	*myAttributes;
		int				previousChar;

		fastColor = NO;
		[_textStorage beginEditing];

		
		// TODO: Make this work at the start of a line, too!
		
		// Look first at backspaces over anything except a comment character or line feed
		if (colorRange.length == 0) {
			[textString getLineStart:&lineStart end:nil contentsEnd:&end forRange:colorRange];
			// We do nothing here if we are at the start of the line, because we need to
			// check the color of the previous char on the same line, which obviously
			// wouldn't work for the first char...
			if (colorRange.location > lineStart) {
				// FIXME: We currently do not handle this properly: 
				//   \x{  then x is deleted and we end up with  \{  but the { is colored incorrectly.
				myAttributes = [_textStorage attributesAtIndex:colorRange.location - 1 effectiveRange: NULL];
				previousColor = [myAttributes objectForKey:NSForegroundColorAttributeName];
				if (previousColor == commandColor) { //color rest of word blue
					for (i = colorRange.location; i < end; ++i) {
						aChar = [textString characterAtIndex: i];
						if (!isValidTeXCommandChar(aChar)) {
							break;
						}
					}
					wordRange.location = colorRange.location;
					wordRange.length = i - wordRange.location;
					[_textStorage setTextColor: commandColor range: wordRange];
				} else if (previousColor == commentColor) { //color rest of line red
					lineRange.location = colorRange.location;
					lineRange.length = (end - colorRange.location);
					[_textStorage setTextColor: commentColor range: lineRange];
				}
				DONE = YES;
			}
		}
		// Look next at cases where a single character is added
		else if ((colorRange.length == 1) && (colorRange.location > 0)) {
			// FIXME: In the (colorRange.length == 0) case above, we actually checked that we aren't looking
			// at the first char *in the line*. Here we only check for the first char *in the document*.
			// Hum....
			theChar = [textString characterAtIndex: colorRange.location];
			previousChar = [textString characterAtIndex: (colorRange.location - 1)];
			myAttributes = [_textStorage attributesAtIndex:colorRange.location - 1 effectiveRange: NULL];
			previousColor = [myAttributes objectForKey:NSForegroundColorAttributeName];
			if (previousColor == commentColor) {
				// The previous character is part of a comment. Hence this new character is
				// part of the same comment, and so we color it accordingly.
				[_textStorage setTextColor: commentColor range: colorRange];
			} else if (theChar == '%') {
				// When a % is inserted, all chars following are re-colored, since they are now commented out.
				[textString getLineStart:&lineStart end:&end1 contentsEnd:&end forRange:colorRange];
				lineRange.location = colorRange.location;
				lineRange.length = end - colorRange.location;
				[_textStorage setTextColor: commentColor range: lineRange];
			} else if (theChar == g_texChar) {
				// A backslash (or yen) was inserted. Change all subsequent letters [A-Za-z]
				// to the command color.
				wordRange.location = colorRange.location;
				i = wordRange.location + 1;
				aChar = [textString characterAtIndex: i];
				if (!isValidTeXCommandChar(aChar)) {
					// Special case: A backslash plus one non-letter character also form a TeX command!
					wordRange.length = 2;
				} else {
					// Grab as many letters as possible
					[textString getLineStart:nil end:nil contentsEnd:&end forRange:colorRange];
					for (; i < end; ++i) {
						aChar = [textString characterAtIndex: i];
						if (!isValidTeXCommandChar(aChar)) {
							break;
						}
					}
					wordRange.length = i - wordRange.location;
				}
				[_textStorage setTextColor: commandColor range: wordRange];
			} else if (previousColor == commandColor) {
				// The previous character is part of a TeX command. So far, it was colored using
				// the commandColor (and possibly some chars after it where, too).
				// There are two main cases that can occur: Either the new char is a letter
				// and thus will be part of the command. Then we just color it accordingly.
				// Or the new char will cut off the command. Then we have to remove the color
				// from all letters after it.
				//
				// Actually there is third case: If the new char is not a letter, but the
				// char just before it is a backslash, then we color the new char in the command
				// color, too. This is there to ensure things like \; or \[ are colored correctly.
				
				NSColor *remainderColor = regularColor;
				
				if (previousChar == g_texChar) {
					// The new char is not a letter, but is preceeded by a backslash:
					// We have to color it in the command color, but everything after it
					// has to be reset to the regular color.
					[_textStorage setTextColor: commandColor range: colorRange];
					colorRange.location++;
					// FIXME: this doesn't work if the next character is { } $
					
					// FIXME: The following is wrong if we are at the end of the file!
					theChar = [textString characterAtIndex: colorRange.location];
					if ((theChar == '{') || (theChar == '}') || (theChar == '$'))
						[_textStorage setTextColor: markerColor range: colorRange];
				} else if (isValidTeXCommandChar(theChar)) {
					remainderColor = commandColor;
				} else if ((theChar == '{') || (theChar == '}') || (theChar == '$')) {
					// If the new char is one of {, }, $, then we color it using the marker color
					// and proceed with the next character
					[_textStorage setTextColor: markerColor range: colorRange];
					colorRange.location++;
				} else {
					[_textStorage setTextColor: regularColor range: colorRange];
					colorRange.location++;
				}

				// Change all subsequent letters [A-Za-z] back to the regular color.
				[textString getLineStart:nil end:nil contentsEnd:&end forRange:colorRange];
				for (i = colorRange.location; i < end; ++i) {
					aChar = [textString characterAtIndex: i];
					if (!isValidTeXCommandChar(aChar)) {
						break;
					}
				}
				wordRange.location = colorRange.location;
				wordRange.length = i - wordRange.location;
				[_textStorage setTextColor: remainderColor range: wordRange];
			} else if ((theChar == '{') || (theChar == '}') || (theChar == '$')) {
				[_textStorage setTextColor: markerColor range: colorRange];
			} else {
				[_textStorage setTextColor: regularColor range: colorRange];
			}
			DONE = YES;
		}

		[_textStorage endEditing];
	}

	if (!DONE) {
		// If that trick fails, we work harder and perform the regular coloring
		[self colorizeStorage:_textStorage inRange:colorRange];
	}
}


//-----------------------------------------------------------------------------
- (void)reColor:(NSNotification *)notification;
//-----------------------------------------------------------------------------
{
	NSRange theRange;

	theRange.location = 0;
	theRange.length = [_textStorage length];
	if ([SUD boolForKey:SyntaxColoringEnabledKey]) {
		[self colorizeStorage:_textStorage inRange:theRange];
	} else {
		[_textStorage setTextColor:[NSColor blackColor] range:theRange];
	}
}


@end
