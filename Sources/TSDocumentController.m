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
 * Created by Richard Koch on Sun Feb 16 2003.
 * Parts of this code are taken from Apple's example SimpleToolbar
 *
 */

#import "TSDocumentController.h"
#import "TSEncodingSupport.h"


@implementation TSDocumentController : NSDocumentController

- (void)initializeEncoding  // the idea is that this is called after preferences is set up
{
    encoding = [[TSEncodingSupport sharedInstance] tagForEncodingPreference];
}

- (int) encoding
{
    return encoding;
}

- (IBAction)newDocument:(id)sender{
    
    encoding = [[TSEncodingSupport sharedInstance] tagForEncodingPreference];
    [super newDocument: sender];
}

- (IBAction)openDocument:(id)sender{
    
    [super openDocument: sender];
    encoding = [[TSEncodingSupport sharedInstance] tagForEncodingPreference];
}


- (int)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions
{
    int		result;
    int		theCode;
    
    theCode = [[TSEncodingSupport sharedInstance] tagForEncodingPreference];
    [openPanel setAccessoryView: encodingView ];
    [encodingView retain];
    [encodingMenu selectItemAtIndex: theCode];
    result = [super runModalOpenPanel: openPanel forTypes: extensions];
    if (result == YES) {
        encoding = [[encodingMenu selectedCell] tag];
        }
    return result;
}

@end
