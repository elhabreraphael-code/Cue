import AppKit
import Darwin

// Event-driven removal detection: no repeating timer and no helper process.
// Ancestors are watched for rename/deletion, so moving the containing folder
// also releases Cue. No .write watch on broad folders (unrelated writes stay quiet).
final class InstallationGuard {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var stopped = false
    init(bundleURL: URL = Bundle.main.bundleURL, removed: @escaping () -> Void) {
        guard bundleURL.pathExtension == "app" else { return }
        let executable = Bundle(url: bundleURL)?.executableURL
        let verify: () -> Void = { [weak self] in
            guard let self, !self.stopped else { return }
            let valid = FileManager.default.fileExists(atPath: bundleURL.path) && executable.map { FileManager.default.fileExists(atPath: $0.path) } == true
            if !valid { self.stopped = true; removed() }
        }
        var urls: [URL] = []
        var ancestor = executable ?? bundleURL
        while ancestor.path != "/" {
            urls.append(ancestor)
            ancestor = ancestor.deletingLastPathComponent()
        }
        for url in urls {
            let fd = open(url.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.delete, .rename, .revoke], queue: .main)
            source.setEventHandler(handler: verify)
            source.setCancelHandler { Darwin.close(fd) }
            sources.append(source); source.resume()
        }
    }
    deinit { sources.forEach { $0.cancel() } }
}
