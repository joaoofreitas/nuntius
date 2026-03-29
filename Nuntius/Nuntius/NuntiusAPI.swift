//
//  NuntiusAPI.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import Foundation

/// Starts serving files over iroh P2P and returns a handle once the node is ready.
/// The handle's ticket can be shared with the receiver to initiate a transfer.
/// @param paths Absolute file system paths of the files to send.
/// @returns A SendHandle whose ticket() can be shared with the receiver.
func sendFiles(paths: [String]) async throws -> SendHandle {
    try await withCheckedThrowingContinuation { continuation in
        sendFiles(paths: paths, callback: SendCallbackBridge(continuation))
    }
}

/// Downloads files from a remote iroh node identified by the given ticket.
/// @param ticket The ticket string produced by the sender.
/// @param destDir Absolute path to the directory where received files will be saved.
/// @returns The filenames of the received files, relative to destDir.
func receiveFile(ticket: String, destDir: String) async throws -> [String] {
    try await withCheckedThrowingContinuation { continuation in
        receiveFile(ticket: ticket, destDir: destDir, callback: ReceiveCallbackBridge(continuation))
    }
}

// MARK: - Callback bridges

/// Bridges the uniffi SendCallback protocol to a Swift async continuation.
/// Resumes the continuation when the P2P node is ready or when an error occurs.
private class SendCallbackBridge: SendCallback {

    /// The continuation to resume once the send node is ready.
    private let continuation: CheckedContinuation<SendHandle, Error>

    /// @param continuation The continuation to resume with a handle or an error.
    init(_ continuation: CheckedContinuation<SendHandle, Error>) {
        self.continuation = continuation
    }

    /// Called by the FFI layer once the iroh node is ready and serving.
    /// @param handle A handle to the active send session.
    func onReady(handle: SendHandle) {
        continuation.resume(returning: handle)
    }

    /// Called by the FFI layer when a fatal error occurs during setup.
    /// @param msg A human-readable description of the error.
    func onError(msg: String) {
        continuation.resume(throwing: NuntiusApiError(msg))
    }
}

/// Bridges the uniffi ReceiveCallback protocol to a Swift async continuation.
/// Resumes the continuation with file names on completion or an error on failure.
private class ReceiveCallbackBridge: ReceiveCallback {

    /// The continuation to resume once all files have been received.
    private let continuation: CheckedContinuation<[String], Error>

    /// @param continuation The continuation to resume with filenames or an error.
    init(_ continuation: CheckedContinuation<[String], Error>) {
        self.continuation = continuation
    }

    /// Called periodically with download progress. Not used by this bridge;
    /// progress is tracked separately via ReceiveProgressCallbackImpl in ReceiveView.
    /// @param bytesReceived Number of bytes received so far.
    /// @param totalBytes Total expected byte count.
    func onProgress(bytesReceived: UInt64, totalBytes: UInt64) {}

    /// Called by the FFI layer when all files have been successfully received.
    /// @param names The filenames of the received files relative to destDir.
    func onDone(names: [String]) {
        continuation.resume(returning: names)
    }

    /// Called by the FFI layer when a fatal error occurs during the transfer.
    /// @param msg A human-readable description of the error.
    func onError(msg: String) {
        continuation.resume(throwing: NuntiusApiError(msg))
    }
}

// MARK: - Error

/// A simple LocalizedError wrapping an FFI error message string.
private struct NuntiusApiError: LocalizedError {

    /// The human-readable error description surfaced to the user.
    let errorDescription: String?

    /// @param msg The raw error string from the FFI layer.
    init(_ msg: String) { errorDescription = msg }
}
