//
//  SendView.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SendView: View {
    @State private var fileName: String = ""
    @State private var fileSize: String = ""
    @State private var fileURL: URL? = nil
    @State private var blobHash: String = ""
    @State private var isSending: Bool = false
    @State private var showPicker: Bool = false
    @State private var sendHandle: SendHandle? = nil
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack {
            Color(hex: "120c18").ignoresSafeArea()
            if isSending {
                transferView
            } else {
                initView
            }
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.item]) { result in
            guard let url = try? result.get() else { return }
            fileURL = url
            fileName = url.lastPathComponent
            errorMessage = nil
            let accessing = url.startAccessingSecurityScopedResource()
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let bytes = attrs?[.size] as? Int64 ?? 0
            fileSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            if accessing { url.stopAccessingSecurityScopedResource() }
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
                Text("Select a file. A unique hash is generated — share it with the receiver and they download directly from your device, no servers.")
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
                label: isSending ? "PREPARING..." : "SEND",
                active: !fileName.isEmpty,
                action: startSending
            )
            .disabled(fileName.isEmpty)
        }
    }

    private var dropZone: some View {
        Button(action: { showPicker = true }) {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: fileName.isEmpty ? "arrow.up.doc" : "doc.fill")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundColor(Color(hex: fileName.isEmpty ? "4d4553" : "9cff93"))

                VStack(spacing: 8) {
                    if fileName.isEmpty {
                        Text("TAP TO SELECT FILE")
                            .font(.spaceBold(13))
                            .foregroundColor(Color(hex: "4d4553"))
                            .kerning(2)
                        Text("Photos, documents, archives — any format")
                            .font(.manrope(13))
                            .foregroundColor(Color(hex: "6b5f78"))
                    } else {
                        Text(fileName)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "9cff93"))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 20)
                        if !fileSize.isEmpty {
                            Text(fileSize)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Color(hex: "6b5f78"))
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
                    Color(hex: fileName.isEmpty ? "2c2137" : "9cff93")
                        .opacity(fileName.isEmpty ? 1 : 0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [8, 5])
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transfer

    private var transferView: some View {
        VStack(alignment: .leading, spacing: 0) {
            appHeader(onDismiss: cancelSend)

            if blobHash.isEmpty {
                preparingView
            } else {
                readyView
            }

            Spacer()
        }
    }

    private var preparingView: some View {
        VStack(alignment: .leading, spacing: 28) {
            fileMetaBlock.padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("PREPARING").padding(.horizontal, 24)
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color(hex: "9cff93"))
                    .padding(.horizontal, 24)
                Text("Importing file and starting P2P node...")
                    .font(.manrope(13))
                    .foregroundColor(Color(hex: "9b8faa"))
                    .padding(.horizontal, 24)
            }
        }
    }

    private var readyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                fileMetaBlock

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
            Text(fileName)
                .font(.system(size: 17, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "f4e7f9"))
                .lineLimit(2)
            if !fileSize.isEmpty {
                Text(fileSize)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(hex: "b2a7b9"))
            }
        }
    }

    // MARK: - Shared Components

    /// Top brand header with optional dismiss button and divider
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

    /// Uppercase section label in monospaced style
    /// @param title The label text
    /// @returns A styled section label view
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.spaceBold(10))
            .foregroundColor(Color(hex: "b2a7b9"))
            .kerning(2.5)
    }

    /// Full-width primary or disabled action button
    /// @param label The button text
    /// @param active Whether the primary style is applied
    /// @param action The button action
    /// @returns A styled full-width button
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

    // MARK: - Actions

    private func startSending() {
        guard let url = fileURL else { return }
        isSending = true
        blobHash = ""
        errorMessage = nil

        let accessing = url.startAccessingSecurityScopedResource()

        Task {
            do {
                let handle = try await sendFile(path: url.path)
                await MainActor.run {
                    blobHash = handle.ticket()
                    sendHandle = handle
                    if accessing { url.stopAccessingSecurityScopedResource() }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = error.localizedDescription
                    if accessing { url.stopAccessingSecurityScopedResource() }
                }
            }
        }
    }

    private func cancelSend() {
        sendHandle?.stop()
        sendHandle = nil
        isSending = false
        blobHash = ""
    }
}

#Preview {
    SendView()
}
