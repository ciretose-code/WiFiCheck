//
//  WiFiListView.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 9/10/21.
//

import SwiftUI
import UniformTypeIdentifiers

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
    var body: some View {
        NavigationView {
            WiFiListPane()
            WiFiDetailPane()
        }.toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleSidebar, label: {
                    Image(systemName: "sidebar.leading")
                })
                .padding(0)
                .accessibilityLabel("Toggle sidebar")
            }
        }
    }
    
    private func toggleSidebar() {
        #if os(iOS)
        #else
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        #endif
    }
    
}

struct WiFiListPane: View {

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

    @State private var selectedSort = SortableMenu.preferredOrder
    @State private var wifidataArray = Array<WiFiData>()
    @State private var sortString = "Preferred"
    @State private var listSelection: WiFiData? = nil
    @State private var activeDeleteAlert: DeleteAlert? = nil
    @State private var showPermissionError = false
    @State private var reloadView = false
    @State private var isDropTargeted = false
    @State private var showDropError = false
    @State private var dropErrorMessage = ""
    @State private var accessCheckFailed = false

    func loadWiFiData() {
        wifidataArray = WiFiDataManager.shared.getWiFiDataList()
    }

    /// Called after the user grants Full Disk Access and clicks "Check Access".
    /// Without app sandbox, TCC changes take effect immediately — no restart needed.
    func recheckAccess() {
        accessCheckFailed = false
        if WiFiDataManager.shared.recheckAccess() {
            wifidataArray = WiFiDataManager.shared.getWiFiDataList()
            reloadView.toggle()
        } else {
            accessCheckFailed = true
        }
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadFileRepresentation(forTypeIdentifier: UTType.propertyList.identifier) { url, error in
            guard let fileURL = url, error == nil else {
                // Read failed — check if it was the system WiFi plist. That file is root-owned
                // and TCC-protected; even root processes (like `do shell script`) cannot read it
                // without Full Disk Access. Guide the user to the FDA screen instead.
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
                            // Show FDA instructions rather than a confusing generic error
                            dropErrorMessage = "The system WiFi file requires Full Disk Access. Grant Full Disk Access to WiFiCheck in System Settings → Privacy & Security → Full Disk Access, then click \"Check Access\"."
                            showDropError = true
                        } else {
                            dropErrorMessage = error?.localizedDescription ?? "Could not read the dropped file."
                            showDropError = true
                        }
                    }
                }
                return
            }

            let parsed = WiFiDataManager.shared.loadFromURL(fileURL)
            DispatchQueue.main.async {
                if parsed {
                    wifidataArray = WiFiDataManager.shared.getWiFiDataList()
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
        if wifidataArray.count == 0 && WiFiDataManager.shared.needsPassword() {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 56))
                    .foregroundColor(.secondary)
                Text("WiFi/Check")
                    .font(.title)
                    .fontWeight(.semibold)
                VStack(alignment: .leading, spacing: 8) {
                    Text("WiFi/Check needs Full Disk Access to read the WiFi known-networks file.")
                        .multilineTextAlignment(.leading)
                    Text("1. Click Open Privacy Settings below")
                    Text("2. Click the lock to unlock, then click +")
                    Text("3. Navigate to and select WiFiCheck.app")
                    Text("4. Return here and click Check Access")
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: 360)
                HStack(spacing: 12) {
                    Button(action: {
                        WiFiDataManager.shared.openFullDiskAccessSettings()
                    }) {
                        HStack {
                            Image(systemName: "lock.shield")
                            Text("Open Privacy Settings")
                        }
                    }
                    .buttonStyle(WiFiButtonStyle())
                    .accessibilityLabel("Open Full Disk Access settings in System Settings")
                    Button(action: {
                        recheckAccess()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Check Access")
                        }
                    }
                    .buttonStyle(WiFiButtonStyle())
                    .accessibilityLabel("Check whether Full Disk Access has been granted")
                }
                if accessCheckFailed {
                    Text("Full Disk Access not yet granted. Grant access in System Settings and try again.")
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 360)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onDrop(of: [UTType.propertyList], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .opacity(isDropTargeted ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isDropTargeted)
            )
            .alert(isPresented: $showDropError) {
                Alert(
                    title: Text("Could Not Read File"),
                    message: Text(dropErrorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        } else {
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
                    .onChange(of: selectedSort) { sm in
                        sortString = sm.title
                        if sm == .preferredOrder {
                            wifidataArray = WiFiDataManager.shared.sortByPreferredOrder()
                        } else if sm == .recentUser {
                            wifidataArray = WiFiDataManager.shared.sortByRecentUser()
                        } else if sm == .recentSystem {
                            wifidataArray = WiFiDataManager.shared.sortByRecentSystem()
                        } else {
                            // Alphabetical
                            wifidataArray = WiFiDataManager.shared.sortByAlphabetical()
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                Divider()
                List(selection: $listSelection) {
    //                Section(header: Text("WiFi Networks: \(sortString)")) {
                        ForEach(wifidataArray) { wifidata in
                            NavigationLink(destination: WiFiDataDetail(wifidata: wifidata)){
                                WiFiDataRow(wifidata: wifidata)
                            }
                        }
    //                }
                }
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
                .alert(isPresented: $showDropError) {
                    Alert(
                        title: Text("Could Not Read File"),
                        message: Text(dropErrorMessage),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }.onAppear {
                loadWiFiData()
            }
            Divider()
            VStack {
                Button(action:{
                    if let selection = listSelection {
                        activeDeleteAlert = .confirm(selection)
                    }
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove WiFi")
                    }
                }
                .disabled(listSelection == nil)
                .accessibilityLabel(listSelection.map { "Remove \($0.ssidString())" } ?? "Remove WiFi network")
                .buttonStyle(WiFiButtonStyle(delete: true, disabled: (listSelection == nil)))
                .alert(item: $activeDeleteAlert) { alert in
                    switch alert {
                    case .confirm(let selection):
                        return Alert(
                            title: Text("Are you sure you want to remove \"\(selection.ssidString())\"?"),
                            message: Text("This will remove \"\(selection.ssidString())\" from your list of known WiFi Networks.  You can always rejoin this WiFi Network in the future."),
                            primaryButton: .destructive(Text("Delete")) {
                                let result = NetworkSetup.shared.deleteNetwork(selection.ssidString())
                                if result {
                                    if let idx = wifidataArray.firstIndex(of: selection) {
                                        wifidataArray.remove(at: idx)
                                        listSelection = nil
                                    }
                                    activeDeleteAlert = .result(success: true, message: "Successfully removed \"\(selection.ssidString())\"")
                                } else {
                                    activeDeleteAlert = .result(success: false, message: "Failed to remove \"\(selection.ssidString())\". Please try again.")
                                }
                            },
                            secondaryButton: .cancel()
                        )
                    case .result(let success, let message):
                        return Alert(
                            title: Text(success ? "Success" : "Error"),
                            message: Text(message),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }

                Button(action: {
                    WiFiDataManager.shared.revealKnownNetworksPlistInFinder()
                }) {
                    HStack {
                        Image(systemName: "doc.badge.magnifyingglass")
                        Text("Show Plist in Finder")
                    }
                }
                .buttonStyle(WiFiButtonStyle())
                .accessibilityLabel("Reveal WiFi known networks plist file in Finder")
            }
            Spacer()
        }
    }
}


struct WiFiDetailPane: View {
    var body: some View {
        VStack() {
            HStack() {
                Image(systemName: "arrow.left.circle.fill").font(.system(.title))
                Text("Select WiFi Network").font(.title)
            }
            .accessibilityLabel("Select a WiFi network from the list to view details")
        }.frame(minWidth: 400)

    }
}


struct WiFiListView_Previews: PreviewProvider {
    static var previews: some View {
        WiFiListView()
    }
}
