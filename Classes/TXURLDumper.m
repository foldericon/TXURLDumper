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


#import "TXURLDumper.h"
#import "TXHTTPHelper.h"

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

    NSString *title;
    if([[TPCPreferences gitCommitCount] intValue] > 2570) {
        title=@"File Transfers";
    } else {
        title=@"Highlight List";
    }
    
    int i=0;
    for (NSMenuItem *item in [windowMenu itemArray]) {
        if([item.title isEqualTo:title]){
            break;
        }
        i++;
    }
    
    NSMenuItem *menuItem = [NSMenuItem menuItemWithTitle:@"URL List" target:self action:@selector(showDumper:) keyEquivalent:[NSString stringWithFormat:@"%i", i-9] keyEquivalentMask:NSControlKeyMask];
    [windowMenu insertItem:menuItem atIndex:i+1];
 
}


- (void)pluginUnloadedFromMemory {
    NSMenu *windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"Window"] submenu];
    NSMenuItem *item = [windowMenu itemWithTitle:@"URL List"];
    [windowMenu removeItem:item];
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
    [self.enableBox setState:(self.dumpingEnabled ? NSOnState : NSOffState)];
    [self.selfDumpsBox setState:(self.selfDumpsEnabled ? NSOnState : NSOffState)];
    [self.debugBox setState:(self.debugModeEnabled ? NSOnState : NSOffState)];
    [self.matchingBox selectItemWithTag:(self.strictMatching ? 1 : 0)];
    [self.doubleClickActionBox selectItemWithTag:(self.openInBrowser ? 1 : 0)];
    [self.doubleEntryHandlingBox selectItemWithTag:self.doubleEntryHandling];
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

- (NSArray *)pluginSupportsServerInputCommands
{
	return @[@"privmsg"];
}

#pragma mark -
#pragma mark Private API

- (void)createDBStructure
{
    [self updateDBWithSQL:@"CREATE TABLE IF NOT EXISTS urls (id integer primary key asc, timestamp integer(10), client char(36), channel varchar(255), nick varchar(32), url text)"];
    [self updateDBWithSQL:@"CREATE UNIQUE INDEX IF NOT EXISTS IDX_URLS_1 on urls (timestamp, client, channel, nick, url)"];
    [self updateDBWithSQL:@"ALTER TABLE urls ADD COLUMN title text"];
}

- (void)resetDBStructure
{
    [self updateDBWithSQL:@"DROP INDEX IDX_URLS_1 on urls"];
    [self updateDBWithSQL:@"DROP TABLE urls"];
    [self createDBStructure];
}

- (void)dumpURLsFromMessage:(NSString *)message client:(IRCClient *)client time:(NSDate *)time channel:(NSString *)channel nick:(NSString *)nick
{
    if(self.dumpingEnabled == NO || [self.disabledNetworks containsObject:client.config.itemUUID]) NSAssertReturn(nil);
    if([channel isEqualToString:self.worldController.selectedClient.localNickname]) {
        channel = nick;
    }
    NSNumber *timestamp = [NSNumber numberWithDouble:[time timeIntervalSince1970]];
	AHHyperlinkScanner *scanner = [AHHyperlinkScanner new];
    NSArray *urlAry;
    if(self.strictMatching)
        urlAry = [scanner strictMatchesForString:message];
    else
        urlAry = [scanner matchesForString:message];
    NSString *url;
    for (NSString *rn in urlAry) {
        NSRange r = NSRangeFromString(rn);
        if(r.length > 0) {
            url = [[message substringFromIndex:r.location] substringToIndex:r.length];
            if ([url hasSuffix:@"…"] == NO) {
                if([url hasPrefix:@"/r/"]) {
                    // Handle reddit short links
                    url = [NSString stringWithFormat:@"http://www.reddit.com%@", url];
                }
                if(self.doubleEntryHandling == 2 && [self checkDupe:url forClient:client] == YES) {
                    return;
                }
                
                NSString *sql;
                if(self.doubleEntryHandling == 0 && [self checkDupe:url forClient:client] == YES) {
                    sql = [NSString stringWithFormat:@"UPDATE urls SET timestamp=:timestamp, channel=:channel, nick=:nick WHERE id=(SELECT max(id) from urls where client='%@' AND url='%@')", client.config.itemUUID, url];
                    [self updateDBWithSQL:sql withParameterDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                       timestamp, @"timestamp",
                                                                       channel, @"channel",
                                                                       nick, @"nick",
                                                                       nil]];
                } else {
                    sql = @"INSERT INTO urls (timestamp, client, channel, nick, url) VALUES (:timestamp, :client, :channel, :nick, :url)";
                    [self updateDBWithSQL:sql withParameterDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                       timestamp, @"timestamp",
                                                                       client.config.itemUUID, @"client",
                                                                       channel, @"channel",
                                                                       nick, @"nick",
                                                                       url, @"url",
                                                                       nil]];
                    TXHTTPHelper *http = [[TXHTTPHelper alloc] init];
                    http.delegate = self;
                    http.client = client;
                    [http get:url];
                }
            }
        }
    }
}

