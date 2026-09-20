// Core/Sounds.swift
import AppKit

enum Sounds {
    static func playStart() { NSSound(named: "Pop")?.play() }
    static func playEnd()   { NSSound(named: "Submarine")?.play() }
}
