//
//  ContentView.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import SwiftUI

/// Root view. Hosts the Send and Receive tabs and the bottom navigation bar.
struct ContentView: View {

    /// Shared application state, injected from NuntiusApp.
    @EnvironmentObject private var appState: AppState

    /// The index of the currently visible tab. 0 = Send, 1 = Receive.
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
        .onChange(of: appState.activeTab) { newTab in
            tab = newTab
        }
    }

    /// Builds a single bottom tab button.
    /// @param index The tab index this button activates.
    /// @param label The uppercase label displayed below the icon.
    /// @param icon The SF Symbol name. The fill variant is used when the tab is active.
    /// @returns A styled, tappable tab button that fills its available width.
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

// MARK: - Color

extension Color {

    /// Initializes a Color from a 6-character hex string.
    /// @param hex A hex string without the # prefix, e.g. "9cff93".
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

// MARK: - Font

extension Font {

    /// Space Grotesk Bold — used for headings, buttons, and uppercase labels.
    /// @param size The point size.
    /// @returns A custom Font instance.
    static func spaceBold(_ size: CGFloat) -> Font { .custom("SpaceGrotesk-Bold", size: size) }

    /// Space Grotesk Regular.
    /// @param size The point size.
    /// @returns A custom Font instance.
    static func spaceGrotesk(_ size: CGFloat) -> Font { .custom("SpaceGrotesk-Regular", size: size) }

    /// Manrope Regular — used for body text and descriptions.
    /// @param size The point size.
    /// @returns A custom Font instance.
    static func manrope(_ size: CGFloat) -> Font { .custom("Manrope-Regular", size: size) }

    /// Manrope Medium.
    /// @param size The point size.
    /// @returns A custom Font instance.
    static func manropeMedium(_ size: CGFloat) -> Font { .custom("Manrope-Medium", size: size) }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
