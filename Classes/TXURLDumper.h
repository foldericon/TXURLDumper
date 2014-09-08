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


#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "AutoHyperlinks/AutoHyperlinks.h"
#import "TextualApplication.h"
#import "TXDumperPrefs.h"
#import "TXDumperSheet.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "FMDatabaseQueue.h"

@interface TXURLDumper : TXDumperPrefs

@property (nonatomic, strong) IBOutlet NSView *ourView;
@property (assign) BOOL dumperSheetVisible;
@property (assign) IBOutlet NSButton *enableBox;
@property (assign) IBOutlet NSButton *selfDumpsBox;
@property (assign) IBOutlet NSButton *shortenerBox;
@property (assign) IBOutlet NSButton *titlesBox;
@property (assign) IBOutlet NSButton *debugBox;
@property (assign) IBOutlet NSPopUpButtonCell *matchingBox;
@property (assign) IBOutlet NSPopUpButtonCell *doubleClickActionBox;
@property (assign) IBOutlet NSPopUpButtonCell *doubleEntryHandlingBox;

@property (nonatomic, strong) FMDatabaseQueue *queue;

- (IBAction)setEnable:(id)sender;
- (IBAction)setSelfDumps:(id)sender;
- (IBAction)setResolveShortURLs:(id)sender;
- (IBAction)setGetTitles:(id)sender;
- (IBAction)setDebugMode:(id)sender;
- (IBAction)setMatching:(id)sender;
- (IBAction)setDoubleClickAction:(id)sender;
- (IBAction)setDoubleEntryHandling:(id)sender;
- (IBAction)resetDatabase:(id)sender;
- (IBAction)github:(id)sender;

- (void)pluginLoadedIntoMemory;
- (void)pluginWillBeUnloadedFromMemory;

- (NSView *)pluginPreferencesPaneView;
- (NSString *)pluginPreferencesPaneMenuItemName;

- (void)didPostNewMessageForViewController:(TVCLogController *)logController
                               messageInfo:(NSDictionary *)messageInfo
                             isThemeReload:(BOOL)isThemeReload
                           isHistoryReload:(BOOL)isHistoryReload;

- (void)clearList;
- (void)loadData;
- (void)echo:(NSString *)msg,...;
@end
