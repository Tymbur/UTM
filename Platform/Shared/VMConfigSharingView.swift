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

import SwiftUI

@available(iOS 14, macOS 11, *)
struct VMConfigSharingView: View {
    @ObservedObject var config: UTMConfiguration
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Clipboard Sharing"), footer: Text("Requires SPICE guest agent tools to be installed.").padding(.bottom)) {
                    Toggle(isOn: $config.shareClipboardEnabled, label: {
                        Text("Enable Clipboard Sharing")
                    })
                }
                
                Section(header: Text("Shared Directory"), footer: Text("Requires SPICE WebDAV service to be installed.").padding(.bottom)) {
                    Toggle(isOn: $config.shareDirectoryEnabled.animation(), label: {
                        Text("Enable Directory Sharing")
                    })
                    Toggle(isOn: $config.shareDirectoryReadOnly, label: {
                        Text("Read Only")
                    })
                    Text("Note: select the path to share from the main screen.")
                }
            }
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMConfigSharingView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration()
    
    static var previews: some View {
        VMConfigSharingView(config: config)
    }
}
