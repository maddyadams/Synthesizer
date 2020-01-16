//
//  Synthesizer.swift
//  Synthesizer
//
//  Created by Maddy Adams on 8/17/19.
//  Copyright © 2019 Maddy Adams. All rights reserved.
//

import Foundation

//.wav handling
struct Synthesizer {
    func main() {
//        Persistent.setup()
        let soundData = makeSoundData()
        var data = Data()
        data.append("RIFF".ascii())
        data.append((36 + soundData.count).pad(4))
        data.append("WAVE".ascii())
        
        let numChannels = 1
        let sampleRate = 44100
        let bitsPerSample = 16
        data.append("fmt ".ascii())
        data.append(16.pad(4))
        data.append(1.pad(2))
        data.append(numChannels.pad(2))
        data.append(sampleRate.pad(4))
        data.append((sampleRate * numChannels * bitsPerSample / 8).pad(4))
        data.append((numChannels * bitsPerSample / 8).pad(2))
        data.append(bitsPerSample.pad(2))
        
        data.append("data".ascii())
        data.append(soundData.count.pad(4))
        data.append(soundData)
        
        do {
            try data.write(to: URL(fileURLWithPath: filePath))
            print("did write")
        } catch {
            print("ERROR: could not write data to path \(filePath)")
            print("Did you remember to change the file path?")
        }
    }
    
}

enum Instrument: String {
    case inst1, inst1NoSaws, inst2, inst3, inst4, inst5, inst6, inst7, inst8, inst8DoubledOctaveUp, inst9, inst10
    
    func gen() -> Gen {
        switch self {
        case .inst1:
            return { (f, t) in
                let sines = sineWave(f/2, t) + sineWave(f, t) + sineWave(2*f, t)
                let saws = sawtoothWave(f/2, t) + sawtoothWave(f, t) + sawtoothWave(2*f, t)
                
                return sines + 0.1*saws * max(0, sineWave(1.0/6, t))
            }
        case .inst1NoSaws:
            return { (f, t) in
                return sineWave(f/2, t) + sineWave(f, t) + sineWave(2*f, t)
            }
        case .inst2:
            return { (f, t) in
            let freqs = [1, 2, 4].map { (Double($0), pow(4.0, Double(1-$0))) }
            return harmonicSeries(sineWave, freqs)(f, t)
            }
        case .inst3:
            return { (f, t) in
            let first = sineWave(f, t)
            let rest: [Double] = Array(2...4).map {
                let a = sineWave(f * Double($0), t)
                let b = max(0, sineWave(1.0/6, t))
                return a * b / Double($0)
            }
            var total = first
            for x in rest { total += x }
            return total
            }
        case .inst4:
            return { (f, t) in
            return (triangleWave(f, t) + 0.25*sineWave(2*f, t) + 0.1*sineWave(0.5*f, t))*0.25
            }
        case .inst5:
            return { (f, t) in
                return sineWave(f, t) + 0.1*squareWave(f, t)
            }
            
        case .inst6:
            return { (f, t) in
                return triangleWave(f, t) + sineWave(f*2, t) + 0.25*sawtoothWave(f, t)
            }
            
        case .inst7:
            return { (f, t) in
                return (sineWave(f, t) + sineWave(f*2, t) + sineWave(f*3, t) + triangleWave(f, t) + triangleWave(f*2, t))/5
            }
            
        case .inst8:
            return { (f, t) in
                return triangleWave(f, t) + 0.5*sawtoothWave(f, t)*((triangleWave(125/(8*60), t)+1)/2)
            }
            
        case .inst8DoubledOctaveUp:
            return { (f, t) in
                return (Instrument.inst8.gen()(f, t) + 0.5*Instrument.inst8.gen()(f*2, t))
            }
            
        case .inst9:
            return { (f, t) in
                return harmonicSeries(sineWave, [(1, 1), (2, 1/2), (4, 1/4)])(f, t)
            }
            
        case .inst10:
            return sineWave
        }
    }
}

