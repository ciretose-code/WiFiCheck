//
//  WiFiListView.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 9/10/21.
//

import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement
import CoreWLAN

enum SortableMenu: String, CaseIterable, Identifiable {
    var id: String {
        return self.rawValue
    }
    
    case preferredOrder, recentUser, recentSystem, alphabetical
    
    var title: String {
        switch self {
        case .preferredOrder: return "Preferred"
        case .recentUser: return "Recent User"
        case .recentSystem: return "Recent System"
        case .alphabetical: return "Alphabetical"
        }
    }
    
    var image: String {
        switch self {
        case .preferredOrder: return "star.fill"
        case .recentUser: return "person.circle.fill"
        case .recentSystem: return "desktopcomputer"
        case .alphabetical: return "arrow.up.arrow.down.square.fill"
        }
    }
}



struct WiFiListView: View {
    @State private var wifidataArray = Array<WiFiData>()
    @State private var listSelection: WiFiData? = nil
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var hasAutoSelected = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            WiFiListPane(sharedNetworks: $wifidataArray, listSelection: $listSelection)
        } detail: {
            if let selected = listSelection {
                WiFiDataDetail(wifidata: selected, onDelete: {
                    wifidataArray.removeAll { $0.id == selected.id }
                    listSelection = nil
                })
            } else {
                WiFiDetailPane(networks: wifidataArray)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: wifidataArray) {
            guard !hasAutoSelected, !wifidataArray.isEmpty else { return }
            hasAutoSelected = true
            if let currentSSID = CWWiFiClient.shared().interface()?.ssid(),
               let match = wifidataArray.first(where: { $0.ssidString() == currentSSID }) {
                listSelection = match
            }
        }
    }
}

struct WiFiListPane: View {
    @Binding var sharedNetworks: [WiFiData]
    @Binding var listSelection: WiFiData?

    private enum DeleteAlert: Identifiable {
        case confirm(WiFiData)
        case result(success: Bool, message: String)
        var id: String {
            switch self {
            case .confirm(let w): return "confirm-\(w.WiFiID)"
            case .result(let s, let m): return "result-\(s)-\(m)"
            }
        }
    }

    @AppStorage("selectedSort") private var selectedSort = SortableMenu.recentSystem
    @State private var searchText = ""

    var filteredNetworks: [WiFiData] {
        guard !searchText.isEmpty else { return sharedNetworks }
        return sharedNetworks.filter { $0.ssidString().localizedCaseInsensitiveContains(searchText) }
    }

    @State private var sortString = "Preferred"
    @State private var activeDeleteAlert: DeleteAlert? = nil
    @State private var showPermissionError = false
    @State private var reloadView = false
    @State private var isDropTargeted = false
    @State private var showDropError = false
    @State private var dropErrorMessage = ""
    @State private var showSetupSheet = false
    @State private var helperInstalling = false
    @State private var helperError: String? = nil
    @State private var helperNeedsApproval = false
    @State private var helperNeedsFDA = false
    @State private var showRemoveHelperSheet = false
    @State private var helperRemoving = false
    @State private var helperRemoveError: String? = nil
    @State private var helperRemoved = false

    static let sudoCommand = "sudo cp /Library/Preferences/com.apple.wifi.known-networks.plist ~/Downloads/wifi-networks.plist && sudo chmod 644 ~/Downloads/wifi-networks.plist"

    func applySort() {
        sortString = selectedSort.title
        switch selectedSort {
        case .preferredOrder:
            sharedNetworks = WiFiDataManager.shared.sortByPreferredOrder()
        case .recentUser:
            sharedNetworks = WiFiDataManager.shared.sortByRecentUser()
        case .recentSystem:
            sharedNetworks = WiFiDataManager.shared.sortByRecentSystem()
        case .alphabetical:
            sharedNetworks = WiFiDataManager.shared.sortByAlphabetical()
        }
    }

    func loadWiFiData() {
        applySort()
    }

