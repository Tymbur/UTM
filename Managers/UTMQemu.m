//
// Copyright © 2019 osy. All rights reserved.
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

#import "UTMQemu.h"
#import "UTMLogging.h"
#import <dlfcn.h>
#import <pthread.h>
#import <TargetConditionals.h>

@implementation UTMQemu {
    NSMutableArray<NSString *> *_argv;
    NSMutableArray<NSURL *> *_urls;
    NSXPCConnection *_connection;
}

#pragma mark - Properties

@synthesize argv = _argv;

- (NSURL *)libraryURL {
    NSURL *bundleURL = [[NSBundle mainBundle] bundleURL];
    NSURL *contentsURL = [bundleURL URLByAppendingPathComponent:@"Contents" isDirectory:YES];
    NSURL *frameworksURL = [contentsURL URLByAppendingPathComponent:@"Frameworks" isDirectory:YES];
    return frameworksURL;
}

- (BOOL)hasRemoteProcess {
    return _connection != nil;
}

#pragma mark - Construction

- (instancetype)init {
    return [self initWithArgv:[NSArray<NSString *> array]];
}

- (instancetype)initWithArgv:(NSArray<NSString *> *)argv {
    if (self = [super init]) {
        _argv = [argv mutableCopy];
        _urls = [NSMutableArray<NSURL *> array];
    }
    return self;
}

- (void)dealloc {
    if (_connection) {
        [_connection invalidate];
    }
    for (NSURL *url in _urls) {
        [url stopAccessingSecurityScopedResource];
    }
}

#pragma mark - Methods

- (BOOL)setupXpc {
#if !TARGET_OS_IPHONE // only supported on macOS
    _connection = [[NSXPCConnection alloc] initWithServiceName:@"com.osy86.QEMUHelper"];
    _connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(QEMUHelperProtocol)];
    [_connection resume];
#endif
    return _connection != nil;
}

- (void)pushArgv:(nullable NSString *)arg {
    NSAssert(arg, @"Cannot push null argument!");
    [_argv addObject:arg];
}

- (void)clearArgv {
    [_argv removeAllObjects];
}

- (void)printArgv {
    NSString *args = @"";
    for (NSString *arg in _argv) {
        if ([arg containsString:@" "]) {
            args = [args stringByAppendingFormat:@" \"%@\"", arg];
        } else {
            args = [args stringByAppendingFormat:@" %@", arg];
        }
    }
    UTMLog(@"Running: %@", args);
}

- (BOOL)didLoadDylib:(void *)handle {
    return YES;
}

- (void)startDylibThread:(nonnull NSString *)dylib completion:(void(^)(BOOL,NSString *))completion {
    void *dlctx;
    __block pthread_t qemu_thread;
    pthread_attr_t qosAttribute;
    __weak typeof(self) wself = self;
    
    NSAssert(self.entry != NULL, @"entry is NULL!");
    self.status = self.fatal = 0;
    self.done = dispatch_semaphore_create(0);
    UTMLog(@"Loading %@", dylib);
    dlctx = dlopen([dylib UTF8String], RTLD_LOCAL);
    if (dlctx == NULL) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        completion(NO, err);
        return;
    }
    if (![self didLoadDylib:dlctx]) {
        NSString *err = [NSString stringWithUTF8String:dlerror()];
        dlclose(dlctx);
        completion(NO, err);
        return;
    }
    if (atexit_b(^{
        if (pthread_self() == qemu_thread) {
            __strong typeof(self) sself = wself;
            if (sself) {
                sself->_fatal = 1;
                dispatch_semaphore_signal(sself->_done);
            }
            pthread_exit(NULL);
        }
    }) != 0) {
        completion(NO, NSLocalizedString(@"Internal error has occurred.", @"UTMQemu"));
        return;
    }
    [self printArgv];
    pthread_attr_init(&qosAttribute);
    pthread_attr_set_qos_class_np(&qosAttribute, QOS_CLASS_USER_INTERACTIVE, 0);
    pthread_create(&qemu_thread, &qosAttribute, self.entry, (__bridge_retained void *)self);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        if (dispatch_semaphore_wait(self.done, DISPATCH_TIME_FOREVER)) {
            dlclose(dlctx);
            completion(NO, NSLocalizedString(@"Internal error has occurred.", @"UTMQemu"));
        } else {
            if (dlclose(dlctx) < 0) {
                NSString *err = [NSString stringWithUTF8String:dlerror()];
                completion(NO, err);
            } else if (self.fatal || self.status) {
                completion(NO, [NSString stringWithFormat:NSLocalizedString(@"QEMU exited from an error: %@", @"UTMQemu"), [[UTMLogging sharedInstance] lastErrorLine]]);
            } else {
                completion(YES, nil);
            }
        }
    });
}