extension Synthesizer {
    func makeSoundData() -> Data {
        return renderPolyphony(song1())
    }
    
    
    func test() -> [Line] {
        return [.init(bpm: 125, string: "(INST=inst8DoubledOctaveUp)A4{8}G4{7}r{1/2}D4{1/2}"*2)]
    }
    
    func song1() -> [Line] {
        let bass =
            "(INST=inst1)(TEMPO=1/8)" +
            "[D3A3]  [C3G3]  [G2D3]  [Bb2F3]{1/2}[C3G3]{1/2}"*2 +
            
            "(INST=inst1NoSaws)" +
            "(ADSR=1;0;0;22050)[D3A3]  (ADSR=0.1;0;44100;11025)[C3G3]  [G2D3]  [Bb2F3]{1/2}[C3G3]{1/2}" +
            "[D3A3]  [C3G3]  [G2D3]  [Bb2F3]{1/2}[C3G3]{1/2}" +
            
            "(TEMPO=4)(ADSR=1;0;0;0)" +
            ("D3{5}F3{2}A3D4{6}A3{2} D3{5}F3{2}A3D4{6}A3{2}" +
                "C3{5}E3{2}G3C4{6}G3{2} C3{5}E3{2}G3C4{6}G3{2}" +
                "G2{5}B2{2}D3G3{6}D3{2} G2{5}B2{2}D3G3{6}D3{2}" +
                "Bb2{5}D3{2}F3Bb3{3}F3{2}D3{2}Bb2 C3{5}E3{2}G3C4{3}G3{2}E3{2}C3")*2 +
                
            "(TEMPO=4)(ADSR=1;0;0;0)" +
            ("D3{5}F3{2}A3D4{6}A3{2} D3{5}F3{2}A3D4{6}A3{2}" +
                "C3{5}E3{2}G3C4{6}G3{2} C3{5}E3{2}G3C4{6}G3{2}" +
                "G2{5}B2{2}D3G3{6}D3{2} G2{5}B2{2}D3G3{6}D3{2}" +
                "Bb2{5}D3{2}F3Bb3{3}F3{2}D3{2}Bb2 C3{5}E3{2}G3C4{3}G3{2}E3{2}C3")*2 +
            
            "(INST=inst1NoSaws)(TEMPO=1/8)" +
            "[D3A3]  [C3G3]  [G2D3]  [Bb2F3]{1/2}[C3G3]{1/2}"*2 +
                
            "(TEMPO=1)" +
            "[D3A3]{2}[C3G3]{2}[G2D3]{2}" +
            "(TEMPO=0.9)[Bb2F3]{1/2}(TEMPO=0.8)[Bb2F3]{1/2}(TEMPO=0.7)[C3G3]{1/2}(TEMPO=0.6)[C3G3]{1/2} (TEMPO=0.5)[D3A3]{2}" +
            ""
        
        let tenor =
            "(INST=inst5)(TEMPO=4)(ADSR=2;0;2205;441)" +
            ("C4D4rD4rD4rD4"*3 + "rD4rD4F4E4D4C4") * 4 +
            ("C4D4rD4rD4rD4"*3 + "rD4rD4F4E4D4C4") * 3 +
            "C4D4rD4rD4rD4"*3 + "rD4rD4F4{2}E4{2}" +
            
            "(TEMPO=1)(DYNAM=1.5)" +
            "(ADSR=1;441;2205;11025)F4{2}r{5}(ADSR=1;11025;0;11025)F4  E4{2}r{5}E4  B3{2}r{5}E4  D4{2}r{2}D4{2}r{2}" +
            "F4{2}r{5}A4  E4{2}r{5}A4  [B3D4]{2}r{5}A4  D4{2}A4{2}D4{2}A4{2}" +
            
            "(TEMPO=1)(ADSR=1;0;0;0)(DYNAM=1)" +
            "F4{2}r{5}F4  E4{2}r{5}E4  B3{2}r{5}E4  D4{2}r{2}D4{2}r{2}" +
            "F4{2}r{5}A4  E4{2}r{5}A4  [B3D4]{2}r{5}A4  D4{2}A4{2}D4{2}A4{2}" +
            
            "(TEMPO=1)" +
            "r{32}" +
            "(TEMPO=4)(DYNAM=0.5)" +
            "r{2}F4D4F4D4F4D4"*4 + "r{2}E4C4E4C4E4C4"*4 +
            "r{2}F4D4F4D4F4D4"*4 + "r{2}F4D4F4D4F4D4"*2 + "r{2}E4C4E4C4E4C4"*2 +
            
            "(TEMPO=1)(ADSR=1;0;0;0)(DYNAM=1)" +
            "F4{2}r{5}F4  E4{2}r{5}E4  B3{2}r{5}E4  D4{2}r{2}D4{2}r{2}" +
            "F4{2}r{5}A4  E4{2}r{5}A4  [B3D4]{2}r{5}A4  D4{2}A4{2}D4{2}A4{2}" +
                
            "(TEMPO=4)" +
            "(DYNAM=1)C4D4rD4rD4rD4" + "(DYNAM=0.9)C4D4rD4rD4rD4" +
            "(DYNAM=0.7)C4D4rD4rD4rD4" + "(DYNAM=0.5)(TEMPO=3.6)F4{2}(TEMPO=3.2)E4{2}(TEMPO=2.8)D4{2}(TEMPO=2.4)C4{2}" +
            "(TEMPO=2)D4{8}" +
            ""
        
        let sop =
            "(INST=inst4)(ADSR=2;0;441;0)" +
            "r{32}" +
            "(TEMPO=4)" +
            "r{8}A5D5A5D5A5D5A5D5  r{8}A5D5A5D5A5D5A5G5{3}" +
            "(TEMPO=2)F5E5C5[C5E5][D5F5][E5G5][F5A5] [E5G5][D5F5][C5E5][G4C5][C5E5][D5F5][E5G5]" +
            "(TEMPO=4)[C5A5][D5G5]{2}  B4G5B4G5B4G5B4 G5B4G5B4G5B4[C5A5][D5G5]{2}  B4G5B4G5B4G5B4 G5B4G5B4G5B4G5F5" +
            "D5{8}r{6}G5F5D5{8}r{8}" +
            
            "(TEMPO=2)(ADSR=1;0;0;0)(DYNAM=0.4)" +
            "D5A5G5F5D6A5G5F5 D5A5G5F5D6A5G5F5"*4 * 2 +
            
            "(TEMPO=4)(ADSR=1;0;0;0)(DYNAM=1)" +
            ("C5D5rD5rD5rD5"*3 + "rD5rD5F5E5D5C5")*4 * 2 +
            
            "(TEMPO=4)" +
            ("D5{8}A5{7}G5F5{7}G5A5{2}r{2}C6{2}r{2} C6{7}A5G5{7}F5E5{7}D5C5{2}r{2}E5{2}F5{2}" +
            "[G5G5]{4}[F5G5]{4}[D5G5]{4}r{2}F5{2}[G5G5]{4}[F5G5]{4}[D5G5]{4}r{2}A5G5 F5{8}D5{8}E5{8}C5{8}")*2 +
            
            "(TEMPO=4)" +
            ("D5{8}A5{7}G5F5{7}G5A5{2}r{2}C6{2}r{2} C6{7}A5G5{7}F5E5{7}D5C5{2}r{2}E5{2}F5{2}" +
            "[G5G5]{4}[F5G5]{4}[D5G5]{4}r{2}F5{2}[G5G5]{4}[F5G5]{4}[D5G5]{4}r{2}A5G5 F5{8}D5{8}E5{8}C5{8}")*2 +
                
            "(TEMPO=1)" +
            "D5{2}" +
            ""
        
        
        let bpm: Double = 84
        let lines = [Line(bpm: bpm, string: bass),
                     .init(bpm: bpm, string: tenor),
                     .init(bpm: bpm, string: sop)]
        return lines
    }
    
