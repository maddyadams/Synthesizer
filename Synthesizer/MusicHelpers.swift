//
//  MusicHelpers.swift
//  Synthesizer
//
//  Created by Maddy Adams on 8/17/19.
//  Copyright © 2019 Maddy Adams. All rights reserved.
//

import Foundation

protocol Effect { }
extension Effect {
    static var id: String { return String(describing: type(of: self)) }
}

protocol NoteEffect: Effect {
    func apply(to: inout [Double], at: Int)
}
protocol LineEffect: Effect {
    var effectStart: Int { get }
    func apply(to: inout [Double], at: Int)
}


struct Echo: LineEffect {
    var amplitude: Double
    var beatDelay: Double
    
    var framesPerBeat: Double!
    var frameDelay: Int! { return Int(beatDelay * framesPerBeat) }
    
    var effectStart = 0
    
    init(amplitude: Double, beatDelay: Double) {
        self.amplitude = amplitude
        self.beatDelay = beatDelay
    }
    
    func apply(to: inout [Double], at: Int) {
        let start = max(at - frameDelay, effectStart)
        let end = to.count - frameDelay
        guard start < end else { return }
        for t in start..<end {
            to[t + frameDelay] += amplitude * to[t]
        }
    }
}

struct ADSR: NoteEffect {
    var aPeak: Double
    var aDur: Int
    var dDur: Int
    var rDur: Int
    
    init(_ aPeak: Double, _ aDur: Int, _ dDur: Int, _ rDur: Int) {
        self.aPeak = aPeak
        self.aDur = aDur
        self.dDur = dDur
        self.rDur = rDur
    }
    
    func apply(to: inout [Double], at: Int) {
        func envelope(t: Int) -> Double {
            if t < aDur {
                let p = Double(t) / Double(aDur)
                return aPeak * p
            }
            else if t < aDur + dDur {
                let p = Double(t - aDur) / Double(dDur)
                return (1 - p) * aPeak + p * 1
            } else if to.count < t + rDur {
                let p = Double(t - (to.count - rDur)) / Double(rDur)
                return (1 - p) * 1 + p * 0
            } else {
                return 1
            }
        }
        for t in at..<to.count {
            to[t] *= envelope(t: t)
        }
    }
}

struct Event {
    var freqs = [Double]()
    var durationNum: Double
    var durationDenom: Double
    var command: Command?
    
    static let oneNoteOctaveRegex = #"[A-G](#|x|b|bb)?\d(\+\d\d?|-\d\d?)?"#
    static let commandRegex = #"\([A-Z]+=[^)]+\)"#
    
