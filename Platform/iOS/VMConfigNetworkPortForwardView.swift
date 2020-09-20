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

@available(iOS 14, *)
struct VMConfigNetworkPortForwardView: View {
    @ObservedObject var config: UTMConfiguration
    
    var body: some View {
        Section(header: HStack { Text("Port Forward") }, footer: EmptyView().padding(.bottom)) {
            List {
                ForEach(0..<config.countPortForwards, id: \.self) { index in
                    let configPort = config.portForward(for: index)!
                    NavigationLink(
                        destination: PortForwardEdit(config: config, index: index),
                        label: {
                            VStack(alignment: .leading) {
                                Text("\(configPort.guestAddress ?? ""):\(String(configPort.guestPort)) ➡️ \(configPort.hostAddress ?? ""):\(String(configPort.hostPort))")
                                Text(configPort.protocol ?? "").font(.subheadline)
                            }
                        })
                }.onDelete(perform: deletePortForwards)
                NavigationLink(
                    destination: PortForwardEdit(config: config),
                    label: {
                        Text("New")
                })
            }
        }
    }
    
    private func deletePortForwards(offsets: IndexSet) {
        for offset in offsets {
            config.removePortForward(at: offset)
        }
    }
}

@available(iOS 14, *)
struct PortForwardEdit: View {
    @StateObject private var configPort: UTMConfigurationPortForward
    private let save: () -> Void
    @Environment(\.presentationMode) private var presentationMode: Binding<PresentationMode>
    
    init(config: UTMConfiguration, index: Int? = nil) {
        var configPort: UTMConfigurationPortForward
        if let i = index {
            configPort = config.portForward(for: i)!
        } else {
            configPort = UTMConfigurationPortForward()
        }
        self._configPort = StateObject<UTMConfigurationPortForward>(wrappedValue: configPort)
        save = {
            config.updatePortForward(at: index ?? config.countPortForwards, withValue: configPort)
        }
    }
    
    var body: some View {
        Form {
            List {
                VMConfigPortForwardForm(configPort: configPort).multilineTextAlignment(.trailing)
            }
        }.navigationBarItems(trailing:
            Button(action: savePortForward, label: {
                Text("Save")
            }).disabled(configPort.guestPort == 0 || configPort.hostPort == 0)
        )
    }
    
    private func savePortForward() {
        save()
        self.presentationMode.wrappedValue.dismiss()
    }
}

@available(iOS 14, *)
struct VMConfigNetworkPortForwardView_Previews: PreviewProvider {
    @State static private var config = UTMConfiguration()
    static var previews: some View {
        Group {
            Form {
                VMConfigNetworkPortForwardView(config: config)
            }.onAppear {
                if config.countPortForwards == 0 {
                    let newConfigPort = UTMConfigurationPortForward()
                    newConfigPort.protocol = "tcp"
                    newConfigPort.guestAddress = "1.2.3.4"
                    newConfigPort.guestPort = 1234
                    newConfigPort.hostAddress = "4.3.2.1"
                    newConfigPort.hostPort = 4321
                    config.newPortForward(newConfigPort)
                    newConfigPort.protocol = "udp"
                    newConfigPort.guestAddress = nil
                    newConfigPort.guestPort = 2222
                    newConfigPort.hostAddress = nil
                    newConfigPort.hostPort = 3333
                    config.newPortForward(newConfigPort)
                }
            }
            PortForwardEdit(config: config, index: 0)
        }
    }
}
