//
//  NuntiusAPI.swift
//  Nuntius
//
//  Created by João Freitas on 27/03/2026.
//

import Foundation

/// @param path Absolute path to the file to send
/// @returns A SendHandle whose ticket() can be shared with the receiver
func sendFile(path: String) async throws -> SendHandle {
    try await withCheckedThrowingContinuation { continuation in
        sendFile(path: path, callback: SendCallbackBridge(continuation))
    }
}

/// @param ticket  The ticket string produced by the sender
/// @param destDir Absolute path to the directory where the file will be saved
/// @returns The filename of the received file relative to destDir
func receiveFile(ticket: String, destDir: String) async throws -> String {
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
    private let continuation: CheckedContinuation<String, Error>

    init(_ continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    func onDone(name: String) {
        continuation.resume(returning: name)
    }

    func onError(msg: String) {
        continuation.resume(throwing: NuntiusApiError(msg))
    }
}

private struct NuntiusApiError: LocalizedError {
    let errorDescription: String?
    init(_ msg: String) { errorDescription = msg }
}
