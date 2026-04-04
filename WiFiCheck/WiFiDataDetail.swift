//
//  WiFiDataDetail.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/3/21.
//

import SwiftUI
import MapKit
import CoreLocation


// MARK: - Geocode Cache

final class GeocodeCache {
    static let shared = GeocodeCache()
    private init() {}

    private var cache: [String: String] = [:]

    private func key(lat: Double, lon: Double) -> String {
        // 4 decimal places ≈ 11 m resolution — more than enough for city-level results
        String(format: "%.4f,%.4f", lat, lon)
    }

    /// Returns a cached place name immediately, or performs a reverse geocode and caches the result.
    /// Completion is always called on the main queue.
    func resolve(lat: Double, lon: Double, completion: @escaping (String?) -> Void) {
        let k = key(lat: lat, lon: lon)
        if let cached = cache[k] {
            completion(cached)
            return
        }
        CLGeocoder().reverseGeocodeLocation(CLLocation(latitude: lat, longitude: lon)) { [self] placemarks, _ in
            let parts = [placemarks?.first?.locality,
                         placemarks?.first?.administrativeArea,
                         placemarks?.first?.country].compactMap { $0 }
            let name = parts.isEmpty ? nil : parts.joined(separator: ", ")
            if let name { self.cache[k] = name }
            DispatchQueue.main.async { completion(name) }
        }
    }
}

struct WiFiDataDetail: View {
    var wifidata: WiFiData = WiFiDataManager.shared.getWiFiDataList().first ?? WiFiData()

    var circleSize: CGFloat = 26.0
    var circleColor: Color = Color(white:0.4, opacity: 0.2)

    @State private var showPassword = false
    @State private var pwdShown = false
    @State private var pwdText = "Show Password"
    @State private var pwdIcon = "lock"
    @State private var cachedPassword: String? = nil

    @State private var showDeleteConfirm = false
    @State private var deleteError: String? = nil
    var onDelete: (() -> Void)? = nil

    // Password auto-hide timer
    @State private var passwordTimer: Timer?
    @State private var remainingSeconds: Int = Constants.passwordAutoHideDelay
    private let autoHideDelay: Int = Constants.passwordAutoHideDelay

