//
//  TopSheet.swift
//  Intentio
//

import SwiftUI

/// A sheet that drops in from the top edge. Driven by an optional `item` so the
/// presented content is retained through the dismiss transition — clearing the
/// item animates the sheet back out instead of removing it instantly.
struct TopSheet<Item: Identifiable, Content: View>: View {
    @Binding var item: Item?
    @ViewBuilder var content: (Item) -> Content

    /// Mirrors `item`, but lingers during the exit transition so the disappearing
    /// sheet still has content to render while it animates away.
    @State private var cached: Item?

    var body: some View {
        ZStack(alignment: .top) {
            if let cached {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .onTapGesture { item = nil }

                VStack {
                    content(cached)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 28)
                        .frame(maxWidth: .infinity)
                        .background(Color.intentioSheet)
                        .clipShape(
                            .rect(
                                bottomLeadingRadius: 28,
                                bottomTrailingRadius: 28
                            )
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)

                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: cached?.id)
        .ignoresSafeArea()
        .onChange(of: item?.id, initial: true) {
            cached = item
        }
    }
}
