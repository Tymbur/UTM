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
struct VMPlaceholderView: View {
    @Binding var createNewVMPresented: Bool
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("Welcome to UTM").font(.title)
                Spacer()
            }
            HStack {
                Spacer()
                TileButton(titleKey: "Create a New Virtual Machine", systemImage: "plus.circle") {
                    createNewVMPresented.toggle()
                }
                TileButton(titleKey: "Browse UTM Gallery", systemImage: "square.grid.3x2") {
                    openURL(URL(string: "https://getutm.app/gallery/")!)
                }
                TileButton(titleKey: "User Guide", systemImage: "questionmark.circle") {
                    #if os(macOS)
                    openURL(URL(string: "https://mac.getutm.app/guide/")!)
                    #else
                    openURL(URL(string: "https://getutm.app/guide_v2/")!)
                    #endif
                }
                Spacer()
            }
            Spacer()
        }
    }
}

@available(iOS 14, macOS 11, *)
private struct TileButton: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action, label: {
            Label(titleKey, systemImage: systemImage)
                .labelStyle(TileLabelStyle())
        }).buttonStyle(TileButtonStyle())
    }
}

@available(iOS 14, macOS 11, *)
private struct TileButtonStyle: ButtonStyle {
    let defaultColor = Color(red: 220.0/255.0, green: 220.0/255.0, blue: 220.0/255.0)
    let pressedColor = Color(red: 200.0/255.0, green: 200.0/255.0, blue: 200.0/255.0)
    let foregroundColor = Color(red: 126.0/255.0, green: 126.0/255.0, blue: 126.0/255.0)
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10.0)
                .fill(configuration.isPressed ? pressedColor : defaultColor)
            configuration.label
                .foregroundColor(foregroundColor)
        }.frame(width: 150, height: 150)
    }
}


@available(iOS 14, macOS 11, *)
private struct TileLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.icon
                .font(.system(size: 48.0, weight: .medium))
                .padding(.bottom)
            configuration.title
                .multilineTextAlignment(.center)
        }
    }
}

@available(iOS 14, macOS 11, *)
struct VMPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        VMPlaceholderView(createNewVMPresented: .constant(false))
    }
}
