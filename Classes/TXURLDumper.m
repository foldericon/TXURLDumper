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

    // Legacy code to get titles enabled per default on older versions
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.preferences];
    if([dict objectForKey:TXDumperGetTitlesEnabledKey] == nil) {
        [dict setObject:[NSNumber numberWithBool:YES] forKey:TXDumperGetTitlesEnabledKey];
        [self setPreferences:dict];
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
    [self.titlesBox setState:(self.getTitlesEnabled ? NSOnState : NSOffState)];
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

static inline BOOL isEmpty(id thing) {
    return thing == nil
    || [thing isKindOfClass:[NSNull class]]
    || ([thing respondsToSelector:@selector(length)]
        && [(NSData *)thing length] == 0)
    || ([thing respondsToSelector:@selector(count)]
        && [(NSArray *)thing count] == 0);
}

- (void)createDBStructure
{
    [self updateDBWithSQL:@"CREATE TABLE IF NOT EXISTS urls (id integer primary key asc, timestamp integer(10), client char(36), channel varchar(255), nick varchar(32), url text)"];
    [self updateDBWithSQL:@"CREATE UNIQUE INDEX IF NOT EXISTS IDX_URLS_1 on urls (timestamp, client, channel, nick, url)"];

    NSMutableArray *data = [[NSMutableArray alloc] init];
    [self.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *s = [db executeQuery:@"SELECT title from urls"];
        while ([s next]) {
            [data addObject:[s resultDictionary]];
        }
    }];
    
    if(data.count > 0) return;
    
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
    NSString *urlString;
    for (NSArray *rn in urlAry) {
        NSRange r = NSRangeFromString(rn[0]);
        if(r.length > 0) {
            urlString = rn[1];
            if ([urlString hasSuffix:@"…"] == NO) {
                if([urlString hasPrefix:@"/r/"]) {
                    // Handle reddit short links
                    urlString = [NSString stringWithFormat:@"http://www.reddit.com%@", urlString];
                }
                if(self.doubleEntryHandling == 2 && [self checkDupe:urlString forClient:client withTimestamp:timestamp] == YES) {
                    return;
                }
                
                NSString *sql;
                if(self.doubleEntryHandling == 0 && [self checkDupe:urlString forClient:client withTimestamp:timestamp] == YES) {
                    [self updateDBWithSQL:@"UPDATE urls SET timestamp=:timestamp, channel=:channel, nick=:nick WHERE id=(SELECT max(id) from urls where client=:client AND url=:url)" withParameterDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                       timestamp, @"timestamp",
                                                                       channel, @"channel",
                                                                       nick, @"nick",
                                                                       client.config.itemUUID, @"client",
                                                                       urlString, @"url",
                                                                       nil]];
                } else {
                    sql = @"INSERT INTO urls (timestamp, client, channel, nick, url) VALUES (:timestamp, :client, :channel, :nick, :url)";
                    int errCode = [self updateDBWithSQL:sql withParameterDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                       timestamp, @"timestamp",
                                                                       client.config.itemUUID, @"client",
                                                                       channel, @"channel",
                                                                       nick, @"nick",
                                                                       urlString, @"url",
                                                                       nil]];
                    
                    if(errCode == 0) {
                        [self updateSheet];                        
                        if(self.resolveShortURLsEnabled || self.getTitlesEnabled) {
                            TXHTTPHelper *http = [[TXHTTPHelper alloc] init];
                            [http setDelegate:self];
                            [http setCompletionBlock:^(NSError *error) {
                                NSString *dataStr;
                                NSString *title;
                                switch (error.code){
                                    case 100: {
                                        // SUCCESS
                                        
                                        // Check if we already have a title
                                        __block BOOL dupe = NO;
                                        [self.queue inDatabase:^(FMDatabase *db) {
                                            FMResultSet *s = [db executeQuery:@"SELECT id from urls where url=? AND timestamp=? AND title IS NOT NULL", http.url.absoluteString, timestamp];
                                            while ([s next]) {
                                                dupe = YES;
                                            }
                                        }];
                                        
                                        if(dupe) break;
                                        
                                        dataStr=[[NSString alloc] initWithData:http.receivedData encoding:NSUTF8StringEncoding];
                                        title = [self scanString:dataStr startTag:@"<title>" endTag:@"</title>"];
                                        // Trim Whitespace
                                        title = [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                                        // Replace double space with single space
                                        title = [title stringByReplacingOccurrencesOfString:@"  " withString:@" "];
                                        // Replace newline characters with single space
                                        title = [[[[title gtm_stringByUnescapingFromHTML] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]] componentsJoinedByString:@" "];
                                        
                                        if(isEmpty(title)) {
                                            if(self.debugModeEnabled) {
                                                NSString *log = [NSString stringWithFormat:@"URL: %@ has been dumped.", http.url.absoluteString];
                                                [client printDebugInformationToConsole:log];
                                            }
                                            return;
                                        }
                                        
                                        [self updateDBWithSQL:@"UPDATE urls SET title=:title WHERE url=:url" withParameterDictionary:
                                         [NSDictionary dictionaryWithObjectsAndKeys:title, @"title", http.url.absoluteString, @"url", nil]];
                                        [self updateSheet];
                                        if(self.debugModeEnabled) {
                                            NSString *log = [NSString stringWithFormat:@"URL: %@ with title: \"%@\" has been dumped.", http.url.absoluteString, title];
                                            [client printDebugInformationToConsole:log];
                                        }
                                        break;
                                    }
                                    case 101: {
                                        // CANCEL
                                        [self updateSheet];                                        
                                        if(self.debugModeEnabled) {
                                            NSString *log = [NSString stringWithFormat:@"URL: %@ has been dumped.", http.url.absoluteString];
                                            [client printDebugInformationToConsole:log];
                                        }
                                        break;
                                    }
                                    case 102: {
                                        // REDIRECT
                                        if(self.doubleEntryHandling == 2 && [self checkDupe:http.finalURL.absoluteString forClient:client withTimestamp:timestamp] == YES) {
                                            [self updateDBWithSQL:@"DELETE FROM urls WHERE url=:url" withParameterDictionary:
                                             [NSDictionary dictionaryWithObjectsAndKeys:http.url.absoluteString, @"url", nil]];
                                            return;
                                        } else if(self.doubleEntryHandling == 0 && [self checkDupe:http.finalURL.absoluteString forClient:client withTimestamp:timestamp] == YES) {
                                            [self updateDBWithSQL:@"DELETE FROM urls WHERE url=:url" withParameterDictionary:
                                             [NSDictionary dictionaryWithObjectsAndKeys:http.url.absoluteString, @"url", nil]];
                                            [self updateDBWithSQL:@"UPDATE urls SET timestamp=:timestamp, nick=:nick, channel=:channel WHERE client=:client AND url=:url" withParameterDictionary:
                                             [NSDictionary dictionaryWithObjectsAndKeys:timestamp, @"timestamp", nick, @"nick", channel, @"channel", http.finalURL.absoluteString, @"url", client.uniqueIdentifier, @"client", nil]];
                                        } else {
                                            [self updateDBWithSQL:@"UPDATE urls SET url=:finalurl WHERE url=:url" withParameterDictionary:
                                             [NSDictionary dictionaryWithObjectsAndKeys:http.finalURL.absoluteString, @"finalurl", http.url.absoluteString, @"url", nil]];
                                        }
                                        [http get:http.finalURL];
                                        break;
                                    }
                                    case 103: {
                                        // ERROR
                                        NSLog(@"Error receiving response: %@", error);                                    
                                        break;
                                    }
                                }
                            }];
                            [http get:[NSURL URLWithString:urlString]];
                        } else if(self.debugModeEnabled) {
                            NSString *log = [NSString stringWithFormat:@"URL: %@ has been dumped.", urlString];
                            [client printDebugInformationToConsole:log];
                        }
                    }
                }
            }
        }
    }
}

