//
//  WiFiDateBox.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 10/22/21.
//

import SwiftUI


struct WiFiDateBox: View {
    var date: Date?
    var color: Color = Color.gray
    var frameWidth: CGFloat = 150.0
    var frameHeight: CGFloat = 32.0
    
    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Text(Utils.relativeDateToString(date) ?? "NEVER")
                .bold()
                .font(.system(size:14))
                .textCase(.uppercase)
                .foregroundColor(.white)
                .padding(3)
                .frame(width: frameWidth, height: frameHeight, alignment: .center)
                .background(color)
                .clipShape(Capsule())
                .help(Text("\(Utils.dateToString(date) ?? "NEVER")"))
                .accessibilityLabel(Utils.dateToString(date) ?? "Never joined")
        }
    }
}

struct WiFiDateBox_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WiFiDateBox(date: Date())
            WiFiDateBox(date: Date())
            WiFiDateBox(date: nil)
        }
    }
}
