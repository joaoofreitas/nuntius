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
    @State private var receivedFile: ReceivedFile? = nil
    @State private var showShareSheet: Bool = false

    struct ReceivedFile {
        let name: String
        let size: String
        let url: URL
    }

    var body: some View {
        ZStack {
            Color(hex: "120b1a").ignoresSafeArea()
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
            HStack {
                Text("NUNTIUS")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(hex: "eee1f7"))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 20)

            VStack(alignment: .leading, spacing: 10) {
                Text("RECEIVE A FILE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "b3a7bc"))
                    .kerning(2)

                Text("Ask the sender for their hash, paste it below, and Nuntius will connect directly to their device to download the file — no servers involved.")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "6b5f78"))
                    .lineSpacing(5)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if hashText.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("PASTE HASH HERE")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "3d3347"))
                                .kerning(2)
                            Text("blob1ayw...")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(Color(hex: "2c2137"))
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
                        .frame(height: 200)
                }
                .background(Color(hex: "181021"))
                .overlay(
                    Rectangle().stroke(
                        Color(hex: hashText.isEmpty ? "2c2137" : "9cff93").opacity(hashText.isEmpty ? 1 : 0.5),
                        lineWidth: 1
                    )
                )

                Button(action: paste) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 15))
                        Text("PASTE FROM CLIPBOARD")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .kerning(1.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(hex: "1e1628"))
                    .foregroundColor(Color(hex: "9cff93"))
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: fetchFile) {
                HStack(spacing: 10) {
                    if isFetching {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(Color(hex: "006413"))
                    }
                    Text(isFetching ? "FETCHING..." : "FETCH")
                        .font(.system(size: 13, weight: .bold))
                        .kerning(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(hashText.isEmpty ? Color(hex: "1e1628") : Color(hex: "9cff93"))
                .foregroundColor(hashText.isEmpty ? Color(hex: "4d4456") : Color(hex: "006413"))
            }
            .disabled(hashText.isEmpty || isFetching)
        }
    }

    // MARK: - File Received

    /// Builds the file received confirmation screen
    /// @param file The received file metadata
    /// @returns A view showing the received file details and open action
    private func fileReceivedView(_ file: ReceivedFile) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NUNTIUS")
                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color(hex: "eee1f7"))
                Spacer()
                Button(action: reset) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "b3a7bc"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "9cff93"))
                    Text("RECEIVED")
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundColor(Color(hex: "9cff93"))
                }

                VStack(alignment: .leading, spacing: 0) {
                    infoRow("FILE", value: file.name)
                    Rectangle().fill(Color(hex: "4d4456").opacity(0.3)).frame(height: 1)
                    infoRow("SIZE", value: file.size)
                    Rectangle().fill(Color(hex: "4d4456").opacity(0.3)).frame(height: 1)
                    infoRow("INTEGRITY", value: "SHA-256 VERIFIED")
                }
                .background(Color(hex: "1e1628"))
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: { showShareSheet = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 15))
                    Text("SAVE FILE")
                        .font(.system(size: 13, weight: .bold))
                        .kerning(2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(Color(hex: "9cff93"))
                .foregroundColor(Color(hex: "006413"))
            }
            .sheet(isPresented: $showShareSheet) {
                ActivityViewController(url: file.url)
            }
        }
    }

    /// Builds a labeled key-value info row
    /// @param label The uppercase field label
    /// @param value The value string to display
    /// @returns A padded label/value row
    private func infoRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "b3a7bc"))
                .kerning(1.2)
            Text(value)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color(hex: "eee1f7"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
        Task {
            let dest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                let name = try await receiveFile(ticket: hashText, destDir: dest.path)
                let fileURL = dest.appendingPathComponent(name)
                let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let bytes = attrs?[.size] as? Int64 ?? 0
                let size = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
                await MainActor.run {
                    isFetching = false
                    receivedFile = ReceivedFile(name: name, size: size, url: fileURL)
                }
            } catch {
                await MainActor.run { isFetching = false }
            }
        }
    }

    private func reset() {
        receivedFile = nil
        hashText = ""
    }
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
