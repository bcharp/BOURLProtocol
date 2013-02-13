//
//  BOURLProtocol.m
//  
//
//  Created by Boris Charpentier on 02/10/13.
//  Copyright (c) 2013 Boris Charpentier. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "BOURLProtocol.h"

static NSMutableSet *requests = nil;
static NSMutableDictionary *dico = nil;

static NSString * const kPARAMS = @"PARAMS";
static NSString * const kURL = @"URL";
static NSString * const kMIME_TYPE = @"MIMETYPE";
static NSString * const kDEFAULT_MIMETYPE = @"application/json";
static NSString * const kENCODING = @"UTF8";

@interface BOURLProtocol (Private)

+ (NSMutableSet *)requests;
+ (NSMutableDictionary *)subtitutionDictionary;
+ (NSURL *)stubURLForPath:(NSString *)paths;

+ (void)setPaths:(NSMutableSet *)newPaths;
+ (void)addPath:(NSString *)path;
+ (void)removePath:(NSString *)path;
+ (BOOL)hasPath:(NSString *)path;


@end

@implementation BOURLProtocol

/*****************************************************************************/
#pragma mark - Getters & Setters

+ (NSMutableSet *)requests
{
    return requests;
}

+ (void)setPaths:(NSMutableSet *)newPaths
{
    if (requests != newPaths)
    {
        requests = newPaths;
    }
}

+ (void)addPath:(NSString *)path
{
    //  lazily instantiate set
    if (requests == nil)
        [[self class] setPaths:[NSMutableSet set]];
    
    //  add request
    [requests addObject:path];
}


+ (void)removePath:(NSString *)path
{
    // remove request
    [requests removeObject:path];
    
    //  minimize memory footprint
    if ([requests count] == 0)
        [[self class] setPaths:nil];
}

+ (BOOL)hasPath:(NSString *)path
{
    return [requests containsObject:path];
}

+ (NSMutableDictionary *)subtitutionDictionary
{
    return dico;
}

/*****************************************************************************/
#pragma mark - Stubs

+ (void)stubPath:(NSString *)path execute:(BOURLProtocolBlock)block
{
    if (!path)
    {
        return;
    }
    
    if (dico == nil)
    {
        dico = [[NSMutableDictionary alloc] init];
    }
    
    [dico setObject:block forKey:path];
}

+ (void)stubPath:(NSString *)path withData:(NSData *)data
{
    if (!path)
    {
        return;
    }
    
    if (dico == nil)
    {
        dico = [[NSMutableDictionary alloc] init];
    }
    
    [dico setObject:data forKey:path];
}

+ (void)stubPath:(NSString *)path fail:(NSError *)error
{
    if (!path)
    {
        return;
    }
    
    if (dico == nil)
    {
        dico = [[NSMutableDictionary alloc] init];
    }
    
    [dico setObject:error forKey:path];
}

+ (void)stubPath:(NSString *)path load:(NSURL *)url
{
    [self stubPath:path parameters:nil mimeType:kDEFAULT_MIMETYPE load:url];
}

+ (void)stubPath:(NSString *)path mimeType:(NSString *)mimeType load:(NSURL *)url
{
    [self stubPath:path parameters:nil mimeType:mimeType load:url];
}

+ (void)stubPath:(NSString *)path parameters:(NSDictionary *)params mimeType:(NSString *)mimeType load:(NSURL *)url
{
    if (path == nil)
    {
        return;
    }
    
    if (dico == nil)
    {
        dico = [[NSMutableDictionary alloc] init];
    }
    
    NSMutableDictionary *mutParameters = [[NSMutableDictionary alloc] init];
    
    if (mimeType)
    {
        [mutParameters setObject:mimeType forKey:kMIME_TYPE];
    }
    
    if (url)
    {
        [mutParameters setObject:url forKey:kURL];
    }
    
    if (params)
    {
        [params enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
           
            if (![key isKindOfClass:[NSString class]])
            {
                NSLog(@"%@ MUST BE NSSring, BOURLPROTOCOL won't work correctly with your params",key);
            }
            
            if (![obj isKindOfClass:[NSString class]])
            {
               NSLog(@"%@ MUST BE NSSRING, BOURLPROTOCOL won't work correctly with your params",obj);
            }
            
        }];
        
        [mutParameters setObject:params forKey:kPARAMS];
    }
    
    [dico setObject:mutParameters forKey:path];
}

/*****************************************************************************/
#pragma mark - Utils

+ (void)removeStubForPath:(NSString *)path
{
    [dico removeObjectForKey:path];
}

