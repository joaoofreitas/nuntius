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

/// Shared observable state passed through the environment.
class AppState: ObservableObject {
    @Published var pendingShareURLs: [URL] = []
    @Published var activeTab: Int = 0

    private static let appGroupID = "group.com.github.joaoofreitas.Nuntius"
    private static let pendingPathsKey = "pendingFilePaths"

    /// Reads any files the Share Extension wrote to the App Group container.
    /// Clears the stored paths after reading them.
    /// @returns File URLs ready to pass to SendView, or empty if none pending.
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

@main
struct NuntiusApp: App {
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

    private func loadPendingSharedFiles() {
        let urls = appState.consumePendingSharedFiles()
        guard !urls.isEmpty else { return }
        appState.pendingShareURLs = urls
        appState.activeTab = 0
    }

    /// Registers all custom fonts from the app bundle at startup.
    /// Required because fonts in a bundle subdirectory are not found by UIAppFonts automatically.
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
