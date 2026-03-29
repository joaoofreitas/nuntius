//
//  ReceiveView.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import SwiftUI
import UIKit
import Photos
import UniformTypeIdentifiers

/// The Receive tab. Accepts an iroh blob ticket, fetches files directly from the
/// sender's device, and offers saving to the Photos library or the Files app.
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

    /// Non-nil error message causes an alert to be shown.
    @State private var errorMessage: String? = nil

    /// The timeout task. Cancelled when the download completes, errors, or is cancelled.
    @State private var timeoutTask: Task<Void, Never>? = nil

    /// Reference to the active callback bridge, used to suppress callbacks after cancellation.
    @State private var activeBridge: ReceiveProgressCallbackImpl? = nil

    /// True once media files have been successfully saved to the Photos library.
    @State private var photosSaved: Bool = false

    // MARK: - Nested types

    /// Metadata for a successfully received file set.
    struct ReceivedFile {

        /// The filenames of each received file, relative to the destination directory.
        let names: [String]

        /// Human-readable total size of all received files, e.g. "4.2 MB".
        let totalSize: String

        /// Absolute file URLs for all received files.
        let urls: [URL]

        /// A single filename for one file, or a count string for multiple.
        var displayTitle: String {
            names.count == 1 ? names[0] : "\(names.count) files"
        }

        /// File URLs that are images or videos, eligible for saving to the Photos library.
        var mediaURLs: [URL] {
            urls.filter { url in
                guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
                return type.conforms(to: .image) || type.conforms(to: .movie)
            }
        }

        /// True if any received files are images or videos.
        var hasMedia: Bool { !mediaURLs.isEmpty }
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
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Fetch init state

    /// The initial view. Shows the ticket input field, paste button, and Fetch/Cancel button.
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
                        .disabled(isFetching)
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
                    .foregroundColor(isFetching ? Color(hex: "4d4553") : Color(hex: "9cff93"))
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(Color(hex: "4d4553").opacity(0.3))
                            .frame(height: 1)
                    }
                }
                .disabled(isFetching)
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 24)

            bottomBar
        }
    }

    /// The bottom action area. Shows a progress bar while downloading, then a Fetch or Cancel button.
    private var bottomBar: some View {
        VStack(spacing: 0) {
            if isFetching && downloadTotal > 0 {
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
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(hex: "4d4553").opacity(0.3)).frame(height: 1)
                }
            }

            if isFetching {
                Button(action: cancelFetch) {
                    Text("CANCEL")
                        .font(.spaceBold(14))
                        .kerning(3)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 22)
                        .background(Color(hex: "1e1626"))
                        .foregroundColor(Color(hex: "b2a7b9"))
                        .overlay(alignment: .top) {
                            Rectangle().fill(Color(hex: "4d4553").opacity(0.3)).frame(height: 1)
                        }
                }
            } else {
                Button(action: fetchFile) {
                    HStack(spacing: 10) {
                        Text("FETCH")
                            .font(.spaceBold(14))
                            .kerning(3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(hashText.isEmpty ? Color(hex: "1e1626") : Color(hex: "9cff93"))
                    .foregroundColor(hashText.isEmpty ? Color(hex: "4d4553") : Color(hex: "006413"))
                }
                .disabled(hashText.isEmpty)
            }
        }
    }

    // MARK: - File received state

    /// Builds the success state shown after a transfer completes.
    /// @param file The received file(s) metadata including names, size, and URLs.
    /// @returns A centered success view with a file list and save action buttons.
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

            saveButtons(file)
        }
    }

    /// Builds the save action buttons appropriate for the received file types.
    /// Media files get a "Save to Photos" primary button; all files get a share sheet option.
    /// @param file The received file metadata.
    /// @returns A VStack of save and reset action buttons.
    private func saveButtons(_ file: ReceivedFile) -> some View {
        VStack(spacing: 0) {
            if file.hasMedia {
                Button(action: { saveToPhotos(file.mediaURLs) }) {
                    HStack(spacing: 10) {
                        Image(systemName: photosSaved ? "checkmark" : "photo")
                            .font(.system(size: 14))
                        Text(photosSaved ? "SAVED TO PHOTOS" : "SAVE TO PHOTOS")
                            .font(.spaceBold(14))
                            .kerning(3)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(photosSaved ? Color(hex: "1e1626") : Color(hex: "9cff93"))
                    .foregroundColor(photosSaved ? Color(hex: "9cff93") : Color(hex: "006413"))
                }
                .disabled(photosSaved)
            }

            Button(action: { showShareSheet = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13))
                    Text(file.hasMedia ? "SHARE / SAVE TO FILES" : (file.names.count == 1 ? "SAVE FILE" : "SAVE ALL FILES"))
                        .font(.spaceBold(file.hasMedia ? 12 : 14))
                        .kerning(file.hasMedia ? 2 : 3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, file.hasMedia ? 18 : 22)
                .background(file.hasMedia ? Color(hex: "181021") : Color(hex: "9cff93"))
                .foregroundColor(file.hasMedia ? Color(hex: "b2a7b9") : Color(hex: "006413"))
                .overlay(alignment: .top) {
                    if file.hasMedia {
                        Rectangle().fill(Color(hex: "4d4553").opacity(0.4)).frame(height: 1)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(urls: file.urls)
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
                        Rectangle().fill(Color(hex: "4d4553").opacity(0.4)).frame(height: 1)
                    }
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
    /// Starts a 30-second timeout that fires if no data is received (sender unreachable).
    private func fetchFile() {
        guard !hashText.isEmpty else { return }
        isFetching = true
        errorMessage = nil
        downloadProgress = 0
        downloadTotal = 0

        let dest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        let bridge = ReceiveProgressCallbackImpl(
            onProgress: { received, total in
                DispatchQueue.main.async {
                    self.downloadProgress = Double(received)
                    self.downloadTotal = Double(total)
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
                    self.isFetching = false
                    self.timeoutTask?.cancel()
                    self.timeoutTask = nil
                    self.activeBridge = nil
                    self.receivedFile = ReceivedFile(names: names, totalSize: size, urls: urls)
                }
            },
            onError: { msg in
                DispatchQueue.main.async {
                    self.isFetching = false
                    self.timeoutTask?.cancel()
                    self.timeoutTask = nil
                    self.activeBridge = nil
                    self.errorMessage = msg
                }
            }
        )

        activeBridge = bridge
        receiveFile(ticket: hashText, destDir: dest.path, callback: bridge)

        // Cancel with a user-friendly message if no data arrives within 30 seconds.
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.isFetching && self.downloadTotal == 0 else { return }
                bridge.isCancelled = true
                self.isFetching = false
                self.activeBridge = nil
                self.errorMessage = "Connection timed out. Make sure the sender is online and try again."
            }
        }
    }

    /// Cancels an in-progress fetch, suppressing any pending callbacks and resetting state.
    private func cancelFetch() {
        activeBridge?.isCancelled = true
        activeBridge = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        isFetching = false
        downloadProgress = 0
        downloadTotal = 0
    }

    /// Requests Photos library write access and saves the given media files.
    /// Shows an error alert if permission is denied or the save fails.
    /// @param urls The image or video file URLs to save.
    private func saveToPhotos(_ urls: [URL]) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.errorMessage = "Photo library access denied. Please enable it in Settings > Nuntius."
                }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                for url in urls {
                    let request = PHAssetCreationRequest.forAsset()
                    let type = UTType(filenameExtension: url.pathExtension)
                    if type?.conforms(to: .image) == true {
                        request.addResource(with: .photo, fileURL: url, options: nil)
                    } else {
                        request.addResource(with: .video, fileURL: url, options: nil)
                    }
                }
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.photosSaved = true
                    } else {
                        self.errorMessage = error?.localizedDescription ?? "Failed to save to Photos."
                    }
                }
            }
        }
    }

    /// Resets all state back to the initial ticket input screen.
    private func reset() {
        receivedFile = nil
        hashText = ""
        downloadProgress = 0
        downloadTotal = 0
        photosSaved = false
        errorMessage = nil
    }
}

// MARK: - Callback bridge

/// Bridges the uniffi ReceiveCallback protocol to Swift closures.
/// The isCancelled flag suppresses callbacks after a cancel or timeout.
class ReceiveProgressCallbackImpl: ReceiveCallback {

    /// When true, all incoming callbacks are silently ignored.
    var isCancelled = false

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

    func onProgress(bytesReceived: UInt64, totalBytes: UInt64) {
        guard !isCancelled else { return }
        onProgressHandler(bytesReceived, totalBytes)
    }

    func onDone(names: [String]) {
        guard !isCancelled else { return }
        onDoneHandler(names)
    }

    func onError(msg: String) {
        guard !isCancelled else { return }
        onErrorHandler(msg)
    }
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
