// Generates license-free (pastel landscapes with film grain, ~2.5-5 MB each) abstract "landscape" JPEGs (no EXIF, no real photos).
// Usage: swift scripts/make-sample-photos.swift <outDir> [count]
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 2 else { FileHandle.standardError.write(Data("usage: make-sample-photos <outDir> [count]\n".utf8)); exit(2) }
let outDir = URL(fileURLWithPath: args[1])
let count = args.count > 2 ? Int(args[2]) ?? 36 : 36
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let w = 3000, h = 4000
let cs = CGColorSpaceCreateDeviceRGB()

struct RNG: RandomNumberGenerator {
    var s: UInt64
    mutating func next() -> UInt64 { s &+= 0x9E3779B97F4A7C15; var z = s; z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9; z = (z ^ (z >> 27)) &* 0x94D049BB133111EB; return z ^ (z >> 31) }
}

func hsb(_ hue: CGFloat, _ sat: CGFloat, _ bri: CGFloat) -> CGColor {
    let h6 = (hue - floor(hue)) * 6, c = bri * sat, x = c * (1 - abs(h6.truncatingRemainder(dividingBy: 2) - 1)), m = bri - c
    let (r, g, b): (CGFloat, CGFloat, CGFloat)
    switch Int(h6) { case 0: (r, g, b) = (c, x, 0); case 1: (r, g, b) = (x, c, 0); case 2: (r, g, b) = (0, c, x); case 3: (r, g, b) = (0, x, c); case 4: (r, g, b) = (x, 0, c); default: (r, g, b) = (c, 0, x) }
    return CGColor(red: r + m, green: g + m, blue: b + m, alpha: 1)
}

for i in 0..<count {
    var rng = RNG(s: UInt64(i + 1) &* 7919)
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let base = CGFloat.random(in: 0...1, using: &rng)
    // Sky gradient
    let sky = CGGradient(colorsSpace: cs, colors: [hsb(base, 0.45, 0.98), hsb(base + 0.08, 0.30, 1.0), hsb(base + 0.14, 0.55, 0.85)] as CFArray, locations: [0, 0.55, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])
    // Sun
    let sunR = CGFloat.random(in: 220...420, using: &rng)
    ctx.setFillColor(hsb(base + 0.02, 0.15, 1.0))
    ctx.fillEllipse(in: CGRect(x: CGFloat.random(in: 400...2600, using: &rng), y: CGFloat.random(in: 2200...3300, using: &rng), width: sunR * 2, height: sunR * 2))
    // Layered hills
    let layers = Int.random(in: 3...5, using: &rng)
    for l in 0..<layers {
        let t = CGFloat(l) / CGFloat(layers)
        let baseY = 1800 - t * 1300
        let amp = CGFloat.random(in: 120...320, using: &rng), phase = CGFloat.random(in: 0...6, using: &rng), freq = CGFloat.random(in: 0.6...1.6, using: &rng)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: 0))
        for x in stride(from: 0, through: w, by: 25) {
            let y = baseY + amp * sin(CGFloat(x) / CGFloat(w) * .pi * 2 * freq + phase) + amp * 0.4 * sin(CGFloat(x) / 400 + phase)
            p.addLine(to: CGPoint(x: CGFloat(x), y: y))
        }
        p.addLine(to: CGPoint(x: CGFloat(w), y: 0)); p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor(hsb(base + 0.45 + t * 0.1, 0.35 + t * 0.2, 0.75 - t * 0.45))
        ctx.fillPath()
    }
    // Fine detail: thousands of small translucent strokes (grass/foliage-like texture), still abstract.
    let strokes = Int.random(in: 14000...26000, using: &rng)
    for _ in 0..<strokes {
        let x = CGFloat.random(in: 0...CGFloat(w), using: &rng), y = CGFloat.random(in: 0...1900, using: &rng)
        let len = CGFloat.random(in: 8...40, using: &rng), ang = CGFloat.random(in: 1.2...1.9, using: &rng)
        ctx.setStrokeColor(hsb(base + CGFloat.random(in: 0.35...0.6, using: &rng), 0.4, CGFloat.random(in: 0.2...0.7, using: &rng)).copy(alpha: 0.18)!)
        ctx.setLineWidth(CGFloat.random(in: 2...5, using: &rng))
        ctx.move(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: x + cos(ang) * len, y: y + sin(ang) * len)); ctx.strokePath()
    }
    // Film grain: per-pixel luminance noise, strength varies per image.
    if let data = ctx.data {
        let px = data.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * h)
        let amp = Int.random(in: 4...9, using: &rng)
        var st = UInt64(i + 1) &* 0x2545F4914F6CDD1D
        for row in 0..<h {
            let base = row * ctx.bytesPerRow
            for col in 0..<w {
                st ^= st << 13; st ^= st >> 7; st ^= st << 17
                let n = Int(st & 0xFF) % (2 * amp + 1) - amp
                let o = base + col * 4
                for c in 0..<3 { px[o + c] = UInt8(max(0, min(255, Int(px[o + c]) + n))) }
            }
        }
    }
    let img = ctx.makeImage()!
    let url = outDir.appendingPathComponent(String(format: "sample-%02d.jpg", i + 1))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { exit(1) }
    // Varied dates: spread across ~2 years via file timestamps.
    let daysAgo = Double(i) * 19 + Double.random(in: 0...10, using: &rng)
    let date = Date().addingTimeInterval(-daysAgo * 86400 - Double.random(in: 0...80000, using: &rng))
    try FileManager.default.setAttributes([.creationDate: date, .modificationDate: date], ofItemAtPath: url.path)
}
print("wrote \(count) images to \(outDir.path)")