+ (id)stubObjectForPath:(NSString *)path
{
   return [[self subtitutionDictionary] objectForKey:path];
}

+ (NSURL *)stubURLForPath:(NSString *)path
{
    id object = [self stubObjectForPath:path];
    
    if ([object isKindOfClass:[NSURL class]])
    {
        return object;
    }
    else if ([object isKindOfClass:[NSDictionary class]])
    {
        return [object objectForKey:kURL];
    }
    
    return nil;
}

/*****************************************************************************/
#pragma mark - Birth & Death

+ (void)registerSpecialProtocol 
{
    [NSURLProtocol registerClass:[self class]];
}

+ (void)unregisterSpecialProtocol
{
    dico = nil;
    [NSURLProtocol unregisterClass:[self class]];
}

/*****************************************************************************/
#pragma mark - Protocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request 
{
    NSString *path = [[request URL] relativePath];
    
    BOOL hasPath = [[[self subtitutionDictionary] allKeys] containsObject:path];
    
    id object = [[self subtitutionDictionary] objectForKey:path];
    BOOL hasMatchingParam = YES;
    
    if ([object isKindOfClass:[NSDictionary class]])
    {
        NSDictionary *params = [object objectForKey:kPARAMS];
        if (params != nil)
        {
            NSString *query = [[request URL] query];
            NSArray *parameters = [query componentsSeparatedByString:@"&"];
            
            NSMutableDictionary *mutDico = [[NSMutableDictionary alloc] init];
            [parameters enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                
                NSArray *component = [obj componentsSeparatedByString:@"="];
                [mutDico setValue:[component objectAtIndex:1] forKey:[component objectAtIndex:0]];
                
            }];
            
            hasMatchingParam = [mutDico isEqualToDictionary:params];
        }
    }
    
    if ((hasPath && hasMatchingParam) && ![self hasPath:path])
    {
        return YES;
    }
    
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request 
{
    return request;
}

- (void)startLoading
{
    NSURL *requestUrl = [[self request] URL];
    [[self class] addPath:[requestUrl relativePath]];
    
    id object = [[self class] stubObjectForPath:[requestUrl relativePath]];
    
    if ([object isKindOfClass:[NSData class]])
    {
        [self loadWithData:object mimeType:kDEFAULT_MIMETYPE];
    }
    else if ([object isKindOfClass:[NSError class]])
    {
       [[self client] URLProtocol:self didFailWithError:object];
    }
    else if ([object isKindOfClass:[NSDictionary class]])
    {
        [self loadWithURL:requestUrl mimeType:[object objectForKey:kMIME_TYPE]];
    }
    else
    {
        if (object != nil)
        {
            BOURLProtocolBlock block = (BOURLProtocolBlock)object;
            block(self,[self request]);
        }
    }
    [[self class] removePath:[requestUrl relativePath]];
}

- (void)stopLoading
{
}

/*****************************************************************************/
#pragma mark - Loaders

- (void)loadWithData:(NSData *)data mimeType:(NSString *)mimetype
{
    if (data)
    {
        NSURLResponse *resp = [[NSURLResponse alloc] initWithURL:[[self request] URL] MIMEType:mimetype expectedContentLength:[data length] textEncodingName:kENCODING];
        [[self client] URLProtocol:self didReceiveResponse:resp cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [[self client] URLProtocol:self didLoadData:data];
        [[self client] URLProtocolDidFinishLoading:self];
    }
    else
    {
        [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:@"Local File" code:404 userInfo:nil]];
    }
}

- (void)loadWithURL:(NSURL *)requestUrl mimeType:(NSString *)mimeType
{
    NSURL *newURL = [[self class] stubURLForPath:[requestUrl relativePath]];
    
    if ([newURL isFileURL])
    {
        NSData *data = [NSData dataWithContentsOfURL:newURL];
        [self loadWithData:data mimeType:mimeType];
    }
    else
    {
        NSURLRequest *request = [NSURLRequest requestWithURL:newURL];
        
        
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue currentQueue]
                               completionHandler:^(NSURLResponse *resp, NSData *data, NSError *error)
         {
             if (!error)
             {
                 [[self client] URLProtocol:self didReceiveResponse:resp cacheStoragePolicy:NSURLCacheStorageNotAllowed];
                 [[self client] URLProtocol:self didLoadData:data];
                 [[self client] URLProtocolDidFinishLoading:self];
                 
             }
             else
             {
                 [[self client] URLProtocol:self didFailWithError:error];
             }
             
         }];
    }
}

@end
