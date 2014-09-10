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
@synthesize networkSheet;

BOOL yosemiteorlater=NO;

- (id)init
{
	if ((self = [super init])) {
        [[NSBundle bundleForClass:[self class]] loadNibNamed:@"DumperSheet" owner:self topLevelObjects:nil];
    }
    NSProcessInfo *pinfo = [NSProcessInfo processInfo];
    NSArray *myarr = [[pinfo operatingSystemVersionString] componentsSeparatedByString:@" "];
    if([[myarr objectAtIndex:1] hasPrefix:@"10.8"] == NO && [[myarr objectAtIndex:1] hasPrefix:@"10.9"] == NO) {
        yosemiteorlater=YES;
        [self.searchBar setHidden:NO];
        [self.searchBar2 setHidden:YES];
    }
	return self;
}

- (void)awakeFromNib
{

    [self.tableView setDataSource:self];
    [self.tableView setDelegate:self];
    [self.tableView setDoubleAction:@selector(doubleClick:)];
    
    // Setup sort descriptors
    for (NSTableColumn *tableColumn in self.tableView.tableColumns ) {
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:tableColumn.identifier ascending:YES selector:@selector(localizedStandardCompare:)];
        [tableColumn setSortDescriptorPrototype:sortDescriptor];
    }
    // Initial sorting
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:self.sortBy ascending:self.sortAscending];
    [self.tableView setSortDescriptors:[NSArray arrayWithObject:sortDescriptor]];

}

- (void)start
{
    if([self.masterController.mainWindow.selectedItem isClient] == NO) {
        [self.tableView removeTableColumn:[self.tableView tableColumnWithIdentifier:@"channel"]];
        if(self.masterController.mainWindow.selectedChannel.isChannel)
            [self.disableDumpingBox setTitle:@"Disable dumping for this channel"];
        else
            [self.disableDumpingBox setTitle:@"Disable dumping for this query"];
        networkSheet = NO;
    } else {
        [self.disableDumpingBox setTitle:@"Disable dumping for this network"];
        networkSheet = YES;
    }

    // Build Header Contextual Menu
    NSMenu *columnsMenu = [[NSMenu alloc] initWithTitle:@""];
    for (NSTableColumn *column in self.tableView.tableColumns) {
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[column.headerCell stringValue]
                                                          action:@selector(toggleColumn:)
                                                   keyEquivalent:@""];
        menuItem.target = self;
        menuItem.representedObject = column;
        [columnsMenu addItem:menuItem];
        if([self.hiddenColumns containsObject:column.identifier])
            [column setHidden:YES];
    }
    columnsMenu.delegate = self;
    [self.tableView.headerView setMenu:columnsMenu];
    
    // Get Sizes
    NSDictionary *columns = [self columnWidths];
    if (columns != nil) {
        for (NSTableColumn *column in self.tableView.tableColumns) {
            if(columns[column.identifier] != nil)
                column.width = [columns[column.identifier] floatValue];
        }
    }
    if(networkSheet) {
        if([self.disabledNetworks containsObject:self.masterController.mainWindow.selectedClient.config.itemUUID])
            [self.disableDumpingBox setState:1];
        else
            [self.disableDumpingBox setState:0];
    } else {
        if([self.disabledChannels containsObject:self.masterController.mainWindow.selectedChannel.config.itemUUID])
            [self.disableDumpingBox setState:1];
        else
            [self.disableDumpingBox setState:0];
    }
    
    NSRect rect = NSMakeRect(self.sheet.frame.origin.x, self.sheet.frame.origin.y, self.dumperSheetWidth, self.dumperSheetHeight);
    [self.sheet setFrame:rect display:YES];
    [self loadData];
    [self.window makeKeyAndOrderFront:self.sheet];
    if(yosemiteorlater) [self.sheet makeFirstResponder:self.searchBar];
    else [self.sheet makeFirstResponder:self.searchBar2];
	[self startSheetWithWindow:self.window];
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
    [self.plugin setDumperSheetVisible:NO];
    self.dataSource = nil;
	[NSApp endSheet:self.sheet];
    [self.sheet close];
}

