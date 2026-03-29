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

struct SendView: View {
    @State private var selectedURLs: [URL] = []
    @State private var totalSize: String = ""
    @State private var blobHash: String = ""
    @State private var isSending: Bool = false
    @State private var showSourceChoice: Bool = false
    @State private var showFilePicker: Bool = false
    @State private var showPhotoPicker: Bool = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var sendHandle: SendHandle? = nil
    @State private var errorMessage: String? = nil
    @State private var didSend: Bool = false
    @State private var receiverConnected: Bool = false
    @State private var sendProgress: Double = 0
    @State private var sendTotal: Double = 0

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
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Init

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

    private var dropZoneIcon: String {
        switch selectedURLs.count {
        case 0: return "arrow.up.doc"
        case 1: return "doc.fill"
        default: return "doc.on.doc.fill"
        }
    }

    // MARK: - Transfer

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

    // MARK: - Sent

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

    // MARK: - Shared Components

    private func progressLabel(sent: Double, total: Double) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(sent), countStyle: .file)
            + " / "
            + ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    /// @param onDismiss Action for the X button, or nil to hide it
    /// @returns A styled header with NUNTIUS branding
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

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceBold(10))
            .foregroundColor(Color(hex: "b2a7b9"))
            .kerning(2.5)
    }

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

    // MARK: - File selection helpers

    /// Adds file picker URLs and recalculates total size.
    private func addURLs(_ urls: [URL]) {
        selectedURLs = urls
        errorMessage = nil
        recalcTotalSize()
    }

    /// Loads photo items from the photos picker and copies them to temp storage.
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

    private func recalcTotalSize() {
        let bytes = selectedURLs.reduce(Int64(0)) { sum, url in
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return sum + (attrs?[.size] as? Int64 ?? 0)
        }
        totalSize = bytes > 0 ? ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file) : ""
    }

    // MARK: - Actions

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

    private func cancelSend() {
        sendHandle?.stop()
        sendHandle = nil
        isSending = false
        blobHash = ""
        receiverConnected = false
        sendProgress = 0
        sendTotal = 0
    }

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

/// Bridges the uniffi SendProgressCallback protocol to Swift closures.
private class SendProgressCallbackImpl: SendProgressCallback {
    private let onConnectedHandler: () -> Void
    private let onProgressHandler: (UInt64, UInt64) -> Void
    private let onDoneHandler: () -> Void

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
}