- (void)didFinishDownload:(NSArray *)array
{
    NSString *sql = [NSString stringWithFormat:@"UPDATE urls SET title=:title WHERE url='%@'", array[1]];
    NSString *title = [self scanString:array[2] startTag:@"<title>" endTag:@"</title>"];
    // Replace double space with single space
    title = [title stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    // Replace newline characters with single space
    title = [[[title componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]] componentsJoinedByString:@" "];
    [self updateDBWithSQL:sql withParameterDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                       [title gtm_stringByUnescapingFromHTML], @"title",
                                                       nil]];
    
    if(self.debugModeEnabled) {
        IRCClient *client = array[0];
        NSString *log = [NSString stringWithFormat:@"URL: %@ with title: \"%@\" has been dumped.", array[1], title];
        [client printDebugInformationToConsole:log];
    }
}

- (void)didCancelDownload:(NSArray *)ret
{
    if(self.debugModeEnabled) {
        IRCClient *client = ret[0];
        NSString *log = [NSString stringWithFormat:@"URL: %@ has been dumped.", ret[1]];
        [client printDebugInformationToConsole:log];
    }
}

- (NSString *)scanString:(NSString *)string startTag:(NSString *)startTag endTag:(NSString *)endTag
{
    
    NSString* scanString = @"";
    
    if (string.length > 0) {
        
        NSScanner* scanner = [[NSScanner alloc] initWithString:string];
            
        @try {
            [scanner scanUpToString:startTag intoString:nil];
            scanner.scanLocation += [startTag length];
            [scanner scanUpToString:endTag intoString:&scanString];
        }
        @catch (NSException *exception) {
            return nil;
        }
        @finally {
            return scanString;
        }
    }
    return scanString;
}

- (void)showDumperForClient:(IRCClient *)client
{
    dumperSheet = [[TXDumperSheet alloc] init];
    dumperSheet.window = self.masterController.mainWindow;
    dumperSheet.networkLabel.stringValue = [dumperSheet.networkLabel.stringValue stringByAppendingFormat:@" %@", client.altNetworkName];
    IRCTreeItem *channel = self.worldController.selectedItem;
    if([channel isClient] == NO) {
        dumperSheet.networkLabel.stringValue = [dumperSheet.networkLabel.stringValue stringByAppendingFormat:@" > %@", channel.name];
    }
    dumperSheet.plugin = self;
    [dumperSheet start];
}

- (void)loadDataSortedBy:(NSString *)column
{
    IRCClient *client = self.worldController.selectedClient;
    NSMutableArray *data = [[NSMutableArray alloc] init];

    [self.queue inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT channel,nick,url,title,timestamp FROM urls WHERE client=? ORDER BY %@ DESC;", column];
        FMResultSet *s = [db executeQuery:sql, client.config.itemUUID];
        if([self.worldController.selectedItem isClient] == NO) {
            sql = [NSString stringWithFormat:@"SELECT channel,nick,url,title,timestamp FROM urls WHERE client=? AND channel=? ORDER BY %@ DESC;", column];
            s = [db executeQuery:sql, client.config.itemUUID, self.worldController.selectedItem.name];
        }
        while ([s next]) {
            NSDictionary *dict = @{ @"channel"      : [s stringForColumn:@"channel"],
                                    @"nick"         : [s stringForColumn:@"nick"],
                                    @"url"          : [s stringForColumn:@"url"],
                                    @"title"        : [s stringForColumn:@"title"] ? [s stringForColumn:@"title"] : @"",
                                    @"timestamp"    : [s stringForColumn:@"timestamp"],
                                 };
            [data addObject:dict];
        }
    }];
    dumperSheet.dataSource = data;
}

- (BOOL)checkDupe:(NSString *)url forClient:(IRCClient *)client
{
    BOOL dupe = NO;
    NSMutableArray *data = [[NSMutableArray alloc] init];
    [self.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *s = [db executeQuery:@"SELECT id from urls where url=? AND client=?", url, client.config.itemUUID];
        while ([s next]) {
            [data addObject:[s resultDictionary]];
        }
    }];
    if([data count] > 0) dupe = YES;
    return dupe;
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

- (IBAction)setMatching:(id)sender {
    BOOL enabled = NO;
    if([self.matchingBox tag] == 1) {
        enabled = YES;
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:[NSNumber numberWithBool:enabled] forKey:TXDumperStrictMatchingEnabledKey];
    [self setPreferences:dict];
}

- (IBAction)setDoubleClickAction:(id)sender {
    BOOL enabled = NO;
    if([self.doubleClickActionBox tag] == 1) {
        enabled = YES;
    }
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:[NSNumber numberWithBool:enabled] forKey:TXDumperOpenInBrowserEnabledKey];
    [self setPreferences:dict];
}

- (IBAction)setDoubleEntryHandling:(id)sender {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:[NSNumber numberWithInteger:[self.doubleEntryHandlingBox tag]] forKey:TXDumperDoubleEntryHandlingKey];
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
