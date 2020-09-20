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

#import "UTMRenderSource.h"

@class UTMVirtualMachine;
@class UTMConfiguration;
@class CSDisplayMetal;
@class CSInput;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, UTMVMState) {
    kVMStopped,
    kVMSuspended,
    kVMError,
    kVMStarting,
    kVMStarted,
    kVMPausing,
    kVMPaused,
    kVMResuming,
    kVMStopping
};

@protocol UTMVirtualMachineDelegate <NSObject>

@property (nonatomic, nullable, copy) NSString *vmMessage;
@property (nonatomic, weak) UTMConfiguration *vmConfiguration;
@property (nonatomic, assign) BOOL toolbarVisible;
@property (nonatomic, assign) BOOL keyboardVisible;

- (void)virtualMachine:(UTMVirtualMachine *)vm transitionToState:(UTMVMState)state;

@end

NS_ASSUME_NONNULL_END
