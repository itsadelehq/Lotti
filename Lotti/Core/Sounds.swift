// Core/Sounds.swift
import AppKit

enum Sounds {
    static func playStart() { NSSound(named: "Pop")?.play() }
    // Same "Pop" sound on start and end — the previous "Submarine" end sound was disliked.
    static func playEnd()   { NSSound(named: "Pop")?.play() }
}
