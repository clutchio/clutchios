//
//  ClutchJSONKit.h
//  http://github.com/johnezang/JSONKit
//  Dual licensed under either the terms of the BSD License, or alternatively
//  under the terms of the Apache License, Version 2.0, as specified below.
//

/*
 Copyright (c) 2011, John Engelhart
 
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 
 * Neither the name of the Zang Industries nor the names of its
 contributors may be used to endorse or promote products derived from
 this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/*
 Copyright 2011 John Engelhart
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#include <stddef.h>
#include <stdint.h>
#include <limits.h>
#include <TargetConditionals.h>
#include <AvailabilityMacros.h>

#ifdef    __OBJC__
#import <Foundation/NSArray.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSString.h>
#endif // __OBJC__

#ifdef __cplusplus
extern "C" {
#endif
    
    
    // For Mac OS X < 10.5.
#ifndef   NSINTEGER_DEFINED
#define   NSINTEGER_DEFINED
#if       defined(__LP64__) || defined(NS_BUILD_32_LIKE_64)
    typedef long           NSInteger;
    typedef unsigned long  NSUInteger;
#define NSIntegerMin   LONG_MIN
#define NSIntegerMax   LONG_MAX
#define NSUIntegerMax  ULONG_MAX
#else  // defined(__LP64__) || defined(NS_BUILD_32_LIKE_64)
    typedef int            NSInteger;
    typedef unsigned int   NSUInteger;
#define NSIntegerMin   INT_MIN
#define NSIntegerMax   INT_MAX
#define NSUIntegerMax  UINT_MAX
#endif // defined(__LP64__) || defined(NS_BUILD_32_LIKE_64)
#endif // NSINTEGER_DEFINED
    
    
#ifndef _CLUTCH_JSONKIT_H_
#define _CLUTCH_JSONKIT_H_
    
#define CLUTCH_JSONKIT_VERSION_MAJOR 1
#define CLUTCH_JSONKIT_VERSION_MINOR 4
    
    typedef NSUInteger ClutchJKFlags;
    
    /*
     ClutchJKParseOptionComments        : Allow C style // and /_* ... *_/ (without a _, obviously) comments in JSON.
     ClutchJKParseOptionUnicodeNewlines : Allow Unicode recommended (?:\r\n|[\n\v\f\r\x85\p{Zl}\p{Zp}]) newlines.
     ClutchJKParseOptionLooseUnicode    : Normally the decoder will stop with an error at any malformed Unicode.
     This option allows JSON with malformed Unicode to be parsed without reporting an error.
     Any malformed Unicode is replaced with \uFFFD, or "REPLACEMENT CHARACTER".
     */
    
    enum {
        ClutchJKParseOptionNone                     = 0,
        ClutchJKParseOptionStrict                   = 0,
        ClutchJKParseOptionComments                 = (1 << 0),
        ClutchJKParseOptionUnicodeNewlines          = (1 << 1),
        ClutchJKParseOptionLooseUnicode             = (1 << 2),
        ClutchJKParseOptionPermitTextAfterValidJSON = (1 << 3),
        ClutchJKParseOptionValidFlags               = (ClutchJKParseOptionComments | ClutchJKParseOptionUnicodeNewlines | ClutchJKParseOptionLooseUnicode | ClutchJKParseOptionPermitTextAfterValidJSON),
    };
    typedef ClutchJKFlags ClutchJKParseOptionFlags;
    
    enum {
        ClutchJKSerializeOptionNone                 = 0,
        ClutchJKSerializeOptionPretty               = (1 << 0),
        ClutchJKSerializeOptionEscapeUnicode        = (1 << 1),
        ClutchJKSerializeOptionEscapeForwardSlashes = (1 << 4),
        ClutchJKSerializeOptionValidFlags           = (ClutchJKSerializeOptionPretty | ClutchJKSerializeOptionEscapeUnicode | ClutchJKSerializeOptionEscapeForwardSlashes),
    };
    typedef ClutchJKFlags ClutchJKSerializeOptionFlags;
    
#ifdef    __OBJC__
    
    typedef struct ClutchJKParseState ClutchJKParseState; // Opaque internal, private type.
    
    // As a general rule of thumb, if you use a method that doesn't accept a ClutchJKParseOptionFlags argument, it defaults to ClutchJKParseOptionStrict
    
    @interface ClutchJSONDecoder : NSObject {
        ClutchJKParseState *parseState;
    }
+ (id)decoder;
+ (id)decoderWithParseOptions:(ClutchJKParseOptionFlags)parseOptionFlags;
- (id)initWithParseOptions:(ClutchJKParseOptionFlags)parseOptionFlags;
- (void)clearCache;

// Methods that return immutable collection objects.
- (id)objectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length;
- (id)objectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length error:(NSError **)error;
// The NSData MUST be UTF8 encoded JSON.
- (id)objectWithData:(NSData *)jsonData;
- (id)objectWithData:(NSData *)jsonData error:(NSError **)error;

// Methods that return mutable collection objects.
- (id)mutableObjectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length;
- (id)mutableObjectWithUTF8String:(const unsigned char *)string length:(NSUInteger)length error:(NSError **)error;
// The NSData MUST be UTF8 encoded JSON.
- (id)mutableObjectWithData:(NSData *)jsonData;
- (id)mutableObjectWithData:(NSData *)jsonData error:(NSError **)error;

@end
    
@interface ClutchJSONEncoder: NSObject

+ (NSString *)jsonString:(id)data;
+ (NSData *)jsonData:(id)data;

@end
    
#endif // __OBJC__
    
#endif // _CLUTCH_JSONKIT_H_
    
#ifdef __cplusplus
}  // extern "C"
#endif