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
            }
        }
    }

    // MARK: - Send File Init

    private var initView: some View {
        VStack(spacing: 0) {
            header

            Button(action: { showPicker = true }) {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 40, weight: .ultraLight))
                        .foregroundColor(Color(hex: "9cff93"))
                    if fileName.isEmpty {
                        Text("SELECT FILE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(hex: "9cff93"))
                            .kerning(2.5)
                    } else {
                        Text(fileName)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(hex: "9cff93"))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        Text("Tap to change")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "b3a7bc"))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .background(Color(hex: "181021"))
                .overlay(
                    Rectangle().strokeBorder(
                        Color(hex: fileName.isEmpty ? "4d4456" : "9cff93")
                            .opacity(fileName.isEmpty ? 0.4 : 0.7),
                        style: StrokeStyle(lineWidth: 1, dash: [8, 5])
                    )
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)

            Spacer()

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
        isSending = true
        Task {
            do {
                let handle = try await sendFile(path: fileURL?.path ?? "")
                await MainActor.run {
                    blobHash = handle.ticket()
                    sendHandle = handle
                    progress = 1.0
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    progress = 0
                }
            }
        }
    }

    private func cancelSend() {
        Task { await sendHandle?.stop() }
        sendHandle = nil
        isSending = false
        progress = 0
    }

}

#Preview {
    SendView()
}
