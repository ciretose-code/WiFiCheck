//
//  WiFiDataDetail.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/3/21.
//

import SwiftUI


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
                        }
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
                                WiFiDateBox(date: wifidata.JoinedBySystemAt, color: Utils.getDateBoxColor(wifidata, wifidata.JoinedBySystemAt))
                                Text("Automatically").foregroundColor(.secondary)
                            }
                            VStack {
                                WiFiDateBox(date: wifidata.JoinedByUserAt, color: Utils.getDateBoxColor(wifidata, wifidata.JoinedByUserAt))
                                Text("Manually").foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        VStack(alignment: .center) {
                            Text("Added On").font(.headline)
//                            VStack(alignment: .trailing) {
                                WiFiDateBox(date: wifidata.AddedAt, color: Utils.getDateBoxColor(wifidata, wifidata.AddedAt))
//                            }
                            Text("\(wifidata.AddReason)").foregroundColor(.secondary)
                        }
                    }
                }
                Divider()
                HStack {
                    VStack(alignment: .trailing) {
                        if (wifidata.ChannelHistory.count > 0) {
                            ChannelHistoryView(channelData: wifidata.ChannelHistory)
                        }
                    }
                    if (wifidata.ChannelHistory.count > 0) {
                        Divider()
                    }
                    VStack(alignment: .leading) {
                        if (wifidata.CollocatedGroup.count > 0) {
                            CollocatedGroupView(collocatedGroups: wifidata.CollocatedGroup)
                        }
                        if !wifidata.BSSList.isEmpty {
                            BSSIDListView(bssidData: wifidata.BSSList)
                        }
                        if (wifidata.isCaptive()) {
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
    }
}



struct BSSIDListView: View {
    var bssidData: [WiFiData.BSSData]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("BSSID").bold()
            ForEach(bssidData) { b in
                Text("\(b.BSSID)")
            }
        }
    }
}

struct WiFiDataDetail_Previews: PreviewProvider {
    static var previews: some View {
        WiFiDataDetail(wifidata: WiFiDataManager.shared.getWiFiDataList().first ?? WiFiData())
    }
}

