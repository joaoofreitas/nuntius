//
//  ContentView.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var tab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "120c18").ignoresSafeArea()

            SendView()
                .opacity(tab == 0 ? 1 : 0)
                .padding(.bottom, 60)

            ReceiveView()
                .opacity(tab == 1 ? 1 : 0)
                .padding(.bottom, 60)

            HStack(spacing: 0) {
                tabItem(0, label: "SEND", icon: "arrow.up.circle")
                tabItem(1, label: "RECEIVE", icon: "arrow.down.circle")
            }
            .frame(height: 60)
            .background(Color(hex: "181021"))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(hex: "4d4553").opacity(0.4))
                    .frame(height: 1)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Builds a single bottom tab item
    /// @param index The tab index
    /// @param label The button label
    /// @param icon The SF Symbol name (fill variant used when active)
    /// @returns A styled tab button
    private func tabItem(_ index: Int, label: String, icon: String) -> some View {
        let active = tab == index
        return Button(action: { tab = index }) {
            VStack(spacing: 4) {
                Image(systemName: active ? "\(icon).fill" : icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.spaceBold(9))
                    .kerning(1.5)
            }
            .foregroundColor(active ? Color(hex: "9cff93") : Color(hex: "4d4553"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension Color {
    /// Initialize a Color from a 6-character hex string
    /// @param hex Hex string without the # prefix
    init(hex: String) {
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8)  & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}

extension Font {
    /// Space Grotesk Bold — headings, buttons, labels
    static func spaceBold(_ size: CGFloat) -> Font { .custom("SpaceGrotesk-Bold", size: size) }
    /// Space Grotesk Regular
    static func spaceGrotesk(_ size: CGFloat) -> Font { .custom("SpaceGrotesk-Regular", size: size) }
    /// Manrope Regular — body text and descriptions
    static func manrope(_ size: CGFloat) -> Font { .custom("Manrope-Regular", size: size) }
    /// Manrope Medium
    static func manropeMedium(_ size: CGFloat) -> Font { .custom("Manrope-Medium", size: size) }
}

#Preview {
    ContentView()
}
