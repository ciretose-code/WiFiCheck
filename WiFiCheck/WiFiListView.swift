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
    @State private var isLoadingWithAdmin = false

    func loadWiFiData() {
        wifidataArray = WiFiDataManager.shared.getWiFiDataList()
    }

    /// Triggers the macOS admin password dialog and loads the WiFi plist if authorized.
    @MainActor
    func loadWithAdminPrivileges() {
        isLoadingWithAdmin = true
        let success = WiFiDataManager.shared.loadWithAdminPrivileges()
        isLoadingWithAdmin = false
        if success {
            wifidataArray = WiFiDataManager.shared.getWiFiDataList()
            reloadView.toggle()
        }
        // On cancel/failure, stay on the permission screen — no error shown (user chose to cancel)
    }

    func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        provider.loadFileRepresentation(forTypeIdentifier: UTType.propertyList.identifier) { url, error in
            guard let fileURL = url, error == nil else {
                // Read failed — check if it was the root-owned system WiFi plist.
                // If so, silently escalate to admin auth instead of showing an error.
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
                            loadWithAdminPrivileges()
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
                Text("The WiFi known-networks file is owned by root and requires administrator access to read.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: 380)
                Button(action: {
                    loadWithAdminPrivileges()
                }) {
                    HStack {
                        if isLoadingWithAdmin {
                            ProgressView().scaleEffect(0.7).padding(.trailing, 2)
                        } else {
                            Image(systemName: "key.fill")
                        }
                        Text(isLoadingWithAdmin ? "Waiting for authorization…" : "Load with Administrator Access")
                    }
                    .frame(minWidth: 260)
                }
                .buttonStyle(WiFiButtonStyle())
                .disabled(isLoadingWithAdmin)
                .accessibilityLabel("Load WiFi data using administrator credentials")
                Text("You will be prompted for your administrator password.")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
