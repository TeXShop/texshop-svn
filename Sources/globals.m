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
 * Created by dirk on Thu Dec 07 2000.
 *
 */

#import "globals.h"

NSString *DefaultCommandKey = @"DefaultCommand";
NSString *DefaultEngineKey = @"DefaultEngine";
NSString *DefaultScriptKey = @"DefaultScript";
NSString *ConsoleBehaviorKey = @"ConsoleBehavior";
NSString *SaveRelatedKey = @"SaveRelated";
NSString *DocumentFontKey = @"DocumentFont";
NSString *DocumentWindowFixedPosKey = @"DocumentWindowFixedPosition";
NSString *DocumentWindowNameKey = @"DocumentWindow";
NSString *DocumentWindowPosModeKey = @"DocumentWindowPositionMode";
NSString *LatexPanelNameKey = @"LatexPanel";
NSString *MakeEmptyDocumentKey = @"MakeEmptyDocument";
NSString *UseExternalEditorKey = @"UseExternalEditor";
NSString *EncodingKey = @"Encoding";
NSString *TagSectionsKey = @"TagSections";
NSString *LPanelOutlinesKey = @"LPanelOutlines";
NSString *PanelOriginXKey = @"PanelOriginX";
NSString *PanelOriginYKey = @"PanelOriginY";
NSString *MPanelOriginXKey = @"MPanelOriginX"; //  MatrixPanel Addition by Jonas 1.32 Nov 28 03
NSString *MPanelOriginYKey = @"MPanelOriginY"; //  MatrixPanel Addition by Jonas 1.32 Nov 28 03
NSString *LatexCommandKey = @"LatexCommand";
NSString *LatexGSCommandKey = @"LatexGSCommand";
NSString *SavePSEnabledKey = @"SavePSEnabled";
NSString *LatexScriptCommandKey = @"LatexScriptCommand";
NSString *ParensMatchingEnabledKey = @"ParensMatchingEnabled";
NSString *SpellCheckEnabledKey = @"SpellCheckEnabled";
NSString *AutoCompleteEnabledKey = @"AutoCompleteEnabled";
NSString *PdfMagnificationKey = @"PdfMagnification";
NSString *NoScrollEnabledKey = @"NoScrollEnabled";
NSString *PdfWindowFixedPosKey = @"PdfWindowFixedPosition";
NSString *PdfWindowNameKey = @"PdfWindow";
NSString *PdfKitWindowNameKey = @"PdfKitWindow";
NSString *PdfWindowPosModeKey = @"PdfWindowPositionMode";
NSString *PdfPageStyleKey = @"PdfPageStyle"; // mitsu 1.29 (O)
NSString *PdfRefreshKey = @"PdfRefresh";
NSString *RefreshTimeKey = @"RefreshTime";
NSString *PdfFileRefreshKey = @"PdfFileRefresh";
NSString *PdfFirstPageStyleKey = @"PdfFirstPageStyle";
NSString *PdfFitSizeKey = @"PdfFitSize"; // mitsu 1.29 (O)
NSString *PdfKitFitSizeKey = @"PdfKitFitSize"; // mitsu 1.29 (O)
NSString *PdfCopyTypeKey = @"PdfCopyType"; // mitsu 1.29 (O)
NSString *PdfExportTypeKey = @"PdfExportType"; // mitsu 1.29 (O)
NSString *PdfMouseModeKey = @"PdfMouseMode"; // mitsu 1.29 (O)
NSString *PdfKitMouseModeKey = @"PdfKitMouseMode"; // mitsu 1.29 (O)
NSString *PdfQuickDragKey = @"PdfQuickDrag"; // mitsu 1.29 drag & drop
NSString *SaveDocumentFontKey = @"SaveDocumentFont";
NSString *SyntaxColoringEnabledKey = @"SyntaxColoringEnabled";
NSString *KeepBackupKey = @"KeepBackup";
NSString *TetexBinPath = @"TetexBinPath";
NSString *GSBinPath = @"GSBinPath";
NSString *TexCommandKey = @"TexCommand";
NSString *TexGSCommandKey = @"TexGSCommand";
NSString *TexScriptCommandKey = @"TexScriptCommand";
NSString *MetaPostCommandKey = @"MetaPostCommand";
NSString *BibtexCommandKey = @"BibtexCommand";
NSString *DistillerCommandKey = @"DistillerCommand";
NSString *MatrixSizeKey = @"matrixsize"; // Jonas' Matrix addition
NSString *TSHasBeenUsedKey = @"TSHasBeenUsed";
NSString *UserInfoPath = @"UserInfoPath";
NSString *commentredKey = @"commentred";
NSString *commentgreenKey = @"commentgreen";
NSString *commentblueKey = @"commentblue";
NSString *commandredKey = @"commandred";
NSString *commandgreenKey = @"commandgreen";
NSString *commandblueKey = @"commandblue";
NSString *markerredKey = @"markerred";
NSString *markergreenKey = @"markergreen";
NSString *markerblueKey = @"markerblue";
NSString *tabsKey = @"tabs";
NSString *background_RKey = @"background_R";
NSString *background_GKey = @"background_G";
NSString *background_BKey = @"background_B";
NSString *foreground_RKey = @"foreground_R";
NSString *foreground_GKey = @"foreground_G";
NSString *foreground_BKey = @"foreground_B";
NSString *insertionpoint_RKey = @"insertionpoint_R";
NSString *insertionpoint_GKey = @"insertionpoint_G";
NSString *insertionpoint_BKey = @"insertionpoint_B";
NSString *WarnForShellEscapeKey = @"WarnForShellEscape";
NSString *ptexUtfOutputEnabledKey = @"ptexUtfOutput"; // zenitani 1.35 (C)
// mitsu 1.29 (O)
NSString *PdfColorMapKey = @"PdfColorMap";
NSString *PdfFore_RKey = @"PdfFore_R";
NSString *PdfFore_GKey = @"PdfFore_G";
NSString *PdfFore_BKey = @"PdfFore_B";
NSString *PdfFore_AKey = @"PdfFore_A";
NSString *PdfBack_RKey = @"PdfBack_R";
NSString *PdfBack_GKey = @"PdfBack_G";
NSString *PdfBack_BKey = @"PdfBack_B";
NSString *PdfBack_AKey = @"PdfBack_A";
NSString *PdfColorParam1Key = @"PdfColorParam1";
NSString *PdfColorParam2Key = @"PdfColorParam2";
NSString *PdfPageBack_RKey = @"Pdfbackground_R";
NSString *PdfPageBack_GKey = @"Pdfbackground_G";
NSString *PdfPageBack_BKey = @"Pdfbackground_B";
NSString *ExternalEditorTypesetAtStartKey = @"ExternalEditorTypesetAtStart";
NSString *ConvertLFKey = @"ConvertLF";
NSString *UseOgreKitKey = @"UseOgreKit";
NSString *BringPdfFrontOnAutomaticUpdateKey = @"BringPdfFrontOnAutomaticUpdate";
NSString *SourceWindowAlphaKey = @"SourceWindowAlpha";
NSString *PreviewWindowAlphaKey = @"PreviewWindowAlpha";
NSString *ConsoleWindowAlphaKey = @"ConsoleWindowAlpha";
NSString *OtherTrashExtensionsKey = @"OtherTrashExtensions";
NSString *AggressiveTrashAUXKey = @"AggressiveTrashAUX";
NSString *ShowSyncMarksKey = @"ShowSyncMarks";
NSString *AcceptFirstMouseKey = @"AcceptFirstMouse";
NSString *UseOldHeadingCommandsKey = @"UseOldHeadingCommands";
NSString *SyncMethodKey = @"SyncMethod";
NSString *UseOutlineKey = @"UseOutline";


