// Core/Permissions.swift
import AVFoundation
import AppKit
import ApplicationServices

enum Permissions {
    static func microphoneAuthorized() async -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    static func requestMicrophone() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .audio)
    }
    static func accessibilityTrusted(prompt: Bool) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }
}
