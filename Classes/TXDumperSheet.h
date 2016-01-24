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


#import "TextualApplication.h"
#import "TXURLDumper.h"
#import "TXDumperPrefs.h"


@interface TXDumperSheet : TXDumperPrefs <NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSMenuDelegate>

@property (unsafe_unretained) id plugin;
@property (nonatomic, retain) NSMutableArray *dataSource;
@property (weak) NSWindow *window;
@property (nonatomic, strong) IBOutlet NSWindow *sheet;
@property (weak) IBOutlet NSSearchField *searchBar;

@property (weak) IBOutlet NSTableView *tableView;
@property (weak) IBOutlet NSTextField *networkLabel;
@property (weak) IBOutlet NSTextField *recordsLabel;
@property (weak) IBOutlet NSButton *clearButton;
@property (weak) IBOutlet NSButton *closeButton;
@property (weak) IBOutlet NSButton *disableDumpingBox;
@property (assign) BOOL networkSheet;
@property (weak) NSString *searchString;

- (IBAction)clear:(id)sender;
- (IBAction)close:(id)sender;
- (IBAction)textEntered:(id)sender;
- (IBAction)disableDumping:(id)sender;

- (void)start;
- (void)loadData;

@end