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
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        VStack(alignment: .trailing) {
                            if (showPassword) {
                                let (res, pwd) = KeychainAccess.getWiFiPassword(forNetwork: wifidata.ssidString())
                                if res {
                                    Text("\(pwd)").font(.system(.title, design: .monospaced))
                                } else {
                                    Text("**********").font(.system(.title, design: .monospaced))
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
            Spacer()
            VStack(alignment: .leading) {
                Spacer()
                Text("ciretose © 2021-\(Calendar.current.component(.year, from: Date()))")
                    .foregroundColor(Color.gray)
            }
        }
        .onDisappear {
            // Clean up timer when view disappears
            stopPasswordTimer()
        }
    }

    // MARK: - Password Timer Methods

    /// Toggles password visibility and manages the auto-hide timer
    private func togglePasswordVisibility() {
        showPassword.toggle()

        if showPassword {
            // Password is now shown - start the auto-hide timer
            pwdText = "Hide Password"
            pwdIcon = "lock.slash"
            startPasswordTimer()
        } else {
            // Password is now hidden - cancel the timer
            pwdText = "Show Password"
            pwdIcon = "lock"
            stopPasswordTimer()
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
        stopPasswordTimer()
    }
}


struct CollocatedGroupView: View {
    var collocatedGroups: [WiFiData.CollocatedGroupData]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Networks At Same Location").bold()
            ForEach(collocatedGroups) { cgd in
                (
                    Text(Image(systemName: "wifi")) +
                    Text(" \(String(cgd.ssid))")
                )
                .bold()
                .foregroundColor(.white)
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .frame(height: 26, alignment: .center)
                .background(Color.accentColor)
                .clipShape(Capsule())
            }
        }
    }
}

struct ChannelHistoryView: View {
    var channelData: [WiFiData.ChannelData]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Channel History").bold()
            Spacer()
            ForEach(channelData) { cd in
                HStack() {
                    Text("\(cd.Channel)")
                        .bold()
                        .foregroundColor(.white)
                        .padding(0)
                        .frame(width: 40, height: 26, alignment: .center)
                        .background(Color.black)
                        .clipShape(Capsule())
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
    var bssidData: [WiFiData.BSSIDData]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("BSSID").bold()
            ForEach(bssidData) { b in
                Text("\(b.LEAKY_AP_BSSID)")
            }
        }
    }
}

struct WiFiDataDetail_Previews: PreviewProvider {
    static var previews: some View {
        WiFiDataDetail(wifidata: WiFiDataManager.shared.getWiFiDataList().first ?? WiFiData())
    }
}
