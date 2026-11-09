//
//  WiFiCheckApp.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 9/10/21.
//

import AppKit
import SwiftUI

@main
struct WiFiCheckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage(ForgetAuthentication.preferenceKey) private var requireAuthToForget = true

    var body: some Scene {
        WindowGroup {
            ContentView().frame(minWidth: 600)
        }
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("Open Plist File…") {
                    NotificationCenter.default.post(name: .openWiFiFile, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
                Divider()
                Button("Load Real WiFi Data") {
                    NotificationCenter.default.post(name: .loadRealWiFiData, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    NotificationCenter.default.post(name: .checkForUpdates, object: nil)
                }
                Divider()
                Toggle("Require Auth to Forget Networks", isOn: $requireAuthToForget)
                Divider()
                Button("Setup…") {
                    NotificationCenter.default.post(name: .showSetupSheet, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])
                Button("Remove Helper…") {
                    NotificationCenter.default.post(name: .showRemoveHelperSheet, object: nil)
                }
            }
            CommandGroup(replacing: .help) {
                Button("WiFi Check Help") {
                    NSWorkspace.shared.open(Constants.helpURL)
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let checkForUpdates = Notification.Name("com.ciretose.WiFiCheck.checkForUpdates")
    static let showSetupSheet = Notification.Name("com.ciretose.WiFiCheck.showSetupSheet")
    static let showRemoveHelperSheet = Notification.Name("com.ciretose.WiFiCheck.showRemoveHelperSheet")
    static let openWiFiFile = Notification.Name("com.ciretose.WiFiCheck.openWiFiFile")
    static let loadRealWiFiData = Notification.Name("com.ciretose.WiFiCheck.loadRealWiFiData")
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI builds the menu asynchronously; rewire after the Help item exists,
        // and again whenever AppKit reinstalls the default showHelp: action.
        DispatchQueue.main.async { self.rewireHelpMenu() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.rewireHelpMenu() }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuDidChange(_:)),
            name: NSMenu.didAddItemNotification,
            object: nil
        )
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        rewireHelpMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    @objc private func menuDidChange(_ notification: Notification) {
        guard let menu = notification.object as? NSMenu,
              menu.title == "Help" || menu == NSApp.mainMenu else { return }
        DispatchQueue.main.async { self.rewireHelpMenu() }
    }

    /// Replaces the system Help action that shows “Help isn’t available for WiFi Check.”
    private func rewireHelpMenu() {
        guard let helpMenu = NSApp.mainMenu?.items
            .first(where: { $0.title == "Help" })?
            .submenu else { return }

        for item in helpMenu.items where !item.isSeparatorItem {
            let pointsAtSystemHelp = item.action == #selector(NSApplication.showHelp(_:))
            let looksLikeHelpItem = item.title.localizedCaseInsensitiveContains("Help")
            guard pointsAtSystemHelp || looksLikeHelpItem else { continue }
            item.target = self
            item.action = #selector(openProductHelp(_:))
            item.keyEquivalent = "?"
            item.keyEquivalentModifierMask = .command
        }
    }

    @objc private func openProductHelp(_ sender: Any?) {
        NSWorkspace.shared.open(Constants.helpURL)
    }
}

struct WiFiButtonStyle: ButtonStyle {
    var delete: Bool = false
    var disabled: Bool = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
            .font(.subheadline)
            .background(delete ? (disabled ? Color.gray : Color.red) : (disabled ? Color.gray : Color.accentColor))
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

extension View {
    /// Re-apply control metrics that the macOS 27 SDK resets inside sheets and popovers.
    /// Safe on macOS 26; does not change padding or sizing for the 27-only look.
    func restoredPresentationControls() -> some View {
        self
            .controlSize(.regular)
            .buttonSizing(.flexible)
    }
}
