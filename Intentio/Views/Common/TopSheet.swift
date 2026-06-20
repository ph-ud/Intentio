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
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                if let cached {
                    Color.black.opacity(0.18)
                        .ignoresSafeArea()
                        .onTapGesture { item = nil }

                    // The card's background bleeds up to the very top edge so the
                    // sheet still reads as dropping in from the top, but the
                    // content is padded past the top safe-area inset so the title
                    // and note clear the status bar / Dynamic Island.
                    content(cached)
                        .padding(.horizontal, 24)
                        .padding(.top, proxy.safeAreaInsets.top + 28)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity)
                        .background(Color.intentioSheet)
                        .clipShape(
                            .rect(
                                bottomLeadingRadius: 28,
                                bottomTrailingRadius: 28
                            )
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea(.container, edges: .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: cached?.id)
        .onChange(of: item?.id, initial: true) {
            cached = item
        }
    }
}
