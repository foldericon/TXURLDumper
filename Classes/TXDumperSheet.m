//
//  TXDumperSheet.m
//  TXURLDumper
//
//  Created by Toby P on 5/27/13.
//
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.


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
