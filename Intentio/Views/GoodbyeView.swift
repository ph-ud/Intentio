//
//  GoodbyeView.swift
//  Intentio
//

import SwiftUI

struct GoodbyeView: View {
    var body: some View {
        ZStack {
            Color.intentioBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                Text("See you tomorrow.")
                    .font(.system(.largeTitle, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
        }
    }
}
