//
//  MiscHelpers.swift
//  Synthesizer
//
//  Created by Maddy Adams on 8/17/19.
//  Copyright © 2019 Maddy Adams. All rights reserved.
//

import Foundation

struct Persistent {
    private static var noteOctaveCentsToHz = [String : Double]()
    
    static func getHz(from s: String) -> Double {
        if let result = Persistent.noteOctaveCentsToHz[s] { return result }
        
        let result: Double = {
            if s == "r" { return 0 }
            let halfStepOffset: Int = {
                if s.contains("bb") {
                    return ["A":-2, "B":0, "C":1, "D":-9, "E":-7, "F":-6, "G":-4][s.first]!
                } else if s.contains("b") {
                    return ["A":-1, "B":1, "C":2, "D":-8, "E":-6, "F":-4, "G":-3][s.first]!
                } else if s.contains("#") {
                    return ["A":1, "B":-9, "C":-8, "D":-6, "E":-4, "F":-3, "G":-1][s.first]!
                } else if s.contains("x") {
                    return ["A":2, "B":-8, "C":-7, "D":-5, "E":-3, "F":-2, "G":0][s.first]!
                } else {
                    return ["A":0, "B":2, "C":-9, "D":-7, "E":-5, "F":-4, "G":-2][s.first]!
                }
            }()
            
            let octave: Int = {
                return Int(String(s.first(where: { "0123456789".contains($0) })!))!
            }()
            
            let cents: Int = {
                if let i = s.firstIndex(of: "+") ?? s.firstIndex(of: "-") {
                    return Int(s.suffix(from: i))!
                } else {
                    return 0
                }
            }()
            
            return 440.0 * pow(2.0, Double(1200 * (octave - 4) + halfStepOffset * 100 + cents) / 1200.0)
        }()
        Persistent.noteOctaveCentsToHz[s] = result
        return result
    }
//    static func setup() {
//        let data: [[String] : Int] = [
//            ["A", "Bbb", "Gx"] : 0,
//            ["A#", "Bb", "Cbb"] : 1,
//            ["B", "Ax", "Cb"] : 2,
//            ["C", "B#", "Dbb"] : -9,
//            ["C#", "Bx", "Db"] : -8,
//            ["D", "Cx", "Ebb"] : -7,
//            ["D#", "Eb", "Fbb"] : -6,
//            ["E", "Dx", "Fb"] : -5,
//            ["F", "E#", "Gbb"] : -4,
//            ["F#", "Ex", "Gb"] : -3,
//            ["G", "Fx", "Abb"] : -2,
//            ["G#", "Ab"] : -1
//        ]
//        let tuples = data.map { (k: [String], v: Int) in k.map { ($0, v) } }.reduce([], +)
//        Persistent.noteOctaveCentsToHz["r"] = 0
//        for octave in 0...9 {
//            for t in tuples {
//                let rawHz = 440.0 * pow(2.0, Double(t.1) / 12)
//
//                Persistent.noteOctaveCentsToHz[t.0 + String(octave)] = rawHz * pow(2.0, Double(octave - 4))
//
//            }
//        }
//    }
}

func regex(_ s: String, matches: String, allowingEmtpyString: Bool = false) -> [String] {
    let r = try! NSRegularExpression(pattern: s)
    let result = r.matches(in: matches, range: NSRange(matches.startIndex..., in: matches))
    let mapped = result.map { String(matches[Range($0.range, in: matches)!]) }
    if allowingEmtpyString { return mapped }
    else { return mapped.filter { !$0.isEmpty } }
}

extension Int {
    func pad(_ size: Int) -> Data {
        var x = self
        var bytes = [UInt8]()
        for _ in 0..<size {
            bytes.append(UInt8(x % 256))
            x /= 256
        }
        return Data(bytes: &bytes, count: size)
    }
}

extension String {
    func ascii() -> Data {
        return data(using: .ascii)!
    }
}

func *(lhs: String, rhs: Int) -> String {
    return String(repeating: lhs, count: rhs)
}

extension Double {
    func toInt16() -> Int16 {
        let scaled = Int(self * pow(2, 15))
        return Int16(clamping: scaled)
    }
}
