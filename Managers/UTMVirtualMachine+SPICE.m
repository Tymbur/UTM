//
// Copyright © 2020 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <TargetConditionals.h>
#import "UTMVirtualMachine+SPICE.h"
#import "CocoaSpice.h"
#import "UTMConfiguration+Display.h"
#import "UTMConfiguration+Sharing.h"
#import "UTMLogging.h"
#import "UTMQemuManager.h"
#import "UTMSpiceIO.h"
#import "UTMViewState.h"

extern NSString *const kUTMErrorDomain;

#if TARGET_OS_IPHONE
static const NSURLBookmarkCreationOptions kBookmarkCreationOptions = 0;
static const NSURLBookmarkResolutionOptions kBookmarkResolutionOptions = 0;
#else
static const NSURLBookmarkCreationOptions kBookmarkCreationOptions = NSURLBookmarkCreationWithSecurityScope;
static const NSURLBookmarkResolutionOptions kBookmarkResolutionOptions = NSURLBookmarkResolutionWithSecurityScope;
#endif

@interface UTMVirtualMachine ()

@property (nonatomic, readonly, nullable) UTMQemuManager *qemu;
@property (nonatomic, readonly, nullable) id<UTMInputOutput> ioService;

@end

@implementation UTMVirtualMachine (SPICE)

- (UTMSpiceIO *)spiceIoWithError:(NSError * _Nullable __autoreleasing *)error {
    if (![self.ioService isKindOfClass:[UTMSpiceIO class]]) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"VM frontend does not support shared directories.", "UTMVirtualMachine+Sharing")}];
        }
        return nil;
    }
    return (UTMSpiceIO *)self.ioService;
}

#pragma mark - Shared Directory

- (BOOL)hasShareDirectoryEnabled {
    return self.configuration.shareDirectoryEnabled && !self.configuration.displayConsoleOnly;
}

- (BOOL)saveSharedDirectory:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    NSData *bookmark = [url bookmarkDataWithOptions:kBookmarkCreationOptions
                     includingResourceValuesForKeys:nil
                                      relativeToURL:nil
                                              error:error];
    if (!bookmark) {
        return NO;
    } else {
        self.viewState.sharedDirectory = bookmark;
        self.viewState.sharedDirectoryPath = url.path;
        return YES;
    }
}

- (BOOL)changeSharedDirectory:(NSURL *)url error:(NSError * _Nullable __autoreleasing *)error {
    if (!self.ioService) {
        // if we haven't started the VM yet, save the URL for when the VM starts
        return [self saveSharedDirectory:url error:error];
    }
    UTMSpiceIO *spiceIO = [self spiceIoWithError:error];
    if (!spiceIO) {
        return NO;
    }
    [spiceIO changeSharedDirectory:url];
    return [self saveSharedDirectory:url error:error];
}

- (void)clearSharedDirectory {
    self.viewState.sharedDirectory = nil;
    self.viewState.sharedDirectoryPath = nil;
}

- (BOOL)startSharedDirectoryWithError:(NSError * _Nullable __autoreleasing *)error {
    if (!self.ioService) {
        if (error) {
            *error = [NSError errorWithDomain:kUTMErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"Cannot start shared directory before SPICE starts.", "UTMVirtualMachine+Sharing")}];
        }
        return NO;
    }
    if (!self.configuration.shareDirectoryEnabled) {
        return YES;
    }
    UTMSpiceIO *spiceIO = [self spiceIoWithError:error];
    if (!spiceIO) {
        return NO;
    }
    
    NSData *bookmark = nil;
    if (self.viewState.sharedDirectory) {
        UTMLog(@"found shared directory bookmark");
        bookmark = self.viewState.sharedDirectory;
    } else if (self.configuration.shareDirectoryBookmark) {
        UTMLog(@"found shared directory bookmark (legacy)");
        bookmark = self.configuration.shareDirectoryBookmark;
    }
    if (bookmark) {
        BOOL stale;
        NSURL *shareURL = [NSURL URLByResolvingBookmarkData:bookmark
                                                    options:kBookmarkResolutionOptions
                                              relativeToURL:nil
                                        bookmarkDataIsStale:&stale
                                                      error:error];
        if (shareURL) {
            [spiceIO changeSharedDirectory:shareURL];
            if (stale) {
                UTMLog(@"stale bookmark, attempting to recreate");
                return [self saveSharedDirectory:shareURL error:error];
            }
        } else {
            return NO;
        }
    }
    return YES;
}

#pragma mark - Input device switching

- (void)requestInputTablet:(BOOL)tablet {
    [self.qemu mouseIndexForAbsolute:tablet withCompletion:^(int64_t index, NSError *err) {
        if (err) {
            UTMLog(@"error finding index: %@", err);
        } else {
            UTMLog(@"found index:%lld absolute:%d", index, tablet);
            [self.qemu mouseSelect:index withCompletion:^(NSString *res, NSError *err) {
                if (err) {
                    UTMLog(@"input select returned error: %@", err);
                } else {
                    UTMSpiceIO *spiceIO = [self spiceIoWithError:&err];
                    if (spiceIO) {
                        [spiceIO.primaryInput requestMouseMode:!tablet];
                    } else {
                        UTMLog(@"failed to get SPICE manager: %@", err);
                    }
                }
            }];
        }
    }];
}

@end
