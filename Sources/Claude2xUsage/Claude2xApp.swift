import SwiftUI
import AppKit
import ServiceManagement

@Observable
final class StatusModel {
    var status = UsageStatus.current()
    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.status = UsageStatus.current()
        }
    }
}

enum MascotIcon {
    private static let mascotHeight: CGFloat = 18

    static func load() -> NSImage? {
        // 1. Bundle Resources (packaged .app)
        if let url = Bundle.main.url(forResource: "mascot", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // 2. Next to the executable (swift run / dev builds)
        let candidates = [
            Bundle.main.bundlePath + "/../mascot.png",
            FileManager.default.currentDirectoryPath + "/mascot.png",
            (#file as NSString).deletingLastPathComponent + "/../../../mascot.png"
        ]
        for path in candidates {
            let resolved = (path as NSString).standardizingPath
            if let img = NSImage(contentsOfFile: resolved) {
                return img
            }
        }
        return nil
    }

    static func menuBarImage(grayscale: Bool) -> NSImage {
        guard let original = load() else {
            // Fallback: return a simple text-based image
            let fallback = NSImage(size: NSSize(width: 18, height: 18))
            return fallback
        }

        let aspectRatio = original.size.width / original.size.height
        let size = NSSize(width: mascotHeight * aspectRatio, height: mascotHeight)

        let result = NSImage(size: size, flipped: false) { rect in
            if grayscale {
                // Draw grayscale + dimmed for peak hours
                guard let tiffData = original.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let ciImage = CIImage(bitmapImageRep: bitmap) else {
                    original.draw(in: rect)
                    return true
                }

                let filter = CIFilter(name: "CIColorMonochrome")!
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(CIColor(red: 0.6, green: 0.6, blue: 0.6), forKey: "inputColor")
                filter.setValue(1.0, forKey: "inputIntensity")

                if let output = filter.outputImage {
                    let context = CIContext()
                    let cgRect = CGRect(origin: .zero, size: original.size)
                    if let cgImage = context.createCGImage(output, from: cgRect) {
                        let grayImage = NSImage(cgImage: cgImage, size: original.size)
                        grayImage.draw(in: rect)
                        return true
                    }
                }
                original.draw(in: rect)
            } else {
                // Full color for 2× mode
                original.draw(in: rect)
            }
            return true
        }

        result.isTemplate = false
        return result
    }
}

@main
struct Claude2xApp: App {
    @State private var model = StatusModel()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some Scene {
        MenuBarExtra {
            Text(model.status.menuBarText)
                .font(.headline)

            Text(model.status.reason)
                .font(.caption)

            Text("PT: \(model.status.ptTime)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.status.nextChangeInMinutes > 0 {
                let hours = model.status.nextChangeInMinutes / 60
                let mins = model.status.nextChangeInMinutes % 60
                Text("Next change in \(hours)h \(mins)m")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            Toggle("Launch at Login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            let img = MascotIcon.menuBarImage(grayscale: model.status.status == .normal)
            Image(nsImage: img)
        }
    }
}
