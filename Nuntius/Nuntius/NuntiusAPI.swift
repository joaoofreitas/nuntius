//
//  NuntiusAPI.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import Foundation

/// @param paths Absolute paths to the files to send
/// @returns A SendHandle whose ticket() can be shared with the receiver
func sendFiles(paths: [String]) async throws -> SendHandle {
    try await withCheckedThrowingContinuation { continuation in
        sendFiles(paths: paths, callback: SendCallbackBridge(continuation))
    }
}

/// @param ticket  The ticket string produced by the sender
/// @param destDir Absolute path to the directory where the files will be saved
/// @returns The filenames of the received files relative to destDir
func receiveFile(ticket: String, destDir: String) async throws -> [String] {
    try await withCheckedThrowingContinuation { continuation in
        receiveFile(ticket: ticket, destDir: destDir, callback: ReceiveCallbackBridge(continuation))
    }
}

private class SendCallbackBridge: SendCallback {
    private let continuation: CheckedContinuation<SendHandle, Error>

    init(_ continuation: CheckedContinuation<SendHandle, Error>) {
        self.continuation = continuation
    }

    func onReady(handle: SendHandle) {
        continuation.resume(returning: handle)
    }

    func onError(msg: String) {
        continuation.resume(throwing: NuntiusApiError(msg))
    }
}

private class ReceiveCallbackBridge: ReceiveCallback {
    private let continuation: CheckedContinuation<[String], Error>

    init(_ continuation: CheckedContinuation<[String], Error>) {
        self.continuation = continuation
    }

    func onProgress(bytesReceived: UInt64, totalBytes: UInt64) {}

    func onDone(names: [String]) {
        continuation.resume(returning: names)
    }

    func onError(msg: String) {
        continuation.resume(throwing: NuntiusApiError(msg))
    }
}

private struct NuntiusApiError: LocalizedError {
    let errorDescription: String?
    init(_ msg: String) { errorDescription = msg }
}
