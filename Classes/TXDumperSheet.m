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


#import "TXDumperSheet.h"

@implementation TXDumperSheet
BOOL networkSheet = YES;

- (id)init
{
	if ((self = [super init])) {
		[NSBundle loadNibNamed:@"DumperSheet" owner:self];
        [self.tableView setDataSource:self];
        [self.tableView setDelegate:self];        
        [self.tableView setDoubleAction:@selector(doubleClick:)];
        for (NSTableColumn *tableColumn in self.tableView.tableColumns ) {
            NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:tableColumn.identifier ascending:YES selector:@selector(localizedStandardCompare:)];
            [tableColumn setSortDescriptorPrototype:sortDescriptor];
        }
    }
	return self;
}

- (void)start
{
    if([self.worldController.selectedItem isClient] == NO) {
        [self.tableView removeTableColumn:[self.tableView tableColumnWithIdentifier:@"channel"]];
        networkSheet = NO;
    }
    
    // Get Sizes
    NSDictionary *columns = [self columnWidths];
    if (columns != nil) {
        for (NSTableColumn *column in self.tableView.tableColumns) {
            if(columns[column.identifier] != nil) {
                column.width = [columns[column.identifier] floatValue];
            }
        }
    }
    
    NSArray *disabledNetworks = [self.preferences objectForKey:TXDumperDisabledNetworksKey];
    if([disabledNetworks containsObject:self.worldController.selectedClient.config.itemUUID]){
        [self.disableDumpingBox setState:1];
    }
    NSRect rect = NSMakeRect(self.sheet.frame.origin.x, self.sheet.frame.origin.y, self.dumperSheetWidth, self.dumperSheetHeight);
    [self.sheet setFrame:rect display:YES];
    [self loadDataSortedBy:@"timestamp"];
	[self startSheetWithWindow:self.window];
    [self.window makeKeyAndOrderFront:self.sheet];
    [self.sheet makeFirstResponder:self.searchBar];
    if(self.dumpingEnabled == NO && self.dataSource.count < 1){
        NSAlert *alert = [NSAlert alertWithMessageText:@"Dumping isn't enabled yet, to start dumping URLs you need to enable it in the Textual preferences."
                                         defaultButton:@"OK"
                                       alternateButton:nil
                                           otherButton:@""
                             informativeTextWithFormat:@""];
        [alert beginSheetModalForWindow:self.sheet
                          modalDelegate:self
                         didEndSelector:nil
                            contextInfo:nil];
    }
}

- (void)startSheetWithWindow:(NSWindow *)awindow
{
    [self.plugin setDumperSheetVisible:YES];
	[NSApp beginSheet:self.sheet
	   modalForWindow:awindow
		modalDelegate:self
	   didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:)
		  contextInfo:nil];
}

- (void)endSheet
{
    [self.plugin setDumperSheetVisible:YES];
    self.dataSource = nil;
	[NSApp endSheet:self.sheet];
}

- (void)sheetDidEnd:(NSWindow *)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[self.sheet close];
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    for (NSTableColumn *column in self.tableView.tableColumns) {
        [dict setObject:[NSNumber numberWithFloat:column.width] forKey:column.identifier];
    }
    [self setColumnWidths:dict];
}

- (void)loadDataSortedBy:(NSString *)column
{
    [self.plugin loadDataSortedBy:column];
    [self.tableView reloadData];
    [self updateRecordsLabel];
}

- (void)updateRecordsLabel
{
    NSString *records = @"%i Record";
    if(self.dataSource.count > 1 || self.dataSource.count == 0) {
        records = [records stringByAppendingString:@"s"];
    }
    [self.recordsLabel setStringValue:[NSString stringWithFormat:records, (int)self.dataSource.count]];
}

- (NSString *)timeAgoString:(double)timestamp
{
    return [NSString stringWithFormat:@"%@ Ago", TXSpecialReadableTime([NSDate secondsSinceUnixTimestamp:timestamp], YES, nil)];
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
    [self.plugin loadDataSortedBy:@"timestamp"];
    [self.tableView reloadData];
    NSString *str = [[sender stringValue] lowercaseString];
    if ([str isEqualTo:@""]) {
        [self updateRecordsLabel];        
        NSAssertReturn(nil);
    }
    NSMutableArray *new = [[NSMutableArray alloc] init];
    for (NSDictionary *dict in self.dataSource){
        if ((networkSheet && [[[dict stringForKey:@"channel"] lowercaseString] rangeOfString:str].location != NSNotFound) ||
            [[[dict stringForKey:@"nick"] lowercaseString] rangeOfString:str].location != NSNotFound ||
            [[[dict stringForKey:@"url"] lowercaseString] rangeOfString:str].location != NSNotFound ||
            [[[dict stringForKey:@"title"] lowercaseString] rangeOfString:str].location != NSNotFound ||
            [[[self timeAgoString:[[dict objectForKey:@"timestamp"] doubleValue]] lowercaseString] rangeOfString:str].location != NSNotFound) {
            [new addObject:dict];
        }
    }
    self.dataSource = new;
    [self.tableView reloadData];
    [self updateRecordsLabel];
}

- (IBAction)disableDumping:(id)sender {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    NSMutableArray *disabledNetworks = [[NSMutableArray alloc] initWithArray:self.disabledNetworks];
    if([self.disableDumpingBox state] == 1)
        [disabledNetworks addObject:self.worldController.selectedClient.config.itemUUID];
    else
        [disabledNetworks removeObject:self.worldController.selectedClient.config.itemUUID];
    [dict setObject:disabledNetworks forKey:TXDumperDisabledNetworksKey];
    [self setPreferences:dict];
}

- (void)setWindowSizeWidth:(NSInteger)width height:(NSInteger)height
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:[NSNumber numberWithInteger:width] forKey:TXDumperSheetWidthKey];
    [dict setObject:[NSNumber numberWithInteger:height] forKey:TXDumperSheetHeightKey];
    [self setPreferences:dict];
}

- (void)setColumnWidths:(NSDictionary *)widths
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:widths forKey:TXDumperSheetColumnWidthsKey];
    [self setPreferences:dict];
}

#pragma mark -
#pragma mark DataSource

- (void)doubleClick:(id)object
{
    NSString *url = [[self.dataSource objectAtIndex:[self.tableView clickedRow]] objectForKey:@"url"];
    if(self.openInBrowser) {
        [TLOpenLink openWithString:url];
    } else {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
        BOOL ok = [pasteboard setString:url forType:NSStringPboardType];
        if (ok) {
            NSString *str = [NSString stringWithFormat:@"%@ has been copied to clipboard.", url];
            [self.plugin echo:str];
        }
    }
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
    return [self.dataSource count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
    if([aTableColumn.identifier isEqualToString:@"timestamp"]) {
        return [self timeAgoString:[[[self.dataSource objectAtIndex:rowIndex] objectForKey:aTableColumn.identifier] doubleValue]];
    }
    return [[self.dataSource objectAtIndex:rowIndex] objectForKey:aTableColumn.identifier];
}


#pragma mark -
#pragma mark Window Delegate

- (void)windowDidEndLiveResize:(NSNotification *)notification
{
        [self setWindowSizeWidth:(int)self.sheet.frame.size.width height:(int)self.sheet.frame.size.height];
}

#pragma mark -
#pragma mark TableView Delegate

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
    NSArray *newDescriptors = [self.tableView sortDescriptors];
    [self.dataSource sortUsingDescriptors:newDescriptors];
    [aTableView reloadData];
}

@end
