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
 * Originally part of TSDocument. Broken out by dirk on Tue Jan 09 2001.
 *
 */

#import <AppKit/NSWindow.h>

@class TSDocument;

@interface TSConsoleWindow : NSWindow 
{
    TSDocument	*myDocument;
}

- (void) doChooseMethod: sender;
- (void) doError: sender;
- (TSDocument *)document;
@end
