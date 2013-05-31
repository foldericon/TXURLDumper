/*
 ===============================================================================
 Copyright (c) 2013, Tobias Pollmann (foldericon)
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


#import "TXDumperSheet.h"

@implementation TXDumperSheet

- (id)init
{
	if ((self = [super init])) {
		[NSBundle loadNibNamed:@"DumperSheet" owner:self];
        [self.tableView setDataSource:self];
        [self.tableView setDelegate:self];        
        [self.tableView setDoubleAction:@selector(doubleClick:)];
    }
	return self;
}

- (void)start
{
    [self loadData];
	[self startSheetWithWindow:self.window];
    [self.window makeKeyAndOrderFront:self.sheet];
    [self.sheet makeFirstResponder:self.searchBar];
}

- (void)startSheetWithWindow:(NSWindow *)awindow
{
	[NSApp beginSheet:self.sheet
	   modalForWindow:awindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

- (void)endSheet
{
    self.dataSource = nil;
	[NSApp endSheet:self.sheet];
}

- (void)sheetDidEnd:(NSWindow *)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[self.sheet close];
}

- (void)loadData
{
    [self.plugin loadData];
    [self.tableView reloadData];
    [self updateRecordsLabel];
}

- (void)updateRecordsLabel
{
    NSString *records = @"%i Record";
    if(self.dataSource.count > 1) {
        records = [records stringByAppendingString:@"s"];
    }
    [self.recordsLabel setStringValue:[NSString stringWithFormat:records, (int)self.dataSource.count]];
}

#pragma mark -
#pragma mark Actions
- (void)AlertHasConfirmed:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == 1){
        self.dataSource = nil;
        [self.tableView setNeedsDisplay:YES];
        [self.plugin clearDB];
    }
}

- (IBAction)clear:(id)sender {
    NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to clear the list and lose all dumped URLs for the selected network?"
                                     defaultButton:@"OK"
                                   alternateButton:nil
                                       otherButton:@"Cancel"
                         informativeTextWithFormat:@"There is no way to undo this."];
     [alert beginSheetModalForWindow:self.sheet
                       modalDelegate:self
                      didEndSelector:@selector(AlertHasConfirmed:returnCode:contextInfo:)
                         contextInfo:nil];
}

- (IBAction)close:(id)sender {
    [self endSheet];
}

- (IBAction)textEntered:(id)sender {
    [self.plugin loadData];
    [self.tableView reloadData];
    NSString *str = [[sender stringValue] lowercaseString];
    if ([str isEqualTo:@""]) {
        [self updateRecordsLabel];        
        NSAssertReturn(nil);
    }
    NSMutableArray *new = [[NSMutableArray alloc] init];
    for (NSDictionary *dict in self.dataSource){
        if ([[[dict stringForKey:@"channel"] lowercaseString] rangeOfString:str].location != NSNotFound ||
            [[[dict stringForKey:@"nick"] lowercaseString] rangeOfString:str].location != NSNotFound ||
            [[[dict stringForKey:@"url"] lowercaseString] rangeOfString:str].location != NSNotFound ||
            [[[dict stringForKey:@"time"] lowercaseString] rangeOfString:str].location != NSNotFound) {
            [new addObject:dict];
        }
    }
    self.dataSource = new;
    [self.tableView reloadData];
    [self updateRecordsLabel];
}

#pragma mark -
#pragma mark DataSource

- (void)doubleClick:(id)object
{
    NSString *url = [[self.dataSource objectAtIndex:[self.tableView clickedRow]] objectForKey:@"url"];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
    BOOL ok = [pasteboard setString:url forType:NSStringPboardType];
    if (ok) {
        NSString *str = [NSString stringWithFormat:@"%@ has been copied to clipboard.", url];
        [self.plugin echo:str];
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [self.dataSource count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    return [[self.dataSource objectAtIndex:rowIndex] objectForKey:aTableColumn.identifier];
}

@end
