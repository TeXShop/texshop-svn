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

#define SUD [NSUserDefaults standardUserDefaults]

// FIXME: Try to get rid of the following two functions:
static BOOL isText1(int c);
static void report(NSString *itest);

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

BOOL isText1(int c) {
    if ((c >= 'A') && (c <= 'Z'))
        return YES;
    else if ((c >= 'a') && (c <= 'z'))
        return YES;
    else
        return NO;
}

// fixColor2 is the old fixcolor, now only used when opening documents
- (void)fixColor2: (unsigned)from : (unsigned)to
{
    NSRange	colorRange;
    NSString	*textString;
    NSColor	*regularColor;
    long	length, location, final;
    unsigned	start1, end1;
    int		theChar;
    unsigned	end;
    
    if ((! [SUD boolForKey:SyntaxColoringEnabledKey]) || (! fileIsTex)) return;
    
    // regularColor = [NSColor blackColor];
    regularColor = [NSColor colorWithCalibratedRed: [SUD floatForKey:foreground_RKey] 
        green:[SUD floatForKey:foreground_GKey] blue:[SUD floatForKey:foreground_BKey] alpha:1.00];
 
    textString = [textView string];
    if (textString == nil) return;
    length = [textString length];
    // [[textView textStorage] beginEditing];
    [textStorage beginEditing];

    
    colorRange.location = 0;
    colorRange.length = length;
    [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
    location = start1;
    final = end1;
    colorRange.location = start1;
    colorRange.length = end1 - start1;
    
    [textView setTextColor: regularColor range: colorRange];
        
    // NSLog(@"begin");
    while (location < final) {
		theChar = [textString characterAtIndex: location];
		
		if ((theChar == '{') || (theChar == '}') || (theChar == '$')) {
			colorRange.location = location;
			colorRange.length = 1;
			[textView setTextColor: markerColor range: colorRange];
			colorRange.location = colorRange.location + colorRange.length - 1;
			colorRange.length = 0;
			[textView setTextColor: regularColor range: colorRange];
			location++;
		}
		
		else if (theChar == '%') {
			colorRange.location = location;
			colorRange.length = 0;
			[textString getLineStart:NULL end:NULL contentsEnd:&end forRange:colorRange];
			colorRange.length = (end - location);
			[textView setTextColor: commentColor range: colorRange];
			colorRange.location = colorRange.location + colorRange.length - 1;
			colorRange.length = 0;
			[textView setTextColor: regularColor range: colorRange];
			location = end;
		}
		
		else if (theChar == g_texChar) {
			colorRange.location = location;
			colorRange.length = 1;
			location++;
			if ((location < final) && ([textString characterAtIndex: location] == '%')) {
				colorRange.length = location - colorRange.location;
				location++;
			}
			else while ((location < final) && (isText1([textString characterAtIndex: location]))) {
				location++;
				colorRange.length = location - colorRange.location;
			}
                [textView setTextColor: commandColor range: colorRange];
			colorRange.location = location;
			colorRange.length = 0;
			[textView setTextColor: regularColor range: colorRange];
		}
		
		else
			location++;
	}
            
        // [[textView textStorage] endEditing];
        [textStorage endEditing];

        
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
    NSString			*textString;
    int				i, j, count, uchar, leftpar, rightpar, aChar;
    BOOL			done;
    NSDate			*myDate;
    unsigned 			start, end, end1;
    NSMutableAttributedString 	*myAttribString;
    NSDictionary		*myAttributes;
    NSColor			*previousColor;
	
    fastColor = NO;
    if (affectedCharRange.length == 0)
        fastColor = YES;
    else if (affectedCharRange.length == 1) {
        aChar = [[textView string] characterAtIndex: affectedCharRange.location];
        if (/* (aChar >= ' ') && */ (aChar != 165) && (aChar != 0x005c) && (aChar != '%'))
            fastColor = YES;
        if (aChar == 0x005c) {
            fastColor = YES;
            myAttribString = [[[NSMutableAttributedString alloc] initWithAttributedString:[textView attributedSubstringFromRange: affectedCharRange]] autorelease];
            myAttributes = [myAttribString attributesAtIndex: 0 effectiveRange: NULL];
            // mitsu 1.29 parhaps this (and several others below) can be replaced by
            // myAttributes = [[textView textStorage] attributesAtIndex: 
            // 					affectedCharRange.location effectiveRange: NULL];
            // end mitsu 1.29 and myAttribString is not necessary
            previousColor = [myAttributes objectForKey:NSForegroundColorAttributeName];
            if (previousColor != commentColor) 
                fastColorBackTeX = YES;
		}
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
				matchRange = [textString rangeOfString:
					[g_taggedTeXSections objectAtIndex:i] options:0 range:tagRange];
				if (matchRange.length != 0) {
					tagLine = YES;
					break;
				}
			}
			
		}
	}
    
	if (replacementString == nil) 
        return YES;
	else
		colorEnd = colorStart + [replacementString length];
    
    if ([replacementString length] != 1)
		return YES;
    rightpar = [replacementString characterAtIndex:0];
    
	// mitsu 1.29 (T4) compare with "inserText:" in TSTextView.m
