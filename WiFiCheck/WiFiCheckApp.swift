//
//  WiFiCheckApp.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 9/10/21.
//

import SwiftUI

@main
struct WiFiCheckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView().frame(minWidth: 600)
        }
        .commands {
            SidebarCommands()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

struct WiFiButtonStyle: ButtonStyle {
    var delete: Bool = false
    var disabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(EdgeInsets(top:2, leading: 10, bottom: 2, trailing: 10))
            .font(.subheadline)
            .background(delete ? (disabled ? Color.gray : Color.red) : (disabled ? Color.gray : Color.accentColor))
            .brightness(configuration.isPressed ? -0.2 : 0)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

