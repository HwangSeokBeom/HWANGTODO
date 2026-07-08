#!/usr/bin/env swift
// Renders the HWANGTODO app icon (1024×1024 PNG).
// Usage: swift Scripts/render_appicon.swift <output.png>
//
// Design: calm indigo gradient, one bold white capture bolt, a subtle
// check notch — "record in one second" as a mark. iOS masks the corners.
import AppKit
import CoreGraphics

let size = 1024
guard CommandLine.arguments.count > 1 else {
    fputs("usage: render_appicon.swift <output.png>\n", stderr)
    exit(1)
}
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(
    data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
    space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// Background: vertical indigo gradient.
let top = CGColor(red: 0.36, green: 0.42, blue: 0.95, alpha: 1)
let bottom = CGColor(red: 0.16, green: 0.19, blue: 0.55, alpha: 1)
let gradient = CGGradient(colorsSpace: colorSpace, colors: [top, bottom] as CFArray, locations: [0, 1])!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: CGFloat(size)),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// Soft radial highlight upper-left, for a hint of glass.
let highlight = CGGradient(
    colorsSpace: colorSpace,
    colors: [CGColor(gray: 1, alpha: 0.18), CGColor(gray: 1, alpha: 0)] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    highlight,
    startCenter: CGPoint(x: 330, y: 760), startRadius: 0,
    endCenter: CGPoint(x: 330, y: 760), endRadius: 620,
    options: []
)

// Capture bolt — hand-tuned lightning glyph, slightly left of center.
let bolt = CGMutablePath()
bolt.move(to: CGPoint(x: 585, y: 880))
bolt.addLine(to: CGPoint(x: 330, y: 520))
bolt.addLine(to: CGPoint(x: 470, y: 520))
bolt.addLine(to: CGPoint(x: 415, y: 190))
bolt.addLine(to: CGPoint(x: 690, y: 560))
bolt.addLine(to: CGPoint(x: 545, y: 560))
bolt.addLine(to: CGPoint(x: 585, y: 880))
bolt.closeSubpath()

context.setShadow(offset: CGSize(width: 0, height: -14), blur: 42, color: CGColor(gray: 0, alpha: 0.35))
context.setFillColor(CGColor(gray: 1, alpha: 1))
context.addPath(bolt)
context.fillPath()

let image = context.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: outputURL)
print("wrote \(outputURL.path)")
