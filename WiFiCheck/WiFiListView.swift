//
//  WiFiListView.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 9/10/21.
//

import SwiftUI

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
    
    @State private var selectedSort = SortableMenu.preferredOrder
    @State private var wifidataArray = Array<WiFiData>()
    @State private var sortString = "Preferred"
    @State private var listSelection: WiFiData? = nil
    @State private var showingAlert = false
    @State private var showPermissionError = false
    @State private var showDeleteResult = false
    @State private var deleteSuccess = false
    @State private var deleteMessage = ""
    @State private var reloadView = false
    @State private var isDropTargeted = false
    @State private var showDropError = false
    @State private var dropErrorMessage = ""
//    @State private var savePasswordChecked = false
    
    func loadWiFiData() {
        wifidataArray = WiFiDataManager.shared.getWiFiDataList()
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    dropErrorMessage = error?.localizedDescription ?? "Could not read the dropped file."
                    showDropError = true
                }
                return
            }

            // The item is delivered as Data containing a file URL
            let url: URL?
            if let urlData = item as? Data {
                url = URL(dataRepresentation: urlData, relativeTo: nil)
            } else if let directURL = item as? URL {
                url = directURL
            } else {
                url = nil
            }

            guard let fileURL = url else {
                DispatchQueue.main.async {
                    dropErrorMessage = "Could not resolve the dropped file path."
                    showDropError = true
                }
                return
            }

            guard fileURL.pathExtension == "plist" else {
                DispatchQueue.main.async {
                    dropErrorMessage = "Please drop a .plist file (e.g. com.apple.wifi.known-networks.plist)."
                    showDropError = true
                }
                return
            }

            // Start security-scoped access (granted by com.apple.security.files.user-selected.read-only)
            let accessing = fileURL.startAccessingSecurityScopedResource()
            defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

            guard let data = try? Data(contentsOf: fileURL) else {
                DispatchQueue.main.async {
                    dropErrorMessage = "Could not read \"\(fileURL.lastPathComponent)\". Make sure the file is readable."
                    showDropError = true
                }
                return
            }

            let parsed = WiFiDataManager.shared.parseDroppedData(data)
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
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment:.center) {
                    VStack(alignment:.leading) {
                        Text("WiFi/Check").font(.title)
                        Divider()
                        Text("WiFi/Check provides information about WiFi Network connections known to your Mac. This information comes from your Network System Preferences, hidden preferences files and command line utilities.")
                        Text("")
                        Text("On macOS Big Sur and later, WiFi/Check requires Full Disk Access to read the WiFi Known Networks file.")
                        Text("")
                        Text("Click 'Open Plist File' to reveal the file in Finder, then drag and drop it onto this window to load it.")
                    }.padding()
                    VStack(alignment: .center) {
                        Button(action:{
                            WiFiDataManager.shared.revealKnownNetworksPlistInFinder()
                        }) {
                            HStack {
                                Image(systemName: "doc.badge.magnifyingglass")
                                Text("Open Plist File")
                            }
                        }
                        .buttonStyle(WiFiButtonStyle())
                        .accessibilityLabel("Open WiFi known networks plist file in Finder")
                    }
                    .alert(isPresented: $showPermissionError) {
                        Alert(
                            title: Text("Full Disk Access Required"),
                            message: Text("WiFi/Check needs Full Disk Access to read WiFi preferences.\n\nSteps:\n1. Click 'Open System Settings' below\n2. Click the lock icon to unlock\n3. Click '+' button\n4. Select WiFi/Check.app from Applications\n5. Quit and relaunch WiFi/Check\n6. Click 'Check Access' again"),
                            primaryButton: .default(Text("Open System Settings")) {
                                WiFiDataManager.shared.openFullDiskAccessSettings()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                Spacer()
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
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
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
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
                    showingAlert = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove WiFi")
                    }
                }
                .disabled(listSelection == nil)
                .accessibilityLabel(listSelection.map { "Remove \($0.ssidString())" } ?? "Remove WiFi network")
                .alert(isPresented: $showingAlert) {
                    if let selection = listSelection {
                        return Alert(
                            title: Text("Are you sure you want to remove \"\(selection.ssidString())\"?"),
                            message: Text("This will remove \"\(selection.ssidString())\" from your list of known WiFi Networks.  You can always rejoin this WiFi Network in the future."),
                            primaryButton: .destructive(Text("Delete")) {
                                let result = NetworkSetup.shared.deleteNetwork(selection.ssidString())
                                if result {
                                    // Delete succeeded - remove from UI
                                    if let idx = wifidataArray.firstIndex(of: selection) {
                                        wifidataArray.remove(at: idx)
                                        listSelection = nil
                                    }
                                    deleteSuccess = true
                                    deleteMessage = "Successfully removed \"\(selection.ssidString())\""
                                } else {
                                    // Delete failed - show error
                                    deleteSuccess = false
                                    deleteMessage = "Failed to remove \"\(selection.ssidString())\". Please try again."
                                }
                                showDeleteResult = true
                            },
                            secondaryButton: .cancel()
                        )
                    } else {
                        // This shouldn't happen, but provide a fallback alert
                        return Alert(
                            title: Text("No Network Selected"),
                            message: Text("Please select a network to remove."),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                }
                .buttonStyle(WiFiButtonStyle(delete: true, disabled: (listSelection == nil)))
                .alert(isPresented: $showDeleteResult) {
                    Alert(
                        title: Text(deleteSuccess ? "Success" : "Error"),
                        message: Text(deleteMessage),
                        dismissButton: .default(Text("OK"))
                    )
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
            if WiFiDataManager.shared.needsPassword() {
                HStack() {
                    Image(systemName: "arrow.left.circle.fill").font(.system(.title))
                    Text("Select WiFi Network").font(.title)
                }
                .accessibilityLabel("Select a WiFi network from the list to view details")
            }
        }.frame(minWidth: 400)

    }
}


struct WiFiListView_Previews: PreviewProvider {
    static var previews: some View {
        WiFiListView()
    }
}
