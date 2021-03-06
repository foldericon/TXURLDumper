/*
 ===============================================================================
 Copyright (c) 2013-2014, Tobias Pollmann (foldericon)
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the <organization> nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 ===============================================================================
*/


#import <Foundation/Foundation.h>

extern NSString *TXDumperDumpingEnabledKey;
extern NSString *TXDumperSelfDumpsEnabledKey;
extern NSString *TXDumperResolveShortURLsEnabledKey;
extern NSString *TXDumperGetTitlesEnabledKey;
extern NSString *TXDumperDebugModeEnabledKey;
extern NSString *TXDumperStrictMatchingEnabledKey;
extern NSString *TXDumperOpenInBrowserEnabledKey;
extern NSString *TXDumperDoubleEntryHandlingKey;
extern NSString *TXDumperSheetWidthKey;
extern NSString *TXDumperSheetHeightKey;
extern NSString *TXDumperDisabledNetworksKey;
extern NSString *TXDumperDisabledChannelsKey;
extern NSString *TXDumperSheetColumnWidthsKey;
extern NSString *TXDumperSheetHiddenColumnsKey;
extern NSString *TXDumperSheetSortByKey;
extern NSString *TXDumperSheetSortAscendingKey;

@interface TXDumperPrefs : NSObject

@property (weak) NSDictionary *preferences;
@property (weak, readonly) NSString *preferencesPath;
@property (readonly) BOOL dumpingEnabled;
@property (readonly) BOOL selfDumpsEnabled;
@property (readonly) BOOL resolveShortURLsEnabled;
@property (readonly) BOOL getTitlesEnabled;
@property (readonly) BOOL debugModeEnabled;
@property (readonly) BOOL strictMatching;
@property (readonly) BOOL openInBrowser;
@property (readonly) NSInteger doubleEntryHandling;
@property (readonly) NSInteger dumperSheetWidth;
@property (readonly) NSInteger dumperSheetHeight;
@property (weak, readonly) NSArray *disabledNetworks;
@property (weak, readonly) NSArray *disabledChannels;
@property (weak, readonly) NSDictionary *columnWidths;
@property (weak, readonly) NSArray *hiddenColumns;
@property (weak, readonly) NSString *sortBy;
@property (readonly) BOOL sortAscending;
@end
