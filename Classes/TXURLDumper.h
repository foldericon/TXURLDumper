//
//  TXURLDumper.h
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


#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "AutoHyperlinks/AutoHyperlinks.h"
#import "TextualApplication.h"
#import "TXDumperPrefs.h"
#import "TXDumperSheet.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "FMDatabaseQueue.h"

@interface TXURLDumper : NSObject

@property (nonatomic, strong) IBOutlet NSView *ourView;
@property (assign) IBOutlet NSButton *enableBox;
@property (assign) IBOutlet NSButton *debugBox;
@property (nonatomic, strong) FMDatabaseQueue *queue;

- (IBAction)setEnable:(id)sender;
- (IBAction)setDebugMode:(id)sender;
- (IBAction)resetDatabase:(id)sender;

- (void)pluginLoadedIntoMemory:(IRCWorld *)world;
- (void)pluginUnloadedFromMemory;

- (NSView *)preferencesView;
- (NSString *)preferencesMenuItemName;
- (void)clearDB;
- (void)messageReceivedByServer:(IRCClient *)client
						 sender:(NSDictionary *)senderDict
						message:(NSDictionary *)messageDict;

- (void)messageSentByUser:(IRCClient *)client
                  message:(NSString *)messageString
                  command:(NSString *)commandString;

- (NSArray *)pluginSupportsServerInputCommands;
- (NSArray *)pluginSupportsUserInputCommands;
- (void)loadData;
- (void)echo:(NSString *)msg,...;
@end
