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


#import "TXDumperPrefs.h"

NSString *TXDumperDumpingEnabledKey = @"TXDumperDumpingEnabled";
NSString *TXDumperSelfDumpsEnabledKey = @"TXDumperSelfDumpsEnabled";
NSString *TXDumperDebugModeEnabledKey = @"TXDumperDebugModeEnabled";
NSString *TXDumperStrictMatchingEnabledKey = @"TXDumperStrictMatchingEnabled";
NSString *TXDumperOpenInBrowserEnabledKey = @"TXDumperOpenInBrowserEnabled";
NSString *TXDumperDoubleEntryHandlingKey = @"TXDumperDoubleEntryHandling";
NSString *TXDumperSheetWidthKey = @"TXDumperSheetWidth";
NSString *TXDumperSheetHeightKey = @"TXDumperSheetHeight";
NSString *TXDumperDisabledNetworksKey = @"TXDumperDisabledNetworks";

@implementation NSObject (TXDumperPrefs)
- (NSDictionary *)preferences
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self preferencesPath]])
    {
        NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                              @"yes", TXDumperDumpingEnabledKey,
                              @"yes", TXDumperSelfDumpsEnabledKey,
                              @"no", TXDumperDebugModeEnabledKey,
                              @"no", TXDumperStrictMatchingEnabledKey,
                              @"no", TXDumperOpenInBrowserEnabledKey,
                              @"0", TXDumperDoubleEntryHandlingKey,
                              @"778", TXDumperSheetWidthKey,
                              @"350", TXDumperSheetHeightKey,
                              [NSArray array], TXDumperDisabledNetworksKey,
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

- (BOOL)selfDumpsEnabled
{
    return [[self.preferences objectForKey:TXDumperSelfDumpsEnabledKey] boolValue];
}

- (BOOL)debugModeEnabled
{
    return [[self.preferences objectForKey:TXDumperDebugModeEnabledKey] boolValue];
}

- (BOOL)strictMatching
{
    return [[self.preferences objectForKey:TXDumperStrictMatchingEnabledKey] boolValue];
}

- (BOOL)openInBrowser
{
    return [[self.preferences objectForKey:TXDumperOpenInBrowserEnabledKey] boolValue];
}

- (NSInteger)doubleEntryHandling
{
    return [[self.preferences objectForKey:TXDumperDoubleEntryHandlingKey] integerValue];
}

- (NSInteger)dumperSheetWidth
{
    return [[self.preferences objectForKey:TXDumperSheetWidthKey] integerValue];
}

- (NSInteger)dumperSheetHeight
{
    return [[self.preferences objectForKey:TXDumperSheetHeightKey] integerValue];
}

- (NSArray *)disabledNetworks
{
    return [self.preferences objectForKey:TXDumperDisabledNetworksKey];
}

@end
