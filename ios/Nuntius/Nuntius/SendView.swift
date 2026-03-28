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
    @State private var fileURL: URL? = nil
    @State private var blobHash: String = ""
    @State private var isSending: Bool = false
    @State private var progress: Double = 0
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

            VStack(alignment: .leading, spacing: 12) {
                Text("SEND A FILE")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "b3a7bc"))
                    .kerning(2)

                Text("Select any file from your device. A unique hash is generated — share it with the receiver to let them download directly from you over P2P.")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "6b5f78"))
                    .lineSpacing(4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            Button(action: { showPicker = true }) {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: fileName.isEmpty ? "arrow.up.doc" : "doc.fill")
                        .font(.system(size: 52, weight: .ultraLight))
                        .foregroundColor(Color(hex: fileName.isEmpty ? "4d4456" : "9cff93"))

                    VStack(spacing: 8) {
                        if fileName.isEmpty {
                            Text("TAP TO SELECT FILE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "4d4456"))
                                .kerning(2)
                            Text("Photos, documents, archives, any format")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "3d3347"))
                        } else {
                            Text(fileName)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(hex: "9cff93"))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 16)
                            Text("Tap to change")
                                .font(.system(size: 11))
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
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "b3a7bc"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 24) {
                Text(fileName)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "eee1f7"))
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("SENDING")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "9cff93"))
                            .kerning(1.5)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 28, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(hex: "9cff93"))
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color(hex: "1e1628"))
                                .frame(height: 2)
                            Rectangle()
                                .fill(Color(hex: "9cff93"))
                                .frame(width: geo.size.width * progress, height: 2)
                        }
                    }
                    .frame(height: 2)
                }

                HStack(spacing: 8) {
                    Rectangle()
                        .fill(Color(hex: "9cff93").opacity(0.5))
                        .frame(width: 2, height: 28)
                    Text("Keep Nuntius open while the receiver downloads. Switching tabs is fine.")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "6b5f78"))
                        .lineSpacing(2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("SHARE THIS HASH")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "b3a7bc"))
                        .kerning(1.5)
                    HStack(alignment: .top) {
                        Text(blobHash)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "9cff93"))
                            .lineLimit(3)
                        Spacer(minLength: 12)
                        Button(action: { UIPasteboard.general.string = blobHash }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "9cff93"))
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "181021"))
                    .overlay(Rectangle().stroke(Color(hex: "9cff93").opacity(0.3), lineWidth: 1))
                }
            }
            .padding(.horizontal, 20)

            Spacer()
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
        errorMessage = nil

        let accessing = url.startAccessingSecurityScopedResource()

        Task {
            do {
                let handle = try await sendFile(path: url.path)
                await MainActor.run {
                    blobHash = handle.ticket()
                    sendHandle = handle
                    progress = 1.0
                    if accessing { url.stopAccessingSecurityScopedResource() }
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    progress = 0
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
        progress = 0
    }

}

#Preview {
    SendView()
}
