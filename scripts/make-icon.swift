#!/usr/bin/env swift
// Draws the {AppName} app icon and two alternates with CoreGraphics.
// Usage: swift scripts/make-icon.swift <outdir>
// Writes AppIcon-1024.png, AppIcon-alt-1.png, AppIcon-alt-2.png (1024x1024, sRGB, opaque, no alpha, no text).
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [
        CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a,
    ])!
}

func gradient(_ stops: [(UInt32, CGFloat)]) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: stops.map { rgb($0.0) } as CFArray, locations: stops.map { $0.1 })!
}

func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func linear(_ c: CGContext, _ g: CGGradient, from: CGPoint, to: CGPoint) {
    c.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// Abstract "photo": sky gradient, sun, two hills. Pure shapes, no text.
func photo(_ c: CGContext, _ r: CGRect, sky: [(UInt32, CGFloat)], sun: UInt32, hillBack: UInt32, hillFront: UInt32) {
    c.saveGState()
    c.clip(to: r)
    linear(c, gradient(sky), from: CGPoint(x: r.midX, y: r.maxY), to: CGPoint(x: r.midX, y: r.minY))
    c.setFillColor(rgb(sun))
    let d = r.width * 0.30
    c.fillEllipse(in: CGRect(x: r.minX + r.width * 0.55, y: r.minY + r.height * 0.52, width: d, height: d))
    c.setFillColor(rgb(hillBack))
    c.fillEllipse(in: CGRect(x: r.minX - r.width * 0.25, y: r.minY - r.height * 0.30, width: r.width * 1.1, height: r.height * 0.78))
    c.setFillColor(rgb(hillFront))
    c.fillEllipse(in: CGRect(x: r.minX + r.width * 0.15, y: r.minY - r.height * 0.42, width: r.width * 1.3, height: r.height * 0.74))
    c.restoreGState()
}

/// A card rotated about its centre, with soft shadow. `fill` paints inside the card rect (local coords, origin at centre).
func card(_ c: CGContext, center: CGPoint, size: CGSize, angle: CGFloat, radius: CGFloat,
          shadow: CGFloat = 40, fill: (CGContext, CGRect) -> Void) {
    c.saveGState()
    c.translateBy(x: center.x, y: center.y)
    c.rotate(by: angle * .pi / 180)
    let r = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -shadow * 0.5), blur: shadow, color: rgb(0x000000, 0.35))
    c.setFillColor(rgb(0xFFFFFF))
    c.addPath(rounded(r, radius)); c.fillPath()
    c.restoreGState()
    c.addPath(rounded(r, radius)); c.clip()
    fill(c, r)
    c.restoreGState()
}

func solid(_ hex: UInt32) -> (CGContext, CGRect) -> Void { { c, r in c.setFillColor(rgb(hex)); c.fill(r) } }

func framedPhoto(border: CGFloat, sky: [(UInt32, CGFloat)], sun: UInt32, back: UInt32, front: UInt32) -> (CGContext, CGRect) -> Void {
    { c, r in
        c.setFillColor(rgb(0xFFFFFF)); c.fill(r)
        c.saveGState(); c.addPath(rounded(r.insetBy(dx: border, dy: border), 46)); c.clip()
        photo(c, r.insetBy(dx: border, dy: border), sky: sky, sun: sun, hillBack: back, hillFront: front)
        c.restoreGState()
    }
}

func checkBadge(_ c: CGContext, center: CGPoint, diameter: CGFloat, color: UInt32) {
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x000000, 0.35))
    c.setFillColor(rgb(color))
    c.fillEllipse(in: CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter))
    c.restoreGState()
    c.setStrokeColor(rgb(0xFFFFFF)); c.setLineWidth(diameter * 0.12)
    c.setLineCap(.round); c.setLineJoin(.round)
    c.move(to: CGPoint(x: center.x - diameter * 0.22, y: center.y - diameter * 0.01))
    c.addLine(to: CGPoint(x: center.x - diameter * 0.05, y: center.y - diameter * 0.18))
    c.addLine(to: CGPoint(x: center.x + diameter * 0.25, y: center.y + diameter * 0.17))
    c.strokePath()
}

// MARK: Variants