    @ViewBuilder
    private var badgeView: some View {
        let hasBadges = wifidata.PersonalHotspot || wifidata.TemporarilyDisabled ||
                        wifidata.Moving || wifidata.SystemMode || wifidata.PrivacyProxyEnabled
        if hasBadges {
            HStack {
                if wifidata.PersonalHotspot {
                    Label("Personal Hotspot", systemImage: "personalhotspot")
                        .font(.caption).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.orange).clipShape(Capsule())
                }
                if wifidata.TemporarilyDisabled {
                    Label("Temporarily Disabled", systemImage: "wifi.slash")
                        .font(.caption).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.red).clipShape(Capsule())
                }
                if wifidata.Moving {
                    Label("Moving", systemImage: "figure.walk")
                        .font(.caption).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.blue).clipShape(Capsule())
                }
                if wifidata.SystemMode {
                    Label("iCloud Sync", systemImage: "icloud")
                        .font(.caption).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.blue).clipShape(Capsule())
                }
                if wifidata.PrivacyProxyEnabled {
                    Label("Privacy Proxy", systemImage: "shield.checkered")
                        .font(.caption).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color.green).clipShape(Capsule())
                }
            }
        }
    }

    var body: some View {

        ScrollView {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        HStack() {
                            Label {
                                Text(wifidata.ssidString())
                                    .font(.title)
                                    .foregroundColor(.primary)
                            } icon: {
                                Image(systemName: "wifi").renderingMode(.template).foregroundColor(Utils.getSecurityColor(wifidata))
                                    .font(.title)
                            }
                            .accessibilityLabel("Network: \(wifidata.ssidString())")
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Label {
                                Text(wifidata.getSecurityName())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: "lock")
                                    .renderingMode(.template)
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                            .accessibilityLabel("Security: \(wifidata.getSecurityName())")
                            Spacer()
                            Label {
                                Text(wifidata.hiddenStateText())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } icon: {
                                Image(systemName: wifidata.hiddenStateImage())
                                    .renderingMode(.template)
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)
                            }
                            .accessibilityLabel("Network visibility: \(wifidata.hiddenStateText())")
                            Spacer()
                            badgeView
                        }
                        Spacer()
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        VStack(alignment: .trailing) {
                            if showPassword {
                                if let password = cachedPassword, !password.isEmpty {
                                    Text(password).font(.system(.title, design: .monospaced))
                                } else {
                                    Text("**********").font(.system(.title, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                // Show countdown timer when password is visible
                                Text("Auto-hide in \(remainingSeconds)s")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("**********").font(.system(.title, design: .monospaced))
                            }
                            Button(action:{
                                togglePasswordVisibility()
                            }) {
                                HStack {
                                    Image(systemName: pwdIcon)
                                    Text(pwdText)
                                }
                            }
                            .buttonStyle(WiFiButtonStyle(disabled: (wifidata.securityType() == .open)))
                            .accessibilityLabel(showPassword ? "Hide network password" : "Show network password")
                            Spacer().frame(height: 8)
                            Button(action: { showDeleteConfirm = true }) {
                                HStack {
                                    Image(systemName: "minus.circle")
                                    Text("Remove Network")
                                }
                            }
                            .buttonStyle(WiFiButtonStyle(delete: true))
                            .accessibilityLabel("Remove \(wifidata.ssidString()) from known networks")
                        }
                    }
                }
                Spacer()
                Divider()
                Spacer()
                HStack {
                    VStack(alignment: .center) {
                        Text("Last Joined from this Mac").font(.headline)
                        HStack {
                            VStack{
                                WiFiDateBox(date: wifidata.JoinedBySystemAt, color: Color.accentColor)
                                Text("Automatically").foregroundColor(.secondary)
                            }
                            VStack {
                                WiFiDateBox(date: wifidata.JoinedByUserAt, color: Color.accentColor)
                                Text("Manually").foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        VStack(alignment: .center) {
                            Text("Added").font(.headline)
                            WiFiDateBox(date: wifidata.AddedAt, color: Color.accentColor)
                            Text("\(wifidata.AddReason)").foregroundColor(.secondary)
                        }
                    }
                }
                Divider().padding(.vertical, 4)
                HStack {
                    if let discovered = wifidata.LastDiscoveredAt {
                        VStack(alignment: .center) {
                            Text("Last Discovered").font(.headline)
                            WiFiDateBox(date: discovered, color: Utils.getDateBoxColor(wifidata, wifidata.LastDiscoveredAt))
                        }
                        Spacer()
                    }
                    if let updated = wifidata.UpdatedAt {
                        VStack(alignment: .center) {
                            Text("Profile Updated").font(.headline)
                            WiFiDateBox(date: updated, color: Utils.getDateBoxColor(wifidata, wifidata.UpdatedAt))
                        }
                        Spacer()
                    }
                    if wifidata.LastDisconnectTimestamp != nil {
                        VStack(alignment: .center) {
                            Text("Last Disconnect").font(.headline)
                            WiFiDateBox(date: wifidata.LastDisconnectTimestamp, color: Utils.getDateBoxColor(wifidata, wifidata.LastDisconnectTimestamp))
                            Text(wifidata.disconnectReasonText())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Divider()
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        if wifidata.ChannelHistory.count > 0 {
                            ChannelHistoryView(channelData: wifidata.ChannelHistory)
                        }
                        if wifidata.CollocatedGroup.count > 0 {
                            CollocatedGroupView(collocatedGroups: wifidata.CollocatedGroup)
                        }
                        NetworkDetailsSection(wifidata: wifidata)
                        if wifidata.isCaptive() {
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Captive Portal Last Login").bold()
                                Text(wifidata.captiveLogin())
                                    .bold()
                                    .textCase(.uppercase)
                                    .foregroundColor(.white)
                                    .padding(0)
                                    .frame(width: 200, height: 26, alignment: .center)
                                    .background(Color(NSColor.systemBrown))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    VStack(alignment: .leading) {
                        if !wifidata.BSSList.isEmpty {
                            BSSIDListView(bssidData: wifidata.BSSList)
                        }
                        Spacer()
                    }
                    Spacer()
                }
            }
            .padding()
        }
        .onDisappear {
            // Clean up timer when view disappears
            stopPasswordTimer()
        }
        .confirmationDialog(
            "Remove \"\(wifidata.ssidString())\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove Network", role: .destructive) {
                let success = NetworkSetup.shared.deleteNetwork(wifidata.ssidString())
                if success {
                    onDelete?()
                } else {
                    deleteError = "Could not remove \"\(wifidata.ssidString())\". Make sure the network exists in your preferred networks list."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \"\(wifidata.ssidString())\" from your known networks list. You can rejoin the network at any time.")
        }
        .alert("Remove Failed", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    // MARK: - Password Timer Methods

    /// Toggles password visibility and manages the auto-hide timer
    private func togglePasswordVisibility() {
        if showPassword {
            // Password is now being hidden - cancel the timer and clear cached value
            showPassword = false
            pwdText = "Show Password"
            pwdIcon = "lock"
            cachedPassword = nil
            stopPasswordTimer()
        } else {
            // Fetch the password once here (not in body) to avoid blocking the main thread
            // on every render. cachedPassword is cleared when the password is hidden.
            switch KeychainAccess.getPassword(forNetwork: wifidata.ssidString()) {
            case .success(let password):
                cachedPassword = password
            case .failure:
                cachedPassword = nil
            }
            showPassword = true
            pwdText = "Hide Password"
            pwdIcon = "lock.slash"
            startPasswordTimer()
        }
    }

    /// Starts the countdown timer to auto-hide the password
    private func startPasswordTimer() {
        // Reset countdown
        remainingSeconds = autoHideDelay

        // Cancel any existing timer
        stopPasswordTimer()

        // Start a new timer that ticks every second
        passwordTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                // Time's up - hide the password
                hidePassword()
            }
        }
    }

    /// Stops and invalidates the password timer
    private func stopPasswordTimer() {
        passwordTimer?.invalidate()
        passwordTimer = nil
    }

    /// Hides the password and resets the UI state
    private func hidePassword() {
        showPassword = false
        pwdText = "Show Password"
        pwdIcon = "lock"
        cachedPassword = nil
        stopPasswordTimer()
    }
}


struct CollocatedGroupView: View {
    var collocatedGroups: [WiFiData.CollocatedGroupData]

    var body: some View {
        VStack(alignment: .leading) {
            Divider()
            Text("Networks At Same Location").bold()
            ForEach(collocatedGroups) { cgd in
                Text("\(Image(systemName: "wifi")) \(String(cgd.ssid))")
                .bold()
                .foregroundColor(.white)
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .frame(height: 26, alignment: .center)
                .background(Color.accentColor)
                .clipShape(Capsule())
                .accessibilityLabel("Collocated network: \(cgd.ssid)")
            }
        }
    }
}

struct ChannelHistoryView: View {
    var channelData: [WiFiData.ChannelData]

    private func frequencyBand(for channel: Int) -> String {
        switch channel {
        case 1...13: return "2.4 GHz"
        case 14: return "2.4 GHz"
        case 36...177: return "5 GHz"
        default: return "6 GHz"
        }
    }

    private func bandColor(for channel: Int) -> Color {
        switch channel {
        case 1...14: return Color.orange
        case 36...177: return Color(red: 0.1, green: 0.5, blue: 0.9)
        default: return Color.purple
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Channel History").bold()
            Spacer()
            ForEach(channelData) { (cd: WiFiData.ChannelData) in
                HStack() {
                    Text("\(cd.Channel)")
                        .bold()
                        .foregroundColor(.white)
                        .padding(0)
                        .frame(width: 40, height: 26, alignment: .center)
                        .background(Color.black)
                        .clipShape(Capsule())
                        .accessibilityLabel("Channel \(cd.Channel)")
                    Text(frequencyBand(for: cd.Channel))
                        .font(.caption)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .frame(minWidth: 70, minHeight: 26, maxHeight: 26, alignment: .center)
                        .background(bandColor(for: cd.Channel))
                        .clipShape(Capsule())
                        .accessibilityLabel(frequencyBand(for: cd.Channel))
                    Text("\(cd.joinedTime())")
                        .bold()
                        .textCase(.uppercase)
                        .foregroundColor(.white)
                        .padding(0)
                        .frame(width: 200, height: 26, alignment: .center)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .help(Text("\(cd.joinedTime(false))"))
                }
                Spacer()
            }
        }
        Spacer()
    }
}



struct BSSIDListView: View {
    var bssidData: [WiFiData.BSSData]

    private func frequencyBand(for channel: Int) -> String {
        switch channel {
        case 1...14: return "2.4 GHz"
        case 36...177: return "5 GHz"
        default: return "6 GHz"
        }
    }

    private func dhcpServerIP(from data: Data?) -> String? {
        guard let data = data, data.count == 4 else { return nil }
        return data.map { String($0) }.joined(separator: ".")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Access Points").bold()
            ForEach(bssidData) { (b: WiFiData.BSSData) in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(b.BSSID)
                            .font(.system(.body, design: .monospaced))
                            .bold()
                        if b.Channel > 0 {
                            Text("Ch \(b.Channel)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .frame(height: 20)
                                .background(Color.black)
                                .clipShape(Capsule())
                            Text(frequencyBand(for: b.Channel))
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .frame(height: 20)
                                .background(b.Channel <= 14 ? Color.orange : (b.Channel <= 177 ? Color(red: 0.1, green: 0.5, blue: 0.9) : Color.purple))
                                .clipShape(Capsule())
                        }
                    }
                    if let lastSeen = b.LastAssociatedAt {
                        Text("Last seen \(Utils.relativeDateToString(lastSeen) ?? "Unknown")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let ip = dhcpServerIP(from: b.DHCPServerID) {
                        Text("Router: \(ip)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
//                    if !b.IPv4NetworkSignature.isEmpty {
//                        Text(b.IPv4NetworkSignature)
//                            .font(.caption2)
//                            .foregroundColor(.secondary)
//                            .lineLimit(1)
//                            .truncationMode(.tail)
//                    }
                    if let lat = b.LocationLatitude, let lon = b.LocationLongitude {
                        BSSLocationMapView(latitude: lat, longitude: lon, accuracy: b.LocationAccuracy)
                    }
                }
                .padding(.bottom, 4)
                if bssidData.last?.id != b.id {
                    Divider()
                }
            }
        }
    }
}


struct BSSLocationMapView: View {
    let latitude: Double
    let longitude: Double
    let accuracy: Double?

    @State private var showExpanded = false
    @State private var placeName: String? = nil

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private var coordinateText: String {
        "\(String(format: "%.5f", latitude)), \(String(format: "%.5f", longitude))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Map(position: .constant(.region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            ))), interactionModes: []) {
                Marker("", coordinate: coordinate)
            }
            .mapStyle(.standard(elevation: .flat))
            .frame(width: 200, height: 130)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: Alignment.bottomTrailing) {
                Button {
                    showExpanded = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .padding(4)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .padding(4)
            }

            if let place = placeName {
                Text(place)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(coordinateText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let acc = accuracy {
                Text("± \(String(format: "%.0f", acc))m accuracy")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            GeocodeCache.shared.resolve(lat: latitude, lon: longitude) { name in
                placeName = name
            }
        }
        .sheet(isPresented: $showExpanded) {
            LocationMapSheet(coordinate: coordinate, accuracy: accuracy, coordinateText: coordinateText, placeName: placeName)
        }
    }
}


struct LocationMapSheet: View {
    let coordinate: CLLocationCoordinate2D
    let accuracy: Double?
    let coordinateText: String
    let placeName: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Map(position: .constant(.region(MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 800,
                longitudinalMeters: 800
            )))) {
                Marker("Access Point", coordinate: coordinate)
            }
            .mapStyle(.standard)
            .frame(minWidth: 520, minHeight: 420)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let place = placeName {
                        Text("📍 \(place)")
                            .font(.caption)
                    }
                    Text(coordinateText)
                        .font(.caption)
                        .foregroundColor(placeName != nil ? .secondary : .primary)
                    if let acc = accuracy {
                        Text("Accuracy: ± \(String(format: "%.0f", acc)) meters")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Open in Maps") {
                    if let url = URL(string: "maps://?ll=\(coordinate.latitude),\(coordinate.longitude)&z=15") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
    }
}


struct NetworkDetailsSection: View {
    var wifidata: WiFiData

    var body: some View {
        let hasRoaming = !wifidata.RoamingProfileType.isEmpty
        let hasPrivateMAC = !wifidata.CachedPrivateMACAddress.isEmpty
        let hasMACEval = !wifidata.PrivateMACAddressEvaluationState.isEmpty
        let hasBrokenBackhaul = !wifidata.BrokenBackhaulState.isEmpty && wifidata.BrokenBackhaulState != "not broken"
        let hasPreferredNames = !wifidata.UserPreferredNetworkNames.isEmpty

        if hasRoaming || hasPrivateMAC || hasMACEval || hasBrokenBackhaul || hasPreferredNames {
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Details").bold()
                if hasRoaming {
                    HStack {
                        Text("Roaming Profile").foregroundColor(.secondary).frame(width: 160, alignment: .leading)
                        Text(wifidata.RoamingProfileType).bold()
                    }
                }
                if hasPrivateMAC {
                    HStack {
                        Text("Private MAC Address").foregroundColor(.secondary).frame(width: 160, alignment: .leading)
                        Text(wifidata.CachedPrivateMACAddress).bold()
                    }
                }
                if hasMACEval {
                    HStack {
                        Text("MAC Evaluation State").foregroundColor(.secondary).frame(width: 160, alignment: .leading)
                        Text(wifidata.PrivateMACAddressEvaluationState).bold()
                    }
                }
                if hasBrokenBackhaul {
                    HStack {
                        Text("Backhaul State").foregroundColor(.secondary).frame(width: 160, alignment: .leading)
                        Text(wifidata.BrokenBackhaulState).bold()
                    }
                }
                if hasPreferredNames {
                    HStack {
                        Text("Preferred Names").foregroundColor(.secondary).frame(width: 160, alignment: .leading)
                        Text(wifidata.UserPreferredNetworkNames.joined(separator: ", ")).bold()
                    }
                }
            }
        }
    }
}

struct WiFiDataDetail_Previews: PreviewProvider {
    static var previews: some View {
        WiFiDataDetail(wifidata: WiFiDataManager.shared.getWiFiDataList().first ?? WiFiData())
    }
}
