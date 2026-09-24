//
//  WiFiDataList.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/3/21.
//

import SwiftUI

struct WiFiDataList: View {
    var wifidatalist = WiFiDataManager.shared.getWiFiDataList()
    var body: some View {
        List(wifidatalist) { wifidata in
            WiFiDataRow(wifidata: wifidata)
        }
    }
}

#Preview {
    WiFiDataList()
}