- (void)startQemuRemote:(nonnull NSString *)name completion:(void(^)(BOOL,NSString *))completion {
    NSError *error;
    NSData *libBookmark = [self.libraryURL bookmarkDataWithOptions:0
                                    includingResourceValuesForKeys:nil
                                                     relativeToURL:nil
                                                             error:&error];
    if (!libBookmark) {
        completion(NO, error.localizedDescription);
        return;
    }
    [[_connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
        completion(NO, error.localizedDescription);
    }] startQemu:name libraryBookmark:libBookmark argv:self.argv onExit:completion];
}

- (void)start:(nonnull NSString *)name completion:(void(^)(BOOL,NSString *))completion {
    if (_connection) {
        [self startQemuRemote:name completion:completion];
    } else {
        NSString *dylib = [NSString stringWithFormat:@"lib%@.utm.dylib", name];
        [self startDylibThread:dylib completion:completion];
    }
}

- (void)ping:(void (^)(BOOL))onResponse {
    if (_connection) {
        [[_connection remoteObjectProxyWithErrorHandler:^(NSError * _Nonnull error) {
            onResponse(NO);
        }] ping:onResponse];
    } else {
        onResponse(YES);
    }
}

- (void)accessDataWithBookmarkThread:(NSData *)bookmark securityScoped:(BOOL)securityScoped completion:(void(^)(BOOL, NSData * _Nullable, NSString * _Nullable))completion  {
#if 0 // FIXME: enable when we support iOS bookmarks
    BOOL stale = NO;
    NSError *err;
    NSURL *url = [NSURL URLByResolvingBookmarkData:bookmark
                                           options:(securityScoped ? kBookmarkResolutionOptions : 0)
                                     relativeToURL:nil
                               bookmarkDataIsStale:&stale
                                             error:&err];
    if (!url) {
        UTMLog(@"Failed to access bookmark data.");
        completion(NO, nil, nil);
        return;
    }
    if (stale || !securityScoped) {
        bookmark = [url bookmarkDataWithOptions:kBookmarkCreationOptions
                 includingResourceValuesForKeys:nil
                                  relativeToURL:nil
                                          error:&err];
        if (!bookmark) {
            UTMLog(@"Failed to create new bookmark!");
            completion(NO, bookmark, url.path);
            return;
        }
    }
    if ([url startAccessingSecurityScopedResource]) {
        [_urls addObject:url];
    } else {
        UTMLog(@"Failed to access security scoped resource for: %@", url);
    }
    completion(YES, bookmark, url.path);
#endif
}

- (void)accessDataWithBookmark:(NSData *)bookmark {
    [self accessDataWithBookmark:bookmark securityScoped:NO completion:^(BOOL success, NSData *bookmark, NSString *path) {
        if (!success) {
            UTMLog(@"Access bookmark failed for: %@", path);
        }
    }];
}

- (void)accessDataWithBookmark:(NSData *)bookmark securityScoped:(BOOL)securityScoped completion:(void(^)(BOOL, NSData * _Nullable, NSString * _Nullable))completion {
    if (_connection) {
        [[_connection remoteObjectProxy] accessDataWithBookmark:bookmark securityScoped:securityScoped completion:completion];
    } else {
        [self accessDataWithBookmarkThread:bookmark securityScoped:securityScoped completion:completion];
    }
}

@end