/// Main: dusk-indigo ground, fan of three cards. Red (delete) and green (keep) peek out behind a photo.
func drawMain(_ c: CGContext) {
    linear(c, gradient([(0x4A3FD1, 0), (0x241C78, 0.55), (0x120F3A, 1)]), from: CGPoint(x: 0, y: S), to: CGPoint(x: S, y: 0))
    let size = CGSize(width: 520, height: 660)
    card(c, center: CGPoint(x: 350, y: 500), size: size, angle: 14, radius: 64, fill: solid(0xFF4D5A))
    card(c, center: CGPoint(x: 674, y: 500), size: size, angle: -14, radius: 64, fill: solid(0x2FD27A))
    card(c, center: CGPoint(x: 512, y: 470), size: CGSize(width: 560, height: 700), angle: 0, radius: 68, shadow: 60,
         fill: framedPhoto(border: 22,
                           sky: [(0xFFC48A, 0), (0xFF8FA3, 0.55), (0x8C7BFF, 1)],
                           sun: 0xFFF1C9, back: 0x4B3FA8, front: 0x2A2278))
}

/// Alt 1: warm cream ground, one photo mid-flick with ghost trail and a keep badge.
func drawAlt1(_ c: CGContext) {
    linear(c, gradient([(0xFFF6EA, 0), (0xFFE7D2, 1)]), from: CGPoint(x: 0, y: S), to: CGPoint(x: S, y: 0))
    let size = CGSize(width: 520, height: 660)
    let sky: [(UInt32, CGFloat)] = [(0x9EE3FF, 0), (0x6FB5FF, 0.6), (0x5A7CFF, 1)]
    for (i, a) in [(2, 0.18), (1, 0.34)] as [(CGFloat, CGFloat)] {
        c.saveGState(); c.setAlpha(a)
        card(c, center: CGPoint(x: 512 - 120 * i, y: 500 - 30 * i), size: size, angle: 12 - 7 * i, radius: 64, shadow: 0,
             fill: solid(0x5A7CFF))
        c.restoreGState()
    }
    card(c, center: CGPoint(x: 580, y: 520), size: size, angle: -12, radius: 64, shadow: 50,
         fill: framedPhoto(border: 22, sky: sky, sun: 0xFFFFFF, back: 0x2E9E6B, front: 0x147A52))
    checkBadge(c, center: CGPoint(x: 330, y: 250), diameter: 250, color: 0x12A150)
}

/// Alt 2: diagonal red/green split (left/right = delete/keep) with a tilted photo card.
func drawAlt2(_ c: CGContext) {
    c.setFillColor(rgb(0xFF4D5A)); c.fill(CGRect(x: 0, y: 0, width: S, height: S))
    c.setFillColor(rgb(0x2FD27A))
    c.move(to: CGPoint(x: S * 0.62, y: S)); c.addLine(to: CGPoint(x: S, y: S))
    c.addLine(to: CGPoint(x: S, y: 0)); c.addLine(to: CGPoint(x: S * 0.38, y: 0)); c.closePath(); c.fillPath()
    card(c, center: CGPoint(x: 512, y: 512), size: CGSize(width: 520, height: 680), angle: -8, radius: 66, shadow: 60,
         fill: framedPhoto(border: 22, sky: [(0xFFF1B8, 0), (0xFFB36B, 0.6), (0xFF7A8A, 1)],
                           sun: 0xFFFFFF, back: 0x6B4FC8, front: 0x3B2C94))
}

// MARK: Output (opaque: noneSkipLast => PNG written as RGB, no alpha channel)

func render(_ name: String, in dir: URL, _ draw: (CGContext) -> Void) throws {
    guard let c = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError("context") }
    c.interpolationQuality = .high
    c.setAllowsAntialiasing(true)
    c.setFillColor(rgb(0xFFFFFF)); c.fill(CGRect(x: 0, y: 0, width: S, height: S))
    draw(c)
    guard let img = c.makeImage(),
          let dest = CGImageDestinationCreateWithURL(dir.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("image") }
    CGImageDestinationAddImage(dest, img, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("write \(name)") }
    print("wrote \(name)")
}

let args = CommandLine.arguments
guard args.count >= 2 else { print("usage: swift scripts/make-icon.swift <outdir>"); exit(64) }
let out = URL(fileURLWithPath: args[1], isDirectory: true)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
try render("AppIcon-1024.png", in: out, drawMain)
try render("AppIcon-alt-1.png", in: out, drawAlt1)
try render("AppIcon-alt-2.png", in: out, drawAlt2)