    func song2() -> [Line] {
        let bass = "(TEMPO=1/4)(INST=inst6)(DYNAM=0.5)" +
        "D3 F3 C3 G3" +
        "[D3A3] [F3C4] [C3G3] [G3D4]" +
        "[D3A3F4] [F3C4A4] [C3G3E4] [G3D4B4]" +

        "[D3A3F4] [F3C4A4] [C3G3E4] [G3D4B4]"*2 +

        "[D3A3] [F3C4] [C3G3] [G3D4]"*4 +
            
        "[D3A3] [F3C4] [C3G3] [G3D4]"*4 +
        ""
        

        let tenor = "(TEMPO=1)(INST=inst7)(DYNAM=3)" +
        "r{48}" +
        
        "D4{2}D4E4 F4{2}A4{2} E4{5/2}F4{1/4}E4{1/4}D4 B4{5/2}C5{1/4}B4{1/4}A4{3/4}G4{1/4}" +
        "A4{2}C5{2} C5{3/2}D5{1/4}C5{1/4}A4{3/2}A4{1/2} G4{3}r{1/4}A4{1/4}G4{1/4}F4{1/4} E4r{1/4}F4{1/4}E4{1/4}D4{1/4}C4C4" +
        
        "(TEMPO=2)(ECHO=0.8;3)(ADSR=2;0;441;441)" +
        ("r{2}D4F4A4r{3} r{2}F4A4C5r{3} r{2}C4E4G4r{3} r{2}G4B4D5r{3}" +
        "r{2}D5A4F4r{3} r{2}C5A4F4r{3} r{2}C5G4E4r{3} r{2}B4G4D4r{3}")*2 +
        
        "(DYNAM=1)" +
        ("r{2}D4F4A4r{3} r{2}F4A4C5r{3} r{2}C4E4G4r{3} r{2}G4B4D5r{3}" +
        "r{2}D5A4F4r{3} r{2}C5A4F4r{3} r{2}C5G4E4r{3} r{2}B4G4D4r{3}")*2 +
        ""
        
        
        let sop = "(TEMPO=1/4)(INST=inst8DoubledOctaveUp)" +
        "r{12}" +
            
        "r{8}" +
        
        "r{16}" +
            
        "(TEMPO=1)" +
        "A4{8}G4{7}r{1/2}D4{1/2}"*2 +
        "A4{8}G4{7}r{1/2}D4{1/2}"*2 +
        ""
        
        
        let bpm: Double = 125
        return [.init(bpm: bpm, string: bass),
                .init(bpm: bpm, string: tenor),
                .init(bpm: bpm, string: sop)]
    }
    