// Paths
NSString *TeXShopPath = @"~/Library/TeXShop";
NSString *TexTemplatePath = @"~/Library/TeXShop/Templates";
NSString *TexTemplateMorePath = @"~/Library/TeXShop/Templates/More";
NSString *LatexPanelPath = @"~/Library/TeXShop/LatexPanel";
NSString *MatrixPanelPath = @"~/Library/TeXShop/MatrixPanel";
NSString *BinaryPath = @"~/Library/TeXShop/bin";
NSString *EnginePath = @"~/Library/TeXShop/Engines";
NSString *ScriptsPath = @"~/Library/TeXShop/Scripts";
NSString *AutoCompletionPath = @"~/Library/TeXShop/Keyboard";
NSString *MenuShortcutsPath = @"~/Library/TeXShop/Menus";
NSString *MacrosPath = @"~/Library/TeXShop/Macros";
NSString *CommandCompletionPath = @"~/Library/TeXShop/CommandCompletion/CommandCompletion.txt";

// TODO: Shouldn't we use  NSTemporaryDirectory() (or a path based on it) rather than the following three paths?
NSString *TempPath = @"/tmp/TeXShop_Applescripts";
NSString *TempOutputKey = @"/tmp/TeXShop_Output";
NSString *DraggedImagePath = @"~/Library/TeXShop/DraggedImages/texshop_image"; // mitsu 1.29 drag & drop


// Notifications
NSString *SyntaxColoringChangedNotification = @"SyntaxColoringChangedNotification";
NSString *DocumentFontChangedNotification = @"DocumentFontChangedNotification";
NSString *DocumentFontRememberNotification = @"DocumentFontRememberNotification";
NSString *DocumentFontRevertNotification = @"DocumentFontRevertNotification";
NSString *MagnificationChangedNotification = @"MagnificationChangedNotification";
NSString *MagnificationRememberNotification = @"MagnificationRememberNotification";
NSString *MagnificationRevertNotification = @"MagnificationRevertNotification";
NSString *DocumentSyntaxColorNotification = @"DocumentSyntaxColorNotification";
NSString *DocumentAutoCompleteNotification = @"DocumentAutoCompleteNotification";
NSString *ExternalEditorNotification = @"ExternalEditorNotification";

/*" Other variables "*/
// BOOL documentsHaveLoaded;
NSMutableDictionary *g_environment;
TSFilterMode		g_shouldFilter;
int					g_texChar;
NSDictionary		*g_autocompletionDictionary;

NSArray				*g_taggedTeXSections;
NSArray				*g_taggedTagSections;

// command completion
NSString *g_commandCompletionChar = nil;
NSMutableString *g_commandCompletionList = nil;
BOOL g_canRegisterCommandCompletion = NO;

// Koch 8/24/03
int	g_macroType;	// FIXME: get rid of this
