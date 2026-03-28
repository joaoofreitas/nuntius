//
//  NuntiusApp.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import SwiftUI
import CoreText

@main
struct NuntiusApp: App {
    init() {
        registerFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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
