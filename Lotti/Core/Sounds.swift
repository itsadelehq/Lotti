// Core/Sounds.swift
import AppKit

enum Sounds {
    // "Tink" is a soft, clean tick — much subtler than "Pop", which sounded
    // harsh/alarming. Same sound on start and end, as before.
    static func playStart() { NSSound(named: "Tink")?.play() }
    static func playEnd()   { NSSound(named: "Tink")?.play() }
}