    func openWiFiFilePicker() {
        let panel = NSOpenPanel()
        panel.title = "Open WiFi Networks Plist"
        panel.message = "Select a WiFi known-networks plist file"
        panel.allowedContentTypes = [.propertyList]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            if WiFiDataManager.shared.loadFromURL(url) {
                sharedNetworks = WiFiDataManager.shared.getWiFiDataList()
                applySort()
                reloadView.toggle()
            } else {
                dropErrorMessage = "\"\(url.lastPathComponent)\" does not appear to be a valid WiFi known-networks plist."
                showDropError = true
            }
        }
    }

    func loadRealWiFiData() {
        if WiFiDataManager.shared.helperIsRunning {
            WiFiDataManager.shared.loadViaHelper { networks, _ in
                if let networks = networks, !networks.isEmpty {
                    sharedNetworks = networks
                    applySort()
                    reloadView.toggle()
                } else {
                    showSetupSheet = true
                }
            }
        } else {
            showSetupSheet = true
        }
    }

    func copyCommandToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.sudoCommand, forType: .string)
    }

    func loadFromDownloads() {
        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads/wifi-networks.plist")
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            dropErrorMessage = "wifi-networks.plist not found in Downloads. Run the command above first."
            showDropError = true
            return
        }
        if WiFiDataManager.shared.loadFromURL(fileURL) {
            sharedNetworks = WiFiDataManager.shared.getWiFiDataList()
            reloadView.toggle()
            showSetupSheet = false
        } else {
            dropErrorMessage = "wifi-networks.plist doesn't appear to be a valid WiFi known-networks plist."
            showDropError = true
        }
    }

    func removeHelper() {
        helperRemoving = true
        helperRemoveError = nil
        helperRemoved = false
        WiFiDataManager.shared.uninstallHelper { success, error in
            DispatchQueue.main.async {
                helperRemoving = false
                if success {
                    helperRemoved = true
                } else {
                    helperRemoveError = error?.localizedDescription ?? "Failed to remove helper."
                }
            }
        }
    }

    func installAndLoadViaHelper() {        helperInstalling = true
        helperError = nil
        helperNeedsApproval = false
        helperNeedsFDA = false
        // installHelper must run on main thread (presents auth dialog)
        WiFiDataManager.shared.installHelper { success, error in
            if success {
                WiFiDataManager.shared.loadViaHelper { networks, loadError in
                    helperInstalling = false
                    if let networks = networks, !networks.isEmpty {
                        sharedNetworks = networks
                        applySort()
                        reloadView.toggle()
                        showSetupSheet = false
                    } else if Self.isPermissionError(loadError) {
                        helperNeedsFDA = true
                    } else {
                        helperError = loadError?.localizedDescription ?? "Helper installed but could not read WiFi data."
                    }
                }
            } else {
                helperInstalling = false
                let nsErr = error as NSError?
                if nsErr?.domain == WiFiDataManager.requiresApprovalError.domain &&
                   nsErr?.code == WiFiDataManager.requiresApprovalError.code {
                    helperNeedsApproval = true
                    helperError = nil
                } else if let err = nsErr {
                    helperError = "\(err.localizedDescription) (\(err.domain) \(err.code))"
                } else {
                    helperError = error?.localizedDescription ?? "Installation failed."
                }
            }
        }
    }

    /// Returns true when the error indicates a TCC/FDA permission denial.
    private static func isPermissionError(_ error: Error?) -> Bool {
        guard let err = error as NSError? else { return false }
        // NSFileReadNoPermissionError (257) or EPERM/EACCES (1/13)
        return err.domain == NSCocoaErrorDomain && err.code == NSFileReadNoPermissionError
            || err.domain == NSPOSIXErrorDomain && (err.code == 1 || err.code == 13)
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadFileRepresentation(forTypeIdentifier: UTType.propertyList.identifier) { url, error in
            guard let fileURL = url, error == nil else {
                provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                    let originalURL: URL?
                    if let urlData = item as? Data {
                        originalURL = URL(dataRepresentation: urlData, relativeTo: nil)
                    } else if let directURL = item as? URL {
                        originalURL = directURL
                    } else {
                        originalURL = nil
                    }

                    DispatchQueue.main.async {
                        if originalURL?.path == "/Library/Preferences/com.apple.wifi.known-networks.plist" {
                            dropErrorMessage = "That file is root-protected and cannot be read directly. Use the command below to copy it to your Downloads folder first."
                        } else {
                            dropErrorMessage = error?.localizedDescription ?? "Could not read the dropped file."
                        }
                        showDropError = true
                    }
                }
                return
            }

            let parsed = WiFiDataManager.shared.loadFromURL(fileURL)
            DispatchQueue.main.async {
                if parsed {
                    sharedNetworks = WiFiDataManager.shared.getWiFiDataList()
                    reloadView.toggle()
                } else {
                    dropErrorMessage = "\"\(fileURL.lastPathComponent)\" does not appear to be a valid WiFi known-networks plist."
                    showDropError = true
                }
            }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Sort:").padding(.leading, 3).foregroundColor(.secondary)
                Picker("", selection: $selectedSort) {
                    ForEach(SortableMenu.allCases) { sm in
                        HStack() {
                            Image(systemName: sm.image).renderingMode(.template)
                            Text(sm.title)
                        }.tag(sm)
                    }
                }
                .onChange(of: selectedSort) {
                    applySort()
                }
                .pickerStyle(MenuPickerStyle())
            }
            Divider()
            if !sharedNetworks.isEmpty {
                Group {
                    if searchText.isEmpty {
                        Text("\(sharedNetworks.count) networks")
                    } else {
                        Text("\(filteredNetworks.count) of \(sharedNetworks.count) networks")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            List(selection: $listSelection) {
                    ForEach(filteredNetworks) { wifidata in
                        WiFiDataRow(wifidata: wifidata)
                            .tag(wifidata)
                    }
            }
            .searchable(text: $searchText, placement: .sidebar, prompt: "Search networks")
            .listStyle(SidebarListStyle())
            .onDrop(of: [UTType.propertyList], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .opacity(isDropTargeted ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
            )
            .overlay(
                Group {
                    if sharedNetworks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "wifi.slash")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No Networks Loaded")
                                .font(.headline)
                            Text("Set up access to your WiFi history to get started.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 220)
                            Button("Open Setup") {
                                NotificationCenter.default.post(name: .showSetupSheet, object: nil)
                            }
                            .buttonStyle(WiFiButtonStyle())
                        }
                    }
                }
            )
            .alert(isPresented: $showDropError) {
                Alert(
                    title: Text("Could Not Read File"),
                    message: Text(dropErrorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onAppear {
            sortString = selectedSort.title
            // If helper is already running, load directly; otherwise show setup
            if WiFiDataManager.shared.helperIsRunning {
                WiFiDataManager.shared.loadViaHelper { networks, _ in
                    if let networks = networks, !networks.isEmpty {
                        sharedNetworks = networks
                        applySort()
                        reloadView.toggle()
                    } else if WiFiDataManager.shared.needsPassword() {
                        showSetupSheet = true
                    }
                }
            } else {
                loadWiFiData()
                if WiFiDataManager.shared.needsPassword() {
                    showSetupSheet = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSetupSheet)) { _ in
            showSetupSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showRemoveHelperSheet)) { _ in
            helperRemoved = false
            helperRemoveError = nil
            showRemoveHelperSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWiFiFile)) { _ in
            openWiFiFilePicker()
        }
        .onReceive(NotificationCenter.default.publisher(for: .loadRealWiFiData)) { _ in
            loadRealWiFiData()
        }
        .sheet(isPresented: $showSetupSheet) {
            SetupSheetView(
                sudoCommand: WiFiListPane.sudoCommand,
                onCopy: copyCommandToClipboard,
                onLoad: loadFromDownloads,
                onInstallHelper: installAndLoadViaHelper,
                helperInstalling: $helperInstalling,
                helperError: $helperError,
                helperNeedsApproval: $helperNeedsApproval,
                helperNeedsFDA: $helperNeedsFDA,
                showError: $showDropError,
                errorMessage: $dropErrorMessage
            )
        }
        .sheet(isPresented: $showRemoveHelperSheet) {
            RemoveHelperSheetView(
                onRemove: removeHelper,
                removing: $helperRemoving,
                removed: $helperRemoved,
                removeError: $helperRemoveError
            )
        }
            Spacer()
    }
}


struct SetupSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let sudoCommand: String
    let onCopy: () -> Void
    let onLoad: () -> Void
    let onInstallHelper: () -> Void
    @Binding var helperInstalling: Bool
    @Binding var helperError: String?
    @Binding var helperNeedsApproval: Bool
    @Binding var helperNeedsFDA: Bool
    @Binding var showError: Bool
    @Binding var errorMessage: String

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "lock.rectangle.stack")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("WiFi Check Setup")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("The system WiFi file is protected by macOS and requires elevated access to read.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 720)
            }
            .padding(.top, 36)
            .padding(.bottom, 28)

            // Two option cards side by side
            HStack(alignment: .top, spacing: 16) {

                // Option 1: Privileged Helper
                OptionCard(
                    badge: "1",
                    icon: "gearshape.2.fill",
                    title: "Install Helper",
                    subtitle: "Automatic — reads directly on every launch",
                    recommended: true
                ) {
                    VStack(spacing: 10) {
                        Text("Installs a privileged background helper that reads the WiFi file as root. Three one-time steps:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Enter your admin password if prompted", systemImage: "1.circle.fill")
                            Label("Enable WiFi Check in System Settings → Login Items → App Background Activity", systemImage: "2.circle.fill")
                            Label("Grant Full Disk Access to the helper binary", systemImage: "3.circle.fill")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        if helperNeedsFDA {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "lock.open.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                    .padding(.top, 1)
                                Text("One more step — the helper needs **Full Disk Access**. In System Settings → Privacy & Security → Full Disk Access, click **+** and add:\n`WiFiCheck.app`")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Button(action: {
                                NSWorkspace.shared.open(
                                    URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                            }) {
                                HStack {
                                    Image(systemName: "lock.open")
                                    Text("Open Full Disk Access Settings")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(WiFiButtonStyle())
                        } else if helperNeedsApproval {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                    .padding(.top, 1)
                                Text("Helper registered! System Settings opened — enable WiFi Check under **Privacy & Security → Login Items & Extensions**, then click below.")
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Button(action: {
                                SMAppService.openSystemSettingsLoginItems()
                            }) {
                                HStack {
                                    Image(systemName: "gearshape")
                                    Text("Open System Settings")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(WiFiButtonStyle())
                        } else if let err = helperError {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Button(action: onInstallHelper) {
                            HStack {
                                if helperInstalling {
                                    ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: helperNeedsApproval || helperNeedsFDA ? "arrow.clockwise" : "lock.shield")
                                }
                                Text(helperInstalling ? "Installing…" : helperNeedsApproval || helperNeedsFDA ? "Check Again" : "Install Helper")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(WiFiButtonStyle())
                        .disabled(helperInstalling)
                    }
                }

                // Option 2: Manual sudo copy
                OptionCard(
                    badge: "2",
                    icon: "terminal",
                    title: "Terminal Command",
                    subtitle: "Manual — run once in Terminal",
                    recommended: false
                ) {
                    VStack(spacing: 10) {
                        Text("Run the command below in Terminal. It copies the WiFi file to your Downloads folder where the app can read it.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(sudoCommand)
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(5)

                        HStack(spacing: 8) {
                            Button(action: onCopy) {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Command")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(WiFiButtonStyle())

                            Button(action: onLoad) {
                                HStack {
                                    Image(systemName: "arrow.down.circle")
                                    Text("Load File")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(WiFiButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 8)

            // Dismiss button — use ⌘Q to quit, or File > Setup to return here
            Button(action: { dismiss() }) {
                Text("Dismiss")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .frame(minWidth: 800)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Could Not Read File"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

private struct OptionCard<Content: View>: View {
    let badge: String
    let icon: String
    let title: String
    let subtitle: String
    let recommended: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ZStack {
                    Circle()
                        .fill(recommended ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 24, height: 24)
                    Text(badge)
                        .font(.caption.bold())
                        .foregroundColor(recommended ? .white : .primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .font(.headline)
                        Text(title)
                            .font(.headline)
                        if recommended {
                            Text("Recommended")
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(recommended ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}


struct RemoveHelperSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let onRemove: () -> Void
    @Binding var removing: Bool
    @Binding var removed: Bool
    @Binding var removeError: String?

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: removed ? "checkmark.circle.fill" : "trash.circle")
                    .font(.system(size: 48))
                    .foregroundColor(removed ? .green : .red)
                Text(removed ? "Helper Removed" : "Remove Helper")
                    .font(.title)
                    .fontWeight(.semibold)
            }
            .padding(.top, 36)

            if removed {
                // Post-removal: FDA cleanup guidance
                VStack(alignment: .leading, spacing: 12) {
                    Label("Background Activity entry removed.", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.callout)

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("One manual step remaining", systemImage: "lock.fill")
                            .font(.callout.bold())
                        Text("The helper's **Full Disk Access** entry is managed by macOS and cannot be removed automatically. To fully clean up:")
                            .font(.callout)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("1. Open **System Settings → Privacy & Security → Full Disk Access**\n2. Find `com.ciretose.macos.tool.WiFiCheck.helper`\n3. Click **–** to remove it")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: {
                        NSWorkspace.shared.open(
                            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }) {
                        HStack {
                            Image(systemName: "lock.open")
                            Text("Open Full Disk Access Settings")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WiFiButtonStyle())
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .frame(maxWidth: 480)

            } else {
                // Pre-removal: explanation + confirm
                VStack(alignment: .leading, spacing: 12) {
                    Text("This will stop the privileged helper daemon and remove it from **Background Activity** (Login Items).")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    Label("If you delete the app without removing the helper first, macOS will automatically remove the Background Activity entry, but the **Full Disk Access** entry in Privacy & Security will remain and must be removed manually.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let err = removeError {
                        Label(err, systemImage: "xmark.octagon.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .frame(maxWidth: 480)

                Button(action: onRemove) {
                    HStack {
                        if removing {
                            ProgressView().scaleEffect(0.7).frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text(removing ? "Removing…" : "Remove Helper")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WiFiButtonStyle(delete: true))
                .disabled(removing)
                .frame(maxWidth: 480)
            }

            Button(action: { dismiss() }) {
                Text("Done")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 40)
        .frame(minWidth: 520)
    }
}


struct WiFiDetailPane: View {
    let networks: [WiFiData]

    private var mostRecentJoined: String {
        let dates = networks.compactMap { $0.JoinedBySystemAt }
        guard let latest = dates.max() else { return "None" }
        return Utils.relativeDateToString(latest) ?? Utils.dateToString(latest) ?? "Unknown"
    }

    private var wpa3Count: Int { networks.filter { $0.securityType() == .wpa3 }.count }
    private var wpa2Count: Int { networks.filter { $0.securityType() == .wpa2 }.count }
    private var openCount: Int { networks.filter { $0.securityType() == .open }.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 30)

                Image(systemName: "wifi")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                Text("WiFi Check")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Your WiFi network history")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()
                    .padding(.horizontal, 40)

                if networks.isEmpty {
                    Text("Load your WiFi history to get started")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        alignment: .center,
                        spacing: 16
                    ) {
                        StatCard(label: "Total Networks", value: "\(networks.count)", icon: "list.bullet.rectangle")
                        StatCard(label: "Most Recently Joined", value: mostRecentJoined, icon: "clock")
                        StatCard(label: "WPA3", value: "\(wpa3Count)", icon: "lock.shield")
                        StatCard(label: "WPA2", value: "\(wpa2Count)", icon: "lock")
                        StatCard(label: "Open Networks", value: "\(openCount)", icon: "lock.open")
                    }
                    .padding(.horizontal, 30)
                }

                Spacer(minLength: 30)
            }
        }
        .frame(minWidth: 400)
        .accessibilityLabel("No network selected. Summary of WiFi history shown.")
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}


struct WiFiListView_Previews: PreviewProvider {
    static var previews: some View {
        WiFiListView()
    }
}

