// Core/AppLog.swift
import Foundation

/// Tiny, greppable logging helper for debugging the live dictation pipeline.
///
/// Every line is prefixed with `[Lotti]` so it is trivial to filter in
/// Console.app (search "[Lotti]") or in the Xcode console. Never log secret
/// values — log only "present"/"missing" for API keys.
enum AppLog {
    static func log(_ message: String) {
        print("[Lotti] \(message)")
    }
}
