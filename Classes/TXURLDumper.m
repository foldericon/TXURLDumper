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


#import "TXURLDumper.h"

@implementation TXURLDumper

#pragma mark -
#pragma mark Memory Allocation & Deallocation

TXDumperSheet *dumperSheet;

- (void)pluginLoadedIntoMemory:(IRCWorld *)world
{
    if(!self.queue){
        self.queue = [FMDatabaseQueue databaseQueueWithPath:[self dbPath]];
        [self createDBStructure];
    }

    NSMenu *windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"Window"] submenu];
    NSMenuItem *menuItem = [NSMenuItem new];
    [menuItem setTitle:@"URL List"];
    [menuItem setTarget:self];
    [menuItem setAction:@selector(showDumper:)];
    [menuItem setKeyEquivalent:@"6"];
    
    int i=0;
    for (NSMenuItem *item in [windowMenu itemArray]) {
        if([item.title isEqualTo:@"Highlight List"]){
            break;
        }
        i++;
    }
    [windowMenu insertItem:menuItem atIndex:i+1];
 
}


- (void)pluginUnloadedFromMemory {
    NSMenu *windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"Window"] submenu];
    [windowMenu removeItem:[windowMenu itemWithTitle:@"URL List"]];
    [self.queue close];
}

#pragma mark -
#pragma mark Preference Pane

- (NSView *)preferencesView
{
	if (self.ourView == nil) {
		if ([NSBundle loadNibNamed:@"PreferencePane" owner:self] == NO) {
			NSLog(@"TXURLDumper: Failed to load view.");
		}
	}
	return self.ourView;
}

- (NSString *)preferencesMenuItemName
{
	return @"URL Dumper";
}

- (void)awakeFromNib
{
    [self.enableBox setState:([self dumpingEnabled] ? NSOnState : NSOffState)];
    [self.selfDumpsBox setState:([self selfDumpsEnabled] ? NSOnState : NSOffState)];
    [self.debugBox setState:([self debugModeEnabled] ? NSOnState : NSOffState)];
}

- (void)showDumper:(id)sender
{
    IRCClient *client = self.worldController.selectedClient;
    [self showDumperForClient:client];
}

#pragma mark -
#pragma mark Plugin API

- (void)messageReceivedByServer:(IRCClient *)client
						 sender:(NSDictionary *)senderDict
						message:(NSDictionary *)messageDict
{
    id date = [messageDict objectForKey:@"messageReceived"];
    if(!date) {
        date = [NSDate date];
    }
    [self dumpURLsFromMessage:[messageDict objectForKey:@"messageSequence"]
                       client:client
                         time:date
                      channel:[[messageDict objectForKey:@"messageParamaters"] objectAtIndex:0]
                         nick:[senderDict objectForKey:@"senderNickname"]
     ];
}

- (id)interceptUserInput:(id)input command:(NSString *)command
{
    if(self.selfDumpsEnabled == NO) {
        return input;
    }
    IRCChannel *channel = self.worldController.selectedChannel;
    if([command isEqualTo:@"PRIVMSG"]) {
        [self dumpURLsFromMessage:[input string]
                           client:channel.client
                             time:[NSDate date]
                          channel:channel.name
                             nick:channel.client.localNickname
         ];
    }
    return input;
}

- (void)messageSentByUser:(IRCClient *)client
                  message:(NSString *)messageString
                  command:(NSString *)commandString
{
    [self showDumperForClient:client];
}

- (NSArray *)pluginSupportsServerInputCommands
{
	return @[@"privmsg"];
}

- (NSArray *)pluginSupportsUserInputCommands
{
    return @[@"urls"];
}

#pragma mark -
#pragma mark Private API

- (void)createDBStructure
{
    [self updateDBWithSQL:@"CREATE TABLE IF NOT EXISTS urls (id integer primary key asc, timestamp integer(10), client char(36), channel varchar(255), nick varchar(32), url text)"];
    [self updateDBWithSQL:@"CREATE UNIQUE INDEX IF NOT EXISTS IDX_URLS_1 on urls (timestamp, client, channel, nick, url)"];
}

- (void)resetDBStructure
{
    [self updateDBWithSQL:@"DROP INDEX IDX_URLS_1on urls"];
    [self updateDBWithSQL:@"DROP TABLE urls"];
    [self createDBStructure];
}

- (void)dumpURLsFromMessage:(NSString *)message client:(IRCClient *)client time:(NSDate *)time channel:(NSString *)channel nick:(NSString *)nick
{
    NSNumber *timestamp = [NSNumber numberWithInt:(int)[time timeIntervalSince1970]];
	AHHyperlinkScanner *scanner = [AHHyperlinkScanner new];
    NSArray *urlAry = [scanner matchesForString:message];
    if (self.dumpingEnabled == NO || [urlAry count] < 1) {
        NSAssertReturn(nil);
    }
    NSString *url;
    
    for (NSString *rn in urlAry) {
        NSRange r = NSRangeFromString(rn);
        if(r.length > 0) {
            url = [[message substringFromIndex:r.location] substringToIndex:r.length];
            if ([url hasSuffix:@"…"] == NO) {
                NSDictionary *argsDict = [NSDictionary dictionaryWithObjectsAndKeys:
                                          timestamp, @"timestamp",
                                          client.config.itemUUID, @"client",
                                          channel, @"channel",
                                          nick, @"nick",
                                          url, @"url",
                                          nil];
                [self updateDBWithSQL:@"INSERT INTO urls (timestamp, client, channel, nick, url) VALUES (:timestamp, :client, :channel, :nick, :url);" withParameterDictionary:argsDict];
                if(self.debugModeEnabled) {
                    NSString *log = [NSString stringWithFormat:@"URL: %@ has been dumped.", url];
                    [client printDebugInformationToConsole:log];
                }
            }
        }
    }
}

