// Exit 0 if the app area of a screenshot is (almost) one flat colour, 1 otherwise, 2 on error.
// Usage: is-blank <png>
import CoreGraphics
import Foundation
import ImageIO

guard CommandLine.arguments.count == 2,
      let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { exit(2) }
let w = 220, h = 480
guard let band = img.cropping(to: CGRect(x: 0, y: Int(Double(img.height) * 0.15), width: img.width, height: Int(Double(img.height) * 0.7))),
      let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
      let data = ctx.data else { exit(2) }
ctx.interpolationQuality = .low
ctx.draw(band, in: CGRect(x: 0, y: 0, width: w, height: h))
let px = data.bindMemory(to: UInt32.self, capacity: w * h)
var colors = Set<UInt32>()
for i in 0..<(w * h) { colors.insert(px[i]); if colors.count >= 40 { exit(1) } }
exit(0)
