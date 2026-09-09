#!/usr/bin/env swift
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import AppKit

let sizes: [(Int, String)] = [
    (16, "icon_16x16"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/Assets.xcassets/AppIcon.appiconset")

try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

func drawIcon(size: CGSize) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let rect = CGRect(origin: .zero, size: size)

    // Rounded background
    let cornerRadius = size.width * 0.22
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    context.addPath(path)
    context.clip()

    // Green gradient background
    let gradientColors = [
        CGColor(red: 0.10, green: 0.45, blue: 0.25, alpha: 1.0),
        CGColor(red: 0.20, green: 0.65, blue: 0.38, alpha: 1.0),
        CGColor(red: 0.35, green: 0.80, blue: 0.50, alpha: 1.0),
    ]
    let gradientLocations: [CGFloat] = [0.0, 0.5, 1.0]
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors as CFArray, locations: gradientLocations) else { return nil }
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])

    // Subtle inner highlight circle
    let circleRect = rect.insetBy(dx: size.width * 0.15, dy: size.height * 0.15)
    context.addEllipse(in: circleRect)
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08))
    context.fillPath()

    // Draw "T" letter
    let fontSize = size.width * 0.55
    let font = CTFontCreateWithName("SFProRounded-Bold" as CFString, fontSize, nil)

    let text = "T" as CFString
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
    ]
    let attributed = NSAttributedString(string: text as String, attributes: attributes)
    let line = CTLineCreateWithAttributedString(attributed)
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    var leading: CGFloat = 0
    let textWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
    let textHeight = ascent + descent
    let textX = (size.width - CGFloat(textWidth)) / 2.0
    let textY = (size.height - textHeight) / 2.0 - descent

    context.saveGState()
    context.translateBy(x: 0, y: size.height)
    context.scaleBy(x: 1.0, y: -1.0)
    context.textPosition = CGPoint(x: textX, y: size.height - textY - ascent)
    CTLineDraw(line, context)
    context.restoreGState()

    // Draw small curved arrow below the T
    let arrowLineWidth = max(2.0, size.width * 0.018)
    let arrowCenter = CGPoint(x: size.width * 0.72, y: size.height * 0.72)
    let arrowRadius = size.width * 0.10

    context.addArc(center: arrowCenter, radius: arrowRadius, startAngle: .pi * 1.15, endAngle: .pi * 0.15, clockwise: false)
    context.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9))
    context.setLineWidth(arrowLineWidth)
    context.setLineCap(.round)
    context.strokePath()

    // Arrow head
    let headLength = size.width * 0.05
    let headAngle: CGFloat = .pi * 0.15
    let tipX = arrowCenter.x + arrowRadius * cos(headAngle)
    let tipY = arrowCenter.y + arrowRadius * sin(headAngle)
    context.move(to: CGPoint(x: tipX, y: tipY))
    context.addLine(to: CGPoint(x: tipX - headLength * cos(headAngle - .pi / 6), y: tipY - headLength * sin(headAngle - .pi / 6)))
    context.addLine(to: CGPoint(x: tipX - headLength * cos(headAngle + .pi / 6), y: tipY - headLength * sin(headAngle + .pi / 6)))
    context.closePath()
    context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.9))
    context.fillPath()

    return context.makeImage()
}

for (size, name) in sizes {
    let s = CGSize(width: size, height: size)
    guard let image = drawIcon(size: s) else {
        print("Failed to generate icon at size \(size)")
        continue
    }

    let url = outputDirectory.appendingPathComponent("\(name).png")
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        print("Failed to create destination for \(name)")
        continue
    }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    print("Generated \(url.path)")
}

// Update Contents.json
let contents: [String: Any] = [
    "images": sizes.map { (size, name) in
        [
            "size": "\(size)x\(size)",
            "idiom": "mac",
            "filename": "\(name).png",
            "scale": name.contains("@2x") ? "2x" : "1x"
        ]
    },
    "info": [
        "version": 1,
        "author": "xcode"
    ]
]

let contentsURL = outputDirectory.appendingPathComponent("Contents.json")
let data = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! data.write(to: contentsURL)
print("Updated \(contentsURL.path)")