- (void)showDumperForClient:(IRCClient *)client
{
    dumperSheet = [[TXDumperSheet alloc] init];
    dumperSheet.window = self.masterController.mainWindow;
    dumperSheet.networkLabel.stringValue = [dumperSheet.networkLabel.stringValue stringByAppendingFormat:@" \"%@\"", client.altNetworkName];
    dumperSheet.plugin = self;
    [dumperSheet start];
}

- (void)loadDataSortedBy:(NSString *)column order:(NSString*)order
{
    IRCClient *client = self.worldController.selectedClient;
    NSMutableArray *data = [[NSMutableArray alloc] init];
    [self.queue inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT channel,nick,url,timestamp FROM urls WHERE client=? ORDER BY %@ %@;", column, order];        
        FMResultSet *s = [db executeQuery:sql, client.config.itemUUID];
        while ([s next]) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:[s doubleForColumn:@"timestamp"]];
            NSString *timeString = [NSString stringWithFormat:@"%@ Ago",
                                    TXSpecialReadableTime([NSDate secondsSinceUnixTimestamp:[date timeIntervalSince1970]], YES, nil)];
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [s stringForColumn:@"channel"], @"channel",
                                  [s stringForColumn:@"nick"], @"nick",
                                  [s stringForColumn:@"url"], @"url",
                                  timeString, @"timestamp",
                                  nil];
            [data addObject:dict];
        }
    }];
    dumperSheet.dataSource = data;
}

- (BOOL)checkDupe:(NSString *)url
{
    [self.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *s = [db executeQuery:@"SELECT id from urls where url=?", url];
        while ([s next]) {
            NSAssertReturn(YES);
        }
    }];
    return NO;
}

- (void)updateDBWithSQL:(NSString *)sql withArgsArray:(NSArray *)array
{
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL ret = NO;
        ret = [db executeUpdate:sql withArgumentsInArray:array];
        if (!ret) {
            if(self.debugModeEnabled) [self echo:@"TXURLDumper: Transaction failed: %@", db.lastErrorMessage];
            *rollback = YES;
            return;
        }
    }];
}
- (void)updateDBWithSQL:(NSString *)sql withParameterDictionary:(NSDictionary *)dict
{
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL ret = NO;
        ret = [db executeUpdate:sql withParameterDictionary:dict];
        if (!ret) {
            if([db.lastErrorMessage isNotEqualTo:@"columns timestamp, client, channel, nick, url are not unique"]){
                // Don't show unique index errors when we get scrollback buffers.
                if(self.debugModeEnabled) [self echo:@"TXURLDumper: Transaction failed: %@", db.lastErrorMessage];
            }
            *rollback = YES;
            return;
        }
    }];
}

- (void)updateDBWithSQL:(NSString *)sql
{
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL ret = NO;
        ret = [db executeUpdate:sql];
        if (!ret) {
            if(self.debugModeEnabled) [self echo:@"TXURLDumper: Transaction failed: %@", db.lastErrorMessage];
            *rollback = YES;
            return;
        }
    }];
}

- (void)clearDB {
    IRCClient *client = self.worldController.selectedClient;
    [self updateDBWithSQL:@"DELETE FROM urls where client=?" withArgsArray:[NSArray arrayWithObject:client.config.itemUUID]];
}

- (void)echo:(NSString *)msg,...
{
    va_list args;
    va_start(args,msg);
    NSString *s=[[NSString alloc] initWithFormat:msg arguments:args];
    va_end(args);
    [self.worldController.selectedClient printDebugInformation:s forCommand:@"372"];
}

- (NSString *)dbPath
{
    return [[NSString stringWithFormat:@"%@/Library/Application Support/Textual IRC/Extensions/%@.db", NSHomeDirectory(), [[NSBundle bundleForClass:[self class]] principalClass]] stringByExpandingTildeInPath];
}

#pragma mark -
#pragma mark IBActions

- (IBAction)setEnable:(id)sender {
     BOOL enabled = ([self.enableBox state]==NSOnState);
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:[NSNumber numberWithBool:enabled] forKey:TXDumperDumpingEnabledKey];
    [self setPreferences:dict];
}

- (IBAction)setSelfDumps:(id)sender {
    BOOL enabled = ([self.selfDumpsBox state]==NSOnState);
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:[NSNumber numberWithBool:enabled] forKey:TXDumperSelfDumpsEnabledKey];
    [self setPreferences:dict];
}

- (IBAction)setDebugMode:(id)sender {
    BOOL enabled = ([self.debugBox state]==NSOnState);
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:[NSNumber numberWithBool:enabled] forKey:TXDumperDebugModeEnabledKey];
    [self setPreferences:dict];
}

- (void)AlertHasConfirmed:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == 1){
        [self resetDBStructure];
        [self echo:@"TXURLDumper: Database reset."];
    }
}

- (IBAction)resetDatabase:(id)sender {
    NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to reset the database and lose all dumped URLs?"
                                     defaultButton:@"OK"
                                   alternateButton:nil
                                       otherButton:@"Cancel"
                         informativeTextWithFormat:@"There is no way to undo this."];
    [alert beginSheetModalForWindow:self.preferencesView.window
                      modalDelegate:self
                     didEndSelector:@selector(AlertHasConfirmed:returnCode:contextInfo:)
                        contextInfo:nil];
}

@end
