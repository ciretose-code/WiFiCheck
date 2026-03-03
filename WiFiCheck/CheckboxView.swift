//
//  CheckboxView.swift
//  WiFiCheck
//
//  Created by Eric Wuehler on 11/6/21.
//

import SwiftUI

struct CheckboxView: View {
    @Binding var checked: Bool

    var body: some View {
        Image(systemName: checked ? "checkmark.square.fill" : "square")
            .foregroundColor(checked ? Color.accentColor : Color.secondary)
            .onTapGesture {
                self.checked.toggle()
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(checked ? "Checked" : "Unchecked")
    }
}


struct CheckboxView_Previews: PreviewProvider {
    struct CheckboxViewHolder: View {
        @State private var checked = true
        var body: some View {
            HStack {
                CheckboxView(checked: $checked)
                Spacer()
                Text("This is checked")
            }
//            HStack {
//                CheckboxView(checked: $unchecked)
//                Spacer()
//                Text("Not Checked")
//            }
        }
    }
    static var previews: some View {
        CheckboxViewHolder()
    }
}
