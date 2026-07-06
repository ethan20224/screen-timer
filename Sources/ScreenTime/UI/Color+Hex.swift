import SwiftUI

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        let native = NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)
        let r = Int(native.redComponent * 255)
        let g = Int(native.greenComponent * 255)
        let b = Int(native.blueComponent * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
