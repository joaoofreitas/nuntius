//
//  ReceiveView.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import SwiftUI
import UIKit

struct ReceiveView: View {
    @State private var hashText: String = ""
    @State private var isFetching: Bool = false
    @State private var downloadProgress: Double = 0
    @State private var downloadTotal: Double = 0
    @State private var receivedFile: ReceivedFile? = nil
    @State private var showShareSheet: Bool = false

    struct ReceivedFile {
        let name: String
        let size: String
        let url: URL
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

    // MARK: - Fetch Init

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

    // MARK: - File Received

    /// Builds the full-screen success state after a transfer completes
    /// @param file The received file metadata
    /// @returns A centered success view with metadata card and save action
    private func fileReceivedView(_ file: ReceivedFile) -> some View {
        VStack(spacing: 0) {
            appHeader

            Spacer()

            // Icon
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
                Text("Transfer complete")
                    .font(.manrope(12))
                    .foregroundColor(Color(hex: "b2a7b9"))
                    .kerning(0.5)
            }
            .padding(.bottom, 40)

            // File card
            HStack(spacing: 16) {
                ZStack {
                    Color(hex: "120c18")
                    Image(systemName: "doc.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color(hex: "9cff93"))
                }
                .frame(width: 56, height: 56)
                .overlay(Rectangle().stroke(Color(hex: "4d4553").opacity(0.4), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text(file.name)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "f4e7f9"))
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(file.size)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(hex: "b2a7b9"))
                        Rectangle()
                            .fill(Color(hex: "4d4553"))
                            .frame(width: 3, height: 3)
                        Text("SHA-256 VERIFIED")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "9cff93"))
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(Color(hex: "1e1626"))
            .overlay(Rectangle().stroke(Color(hex: "9cff93").opacity(0.12), lineWidth: 1))
            .padding(.horizontal, 24)

            Spacer()

            // Trace line
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

            // Buttons
            VStack(spacing: 0) {
                Button(action: { showShareSheet = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 14))
                        Text("SAVE FILE")
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
                ActivityViewController(url: file.url)
            }
        }
    }

    // MARK: - Shared

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

    /// Uppercase section label in monospaced style
    /// @param title The label text
    /// @returns A styled label for section headings
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceBold(10))
            .foregroundColor(Color(hex: "b2a7b9"))
            .kerning(2.5)
    }

    private var receiveProgressLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(downloadProgress), countStyle: .file)
            + " / "
            + ByteCountFormatter.string(fromByteCount: Int64(downloadTotal), countStyle: .file)
    }

    // MARK: - Actions

    private func paste() {
        if let text = UIPasteboard.general.string {
            hashText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    /// Initiate a P2P fetch for the provided blob hash
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
            onDone: { name in
                let fileURL = dest.appendingPathComponent(name)
                let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let bytes = attrs?[.size] as? Int64 ?? 0
                let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                DispatchQueue.main.async {
                    isFetching = false
                    receivedFile = ReceivedFile(name: name, size: size, url: fileURL)
                }
            },
            onError: { _ in
                DispatchQueue.main.async { isFetching = false }
            }
        )
        receiveFile(ticket: hashText, destDir: dest.path, callback: callback)
    }

    private func reset() {
        receivedFile = nil
        hashText = ""
        downloadProgress = 0
        downloadTotal = 0
    }
}

/// Bridges the uniffi ReceiveCallback protocol to Swift closures.
private class ReceiveProgressCallbackImpl: ReceiveCallback {
    private let onProgressHandler: (UInt64, UInt64) -> Void
    private let onDoneHandler: (String) -> Void
    private let onErrorHandler: (String) -> Void

    init(
        onProgress: @escaping (UInt64, UInt64) -> Void,
        onDone: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.onProgressHandler = onProgress
        self.onDoneHandler = onDone
        self.onErrorHandler = onError
    }

    func onProgress(bytesReceived: UInt64, totalBytes: UInt64) { onProgressHandler(bytesReceived, totalBytes) }
    func onDone(name: String) { onDoneHandler(name) }
    func onError(msg: String) { onErrorHandler(msg) }
}

/// UIActivityViewController wrapper for SwiftUI
/// @param url The file URL to share/save
private struct ActivityViewController: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ReceiveView()
}