- (void)updateSheet
{
    if(self.dumperSheetVisible) {
        NSString *col = [[dumperSheet.tableView.tableColumns objectAtIndex:dumperSheet.tableView.selectedColumn] identifier];
        [dumperSheet loadDataSortedBy:col];
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
    IRCTreeItem *channel = self.worldController.selectedItem;
    if(channel.isClient == NO) {
        dumperSheet.networkLabel.stringValue = [dumperSheet.networkLabel.stringValue stringByAppendingFormat:@"%@ on %@", channel.name, client.altNetworkName];
    } else {
        dumperSheet.networkLabel.stringValue = [dumperSheet.networkLabel.stringValue stringByAppendingFormat:@"%@", client.altNetworkName];
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

- (BOOL)checkDupe:(NSString *)url forClient:(IRCClient *)client withTimestamp:(NSNumber *)timestamp
{
    BOOL dupe = NO;
    NSMutableArray *data = [[NSMutableArray alloc] init];
    [self.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *s = [db executeQuery:@"SELECT id from urls where url=? AND client=? AND timestamp<>?", url, client.config.itemUUID, timestamp];
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

- (int)updateDBWithSQL:(NSString *)sql withParameterDictionary:(NSDictionary *)dict
{
    __block int code = 0;
    [self.queue inTransaction:^(FMDatabase *db, BOOL *rollback) {
        BOOL ret = NO;
        ret = [db executeUpdate:sql withParameterDictionary:dict];
        if (!ret) {
            if([db.lastErrorMessage isNotEqualTo:@"columns timestamp, client, channel, nick, url are not unique"]){
                // Don't show unique index errors when we get scrollback buffers.
                if(self.debugModeEnabled) [self echo:@"TXURLDumper: Transaction failed: %@", db.lastErrorMessage];
            }
            code = db.lastErrorCode;
            *rollback = YES;
            return;
        }
    }];
    return code;
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

- (IBAction)setResolveShortURLs:(id)sender {
    BOOL enabled = ([self.shortenerBox state]==NSOnState);
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:[NSNumber numberWithBool:enabled] forKey:TXDumperResolveShortURLsEnabledKey];
    [self setPreferences:dict];
}

- (IBAction)setGetTitles:(id)sender {
    BOOL enabled = ([self.titlesBox state]==NSOnState);
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:[self preferences]];
    [dict setObject:[NSNumber numberWithBool:enabled] forKey:TXDumperGetTitlesEnabledKey];
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
