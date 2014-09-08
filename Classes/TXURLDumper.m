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

- (void)pluginLoadedIntoMemory
{
    if(!self.queue){
        self.queue = [FMDatabaseQueue databaseQueueWithPath:[self dbPath]];
        [self createDBStructure];
    }
    
    NSMenu *windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"Window"] submenu];
    
    int i=0;
    int index = 0;
    for (NSMenuItem *item in [windowMenu itemArray]) {
        if([item.title isEqualTo:@"File Transfers"]){
            index = [item.keyEquivalent intValue];
            break;
        }
        i++;
    }
    NSMenuItem *menuItem = [NSMenuItem menuItemWithTitle:@"URL List" target:self action:@selector(showDumper:) keyEquivalent:[NSString stringWithFormat:@"%i", index+1] keyEquivalentMask:NSControlKeyMask];
    [windowMenu insertItem:menuItem atIndex:i+1];
 
}

- (void)pluginWillBeUnloadedFromMemory {
    NSMenu *windowMenu = [[[[NSApplication sharedApplication] mainMenu] itemWithTitle:@"Window"] submenu];
    NSMenuItem *item = [windowMenu itemWithTitle:@"URL List"];
    [windowMenu removeItem:item];
    [self.queue close];
}

#pragma mark -
#pragma mark Preference Pane

- (NSView *)pluginPreferencesPaneView
{
	if (self.ourView == nil) {
        if ([[NSBundle bundleForClass:[self class]] loadNibNamed:@"PreferencePane" owner:self topLevelObjects:nil] == NO) {
			NSLog(@"TXURLDumper: Failed to load view.");
		}
	}
	return self.ourView;
}

- (NSString *)pluginPreferencesPaneMenuItemName
{
	return @"URL Dumper";
}

- (void)awakeFromNib
{
    [self.enableBox setState:(self.dumpingEnabled ? NSOnState : NSOffState)];
    [self.selfDumpsBox setState:(self.selfDumpsEnabled ? NSOnState : NSOffState)];
    [self.shortenerBox setState:(self.resolveShortURLsEnabled ? NSOnState : NSOffState)];
    [self.titlesBox setState:(self.getTitlesEnabled ? NSOnState : NSOffState)];
    [self.debugBox setState:(self.debugModeEnabled ? NSOnState : NSOffState)];
    [self.matchingBox selectItemWithTag:(self.strictMatching ? 1 : 0)];
    [self.doubleClickActionBox selectItemWithTag:(self.openInBrowser ? 1 : 0)];
    [self.doubleEntryHandlingBox selectItemWithTag:self.doubleEntryHandling];
}

- (void)showDumper:(id)sender
{
    IRCClient *client = self.masterController.mainWindow.selectedClient;
    [self showDumperForClient:client];
}

#pragma mark -
#pragma mark Plugin API

- (void)didPostNewMessageForViewController:(TVCLogController *)logController
                               messageInfo:(NSDictionary *)messageInfo
                             isThemeReload:(BOOL)isThemeReload
                           isHistoryReload:(BOOL)isHistoryReload
{
    NSInteger lineType = (long)[[messageInfo objectForKey:@"lineType"] integerValue];
    
    // We want regular messages and actions only.
    if(lineType != 1 && lineType != 14) return;
    
    IRCClient *client = logController.associatedClient;
    NSString *channel = logController.associatedChannel.name;
    NSString *nick = [messageInfo objectForKey:@"senderNickname"];
    
    if(isThemeReload || isHistoryReload || self.dumpingEnabled == NO ||
       [self.disabledNetworks containsObject:client.config.itemUUID] ||
       [self.disabledChannels containsObject:[client findChannel:channel].config.itemUUID] ||
       ([nick isEqualToString:client.localNickname] && self.selfDumpsEnabled == NO))
        NSAssertReturn(nil);
    
    id date = [messageInfo objectForKey:@"receivedAtTime"];
    if(!date) {
        date = [NSDate date];
    }

    NSArray *arrLinks = [messageInfo objectForKey:@"allHyperlinksInBody"];

    // Any Links?
    if ([arrLinks count] < 1) return;
    
    if([channel isEqualToString:self.masterController.mainWindow.selectedClient.localNickname]) {
        channel = nick;
    }
    NSNumber *timestamp = [NSNumber numberWithDouble:[date timeIntervalSince1970]];
    NSString *urlString;
    for (NSArray *arr in arrLinks) {
        
        // Do we have a wild match?
        if(self.strictMatching && [[[messageInfo objectForKey:@"messageBody"] substringWithRange:NSRangeFromString(arr[0])] hasPrefix:@"http://"] == NO) break;
        
        urlString = arr[1];
        
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
                [self updateDBWithSQL:@"UPDATE urls SET timestamp=:timestamp, channel=:channel, nick=:nick WHERE id=(SELECT max(id) from urls where client=:client AND url=:url)" withParameterDictionary:
                [NSDictionary dictionaryWithObjectsAndKeys:
                  timestamp, @"timestamp",
                  channel, @"channel",
                  nick, @"nick",
                  client.config.itemUUID,
                  @"client", urlString,
                  @"url",
                 nil]];
            } else {
                sql = @"INSERT INTO urls (timestamp, client, channel, nick, url) VALUES (:timestamp, :client, :channel, :nick, :url)";
                int errCode = [self updateDBWithSQL:sql withParameterDictionary:
                               [NSDictionary dictionaryWithObjectsAndKeys:
                                timestamp, @"timestamp",
                                client.config.itemUUID, @"client",
                                channel, @"channel",
                                nick, @"nick",
                                urlString, @"url",
                                nil]];
                
                if(errCode == 0) {
                    if(self.resolveShortURLsEnabled || self.getTitlesEnabled) {
                        if([[urlString lowercaseString] hasSuffix:@".jpg"] || [[urlString lowercaseString] hasSuffix:@".png"] || [[urlString lowercaseString] hasSuffix:@".gif"]) {
                            if(self.debugModeEnabled) {
                                NSString *log = [NSString stringWithFormat:@"URL: %@ has been dumped.", urlString];
                                [client printDebugInformationToConsole:log];
                            }
                            return;
                        }
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
                    } else {
                        [self updateSheet];
                        if(self.debugModeEnabled) {
                            NSString *log = [NSString stringWithFormat:@"URL: %@ has been dumped.", urlString];
                            [client printDebugInformationToConsole:log];
                        }
                    }
                }
            }
            [self updateSheet];
        }
    }
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
    [self updateDBWithSQL:@"DROP INDEX IDX_URLS_1"];
    [self updateDBWithSQL:@"DROP TABLE urls"];
    [self createDBStructure];
}

