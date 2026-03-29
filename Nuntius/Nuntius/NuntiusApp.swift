//
//  NuntiusApp.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import SwiftUI
import Combine
import CoreText
import UIKit

/// Shared observable state passed through the SwiftUI environment.
/// Coordinates data between the Share Extension and the main app.
class AppState: ObservableObject {

    /// File URLs queued by the Share Extension, waiting to be loaded into SendView.
    @Published var pendingShareURLs: [URL] = []

    /// The currently selected bottom tab. 0 = Send, 1 = Receive.
    @Published var activeTab: Int = 0

    /// The App Group identifier shared between the main app and the Share Extension.
    private static let appGroupID = "group.com.github.joaoofreitas.Nuntius"

    /// The UserDefaults key under which the Share Extension stores pending file paths.
    private static let pendingPathsKey = "pendingFilePaths"

    /// Reads file paths the Share Extension stored in the App Group container and clears them.
    /// @returns File URLs ready to pass to SendView, or an empty array if none are pending.
    func consumePendingSharedFiles() -> [URL] {
        let defaults = UserDefaults(suiteName: Self.appGroupID)
        guard let paths = defaults?.stringArray(forKey: Self.pendingPathsKey),
              !paths.isEmpty
        else { return [] }
        defaults?.removeObject(forKey: Self.pendingPathsKey)
        defaults?.synchronize()
        return paths.map { URL(fileURLWithPath: $0) }
    }
}

/// Application entry point. Registers custom fonts and injects AppState into the environment.
@main
struct NuntiusApp: App {

    /// Shared application state passed down through the environment.
    @StateObject private var appState = AppState()

    init() {
        registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    guard url.scheme == "nuntius" else { return }
                    loadPendingSharedFiles()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    loadPendingSharedFiles()
                }
        }
    }

    /// Reads any files queued by the Share Extension and routes the app to the Send tab.
    private func loadPendingSharedFiles() {
        let urls = appState.consumePendingSharedFiles()
        guard !urls.isEmpty else { return }
        appState.pendingShareURLs = urls
        appState.activeTab = 0
    }

    /// Registers all custom fonts from the app bundle at startup.
    /// Required because fonts inside a bundle subdirectory are not picked up by UIAppFonts automatically.
    private func registerFonts() {
        let fontNames = [
            "SpaceGrotesk-Light",
            "SpaceGrotesk-Regular",
            "SpaceGrotesk-Medium",
            "SpaceGrotesk-SemiBold",
            "SpaceGrotesk-Bold",
            "Manrope-ExtraLight",
            "Manrope-Light",
            "Manrope-Regular",
            "Manrope-Medium",
            "Manrope-SemiBold",
            "Manrope-Bold",
            "Manrope-ExtraBold",
        ]
        for name in fontNames {
            guard
                let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                    ?? Bundle.main.url(forResource: name, withExtension: "ttf")
            else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
