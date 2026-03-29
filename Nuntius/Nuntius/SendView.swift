//
//  SendView.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import PhotosUI

/// The Send tab. Allows the user to select files from Photos or Files,
/// start an iroh P2P session, and share the resulting ticket with a receiver.
struct SendView: View {

    /// Shared application state used to receive files from the Share Extension.
    @EnvironmentObject private var appState: AppState

    /// The files the user has selected to send.
    @State private var selectedURLs: [URL] = []

    /// Human-readable total size of the selected files, e.g. "3.2 MB".
    @State private var totalSize: String = ""

    /// The iroh blob ticket to share with the receiver. Empty until the node is ready.
    @State private var blobHash: String = ""

    /// True while the P2P node is starting or an active transfer is in progress.
    @State private var isSending: Bool = false

    /// True while the source picker action sheet is presented.
    @State private var showSourceChoice: Bool = false

    /// True while the Files document picker is presented.
    @State private var showFilePicker: Bool = false

    /// True while the Photos picker is presented.
    @State private var showPhotoPicker: Bool = false

    /// The items selected from the Photos picker, before they are loaded as Data.
    @State private var photoPickerItems: [PhotosPickerItem] = []

    /// The active iroh send session. Non-nil while a transfer is in progress.
    @State private var sendHandle: SendHandle? = nil

    /// A non-nil error message causes an alert to be shown.
    @State private var errorMessage: String? = nil

    /// True once the receiver has successfully downloaded all files.
    @State private var didSend: Bool = false

    /// True once the receiver has connected to the local iroh node.
    @State private var receiverConnected: Bool = false

    /// Bytes sent so far in the current transfer.
    @State private var sendProgress: Double = 0

    /// Total bytes to send in the current transfer.
    @State private var sendTotal: Double = 0

    /// A display title derived from the selected files.
    /// Shows the filename for a single file, or a count for multiple.
    private var selectionTitle: String {
        switch selectedURLs.count {
        case 0: return ""
        case 1: return selectedURLs[0].lastPathComponent
        default: return "\(selectedURLs.count) files"
        }
    }