    func song3() -> [Line] {
        let bass = "(INST=inst9)(TEMPO=1/4)(DYNAM=2)" +
        "Eb2 G2 Ab2 Eb2{1/2} Bb2{1/2} C3 F2 G2{1/2} Ab2{1/2} Bb2{1/2} Bb1{1/2}" +
            
        "Eb2 G2 Ab2 Eb2{1/2} Bb2{1/2} C3 F2 G2{1/2} Ab2{1/2} Bb2{1/2} Bb1{1/2}" +
        ""
        
        
        let tenor = "(INST=inst9)(TEMPO=1/4)" +
        "[Bb2Eb3] [D3G3] [Eb3Ab3] [Bb2Eb3]{1/2} [F3Bb3]{1/2}" +
        "[G3C4] [Ab3C4] [G3Eb4]{1/2} [Ab3Eb4]{1/2} [Bb3Eb4G4]{1/2} [Bb3D4F4]{1/2}" +
        
        "(TEMPO=2)(DYNAM=0.5)" +
        "Eb3Bb3Eb4Bb3"*2 + "Bb3D4F4D4"*2 + "Ab3Bb3C4Eb4Ab4Eb4C4Ab3" + "Eb3F3G3Bb3 Bb3C4D4F4" +
        "C3D3Eb3G3C4G3Eb3D3" + "Ab2Bb2C3Eb3Ab3Eb3C3Ab3" + "Eb3Bb3Eb4Bb3 Eb3Ab3C4Ab3" + "G3Bb3Eb3Bb3 F3Bb3D4Bb3" +
        ""
        
        
        let sop = "(INST=inst7)" +
        "Eb5{3}F5 D5{3}Eb5 C5{15/4}Bb4{1/4} G4{2}Bb4{2} C5{2}Bb4C5 Ab4{3}Bb4 G4{2}Bb4{2} Eb5{2}D5{2}" +
            
        "Eb5{3}F5 D5{3}Eb5 C5{15/4}Bb4{1/4} G4{2}Bb4{2} C5{2}Bb4C5 Ab4{3}Bb4 G4{2}Bb4{2} Eb5{2}D5{2}" +
        ""

        
        let bpm: Double = 72
        return [.init(bpm: bpm, string: bass),
                .init(bpm: bpm, string: tenor),
                .init(bpm: bpm, string: sop)]
    }
    
