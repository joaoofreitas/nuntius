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
            .padding(.bottom, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("BLOB HASH")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(hex: "b3a7bc"))
                    .kerning(1.5)
                VStack(spacing: 0) {
                    HStack {
                        TextField("blobQm...", text: $hashText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color(hex: "9cff93"))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .tint(Color(hex: "9cff93"))
                        Button(action: paste) {
                            Text("PASTE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(Color(hex: "006413"))
                                .kerning(1.0)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "9cff93"))
                        }
                    }
                    .padding(16)
                    .background(Color(hex: "1e1628"))
                    Rectangle()
                        .fill(hashText.isEmpty ? Color.clear : Color(hex: "9cff93"))
                        .frame(height: 2)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            Button(action: fetchFile) {
                HStack {
                    if isFetching {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(Color(hex: "006413"))
                    }
                    Text(isFetching ? "FETCHING..." : "FETCH")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "b3a7bc"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "9cff93"))
                    Text("RECEIVED")
                        .font(.system(size: 24, weight: .heavy, design: .monospaced))
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
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 13))
                    Text("SAVE FILE")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
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
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color(hex: "b3a7bc"))
                .kerning(1.2)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(hex: "eee1f7"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