#define AUTOCOMPLETE_IN_INSERTTEXT
#ifndef AUTOCOMPLETE_IN_INSERTTEXT
	// end mitsu 1.29
	
    
    // Code added by Greg Landweber for auto-completions of '^', '_', etc.
    // Should provide a preference setting for users to turn it off!
    // First, avoid completing \^, \_, \"
	//  if ([SUD boolForKey:AutoCompleteEnabledKey]) {
	if (doAutoComplete) {
        if ( rightpar >= 128 ||
			 [textView selectedRange].location == 0 ||
			 [textString characterAtIndex:[textView selectedRange].location - 1 ] != g_texChar ) {
			
			NSString *completionString = [g_autocompletionDictionary objectForKey:replacementString];
			if ( completionString && (g_shouldFilter != kMacJapaneseFilterMode || [replacementString
                    characterAtIndex:0]!=g_texChar)) {
				// should really send this as a notification, instead of calling it directly,
				// or should separate out the code that actually performs the completion
				// from the code that responds to the notification sent by the LaTeX panel.
				// mitsu 1.29 (T4)
				[self insertSpecialNonStandard:completionString 
									   undoKey: NSLocalizedString(@"Autocompletion", @"Autocompletion")];
				//[textView insertSpecialNonStandard:completionString 
				//			undoKey: NSLocalizedString(@"Autocompletion", @"Autocompletion")];
				// original was
				//    [self doCompletion:[NSNotification notificationWithName:@"" object:completionString]];
				// end mitsu 1.29
				return NO;
			}
		}
	}
	
    // End of code added by Greg Landweber
	// mitsu 1.29 (T4)
#endif
	// end mitsu 1.29
	
	
    if (rightpar == 0x000a)
        returnline = YES;
	
    if (! [SUD boolForKey:ParensMatchingEnabledKey]) return YES;
    if ((rightpar != '}') &&  (rightpar != ')') &&  (rightpar != ']')) return YES;
	
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


// I was plagued with index out of range errors in fixColor. I think they are gone now, but as a precaution
// I always test for them. 
void report(NSString *itest)
{ 
//    NSLog(itest);
}


// This is the main syntax coloring routine, used for everything except opening documents

