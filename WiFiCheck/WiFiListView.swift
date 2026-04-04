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
    @State private var showSetupSheet = false

    static let sudoCommand = "sudo cp /Library/Preferences/com.apple.wifi.known-networks.plist ~/Downloads/wifi-networks.plist && sudo chmod 644 ~/Downloads/wifi-networks.plist"

    func loadWiFiData() {
        wifidataArray = WiFiDataManager.shared.getWiFiDataList()
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
            wifidataArray = WiFiDataManager.shared.getWiFiDataList()
            reloadView.toggle()
            showSetupSheet = false
        } else {
            dropErrorMessage = "wifi-networks.plist doesn't appear to be a valid WiFi known-networks plist."
            showDropError = true
        }
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
                        wifidataArray = WiFiDataManager.shared.sortByAlphabetical()
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            Divider()
            List(selection: $listSelection) {
                    ForEach(wifidataArray) { wifidata in
                        NavigationLink(destination: WiFiDataDetail(wifidata: wifidata)){
                            WiFiDataRow(wifidata: wifidata)
                        }
                    }
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
        }
        .onAppear {
            loadWiFiData()
            if WiFiDataManager.shared.needsPassword() {
                showSetupSheet = true
            }
        }
        .sheet(isPresented: $showSetupSheet) {
            SetupSheetView(
                sudoCommand: WiFiListPane.sudoCommand,
                onCopy: copyCommandToClipboard,
                onLoad: loadFromDownloads,
                showError: $showDropError,
                errorMessage: $dropErrorMessage
            )
        }
            Spacer()
    }
}


struct SetupSheetView: View {
    let sudoCommand: String
    let onCopy: () -> Void
    let onLoad: () -> Void
    @Binding var showError: Bool
    @Binding var errorMessage: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.rectangle.stack")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("WiFi/Check Setup")
                .font(.title)
                .fontWeight(.semibold)

            Text("The system WiFi file is protected by macOS and requires root access to read.\nRun the command below in Terminal, then click Load WiFi Data.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .frame(maxWidth: 440)

            HStack(spacing: 8) {
                Text(sudoCommand)
                    .font(.system(.body, design: .monospaced))
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }

            HStack(spacing: 12) {
                Button(action: onCopy) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Command")
                    }
                }
                .buttonStyle(WiFiButtonStyle())

                Button(action: onLoad) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("Load WiFi Data")
                    }
                }
                .buttonStyle(WiFiButtonStyle())
            }

            Text("Paste the command into Terminal and press Return, then click Load WiFi Data.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
        }
        .padding(40)
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Could Not Read File"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
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
