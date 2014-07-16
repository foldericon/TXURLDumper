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

#import "TXSearchField.h"

@implementation TXSearchField

- (BOOL)becomeFirstResponder
{
    if (self.acceptsFirstResponder) {
        [self selectText:self];
        [self setNeedsDisplay:YES];
        return YES;
    }
    else {
        return NO;
    }
}

- (void)selectText:(id)sender
{
    NSText *t = [_window fieldEditor:YES forObject:self];
    if (t.superview == nil) {
        [self.cell selectWithFrame:NSMakeRect(10, 3, self.bounds.size.width-15, self.bounds.size.height-6)
                        inView:self
                        editor:[self.cell setUpFieldEditorAttributes:t]
                      delegate:self
                         start:0
                        length:(int)self.stringValue.length];
    }
}

- (void)awakeFromNib
{
    _magnifierImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:self.class] pathForResource:@"Magnifier" ofType:@"tiff"]];
}

- (void)drawRect:(NSRect) aFrame
{
    NSSize tSize = _magnifierImage.size;
    NSRect rect = NSMakeRect(0.0, 0.0, self.bounds.size.width, self.bounds.size.height-1.0);
    NSBezierPath* thePath = [NSBezierPath bezierPath];
    
    [thePath appendBezierPathWithRoundedRect:rect xRadius:6 yRadius:6];
    
    [[NSColor whiteColor] set];
    [thePath fill];
    [_magnifierImage drawInRect:NSMakeRect(6, 3, 15, 15) fromRect:NSMakeRect(0, 0, tSize.width, tSize.height) operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
}

- (void)textDidEndEditing:(NSNotification *)notification
{
    NSString *string = [[[_window fieldEditor:YES forObject:self] string] copy];
    [self.cell setStringValue:string];
    [self.cell endEditing:[notification object]];

    NSMutableDictionary *dict = [[NSMutableDictionary alloc] initWithDictionary:notification.userInfo];
    [dict setObject:notification.object forKey: @"NSFieldEditor"];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSControlTextDidEndEditingNotification
                                                    object:self
                                                  userInfo:dict];
    [self sendAction:self.action to:self.target];
    if(string.length != 0) {
        [self selectText:self];
        [self setNeedsDisplay:YES];
    }
}


- (void)setNeedsDisplay:(BOOL)aBool
{
    [super setNeedsDisplay:aBool];
}

@end