- (void)fixColor: (unsigned)from : (unsigned)to
{
    NSRange			colorRange, newRange, newRange1, lineRange, wordRange;
    NSString			*textString;
    NSColor			*regularColor, *previousColor;
    long			length, location, final;
    unsigned			start1, end1;
    int				theChar, previousChar, aChar, i;
    BOOL			found;
    unsigned			end;
    unsigned long		itest;
    NSMutableAttributedString 	*myAttribString;
    NSDictionary		*myAttributes;

    if ((! [SUD boolForKey:SyntaxColoringEnabledKey]) || (! fileIsTex)) return;
    
    // regularColor = [NSColor blackColor];
    regularColor = [NSColor colorWithCalibratedRed: [SUD floatForKey:foreground_RKey] 
        green:[SUD floatForKey:foreground_GKey] blue:[SUD floatForKey:foreground_BKey] alpha:1.00];
    
 
    textString = [textView string];
    if (textString == nil) return;
    length = [textString length];
    if (length == 0) return;

    if (returnline) {
        colorRange.location = from + 1;
        colorRange.length = 0;
        }
    
    else {

// This is an attempt to be safe.
// However, it should be fine to set colorRange.location = from and colorRange.length = (to - from) 
    if (from < length)
        colorRange.location = from;
    else
        colorRange.location = length - 1;
        
    if (to < length)
        colorRange.length = to - colorRange.location;
    else
        colorRange.length = length - colorRange.location;
    }

// We try to color simple character changes directly.
   
// Look first at backspaces over anything except a comment character or line feed
    if (fastColor && (colorRange.length == 0)) {
        [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
        if (fastColorBackTeX) {
            wordRange.location = colorRange.location;
            wordRange.length = end - wordRange.location;
            i = colorRange.location + 1;
            found = NO;
            while ((i <= end) && (! found)) {
            itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug1"); return;}
            aChar = [textString characterAtIndex: i];
            if (! isText1(aChar)) {
                found = YES;
                wordRange.length = i - wordRange.location;
                }
            i++;
            }

            [textView setTextColor: regularColor range: wordRange];
            
            fastColor = NO;
            fastColorBackTeX = NO;
            return;
            }
        else if (colorRange.location > start1) {
            newRange.location = colorRange.location - 1;
            newRange.length = 1;
            myAttribString = [[[NSMutableAttributedString alloc] initWithAttributedString:[textView attributedSubstringFromRange: newRange]] autorelease];
            myAttributes = [myAttribString attributesAtIndex: 0 effectiveRange: NULL];
            previousColor = [myAttributes objectForKey:NSForegroundColorAttributeName];
            if (previousColor == commandColor) { //color rest of word blue
                wordRange.location = colorRange.location;
                wordRange.length = end - wordRange.location;
                i = colorRange.location;
                found = NO;
                while ((i <= end) && (! found)) {
                    itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug2"); return;}
                    aChar = [textString characterAtIndex: i];
                    if (! isText1(aChar)) {
                        found = YES;
                        wordRange.length = i - wordRange.location;
                        }
                    i++;
                    }
                [textView setTextColor: commandColor range: wordRange];
                }
            else if (previousColor == commentColor) { //color rest of line red
                newRange.location = colorRange.location;
                newRange.length = (end - colorRange.location);
                [textView setTextColor: commentColor range: newRange];
                }
            fastColor = NO;
            fastColorBackTeX = NO;
            return;
            }
        fastColor = NO;
        fastColorBackTeX = NO;
        }
        
    fastColorBackTeX = NO;

// Look next at cases when a single character is added
    if ( fastColor && (colorRange.length == 1) && (colorRange.location > 0)) {
        itest = colorRange.location; if ((itest < 0) || (itest >= length)) {report(@"bug3"); return;}
        theChar = [textString characterAtIndex: colorRange.location];
        itest = (colorRange.location - 1); if ((itest < 0) || (itest >= length)) {report(@"bug4"); return;}
        previousChar = [textString characterAtIndex: (colorRange.location - 1)];
        newRange.location = colorRange.location - 1;
        newRange.length = colorRange.length;
        myAttribString = [[[NSMutableAttributedString alloc] initWithAttributedString:[textView attributedSubstringFromRange: newRange]] autorelease];
        myAttributes = [myAttribString attributesAtIndex: 0 effectiveRange: NULL];
        previousColor = [myAttributes objectForKey:NSForegroundColorAttributeName];
        if ((!isText1(theChar)) && (previousChar == g_texChar)) {
            if (previousColor == commentColor)
                [textView setTextColor: commentColor range: colorRange];
            else if (previousColor == commandColor) {
            	[textView setTextColor: commandColor range: colorRange];
                [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                wordRange.location = colorRange.location + 1;
                wordRange.length = end - wordRange.location;
                i = colorRange.location + 1;
                found = NO;
                while ((i < end) && (! found)) {
                    itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug5"); return;}
                    aChar = [textString characterAtIndex: i];
                    if (! isText1(aChar)) {
                        found = YES;
                        wordRange.length = i - wordRange.location;
                        }
                    i++;
                    }
                // rest of word black; (word range is range AFTER this char to end of word)
                [textView setTextColor: regularColor range: wordRange];
                }
            else
                [textView setTextColor: commandColor range: colorRange];
            fastColor = NO;
            return;
            }
        if ((theChar == '{') || (theChar == '}') || (theChar == '$')) {
            if (previousColor == commentColor)
                [textView setTextColor: commentColor range: colorRange];
            else if (previousColor == commandColor) {
            	[textView setTextColor: markerColor range: colorRange];
                [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                wordRange.location = colorRange.location + 1;
                wordRange.length = end - wordRange.location;
                i = colorRange.location + 1;
                found = NO;
                while ((i < end) && (! found)) {
                    itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug6"); return;}
                    aChar = [textString characterAtIndex: i];
                    if (! isText1(aChar)) {
                        found = YES;
                        wordRange.length = i - wordRange.location;
                        }
                    i++;
                    }
                // rest of word black; (word range is range AFTER this char to end of word)
                [textView setTextColor: regularColor range: wordRange];
                }
            else
                [textView setTextColor: markerColor range: colorRange];
            fastColor = NO;
            return;
            }
        if (theChar == ' ') {
            if (previousColor == commentColor)
                [textView setTextColor: commentColor range: colorRange];
            else if (previousColor == markerColor)
                [textView setTextColor: regularColor range: colorRange];
            else if (previousColor == commandColor) {
                // rest of word black; (wordRange is range to end of word INCLUDING this char)
                [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                wordRange.location = colorRange.location;
                wordRange.length = end - wordRange.location;
                i = colorRange.location + 1;
                found = NO;
                while ((i < end) && (! found)) {
                    itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug7"); return;}
                    aChar = [textString characterAtIndex: i];
                    if (! isText1(aChar)) {
                        found = YES;
                        wordRange.length = i - wordRange.location;
                        }
                    i++;
                    }

                [textView setTextColor: regularColor range: wordRange];
                }
            else
                [textView setTextColor: regularColor range: colorRange];
            fastColor = NO;
            return;
            }
        if (theChar == '%') {
            [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
            lineRange.location = colorRange.location;
            lineRange.length = end - colorRange.location;
            [textView setTextColor: commentColor range: lineRange];
            fastColor = NO;
            return;
            }
        if (theChar == g_texChar) {
            if (previousColor == commentColor)
                [textView setTextColor: commentColor range: colorRange];
            else {
                // word Range is rest of word, including this
                [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                wordRange.location = colorRange.location;
                wordRange.length = end - wordRange.location;
                i = colorRange.location + 1;
                found = NO;
                while ((i < end) && (! found)) {
                    itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug8"); return;}
                    aChar = [textString characterAtIndex: i];
                    if (! isText1(aChar)) {
                        found = YES;
                        wordRange.length = i - wordRange.location;
                        }
                    i++;
                    }

                [textView setTextColor: commandColor range: wordRange];
                }
            fastColor = NO;
            return;
            }
            
        if ((theChar != g_texChar) && (theChar != '{') && (theChar != '}') && (theChar != '$') &&
            (theChar != '%') && (theChar != ' ') && (previousChar != '}') && (previousChar != '{')
            && (previousChar != '$') ) {
                if ((previousColor == commandColor) && (! isText1(theChar))) {
                    [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                    wordRange.location = colorRange.location;
                    wordRange.length = end - wordRange.location;
                    i = colorRange.location + 1;
                    found = NO;
                    while ((i <= end) && (! found)) {
                        itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug9"); return;}
                        aChar = [textString characterAtIndex: i];
                        if (! isText1(aChar)) {
                            found = YES;
                            wordRange.length = i - wordRange.location;
                            }
                        i++;
                        }

                    [textView setTextColor: regularColor range: wordRange];
                     }
                else if ((previousColor == commandColor) && (! isText1(previousChar)) && (previousChar != g_texChar)) {
                    [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
                    wordRange.location = colorRange.location;
                    wordRange.length = end - wordRange.location;
                    i = colorRange.location + 1;
                    found = NO;
                    while ((i < end) && (! found)) {
                        itest = i; if ((itest < 0) || (itest >= length)) {report(@"bug10"); return;}
                        aChar = [textString characterAtIndex: i];
                        if (! isText1(aChar)) {
                            found = YES;
                            wordRange.length = i - wordRange.location;
                            }
                        i++;
                        }

                    [textView setTextColor: regularColor range: wordRange];
                    }
                else if (previousChar >= ' ')
                    [textView setTextColor: previousColor range: colorRange];
                else
                    [textView setTextColor: regularColor range: colorRange];
                fastColor = NO;
                return;
                }
        }
        
    fastColor = NO;

    // If that trick fails, we work harder.
    // [[textView textStorage] beginEditing];
    [textStorage beginEditing];

    [textString getLineStart:&start1 end:&end1 contentsEnd:&end forRange:colorRange];
    location = start1;
    final = end1;

    colorRange.location = start1;
    colorRange.length = end1 - start1;
    
// The following code fixes a subtle syntax coloring bug; Koch; Jan 1, 2003
    if (start1 > 0) 
        newRange1.location = (start1 - 1);
    else
        newRange1.location = 0;
    if (start1 > 0)
        newRange1.length = end1 - start1 + 1;
    else
        newRange1.length = end1 - start1;
    [textView setTextColor: regularColor range: newRange1];
// End of fix

	[textView setTextColor: regularColor range: colorRange]; 
    
	while (location < final) {
		itest = location; if ((itest < 0) || (itest >= length)) {report(@"bug11"); return;}
		theChar = [textString characterAtIndex: location];
		
		if ((theChar == '{') || (theChar == '}') || (theChar == '$')) {
			colorRange.location = location;
			colorRange.length = 1;
			[textView setTextColor: markerColor range: colorRange];
			colorRange.location = colorRange.location + colorRange.length - 1;
			colorRange.length = 0;
			[textView setTextColor: regularColor range: colorRange];
			location++;
		}
		
		else if (theChar == '%') {
			colorRange.location = location;
			colorRange.length = 0;
			[textString getLineStart:NULL end:NULL contentsEnd:&end forRange:colorRange];
			colorRange.length = (end - location);
			[textView setTextColor: commentColor range: colorRange];
			colorRange.location = colorRange.location + colorRange.length - 1;
			colorRange.length = 0;
			[textView setTextColor: regularColor range: colorRange];
			location = end;
		}
		
		else if (theChar == g_texChar) {
			colorRange.location = location;
			colorRange.length = 1;
			location++;
			itest = location; if (location < final) if ((itest < 0) || (itest >= length)) {report(@"bug12"); return;}
			if ((location < final) && (!isText1([textString characterAtIndex: location]))) {
				location++;
				colorRange.length = location - colorRange.location;
			}
			else {
				itest = location; if (location < final) if ((itest < 0) || (itest >= length)) {report(@"bug13"); return;}
				while ((location < final) && (isText1([textString characterAtIndex: location]))) {
					location++;
					colorRange.length = location - colorRange.location;
					itest = location; if (location < final) if ((itest < 0) || (itest >= length)) {report(@"bug14"); return;}
				}
			}
			[textView setTextColor: commandColor range: colorRange];
			colorRange.location = location;
			colorRange.length = 0;
			[textView setTextColor: regularColor range: colorRange];
		}
		else
			location++;
	}

	// [[textView textStorage] endEditing];
	[textStorage endEditing];
}


//-----------------------------------------------------------------------------
- (void)reColor:(NSNotification *)notification;
//-----------------------------------------------------------------------------
{
    NSString	*textString;
    long	length;
    NSRange	theRange;
   // NSColor     *regularColor;
    
    if (syntaxColoringTimer != nil) {
        [syntaxColoringTimer invalidate];
        [syntaxColoringTimer release];
        syntaxColoringTimer = nil;
        }
        
    textString = [textView string];
    length = [textString length];
    if ([SUD boolForKey:SyntaxColoringEnabledKey]) 
        [self fixColor :0 :length];
    else {
        theRange.location = 0;
        theRange.length = length;
        [textView setTextColor: [NSColor blackColor] range: theRange];
        //regularColor = [NSColor colorWithCalibratedRed: [SUD floatForKey:foreground_RKey] 
        //green:[SUD floatForKey:foreground_GKey] blue:[SUD floatForKey:foreground_BKey] alpha:1.00];
        //[textView setTextColor: regularColor range: theRange];
        }
        
    
    // colorLocation = 0;
    // syntaxColoringTimer = [[NSTimer scheduledTimerWithTimeInterval: COLORTIME target:self selector:@selector(fixColor1:) 	userInfo:nil repeats:YES] retain];
}


@end
