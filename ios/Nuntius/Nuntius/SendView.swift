//
//  SendView.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import SwiftUI
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
            Color(hex: "120b1a").ignoresSafeArea()
            if isSending {
                transferView
            } else {
                initView
            }
        }
        .fileImporter(isPresented: $showPicker, allowedContentTypes: [.item]) { result in
            if let url = try? result.get() {
                fileURL = url
                fileName = url.lastPathComponent
                errorMessage = nil
                let accessing = url.startAccessingSecurityScopedResource()
                let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
                let bytes = attrs?[.size] as? Int64 ?? 0
                fileSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                if accessing { url.stopAccessingSecurityScopedResource() }
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

    // MARK: - Send File Init

    private var initView: some View {
        VStack(spacing: 0) {
            header

            VStack(alignment: .leading, spacing: 10) {
                Text("SEND A FILE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "b3a7bc"))
                    .kerning(2)

                Text("Select any file from your device. A unique hash is generated — share it with the receiver to let them download directly from you over P2P.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6b5f78"))
                    .lineSpacing(5)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Button(action: { showPicker = true }) {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: fileName.isEmpty ? "arrow.up.doc" : "doc.fill")
                        .font(.system(size: 56, weight: .ultraLight))
                        .foregroundColor(Color(hex: fileName.isEmpty ? "4d4456" : "9cff93"))

                    VStack(spacing: 10) {
                        if fileName.isEmpty {
                            Text("TAP TO SELECT FILE")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "4d4456"))
                                .kerning(2)
                            Text("Photos, documents, archives, any format")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "3d3347"))
                        } else {
                            Text(fileName)
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(hex: "9cff93"))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 16)
                            Text("Tap to change")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "6b5f78"))
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity)
                .background(Color(hex: "181021"))
                .overlay(
                    Rectangle().strokeBorder(
                        Color(hex: fileName.isEmpty ? "2c2137" : "9cff93")
                            .opacity(fileName.isEmpty ? 1 : 0.5),
                        style: StrokeStyle(lineWidth: 1, dash: [10, 6])
                    )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer().frame(height: 20)

            Button(action: startSending) {
                Text("SEND")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(fileName.isEmpty ? Color(hex: "1e1628") : Color(hex: "9cff93"))
                    .foregroundColor(fileName.isEmpty ? Color(hex: "4d4456") : Color(hex: "006413"))
            }
            .disabled(fileName.isEmpty)
        }
    }

    // MARK: - Transferring Data

    private var transferView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NUNTIUS")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(hex: "eee1f7"))
                Spacer()
                Button(action: cancelSend) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "b3a7bc"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 24)

            if blobHash.isEmpty {
                preparingView
            } else {
                readyView
            }

            Spacer()
        }
    }

    private var preparingView: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text(fileName)
                    .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "eee1f7"))
                    .lineLimit(2)
                if !fileSize.isEmpty {
                    Text(fileSize)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color(hex: "6b5f78"))
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                Text("PREPARING")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "9cff93"))
                    .kerning(2)
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color(hex: "9cff93"))
                    .background(Color(hex: "1e1628"))
                Text("Importing file and starting P2P node...")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "4d4456"))
            }
        }
        .padding(.horizontal, 20)
    }

    private var readyView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(fileName)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "eee1f7"))
                        .lineLimit(2)
                    if !fileSize.isEmpty {
                        Text(fileSize)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color(hex: "6b5f78"))
                    }
                }

                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color(hex: "9cff93").opacity(0.5))
                        .frame(width: 2, height: 36)
                    Text("Keep Nuntius open while the receiver downloads. Switching tabs is fine.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "6b5f78"))
                        .lineSpacing(3)
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("SHARE THIS HASH")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "b3a7bc"))
                            .kerning(1.5)
                        Spacer()
                        Button(action: { UIPasteboard.general.string = blobHash }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 12))
                                Text("COPY")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .kerning(1)
                            }
                            .foregroundColor(Color(hex: "006413"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: "9cff93"))
                        }
                    }

                    Text(blobHash)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(hex: "9cff93"))
                        .lineSpacing(5)
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(hex: "181021"))
                        .overlay(Rectangle().stroke(Color(hex: "9cff93").opacity(0.25), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var header: some View {
        HStack {
            Text("NUNTIUS")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(hex: "eee1f7"))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 20)
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
