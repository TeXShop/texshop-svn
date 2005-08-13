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
 * Created by Richard Koch on Sun Feb 16 2003.
 * Parts of this code are taken from Apple's example SimpleToolbar
 *
 */

#import "TSDocumentController.h"
#import "TSEncodingSupport.h"


@implementation TSDocumentController : NSDocumentController

- (void)initializeEncoding  // the idea is that this is called after preferences is set up
{
	// We use the _encoding field to store the encoding to be used for the
	// next openend file. Normally, this is just the default encoding, and
	// we use that as the initial value of _encoding. However, in the open
	// dialog, the user can choose a custom encoding; if that happens, then
	// the value of _encoding is modified (see runModalOpenPanel below).
	// This happens before openDocument: is called.
    _encoding = [[TSEncodingSupport sharedInstance] tagForEncodingPreference];
}

- (int) encoding
{
    return _encoding;
}

- (IBAction)newDocument:(id)sender{
    
    _encoding = [[TSEncodingSupport sharedInstance] tagForEncodingPreference];
    [super newDocument: sender];
}

- (IBAction)openDocument:(id)sender{
    
    [super openDocument: sender];
    _encoding = [[TSEncodingSupport sharedInstance] tagForEncodingPreference];
}


- (int)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions
{
    int		result;
    int		theCode;
    
	// TODO: Consider creating the view/menu on the fly, based on the list of available
	// encodings from TSEncodingSupport.
    theCode = [[TSEncodingSupport sharedInstance] tagForEncodingPreference];
    [openPanel setAccessoryView: encodingView ];
    [encodingView retain];
    [encodingMenu selectItemAtIndex: theCode];
    result = [super runModalOpenPanel: openPanel forTypes: extensions];
    if (result == YES) {
        _encoding = [[encodingMenu selectedCell] tag];
	}
    return result;
}

@end
