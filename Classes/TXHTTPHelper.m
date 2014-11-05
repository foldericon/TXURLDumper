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

#define _requestUserAgent @"Textual/1.0 (+http://www.codeux.com/textual)"

@implementation TXHTTPHelper

@synthesize receivedData, url, completionBlock;

- init {
    if ((self = [super init])) {
		
    }
    return self;
}



- (void)setDelegate:(id)val
{
    delegate = val;
}

- (id)delegate
{
    return delegate;
}

- (NSArray *)shortenerList {
    return @[@"bit.do", @"t.co", @"go2.do", @"adf.ly", @"goo.gl", @"bitly.com", @"tinyurl.com", @"ow.ly", @"bit.ly", @"adcrun.ch", @"zpag.es", @"ity.im", @"q.gs", @"link.co", @"viralurl.com", @"is.gd", @"vur.me", @"bc.vc", @"yu2.it", @"twitthis.com", @"u.to", @"j.mp", @"bee4.biz", @"adflav.com", @"buzurl.com", @"xlinkz.info", @"cutt.us", @"u.bb", @"yourls.org", @"fun.ly", @"hit.my", @"nov.io", @"crsco.com", @"x.co", @"shortquik.com", @"prettylinkpro.com", @"viralurl.biz", @"longurl.org", @"tota2.org", @"adcraft.co", @"virl.ws", @"scrnch.me", @"filoops.info", @"linkto.im", @"vurl.bz", @"fzy.co", @"vzturl.com", @"picz.us", @"lernde.fr", @"golinks.co", @"xtu.me", @"qr.net", @"1url.com", @"tweez.me", @"sk.gy", @"gog.li", @"cektkp.com", @"v.gd", @"p6l.org", @"id.tl", @"dft.ba", @"aka.gr", @"git.io"];
}

- (void)get:(NSURL *)theurl {
	
    self.url = theurl;
	receivedData = [[NSMutableData alloc] init];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]
							 initWithURL:self.url
							 cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
							 timeoutInterval: 60
							 ];


    [request setValue:_requestUserAgent forHTTPHeaderField:@"User-Agent"];
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    
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

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {

    self.finalURL = response.URL;
    NSNumber *length = [[response allHeaderFields] objectForKey:@"Content-Length"];
    if(length.integerValue > 2097152 || [response.MIMEType isNotEqualTo:@"text/html"]) {
        [connection cancel];
        if([self completionBlock])
            [self completionBlock]([NSError errorWithDomain:@"TXURLDumper" code:101 userInfo:nil]);
    }
    if([self.delegate resolveShortURLsEnabled] && [self.finalURL.absoluteString isNotEqualTo:self.url] && [self.shortenerList containsObject:self.url.host]) {
        [connection cancel];
        if([self completionBlock])
            [self completionBlock]([NSError errorWithDomain:@"TXURLDumper" code:102 userInfo:nil]);
    }
    if([self.delegate getTitlesEnabled] == NO) {
        [connection cancel];
        if([self completionBlock])
            [self completionBlock]([NSError errorWithDomain:@"TXURLDumper" code:101 userInfo:nil]);
    }
    [receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
    [receivedData appendData:data];
    NSString *dataStr=[[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding];
    if([dataStr contains:@"</title>"]) {
        [connection cancel];
        if([self completionBlock])
            [self completionBlock]([NSError errorWithDomain:@"TXURLDumper" code:100 userInfo:nil]);
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    if([self completionBlock])
        [self completionBlock]([NSError errorWithDomain:@"TXURLDumper" code:error.code userInfo:error.userInfo]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if([self completionBlock])
        [self completionBlock]([NSError errorWithDomain:@"TXURLDumper" code:101 userInfo:nil]);
}

@end