    init(_ s: String) {
        let restMatches = regex(#"r"#, matches: s)
        //we allow an optional space after each note in a chord
        var chordMatches = regex(#"\[(\#(Event.oneNoteOctaveRegex + " ?"))+\]"#, matches: s)
        let noteMatches = regex(#"(\#(Event.oneNoteOctaveRegex))"#, matches: s)
        var numDenomMatches = regex(#"\{(\d+)/(\d+)\}"#, matches: s)
        var numMatches = regex(#"\{(\d+)\}"#, matches: s)
        let commandMatches = regex(Event.commandRegex, matches: s)
        
        if let c = commandMatches.first {
            command = Command(c)
            durationNum = 0
            durationDenom = 1
        } else {
            if let first = chordMatches.first {
                chordMatches = regex(Event.oneNoteOctaveRegex, matches: first)
            }
            numDenomMatches = numDenomMatches.map { $0.split { "{/}".contains($0) } }.reduce([], +).map { String($0) }
            numMatches = numMatches.map { $0.split { "{}".contains($0) } }.reduce([], +).map { String($0) }
            
            let notes = [restMatches, chordMatches, noteMatches].first { $0.count != 0 }!
            let duration = [numDenomMatches, numMatches, ["1"]].first { $0.count != 0 }!
            freqs = notes.map { Persistent.getHz(from: $0) }
            durationNum = Double(duration.first!)!
            durationDenom = Double(duration.dropFirst().first ?? "1")!
        }
    }
    
    enum Command {
        case remove(id: String)
        case adsr(adsr: ADSR)
        case echo(echo: Echo)
        
        case inst(s: String)
        case tempo(t: Double)
        case dynam(t: Double)
        case cents(n: Double)
        
        init(_ s: String) {
            let components = s.dropLast().dropFirst().components(separatedBy: "=")
            let params = components[1].components(separatedBy: ";")
            let division = components[1].components(separatedBy: "/")
            
            switch components[0] {
            case "ADSR":
                if let a = Double(params[0]), let b = Int(params[1]), let c = Int(params[2]), let d = Int(params[3]) {
                    self = .adsr(adsr: .init(a, b, c, d))
                } else {
                    self = .remove(id: ADSR.id)
                }
            case "ECHO":
                if let a = Double(params[0]), let b = Double(params[1]) {
                    self = .echo(echo: .init(amplitude: a, beatDelay: b))
                } else {
                    self = .remove(id: Echo.id)
                }
            
            case "INST":
                self = .inst(s: components[1])
            case "TEMPO":
                let num = division.first!
                let denom = division.dropFirst().first ?? "1"
                self = .tempo(t: Double(num)! / Double(denom)!)
            case "DYNAM":
                let num = division.first!
                let denom = division.dropFirst().first ?? "1"
                self = .dynam(t: Double(num)! / Double(denom)!)
            
            case "CENTS":
                self = .cents(n: Double(components[1])!)
            default: fatalError("cannot handle \(s)")
            }
        }
    }
}

class Line {
    var events: [Event]
    var gen: Gen
    var index = -1
    var framesBeforeIndex = 0
    var t = 0
    
    var bpm: Double
    var framesPerBeat: Double {
        return 44100 * 60 / bpm
    }
    var firstBpm: Double
    var dynam: Double
    var currentCents = 0.0
    
    var renderedResult = [Double]()
    
    var noteEffects = [String : NoteEffect]()
    var lineEffects = [String : LineEffect]()
    
    var isDone: Bool { return index >= events.count }
    
    init(bpm: Double, string s: String) {
        self.firstBpm = bpm
        self.bpm = bpm
        //we allow an optional space after each note in a chord
        let multipleNoteOctaves = #"\[(\#(Event.oneNoteOctaveRegex + " ?"))+\]"#
        let duration = #"(\{\d+\}|\{\d+/\d+\})?"#
        let standardEvent = "(r|" + Event.oneNoteOctaveRegex + "|" + multipleNoteOctaves + ")" + duration
        let r = "(" + standardEvent + ")|" + Event.commandRegex
        self.gen = sineWave
        self.dynam = 1
        self.events = regex(r, matches: s).map { Event($0) }
    }
    
    func execute(_ c: Event.Command, eventStart: Int) {
        switch c {
        case let .remove(id: s):
            self.noteEffects[s] = nil
            self.lineEffects[s] = nil
            
        case let .adsr(adsr: adsr): self.noteEffects[ADSR.id] = adsr
        case var .echo(echo: echo):
            echo.framesPerBeat = framesPerBeat
            echo.effectStart = eventStart
            self.lineEffects[Echo.id] = echo
            

        case let .inst(s: s): gen = Instrument(rawValue: s)!.gen()
        case let .tempo(t: t): bpm = firstBpm * t
        case let .dynam(t: t): dynam = t
        case let .cents(n: n): currentCents = n
        }
    }
    
    func render(_ lineIndex: Int, _ totalLineCount: Int) {
        renderedResult = []
        for i in 0..<events.count {
            if (i+1) % (events.count / 10) == 0 {
//                print("rendering event \(i+1) of \(events.count) (\(lineIndex+1)/\(totalLineCount))")
                let rawPercent = Double(i + 1) / Double(events.count)
                let rounded = Int(round(rawPercent * 10)) * 10
                print("Line \(lineIndex): \(rounded)% complete")
            }
            
            let e = events[i]
            var singleEventRender = [Double]()
            var t = -1
            let beats = Double(e.durationNum) / Double(e.durationDenom)
            let eventFrameLength = Int(beats * framesPerBeat)
            
            while t < eventFrameLength {
                t += 1
                if let command = e.command { execute(command, eventStart: renderedResult.count) }
                else {
                    var total = 0.0
                    for f in e.freqs {
                        total += gen(f * pow(2.0, currentCents / 1200.0), t)
                    }
                    singleEventRender.append(total * dynam)
                }
            }
//            noteEffects.values.forEach {
//                $0.apply(to: &singleEventRender)
//            }
//
//            renderedResult.append(contentsOf: singleEventRender)
//            lineEffects.values.forEach {
//                let startIndex = renderedResult.count - $0.leadTime - singleEventRender.count
//                if startIndex < 0 {
//                    renderedResult = $0.apply(to: renderedResult)
//                } else {
//                    renderedResult[startIndex...] = ArraySlice($0.apply(to: Array(renderedResult[startIndex...])))
//                }
//            }
            
            let eventStart = renderedResult.count
            renderedResult.append(contentsOf: singleEventRender)
            noteEffects.values.forEach {
                $0.apply(to: &renderedResult, at: eventStart)
            }
            
            lineEffects.values.forEach {
                $0.apply(to: &renderedResult, at: eventStart)
            }
        }
    }
}


func renderPolyphony(_ lines: [Line]) -> Data {
    let now = Date()
    defer { print("Total compute time: \(Date().timeIntervalSince(now))") }
    
    let semaphore = DispatchSemaphore(value: 0)
    for i in 0..<lines.count {
        DispatchQueue.global().async {
            defer { semaphore.signal() }
            
            lines[i].render(i, lines.count)
        }
    }
    for _ in 0..<lines.count {
        semaphore.wait()
    }
    
    
    
    let maxT = lines.map({ $0.renderedResult.count }).max()!
    var doubleResult = [Double]()
    doubleResult.reserveCapacity(maxT)
    var maxValue = 0.0

    for t in 0..<maxT {
        if t % 44100 == 0 { print("accumulating \(t/44100)s of \(maxT/44100)s") }
        var total = 0.0
        for l in lines {
            total += t < l.renderedResult.count ? l.renderedResult[t] : 0
        }
        if abs(total) > maxValue { maxValue = abs(total) }
        doubleResult.append(total)
    }
    
    var int16result = [Int16]()
    int16result.reserveCapacity(maxT)
    for t in 0..<maxT {
        if t % 44100 == 0 { print("scaling \(t/44100)s of \(maxT/44100)s") }
        int16result.append((doubleResult[t] / maxValue).toInt16())
    }
    return int16result.withUnsafeBufferPointer { Data(buffer: $0) }
    
    
    //multithreading experiment, ended up being slower than single thread in release
    
//    let maxT = lines.map { $0.renderedResult.count }.max()!
//    var doubleData = Data(repeating: 0, count: maxT * MemoryLayout<Double>.size)
//    var threadCount = 4
//    var maxValue = 0.0
//
//    var syncQueue = DispatchQueue(label: "sync queue")
//
//
//    doubleData.withUnsafeMutableBytes { _ptr in
//        let ptr = _ptr.bindMemory(to: Double.self)
//
//        for i in 0..<threadCount {
//            DispatchQueue.global().async {
//                defer { semaphore.signal() }
//
//                var localMaxValue = 0.0
//                for t in (maxT * i) / threadCount ..< (maxT * (i + 1)) / threadCount {
//                    var total = 0.0
//                    for l in lines {
//                        total += t < l.renderedResult.count ? l.renderedResult[t] : 0
//                    }
//                    ptr[t] = total
//                    if abs(total) > localMaxValue { localMaxValue = abs(total) }
//                }
//                syncQueue.sync {
//                    maxValue = max(maxValue, localMaxValue)
//                }
//            }
//        }
//
//        for _ in 0..<threadCount {
//            semaphore.wait()
//        }
//    }
    
    
    
    
    
//    var int16Data = Data(repeating: 0, count: maxT * MemoryLayout<Int16>.size)
//
//    doubleData.withUnsafeBytes { _doubleResult in
//        let doubleResult = _doubleResult.bindMemory(to: Double.self)
//        int16Data.withUnsafeMutableBytes { _ptr in
//            let ptr = _ptr.bindMemory(to: Int16.self)
//
//            for i in 0..<threadCount {
//                DispatchQueue.global().async {
//                    defer { semaphore.signal() }
//
//                    for t in (maxT * i) / threadCount ..< (maxT * (i + 1)) / threadCount {
//                        ptr[t] = (doubleResult[t] / maxValue).toInt16()
//                    }
//                }
//            }
//        }
//
//        for _ in 0..<threadCount {
//            semaphore.wait()
//        }
//    }
//
//    return int16Data
}
