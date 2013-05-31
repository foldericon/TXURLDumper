//
//  TXDumperSheet.h
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


#import "TextualApplication.h"
#import "TXURLDumper.h"

@interface TXDumperSheet : NSObject <NSTableViewDataSource, NSTableViewDelegate>

@property (assign) id plugin;
@property (assign) NSArray *dataSource;
@property (assign) NSWindow *window;
@property (assign) IBOutlet NSWindow *sheet;
@property (assign) IBOutlet NSSearchField *searchBar;
@property (assign) IBOutlet NSTableView *tableView;
@property (assign) IBOutlet NSTextField *recordsLabel;
@property (assign) IBOutlet NSButton *clearButton;
@property (assign) IBOutlet NSButton *closeButton;

- (IBAction)clear:(id)sender;
- (IBAction)close:(id)sender;
- (IBAction)textEntered:(id)sender;

- (void)start;

@end