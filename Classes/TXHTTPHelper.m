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


#import "TXHTTPHelper.h"

@implementation TXHTTPHelper

@synthesize receivedData;

- init {
    if ((self = [super init])) {
		
    }
    return self;
}

- (void)dealloc {
    [super dealloc];
}


- (void)setDelegate:(id)val
{
    delegate = val;
}

- (id)delegate
{
    return delegate;
}

- (void)get: (NSString *)urlString {
	
	self.receivedData = [[NSMutableData alloc] init];
    
    NSURLRequest *request = [[NSURLRequest alloc]
							 initWithURL: [NSURL URLWithString:urlString]
							 cachePolicy: NSURLRequestReloadIgnoringLocalCacheData
							 timeoutInterval: 60
							 ];

    NSURLConnection * connection = [[NSURLConnection alloc]
                                    initWithRequest:request
                                    delegate:self startImmediately:NO];
    
    [connection scheduleInRunLoop:[NSRunLoop mainRunLoop]
                          forMode:NSDefaultRunLoopMode];
    [connection start];

}


#pragma mark NSURLConnection delegate methods
- (NSURLRequest *)connection:(NSURLConnection *)connection
			 willSendRequest:(NSURLRequest *)request
			redirectResponse:(NSURLResponse *)redirectResponse {
    return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if([response.MIMEType isNotEqualTo:@"text/html"]) {
        [connection cancel];
        if ([delegate respondsToSelector:@selector(didCancelDownload:)]) {
            NSArray *responseArray = [NSArray arrayWithObjects:self.client, connection.currentRequest.URL.absoluteString, nil];
            [delegate performSelector:@selector(didCancelDownload:) withObject:responseArray];
        }
    }
    [receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [receivedData appendData:data];
    if((unsigned long)receivedData.length > 2097152) {
        [connection cancel];
        if ([delegate respondsToSelector:@selector(didCancelDownload:)]) {
            NSArray *responseArray = [NSArray arrayWithObjects:self.client, connection.currentRequest.URL.absoluteString, nil];
            [delegate performSelector:@selector(didCancelDownload:) withObject:responseArray];
        }
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Error receiving response: %@", error);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	
	NSString *dataStr=[[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    NSArray *responseArray = [NSArray arrayWithObjects:self.client, connection.currentRequest.URL.absoluteString, dataStr, nil];
	
    if ([delegate respondsToSelector:@selector(didFinishDownload:)]) {
		//NSString* dataAsString = [[[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding] autorelease];
		[delegate performSelector:@selector(didFinishDownload:) withObject:responseArray];
	}
 
}

@end