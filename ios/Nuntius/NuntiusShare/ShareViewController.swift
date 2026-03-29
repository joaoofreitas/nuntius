//
//  ShareViewController.swift
//  NuntiusShare
//
//  Created by João Freitas on 28/03/2026.
//

import UIKit
import UniformTypeIdentifiers

/// Share Extension entry point. Receives shared files from Files/Photos app,
/// copies them to the App Group container, stores paths in shared UserDefaults,
/// then opens the main Nuntius app via the nuntius:// URL scheme.
class ShareViewController: UIViewController {
    private static let appGroupID = "group.com.github.joaoofreitas.Nuntius"
    private static let pendingPathsKey = "pendingFilePaths"

    // MARK: - UI

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Preparing for Nuntius..."
        label.textColor = UIColor(red: 0.61, green: 1.0, blue: 0.58, alpha: 1)
        label.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let spinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.color = UIColor(red: 0.61, green: 1.0, blue: 0.58, alpha: 1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.047, blue: 0.094, alpha: 1)

        view.addSubview(spinner)
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 20),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
        ])

        spinner.startAnimating()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        processSharedItems()
    }

    // MARK: - Processing

    private func processSharedItems() {
        guard
            let items = extensionContext?.inputItems as? [NSExtensionItem],
            !items.isEmpty
        else {
            finish()
            return
        }

        let providers = items.flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty else { finish(); return }

        guard
            let containerBase = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: Self.appGroupID
            )
        else { finish(); return }

        let sessionDir = containerBase
            .appendingPathComponent("SharedFiles", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)

        let group = DispatchGroup()
        var copiedPaths: [String] = []
        let lock = NSLock()

        for provider in providers {
            guard let typeID = provider.registeredTypeIdentifiers.first else { continue }
            group.enter()
            provider.loadFileRepresentation(forTypeIdentifier: typeID) { url, _ in
                defer { group.leave() }
                guard let url = url else { return }
                let dest = sessionDir.appendingPathComponent(url.lastPathComponent)
                do {
                    try FileManager.default.copyItem(at: url, to: dest)
                    lock.lock()
                    copiedPaths.append(dest.path)
                    lock.unlock()
                } catch {}
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            if !copiedPaths.isEmpty {
                let defaults = UserDefaults(suiteName: Self.appGroupID)
                defaults?.set(copiedPaths, forKey: Self.pendingPathsKey)
                defaults?.synchronize()
            }
            self.openMainApp()
        }
    }

    private func openMainApp() {
        guard let appURL = URL(string: "nuntius://share") else { finish(); return }

        // extensionContext?.open() does not reliably bring the host app to foreground
        // from a Share Extension. Instead, walk the responder chain to reach the host
        // app's UIApplication instance and call open directly.
        var responder: UIResponder? = self
        while let r = responder {
            if let application = r as? UIApplication {
                application.open(appURL)
                break
            }
            responder = r.next
        }

        finish()
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