- (void)sheetDidEnd:(NSWindow *)sender returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[self.sheet close];
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    
    // Save Columns Sizes
    NSMutableDictionary *dict = [[NSMutableDictionary alloc] init];
    for (NSTableColumn *column in self.tableView.tableColumns) {
        [dict setObject:[NSNumber numberWithFloat:column.width] forKey:column.identifier];
    }
    [prefs setObject:dict forKey:TXDumperSheetColumnWidthsKey];

    
    // Save sorting
    NSSortDescriptor *sortDescriptor = [[self.tableView sortDescriptors] objectAtIndex:0];
    [prefs setObject:sortDescriptor.key forKey:TXDumperSheetSortByKey];
    [prefs setObject:[NSNumber numberWithBool:sortDescriptor.ascending] forKey:TXDumperSheetSortAscendingKey];
    [self setPreferences:prefs];
}

- (void)loadData
{
    [self.plugin loadData];
    [self.dataSource sortUsingDescriptors:self.tableView.sortDescriptors];
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
    return [NSString stringWithFormat:@"%@ ago", TXHumanReadableTimeInterval([NSDate secondsSinceUnixTimestamp:timestamp], YES, 0)];
}

#pragma mark -
#pragma mark Actions
- (void)AlertHasConfirmed:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == 1){
        self.dataSource = nil;
        [self.tableView setNeedsDisplay:YES];
        [self.tableView reloadData];
        [self updateRecordsLabel];
        [self.plugin clearList];
    }
}

- (IBAction)clear:(id)sender {
    NSString *msg = @"Do you really want to clear the list and lose all dumped URLs for the selected channel?";
    if(networkSheet)
        msg = [msg stringByReplacingOccurrencesOfString:@"channel" withString:@"network"];
    
    NSAlert *alert = [NSAlert alertWithMessageText:msg
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

- (IBAction)textEntered:(id)sender
{
    [self loadData];
    NSString *str = [[sender stringValue] lowercaseString];
    self.searchString = str;
    if ([str isEqualTo:@""]) {
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
    NSMutableArray *disabledChannels = [[NSMutableArray alloc] initWithArray:self.disabledChannels];
    if(networkSheet) {
        IRCClient *cl = self.masterController.mainWindow.selectedClient;
        if([self.disableDumpingBox state] == 1) {
            for(IRCChannel *ch in cl.channelList) {
                [disabledChannels addObject:ch.config.itemUUID];
            }
            [disabledNetworks addObject:cl.config.itemUUID];
        } else {
            for(IRCChannel *ch in cl.channelList) {
                [disabledChannels removeObject:ch.config.itemUUID];
            }
            [disabledNetworks removeObject:cl.config.itemUUID];
        }
    } else {
        IRCChannel *ch = self.masterController.mainWindow.selectedChannel;
        if([self.disableDumpingBox state] == 1) {
            [disabledChannels addObject:ch.config.itemUUID];
        }
        else {
            [disabledNetworks removeObject:ch.associatedClient];
            [disabledChannels removeObject:ch.config.itemUUID];
        }
    }
    [dict setObject:disabledNetworks forKey:TXDumperDisabledNetworksKey];
    [dict setObject:disabledChannels forKey:TXDumperDisabledChannelsKey];
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

- (void)toggleColumn:(id)sender
{
    NSMutableArray *hiddenColumns = [[NSMutableArray alloc] initWithArray:self.hiddenColumns];
    NSTableColumn *column = [sender representedObject];
    [column setHidden:![column isHidden]];
    if([self.hiddenColumns containsObject:column.identifier])
        [hiddenColumns removeObject:column.identifier];
    else
        [hiddenColumns addObject:column.identifier];
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:hiddenColumns forKey:TXDumperSheetHiddenColumnsKey];
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
#pragma mark Menu Delegate

-(void)menuWillOpen:(NSMenu *)menu
{
    for (NSMenuItem *menuItem in menu.itemArray) {
        NSTableColumn *column = [menuItem representedObject];
        [menuItem setState:column.isHidden ? NSOffState : NSOnState];
    }
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
