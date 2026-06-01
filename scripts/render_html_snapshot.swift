import AppKit
import Foundation
import WebKit

final class SnapshotDelegate: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let outputURL: URL
    private let done: () -> Void

    init(webView: WKWebView, outputURL: URL, done: @escaping () -> Void) {
        self.webView = webView
        self.outputURL = outputURL
        self.done = done
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let config = WKSnapshotConfiguration()
            config.rect = CGRect(origin: .zero, size: self.webView.bounds.size)
            self.webView.takeSnapshot(with: config) { image, error in
                if let error {
                    fputs("snapshot error: \(error)\n", stderr)
                    NSApplication.shared.terminate(nil)
                    return
                }
                guard let image,
                      let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:])
                else {
                    fputs("snapshot image conversion failed\n", stderr)
                    NSApplication.shared.terminate(nil)
                    return
                }
                do {
                    try png.write(to: self.outputURL)
                    self.done()
                } catch {
                    fputs("write error: \(error)\n", stderr)
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}

let args = CommandLine.arguments
guard args.count == 5 else {
    fputs("usage: render_html_snapshot.swift <url> <width> <height> <output>\n", stderr)
    exit(2)
}

guard let width = Double(args[2]), let height = Double(args[3]) else {
    fputs("width/height must be numbers\n", stderr)
    exit(2)
}

let pageURL = URL(string: args[1])!
let outputURL = URL(fileURLWithPath: args[4])

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let config = WKWebViewConfiguration()
let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: height), configuration: config)
webView.setValue(false, forKey: "drawsBackground")

let delegate = SnapshotDelegate(webView: webView, outputURL: outputURL) {
    print(outputURL.path)
    NSApplication.shared.terminate(nil)
}

webView.navigationDelegate = delegate
_ = webView.load(URLRequest(url: pageURL))

RunLoop.main.run()