    var body: some View {
        ZStack {
            Color(hex: "120c18").ignoresSafeArea()
            if didSend {
                sentView
            } else if isSending {
                transferView
            } else {
                initView
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            guard let urls = try? result.get() else { return }
            addURLs(urls)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoPickerItems,
            maxSelectionCount: 20,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: photoPickerItems) { items in
            loadPhotoItems(items)
        }
        .confirmationDialog("Add files", isPresented: $showSourceChoice, titleVisibility: .hidden) {
            Button("Photos & Videos") { showPhotoPicker = true }
            Button("Files") { showFilePicker = true }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            let urls = appState.pendingShareURLs
            if !urls.isEmpty {
                appState.pendingShareURLs = []
                addURLs(urls)
            }
        }
        .onChange(of: appState.pendingShareURLs) { urls in
            guard !urls.isEmpty else { return }
            appState.pendingShareURLs = []
            addURLs(urls)
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

    // MARK: - Init state

    /// The initial view before a transfer starts. Shows the file drop zone and Send button.
    private var initView: some View {
        VStack(spacing: 0) {
            appHeader(onDismiss: nil)

            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("SEND A FILE")
                Text("Select a file. A unique hash is generated, share it with the receiver and they download directly from your device, no servers.")
                    .font(.manrope(14))
                    .foregroundColor(Color(hex: "9b8faa"))
                    .lineSpacing(6)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            dropZone
                .padding(.horizontal, 24)

            Spacer().frame(height: 24)

            primaryButton(
                label: "SEND",
                active: !selectedURLs.isEmpty,
                action: startSending
            )
            .disabled(selectedURLs.isEmpty)
        }
    }

    /// An interactive file selection area. Tapping opens the source picker.
    /// Displays file name(s) and size once files are selected.
    private var dropZone: some View {
        Button(action: { showSourceChoice = true }) {
            VStack(spacing: 18) {
                Spacer()

                Image(systemName: dropZoneIcon)
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(Color(hex: selectedURLs.isEmpty ? "4d4553" : "9cff93"))

                VStack(spacing: 8) {
                    if selectedURLs.isEmpty {
                        Text("TAP TO SELECT FILES")
                            .font(.spaceBold(13))
                            .foregroundColor(Color(hex: "4d4553"))
                            .kerning(2)
                        Text("Photos, documents, archives — any format")
                            .font(.manrope(13))
                            .foregroundColor(Color(hex: "6b5f78"))
                    } else if selectedURLs.count == 1 {
                        Text(selectedURLs[0].lastPathComponent)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "9cff93"))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 20)
                        if !totalSize.isEmpty {
                            Text(totalSize)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Color(hex: "6b5f78"))
                        }
                        Text("Tap to change")
                            .font(.manrope(12))
                            .foregroundColor(Color(hex: "6b5f78"))
                    } else {
                        Text("\(selectedURLs.count) FILES SELECTED")
                            .font(.spaceBold(13))
                            .foregroundColor(Color(hex: "9cff93"))
                            .kerning(2)
                        if !totalSize.isEmpty {
                            Text(totalSize + " total")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Color(hex: "6b5f78"))
                        }
                        VStack(spacing: 3) {
                            ForEach(selectedURLs.prefix(3), id: \.path) { url in
                                Text(url.lastPathComponent)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color(hex: "4d4553"))
                                    .lineLimit(1)
                            }
                            if selectedURLs.count > 3 {
                                Text("+ \(selectedURLs.count - 3) more")
                                    .font(.manrope(11))
                                    .foregroundColor(Color(hex: "4d4553"))
                            }
                        }
                        Text("Tap to change")
                            .font(.manrope(12))
                            .foregroundColor(Color(hex: "6b5f78"))
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "1e1626"))
            .overlay(
                Rectangle().strokeBorder(
                    Color(hex: selectedURLs.isEmpty ? "2c2137" : "9cff93")
                        .opacity(selectedURLs.isEmpty ? 1 : 0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [8, 5])
                )
            )
        }
        .buttonStyle(.plain)
    }

    /// The SF Symbol icon shown in the drop zone, reflecting the current selection state.
    private var dropZoneIcon: String {
        switch selectedURLs.count {
        case 0: return "arrow.up.doc"
        case 1: return "doc.fill"
        default: return "doc.on.doc.fill"
        }
    }

    // MARK: - Transfer state

    /// Shown while the P2P node is starting or a transfer is active.
    /// Switches between a preparing spinner and the ready/ticket view.
    private var transferView: some View {
        VStack(alignment: .leading, spacing: 0) {
            appHeader(onDismiss: cancelSend)

            if blobHash.isEmpty {
                preparingView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                readyView
            }
        }
    }

    /// Shown while the iroh node is starting and the ticket is not yet available.
    private var preparingView: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Rectangle()
                    .fill(Color(hex: "9cff93").opacity(0.06))
                    .frame(width: 120, height: 120)
                    .blur(radius: 24)
                ZStack {
                    Color(hex: "2b2234")
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Color(hex: "9cff93"))
                        .scaleEffect(1.4)
                }
                .frame(width: 108, height: 108)
                .overlay(Rectangle().stroke(Color(hex: "9cff93").opacity(0.15), lineWidth: 1))
            }
            .padding(.bottom, 28)

            Text("PREPARING")
                .font(.spaceBold(36))
                .foregroundColor(Color(hex: "f4e7f9"))
                .tracking(-1)
                .padding(.bottom, 10)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "9cff93").opacity(0.5))
                    .frame(width: 5, height: 5)
                Text("Importing \(selectedURLs.count == 1 ? "file" : "\(selectedURLs.count) files") and starting P2P node")
                    .font(.manrope(12))
                    .foregroundColor(Color(hex: "b2a7b9"))
                    .kerning(0.5)
            }
            .padding(.bottom, 32)

            Text(selectionTitle)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color(hex: "4d4553"))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 40)

            Spacer()
        }
    }

    /// Shown once the iroh node is ready and the ticket is available to share.
    /// Also shows live transfer progress once the receiver connects.
    private var readyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                fileMetaBlock

                if receiverConnected && sendTotal > 0 {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: "9cff93"))
                                .frame(width: 5, height: 5)
                            sectionLabel("TRANSFERRING")
                            Spacer()
                            Text(progressLabel(sent: sendProgress, total: sendTotal))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "b2a7b9"))
                        }
                        ProgressView(value: sendProgress, total: sendTotal)
                            .progressViewStyle(.linear)
                            .tint(Color(hex: "9cff93"))
                    }
                } else if receiverConnected {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: "9cff93"))
                            .frame(width: 5, height: 5)
                        Text("Receiver connected")
                            .font(.manrope(13))
                            .foregroundColor(Color(hex: "9b8faa"))
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        Rectangle()
                            .fill(Color(hex: "9cff93").opacity(0.4))
                            .frame(width: 2)
                        Text("Keep Nuntius open while the receiver downloads. Switching tabs is fine.")
                            .font(.manrope(13))
                            .foregroundColor(Color(hex: "9b8faa"))
                            .lineSpacing(4)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        sectionLabel("SHARE THIS HASH")
                        Spacer()
                        Button(action: { UIPasteboard.general.string = blobHash }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                Text("COPY")
                                    .font(.spaceBold(11))
                                    .kerning(1)
                            }
                            .foregroundColor(Color(hex: "006413"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: "9cff93"))
                        }
                    }

                    Text(blobHash)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color(hex: "9cff93"))
                        .lineSpacing(6)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "1e1626"))
                        .overlay(Rectangle().stroke(Color(hex: "9cff93").opacity(0.15), lineWidth: 1))
                }
            }
            .padding(.horizontal, 24)
        }
    }

    /// A small block showing the selected file name(s) and total size during transfer.
    private var fileMetaBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectionTitle)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "f4e7f9"))
                .lineLimit(2)
            if !totalSize.isEmpty {
                Text(totalSize)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(hex: "b2a7b9"))
            }
        }
    }

    // MARK: - Sent state

    /// Shown after the receiver has successfully downloaded all files.
    private var sentView: some View {
        VStack(spacing: 0) {
            appHeader(onDismiss: nil)

            Spacer()

            ZStack {
                Rectangle()
                    .fill(Color(hex: "9cff93").opacity(0.08))
                    .frame(width: 120, height: 120)
                    .blur(radius: 24)
                ZStack {
                    Color(hex: "2b2234")
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "9cff93"))
                }
                .frame(width: 108, height: 108)
                .overlay(Rectangle().stroke(Color(hex: "9cff93").opacity(0.2), lineWidth: 1))
            }
            .padding(.bottom, 28)

            Text("SENT")
                .font(.spaceBold(60))
                .foregroundColor(Color(hex: "f4e7f9"))
                .tracking(-2)
                .padding(.bottom, 10)

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(hex: "9cff93"))
                    .frame(width: 5, height: 5)
                Text("Receiver downloaded your \(selectedURLs.count == 1 ? "file" : "files")")
                    .font(.manrope(12))
                    .foregroundColor(Color(hex: "b2a7b9"))
                    .kerning(0.5)
            }
            .padding(.bottom, 40)

            HStack(spacing: 16) {
                ZStack {
                    Color(hex: "120c18")
                    Image(systemName: selectedURLs.count == 1 ? "doc.fill" : "doc.on.doc.fill")
                        .font(.system(size: 26))
                        .foregroundColor(Color(hex: "9cff93"))
                }
                .frame(width: 56, height: 56)
                .overlay(Rectangle().stroke(Color(hex: "4d4553").opacity(0.4), lineWidth: 1))

                VStack(alignment: .leading, spacing: 6) {
                    Text(selectionTitle)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "f4e7f9"))
                        .lineLimit(2)
                    if !totalSize.isEmpty {
                        Text(totalSize)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(hex: "b2a7b9"))
                    }
                }

                Spacer()
            }
            .padding(20)
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

            Button(action: resetSend) {
                Text("SEND ANOTHER")
                    .font(.spaceBold(14))
                    .kerning(3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .background(Color(hex: "9cff93"))
                    .foregroundColor(Color(hex: "006413"))
            }
        }
    }

    // MARK: - Shared components

    /// Formats a byte progress pair as a human-readable string, e.g. "1.2 MB / 4.8 MB".
    /// @param sent Bytes transferred so far.
    /// @param total Total bytes to transfer.
    /// @returns A formatted progress string.
    private func progressLabel(sent: Double, total: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(sent), countStyle: .file)
            + " / "
            + ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    /// Builds the branded app header shown at the top of every state.
    /// @param onDismiss An optional action for the X dismiss button. Pass nil to hide the button.
    /// @returns A styled header with the Nuntius branding and an optional dismiss button.
    private func appHeader(onDismiss: (() -> Void)?) -> some View {
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
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(hex: "b2a7b9"))
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "1e1626"))
                            .overlay(Rectangle().stroke(Color(hex: "4d4553").opacity(0.5), lineWidth: 1))
                    }
                }
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

    /// Builds a full-width primary action button.
    /// @param label The uppercase button label.
    /// @param active When true, the button renders in the active green style; otherwise muted.
    /// @param action The closure to invoke when tapped.
    /// @returns A styled full-width button.
    private func primaryButton(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.spaceBold(14))
                .kerning(3)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(active ? Color(hex: "9cff93") : Color(hex: "1e1626"))
                .foregroundColor(active ? Color(hex: "006413") : Color(hex: "4d4553"))
        }
    }

    // MARK: - File selection

    /// Replaces the current selection with the given URLs and recalculates the total size.
    /// @param urls The file URLs to set as the current selection.
    private func addURLs(_ urls: [URL]) {
        selectedURLs = urls
        errorMessage = nil
        recalcTotalSize()
    }

    /// Loads raw data from Photos picker items, writes them to the temp directory,
    /// then updates the selection with the resulting URLs.
    /// @param items The PhotosPickerItems selected by the user.
    private func loadPhotoItems(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var tempURLs: [URL] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let ext = item.supportedContentTypes.first?.preferredFilenameExtension ?? "bin"
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(ext)
                    try? data.write(to: tempURL)
                    tempURLs.append(tempURL)
                }
            }
            await MainActor.run {
                selectedURLs = tempURLs
                errorMessage = nil
                recalcTotalSize()
            }
        }
    }

    /// Reads file sizes from disk for all selected URLs and updates the totalSize label.
    private func recalcTotalSize() {
        let bytes = selectedURLs.reduce(Int64(0)) { sum, url in
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return sum + (attrs?[.size] as? Int64 ?? 0)
        }
        totalSize = bytes > 0 ? ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) : ""
    }

    // MARK: - Actions

    /// Starts the iroh P2P send session for the currently selected files.
    /// Requests security-scoped access, calls the FFI, and wires up progress callbacks.
    private func startSending() {
        guard !selectedURLs.isEmpty else { return }
        isSending = true
        blobHash = ""
        errorMessage = nil

        let accesses = selectedURLs.map { $0.startAccessingSecurityScopedResource() }
        let paths = selectedURLs.map { $0.path }

        Task {
            do {
                let handle = try await sendFiles(paths: paths)
                await MainActor.run {
                    blobHash = handle.ticket()
                    sendHandle = handle
                    zip(selectedURLs, accesses).forEach { url, accessing in
                        if accessing { url.stopAccessingSecurityScopedResource() }
                    }
                }
                handle.onSendProgress(callback: SendProgressCallbackImpl(
                    onConnected: {
                        DispatchQueue.main.async { receiverConnected = true }
                    },
                    onProgress: { sent, total in
                        DispatchQueue.main.async {
                            sendProgress = Double(sent)
                            sendTotal = Double(total)
                        }
                    },
                    onDone: {
                        DispatchQueue.main.async {
                            didSend = true
                            sendHandle?.stop()
                            sendHandle = nil
                        }
                    }
                ))
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = error.localizedDescription
                    zip(selectedURLs, accesses).forEach { url, accessing in
                        if accessing { url.stopAccessingSecurityScopedResource() }
                    }
                }
            }
        }
    }

    /// Stops the active send session and resets transfer state, returning to the ready view.
    private func cancelSend() {
        sendHandle?.stop()
        sendHandle = nil
        isSending = false
        blobHash = ""
        receiverConnected = false
        sendProgress = 0
        sendTotal = 0
    }

    /// Resets all state back to the initial file selection screen.
    private func resetSend() {
        didSend = false
        isSending = false
        blobHash = ""
        selectedURLs = []
        totalSize = ""
        sendHandle = nil
        receiverConnected = false
        sendProgress = 0
        sendTotal = 0
    }
}