- (void)updateSheet
{
    if(self.dumperSheetVisible) {
        [dumperSheet reloadData];
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
    IRCTreeItem *channel = self.masterController.mainWindow.selectedItem;
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
    IRCClient *client = self.masterController.mainWindow.selectedClient;
    NSMutableArray *data = [[NSMutableArray alloc] init];

    [self.queue inDatabase:^(FMDatabase *db) {
        NSString *sql = [NSString stringWithFormat:@"SELECT channel,nick,url,title,timestamp FROM urls WHERE client=? ORDER BY %@ DESC;", column];
        FMResultSet *s = [db executeQuery:sql, client.config.itemUUID];
        if([self.masterController.mainWindow.selectedItem isClient] == NO) {
            sql = [NSString stringWithFormat:@"SELECT channel,nick,url,title,timestamp FROM urls WHERE client=? AND channel=? ORDER BY %@ DESC;", column];
            s = [db executeQuery:sql, client.config.itemUUID, self.masterController.mainWindow.selectedItem.name];
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
        [db setLogsErrors:NO];
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

- (void)clearList {
    if(dumperSheet.networkSheet) {
        IRCClient *client = self.masterController.mainWindow.selectedClient;
        [self updateDBWithSQL:@"DELETE FROM urls where client=?" withArgsArray:[NSArray arrayWithObject:client.config.itemUUID]];
    } else {
        IRCClient *client = self.masterController.mainWindow.selectedClient;
        IRCChannel *channel = self.masterController.mainWindow.selectedChannel;
        [self updateDBWithSQL:@"DELETE FROM urls where client=? AND channel=?" withArgsArray:[NSArray arrayWithObjects:client.config.itemUUID, channel.name, nil]];
    }
}

- (void)echo:(NSString *)msg,...
{
    va_list args;
    va_start(args,msg);
    NSString *s=[[NSString alloc] initWithFormat:msg arguments:args];
    va_end(args);
    [self.masterController.mainWindow.selectedClient printDebugInformation:s];
}

- (NSString *)dbPath
{
    return [[NSString stringWithFormat:@"%@/Extensions/%@.db", [TPCPathInfo applicationSupportFolderPath], [[NSBundle bundleForClass:[self class]] principalClass]] stringByExpandingTildeInPath];
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
    // Toggle column
    NSMutableArray *hiddenColumns = [self.hiddenColumns mutableCopy];
    if(enabled) {
        [hiddenColumns removeObject:@"title"];
        [dict removeObjectForKey:TXDumperSheetColumnWidthsKey];
        
    } else {
        [hiddenColumns addObject:@"title"];
    }
    [dict setObject:hiddenColumns forKey:TXDumperSheetHiddenColumnsKey];
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
        [self updateSheet];
    }
}

- (IBAction)resetDatabase:(id)sender {
    NSAlert *alert = [NSAlert alertWithMessageText:@"Do you really want to reset the database and lose all dumped URLs?"
                                     defaultButton:@"OK"
                                   alternateButton:nil
                                       otherButton:@"Cancel"
                         informativeTextWithFormat:@"There is no way to undo this."];
    [alert beginSheetModalForWindow:self.pluginPreferencesPaneView.window
                      modalDelegate:self
                     didEndSelector:@selector(AlertHasConfirmed:returnCode:contextInfo:)
                        contextInfo:nil];
}

- (IBAction)github:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/foldericon/TXURLDumper"]];
}

@end
