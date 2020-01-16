//
//  MathHelpers.swift
//  Synthesizer
//
//  Created by Maddy Adams on 8/17/19.
//  Copyright © 2019 Maddy Adams. All rights reserved.
//

import Foundation

//raw waves
func sineWave(_ f: Double, _ t: Int) -> Double {
    guard f > 0 else { return 0 }
    return sin(2 * .pi * Double(t) * f / 44100)
}

func squareWave(_ f: Double, _ t: Int) -> Double {
    guard f > 0 else { return 0 }
    let framesPerCycle = 44100 / f
    return (Double(t) / framesPerCycle).truncatingRemainder(dividingBy: 1) > 0.5 ? 1 : -1
}

func sawtoothWave(_ f: Double, _ t: Int) -> Double {
    guard f > 0 else { return 0 }
    let framesPerCycle = 44100 / f
    return (Double(t) / framesPerCycle).truncatingRemainder(dividingBy: 1) * 2 - 1
}

func triangleWave(_ f: Double, _ t: Int) -> Double {
    guard f > 0 else { return 0 }
    let framesPerCycle = 44100 / f
    let percent = Double(t).truncatingRemainder(dividingBy: framesPerCycle) / framesPerCycle
    return percent > 0.5 ? 4 * (1 - percent) - 1 : 4 * percent - 1
}

//math helpers
typealias Gen = (Double, Int) -> Double
func harmonicSeries(_ gen: @escaping Gen, _ freqs: [(Double, Double)]) -> Gen {
    return { (f: Double, t: Int) -> Double in
        var total = 0.0
        for x in freqs { total += x.1 * gen(f * x.0, t) }
        return total
    }
}

func linearInterpolateWeights(_ w: [(Int, Double)]) -> [Double] {
    var result = [Double]()
    for i in 1..<w.count {
        let startT = w[i - 1].0
        let endT = w[i].0
        let weightParam = { (t: Int) -> Double in Double(t - startT) / Double(endT - startT) }
        let a = w[i - 1].1
        let b = w[i].1
        result.append(contentsOf: Array(startT..<endT).map { weight(weightParam($0), a, b) })
    }
    return result
}

func weight(_ x: Double, _ a: Double, _ b: Double) -> Double {
    return ((1 - x) * a) + ((x) * b)
}

