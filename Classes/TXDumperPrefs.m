//
//  TXDumperPrefs.m
//  TXURLDumper
//
//  Created by Toby P on 5/31/13.
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


#import "TXDumperPrefs.h"

NSString *TXDumperDumpingEnabledKey = @"TXDumperDumpingEnabled";
NSString *TXDumperDebugModeEnabledKey = @"TXDumperDebugModeEnabled";

@implementation NSObject (TXDumperPrefs)
- (NSDictionary *)preferences
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self preferencesPath]])
    {
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"yes", TXDumperDumpingEnabledKey,
                              @"no", TXDumperDebugModeEnabledKey,
                              nil];
        [self setPreferences:dict];
    }
    
    return [NSDictionary dictionaryWithContentsOfFile:[self preferencesPath]];
}

- (void)setPreferences:(NSDictionary *)dictionary
{
    [dictionary writeToFile:[self preferencesPath] atomically:YES];
}

- (NSString *)preferencesPath
{
    return [[NSString stringWithFormat:@"%@/Library/Preferences/%@.plist", NSHomeDirectory(), [[NSBundle bundleForClass:[self class]] bundleIdentifier]] stringByExpandingTildeInPath];
}

- (BOOL)dumpingEnabled
{
    return [[self.preferences objectForKey:TXDumperDumpingEnabledKey] boolValue];
}

- (BOOL)debugModeEnabled
{
    return [[self.preferences objectForKey:TXDumperDebugModeEnabledKey] boolValue];
}

@end
