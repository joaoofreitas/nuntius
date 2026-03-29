//
//  ReceiveView.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import SwiftUI
import UIKit

/// The Receive tab. Accepts an iroh blob ticket, fetches the files directly
/// from the sender's device, and offers a system share sheet to save them.
struct ReceiveView: View {

    /// The ticket string typed or pasted by the user.
    @State private var hashText: String = ""

    /// True while a P2P connection is being established or files are downloading.
    @State private var isFetching: Bool = false

    /// Bytes received so far in the current download.
    @State private var downloadProgress: Double = 0

    /// Total expected bytes for the current download.
    @State private var downloadTotal: Double = 0

    /// Non-nil once a transfer completes successfully, triggering the received state.
    @State private var receivedFile: ReceivedFile? = nil

    /// True while the system share/save sheet is presented.
    @State private var showShareSheet: Bool = false

    // MARK: - Nested types

    /// Metadata for a successfully received file set.
    struct ReceivedFile {

        /// The filenames of each received file, relative to the destination directory.
        let names: [String]

        /// Human-readable total size of the received files, e.g. "4.2 MB".
        let totalSize: String

        /// Absolute file URLs for all received files, used by the share sheet.
        let urls: [URL]

        /// A single filename for one file, or a count string for multiple files.
        var displayTitle: String {
            names.count == 1 ? names[0] : "\(names.count) files"
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "120c18").ignoresSafeArea()
            if let file = receivedFile {
                fileReceivedView(file)
            } else {
                fetchInitView
            }
        }
    }

    // MARK: - Fetch init state

    /// The initial view. Shows the ticket input field and Fetch button.
    private var fetchInitView: some View {
        VStack(spacing: 0) {
            appHeader

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("RECEIVE A FILE")
                Text("Ask the sender for their hash, paste it below, and Nuntius connects directly to their device. No servers involved.")
                    .font(.manrope(14))
                    .foregroundColor(Color(hex: "9b8faa"))
                    .lineSpacing(6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if hashText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PASTE HASH HERE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "4d4553"))
                                .kerning(2)
                            Text("blob1ayw...")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(Color(hex: "3d3347"))
                        }
                        .padding(20)
                    }
                    TextEditor(text: $hashText)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color(hex: "9cff93"))
                        .tint(Color(hex: "9cff93"))
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding(16)
                        .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
                .background(Color(hex: "1e1626"))
                .overlay(
                    Rectangle().stroke(
                        hashText.isEmpty ? Color(hex: "2c2137") : Color(hex: "9cff93").opacity(0.4),
                        lineWidth: 1
                    )
                )

                Button(action: paste) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 13))
                        Text("PASTE FROM CLIPBOARD")
                            .font(.spaceBold(11))
                            .kerning(1.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(hex: "181021"))
                    .foregroundColor(Color(hex: "9cff93"))
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color(hex: "4d4553").opacity(0.3))
                            .frame(height: 1)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 24)

            if isFetching && downloadTotal > 0 {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ProgressView(value: downloadProgress, total: downloadTotal)
                            .progressViewStyle(.linear)
                            .tint(Color(hex: "9cff93"))
                        Text(receiveProgressLabel)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(hex: "b2a7b9"))
                            .fixedSize()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color(hex: "1e1626"))

                    Text("DOWNLOADING...")
                        .font(.spaceBold(14))
                        .kerning(3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(Color(hex: "9cff93").opacity(0.15))
                        .foregroundColor(Color(hex: "4d9c4d"))
                }
            } else {
                Button(action: fetchFile) {
                    HStack(spacing: 10) {
                        if isFetching {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(Color(hex: "006413"))
                        }
                        Text(isFetching ? "CONNECTING..." : "FETCH")
                            .font(.spaceBold(14))
                            .kerning(3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(hashText.isEmpty ? Color(hex: "1e1626") : Color(hex: "9cff93"))
                    .foregroundColor(hashText.isEmpty ? Color(hex: "4d4553") : Color(hex: "006413"))
                }
                .disabled(hashText.isEmpty || isFetching)
            }
        }
    }

    // MARK: - File received state

    /// Builds the success state shown after a transfer completes.
    /// @param file The received file(s) metadata including names, size, and URLs.
    /// @returns A centered success view with a file list and a save action button.
    private func fileReceivedView(_ file: ReceivedFile) -> some View {
        VStack(spacing: 0) {
            appHeader

            Spacer()

            ZStack {
                Rectangle()
                    .fill(Color(hex: "9cff93").opacity(0.08))
                    .frame(width: 120, height: 120)
                    .blur(radius: 24)
                ZStack {
                    Color(hex: "2b2234")
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 58))
                        .foregroundColor(Color(hex: "9cff93"))
                }
                .frame(width: 108, height: 108)
                .overlay(Rectangle().stroke(Color(hex: "9cff93").opacity(0.2), lineWidth: 1))
            }
            .padding(.bottom, 28)

            Text("RECEIVED")
                .font(.spaceBold(60))
                .foregroundColor(Color(hex: "f4e7f9"))
                .tracking(-2)
                .padding(.bottom, 10)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "9cff93"))
                    .frame(width: 5, height: 5)
                Text("Transfer complete · \(file.totalSize)")
                    .font(.manrope(12))
                    .foregroundColor(Color(hex: "b2a7b9"))
                    .kerning(0.5)
            }
            .padding(.bottom, 40)

            VStack(spacing: 0) {
                ForEach(Array(file.names.enumerated()), id: \.offset) { index, name in
                    HStack(spacing: 16) {
                        ZStack {
                            Color(hex: "120c18")
                            Image(systemName: "doc.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Color(hex: "9cff93"))
                        }
                        .frame(width: 40, height: 40)
                        .overlay(Rectangle().stroke(Color(hex: "4d4553").opacity(0.4), lineWidth: 1))

                        Text(name)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "f4e7f9"))
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < file.names.count - 1 {
                        Rectangle()
                            .fill(Color(hex: "2c2137"))
                            .frame(height: 1)
                            .padding(.leading, 72)
                    }
                }
            }
            .background(Color(hex: "1e1626"))
            .overlay(Rectangle().stroke(Color(hex: "9cff93").opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 8) {
                LinearGradient(
                    colors: [.clear, Color(hex: "4d4553").opacity(0.4), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
                .padding(.horizontal, 40)

                Text("NUNTIUS  ·  P2P TRANSFER COMPLETE")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Color(hex: "b2a7b9").opacity(0.3))
                    .kerning(2)
            }
            .padding(.bottom, 20)

            VStack(spacing: 0) {
                Button(action: { showShareSheet = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                        Text(file.names.count == 1 ? "SAVE FILE" : "SAVE ALL FILES")
                            .font(.spaceBold(14))
                            .kerning(3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Color(hex: "9cff93"))
                    .foregroundColor(Color(hex: "006413"))
                }

                Button(action: reset) {
                    Text("RECEIVE ANOTHER")
                        .font(.spaceBold(12))
                        .kerning(2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(hex: "181021"))
                        .foregroundColor(Color(hex: "b2a7b9"))
                        .overlay(alignment: .top) {
                            Rectangle()
                                .fill(Color(hex: "4d4553").opacity(0.4))
                                .frame(height: 1)
                        }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(urls: file.urls)
            }
        }
    }

    // MARK: - Shared components

    /// The branded app header shown at the top of every state in ReceiveView.
    private var appHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NUNTIUS")
                        .font(.spaceBold(30))
                        .foregroundColor(Color(hex: "f4e7f9"))
                    Text("P2P · No Servers · Encrypted")
                        .font(.manrope(11))
                        .foregroundColor(Color(hex: "6b5f78"))
                        .kerning(0.5)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color(hex: "4d4553").opacity(0.3))
                .frame(height: 1)
                .padding(.bottom, 24)
        }
    }

    /// Builds an uppercase section label.
    /// @param title The label text to display.
    /// @returns A styled Text view for section headings.
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceBold(10))
            .foregroundColor(Color(hex: "b2a7b9"))
            .kerning(2.5)
    }

    /// A formatted string showing bytes received vs total, e.g. "1.2 MB / 4.8 MB".
    private var receiveProgressLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(downloadProgress), countStyle: .file)
            + " / "
            + ByteCountFormatter.string(fromByteCount: Int64(downloadTotal), countStyle: .file)
    }

    // MARK: - Actions

    /// Reads the system clipboard and places its text into the hash input field.
    private func paste() {
        if let text = UIPasteboard.general.string {
            hashText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Initiates a P2P download using the ticket in hashText.
    /// Saves received files to the app's Documents directory.
    private func fetchFile() {
        guard !hashText.isEmpty else { return }
        isFetching = true
        downloadProgress = 0
        downloadTotal = 0

        let dest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let callback = ReceiveProgressCallbackImpl(
            onProgress: { received, total in
                DispatchQueue.main.async {
                    downloadProgress = Double(received)
                    downloadTotal = Double(total)
                }
            },
            onDone: { names in
                let urls = names.map { dest.appendingPathComponent($0) }
                let totalBytes = urls.reduce(Int64(0)) { sum, url in
                    let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                    return sum + (attrs?[.size] as? Int64 ?? 0)
                }
                let size = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
                DispatchQueue.main.async {
                    isFetching = false
                    receivedFile = ReceivedFile(names: names, totalSize: size, urls: urls)
                }
            },
            onError: { _ in
                DispatchQueue.main.async { isFetching = false }
            }
        )
        receiveFile(ticket: hashText, destDir: dest.path, callback: callback)
    }

    /// Resets all state back to the initial ticket input screen.
    private func reset() {
        receivedFile = nil
        hashText = ""
        downloadProgress = 0
        downloadTotal = 0
    }
}

// MARK: - Callback bridge

/// Bridges the uniffi ReceiveCallback protocol to Swift closures,
/// forwarding download progress, completion, and error events.
private class ReceiveProgressCallbackImpl: ReceiveCallback {

    /// Called periodically with bytes received and total expected bytes.
    private let onProgressHandler: (UInt64, UInt64) -> Void

    /// Called when all files have been successfully written to disk.
    private let onDoneHandler: ([String]) -> Void

    /// Called when a fatal error occurs during the transfer.
    private let onErrorHandler: (String) -> Void

    /// @param onProgress Closure invoked with (bytesReceived, totalBytes) during download.
    /// @param onDone Closure invoked with the list of saved filenames on success.
    /// @param onError Closure invoked with an error message on failure.
    init(
        onProgress: @escaping (UInt64, UInt64) -> Void,
        onDone: @escaping ([String]) -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.onProgressHandler = onProgress
        self.onDoneHandler = onDone
        self.onErrorHandler = onError
    }

    func onProgress(bytesReceived: UInt64, totalBytes: UInt64) { onProgressHandler(bytesReceived, totalBytes) }
    func onDone(names: [String]) { onDoneHandler(names) }
    func onError(msg: String) { onErrorHandler(msg) }
}

// MARK: - Activity view controller

/// A UIViewControllerRepresentable wrapper around UIActivityViewController.
/// Used to present the system share/save sheet for received files.
private struct ActivityViewController: UIViewControllerRepresentable {

    /// The file URLs to offer for sharing or saving.
    let urls: [URL]

    /// @param context The representable context provided by SwiftUI.
    /// @returns A UIActivityViewController configured with the file URLs.
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: urls, applicationActivities: nil)
    }

    /// No updates needed after initial creation.
    /// @param uiViewController The existing view controller instance.
    /// @param context The representable context provided by SwiftUI.
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ReceiveView()
}
