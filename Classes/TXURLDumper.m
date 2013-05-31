//
//  TXURLDumper.m
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
}

- (void)pluginUnloadedFromMemory {
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

#pragma mark -
#pragma mark Plugin API

- (void)messageReceivedByServer:(IRCClient *)client
						 sender:(NSDictionary *)senderDict
						message:(NSDictionary *)messageDict
{
	NSString *message = [messageDict objectForKey:@"messageSequence"];
    NSString *nick = [senderDict objectForKey:@"senderNickname"];
    NSString *channel = [[messageDict objectForKey:@"messageParamaters"] objectAtIndex:0];
    NSNumber *time = [NSNumber numberWithInt:(int)[[messageDict objectForKey:@"messageReceived"] timeIntervalSince1970]];
    
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
                                              time, @"timestamp",
                                              client.config.itemUUID, @"client",
                                              channel, @"channel",
                                              nick, @"nick",
                                              url, @"url",
                                              nil];
                [self updateDBWithSQL:@"INSERT INTO urls (timestamp, client, channel, nick, url) VALUES (:timestamp, :client, :channel, :nick, :url);" withParameterDictionary:argsDict];
                if(self.debugModeEnabled) [self echo:@"URL: %@ has been dumped.", url];
            }
        }
    }
}

- (void)messageSentByUser:(IRCClient *)client
                  message:(NSString *)messageString
                  command:(NSString *)commandString
{
    dumperSheet = [[TXDumperSheet alloc] init];
    dumperSheet.window = self.masterController.mainWindow;
    dumperSheet.plugin = self;
    [dumperSheet start];
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

- (void)loadData
{
    IRCClient *client = self.worldController.selectedClient;
    NSMutableArray *data = [[NSMutableArray alloc] init];
    [self.queue inDatabase:^(FMDatabase *db) {
        FMResultSet *s = [db executeQuery:@"SELECT * from urls where client=? order by timestamp desc", client.config.itemUUID];
        while ([s next]) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:[s doubleForColumn:@"timestamp"]];
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [s stringForColumn:@"channel"], @"channel",
                                  [s stringForColumn:@"nick"], @"nick",
                                  [s stringForColumn:@"url"], @"url",
                                  [self createHumanReadableTimeStringFromDate:date], @"time",
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

- (NSString *)createHumanReadableTimeStringFromDate:(NSDate *)date
{
    NSTimeInterval diff = [[NSDate date] timeIntervalSinceDate:date];
    double time;
    NSString *unit;
    if(diff >= 86400) {
        time = ceil(round(diff/86400));
        unit = time > 1 ? @"Days" : @"Day";
    } else if(diff >= 3600) {
        time = ceil(round(diff/3600));
        unit = time > 1 ? @"Hours" : @"Hour";
    } else if (diff >= 60) {
        time = ceil(round(diff/60));
        unit = time > 1 ? @"Minutes" : @"Minute";
    } else {
        time = ceil(diff);
        unit = time > 1 ? @"Seconds" : @"Second";
    }
    return [NSString stringWithFormat:@"%i %@ Ago", (int)time, unit];
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