    func song4() -> [Line] {
        let bass = "(INST=inst10)(TEMPO=1/4)" +
        "C3{2} F2-2{2} C3{2} F2-2{2}" +
        "C3{2} F2-2{2} C3{2} F2-2{2}" +
            
        "(CENTS=-2)" +
        "A2-14{2} F2{2}" +
        "A2-14{2} F2{2}" +
        ""
        
        let tenor = "(INST=inst10)(TEMPO=1)" +
        "G3+2 r G3+2 r"*2 + "G3+2{1/4}A3-16{3/4} r G3+2{1/4}A3-16{3/4} r"*2 + "G3+2 C4 G3+2 C4"*2 + "G3+2{1/4}A3-16{3/4} r G3+2{1/4}A3-16{3/4} r"*2 +
        "G3+2 r G3+2 r"*2 + "G3+2{1/4}A3-16{3/4} r G3+2{1/4}A3-16{3/4} r"*2 + "G3+2 C4 G3+2 C4"*2 + "G3+2{1/4}A3-16{3/4} r G3+2{1/4}A3-16{3/4} r"*2 +
        
        "(CENTS=-2)" +
        "r{16}" +
        "(TEMPO=2)" +
        "r{5} A3-14B3-10C4+2"*4 +
        ""
        
        let sop = "(INST=inst10)" +
        "r{32}" +
        "(TEMPO=4)" +
        "r{3}B4-12 D5+4B4-12D5+4B4-12 D5+4{2}B4-12{2} D5+4{2}B4-12{2}"*2 + "r{2}B4-12D5+4 E5-14B4-12D5+4E5-14"*2*2 +
        "r{3}B4-12 D5+4B4-12D5+4B4-12 D5+4{2}E5-14{2} F#5-10{2}D5+4{2}"*2 + "r{2}B4-12D5+4 E5-14B4-12D5+4E5-14F#5-10{4}D5+4{4}"*2 +
        
        "(CENTS=-2)" +
        "E5-16{2}C5+2D5+6 E5-16{12}  E5-16{2}C5+2D5+6 E5-16{3}F#5-8 E5-16{8}"*2 +
        "E5-16{2}C5+2D5+6 E5-16{12}  E5-16{2}C5+2D5+6 E5-16{3}F#5-8 E5-16{8}"*2 +
        ""
        
        let bpm: Double = 72
        return [.init(bpm: bpm, string: bass),
                .init(bpm: bpm, string: tenor),
                .init(bpm: bpm, string: sop)]
    }
}