// MARK: - Callback bridge

/// Bridges the uniffi SendProgressCallback protocol to Swift closures,
/// forwarding receiver connection, progress, and completion events.
private class SendProgressCallbackImpl: SendProgressCallback {

    /// Called when the receiver first connects to the iroh node.
    private let onConnectedHandler: () -> Void

    /// Called periodically with bytes sent and total bytes.
    private let onProgressHandler: (UInt64, UInt64) -> Void

    /// Called when the receiver has finished downloading all files.
    private let onDoneHandler: () -> Void

    /// @param onConnected Closure invoked when the receiver connects.
    /// @param onProgress Closure invoked with (bytesSent, totalBytes) during transfer.
    /// @param onDone Closure invoked when the transfer completes successfully.
    init(
        onConnected: @escaping () -> Void,
        onProgress: @escaping (UInt64, UInt64) -> Void,
        onDone: @escaping () -> Void
    ) {
        self.onConnectedHandler = onConnected
        self.onProgressHandler = onProgress
        self.onDoneHandler = onDone
    }

    func onReceiverConnected() { onConnectedHandler() }
    func onProgress(bytesSent: UInt64, totalBytes: UInt64) { onProgressHandler(bytesSent, totalBytes) }
    func onDone() { onDoneHandler() }
}

#Preview {
    SendView()
        .environmentObject(AppState())
}
