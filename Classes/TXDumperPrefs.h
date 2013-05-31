//
//  TXDumperPrefs.h
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


#import <Foundation/Foundation.h>

extern NSString *TXDumperDumpingEnabledKey;
extern NSString *TXDumperSelfDumpsEnabledKey;
extern NSString *TXDumperDebugModeEnabledKey;

@interface NSObject (TXDumperPrefs)

@property (assign) NSDictionary *preferences;
@property (readonly) NSString *preferencesPath;
@property (readonly) BOOL dumpingEnabled;
@property (readonly) BOOL selfDumpsEnabled;
@property (readonly) BOOL debugModeEnabled;
@end
