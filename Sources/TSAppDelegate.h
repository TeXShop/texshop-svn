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
 * Created by dirk on Tue Jan 23 2001.
 *
 */

#import "UseMitsu.h"

#import <Foundation/Foundation.h>
#import "Autrecontroller.h"
#import "Matrixcontroller.h"
#import "OgreKit/OgreTextFinder.h"
// added by mitsu --(H) Macro menu and (G) EncodingSupport
// #import "MacroMenuController.h"
#import "EncodingSupport.h"
// end addition

@interface TSAppDelegate : NSObject 
{
    BOOL	forPreview;
}

- (IBAction)displayMatrixPanel:(id)sender; //  MatrixPanel Addition by Jonas 1.32 Nov 28 03
- (IBAction)openForPreview:(id)sender;
- (IBAction)displayLatexPanel:(id)sender;
- (IBAction)displayMatrixPanel:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)anItem;
- (BOOL)forPreview;
- (void)configureExternalEditor;
- (void)configureMenuShortcutsFolder;
- (void)configureAutoCompletion;
- (void)configureTemplates;
- (void)configureScripts;
- (void)configureBin;
- (void)configureLatexPanel;
- (void)configureMatrixPanel; // Jonas 1.32
- (void)configureMacro;
- (void)prepareConfiguration: (NSString *)filePath; // mitsu 1.29 (P)
- (void)finishCommandCompletionConfigure; // mitsu 1.29 (P)
- (void)openCommandCompletionList: (id)sender; // mitsu 1.29 (P)
#ifdef MITSU_PDF
- (void)changeImageCopyType: (id)sender; // mitsu 1.29 (O)
#endif
- (void)finishAutoCompletionConfigure;
- (void)finishMenuKeyEquivalentsConfigure;
- (void)setForPreview: (BOOL)value;
// - (void)showConfiguration:(id)sender;
// - (void)showMacrosHelp:(id)sender;
- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender;
- (void)configureEngine;
- (void)ogreKitWillHackFindMenu:(OgreTextFinder*)textFinder;
- (IBAction)checkForUpdate:(id)sender; // Update checker
@end
