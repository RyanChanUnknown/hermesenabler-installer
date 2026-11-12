import AppKit

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()

// 圆角底板（Apple 风格：圆角约 22.37%）
let inset: CGFloat = 44
let rect = NSRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2)
let plate = NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200)
let grad = NSGradient(colors: [
    NSColor(calibratedRed: 0.16, green: 0.47, blue: 0.95, alpha: 1),
    NSColor(calibratedRed: 0.05, green: 0.20, blue: 0.62, alpha: 1)
])
grad?.draw(in: plate, angle: -90)

// SF Symbol 手表 + 电波
let cfg = NSImage.SymbolConfiguration(pointSize: 470, weight: .medium)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let sym = NSImage(systemSymbolName: "applewatch.radiowaves.left.and.right",
                     accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
    let sz = sym.size
    let scale = min((S * 0.62) / sz.width, (S * 0.62) / sz.height)
    let w = sz.width * scale, h = sz.height * scale
    sym.draw(in: NSRect(x: (S - w)/2, y: (S - h)/2, width: w, height: h))
}

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("render failed")
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/icon.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
