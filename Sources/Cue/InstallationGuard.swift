import AppKit
import Darwin

// Watch only Cue-owned bundle files. Opening protected ancestor directories
// can block startup behind TCC. Ancestor relocation is checked on activation,
// menu opening, and BEFORE a key is consumed; no polling timer is needed.
final class InstallationGuard {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var stopped = false
    private let bundleURL: URL
    private let executable: URL?
    private let removed: () -> Void
    init(bundleURL: URL = Bundle.main.bundleURL, removed: @escaping () -> Void) {
        self.bundleURL = bundleURL; self.removed = removed
        executable = Bundle(url: bundleURL)?.executableURL
        guard bundleURL.pathExtension == "app" else { return }
        let urls = [executable, executable?.deletingLastPathComponent(), bundleURL.appendingPathComponent("Contents"), bundleURL].compactMap { $0 }
        for url in urls {
            let fd = open(url.path, O_EVTONLY)
            guard fd >= 0 else { continue }
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.delete, .rename, .revoke], queue: .main)
            source.setEventHandler { [weak self] in _ = self?.verifyNow() }
            source.setCancelHandler { Darwin.close(fd) }
            sources.append(source); source.resume()
        }
    }
    @discardableResult func verifyNow() -> Bool {
        guard !stopped else { return false }
        let valid = FileManager.default.fileExists(atPath: bundleURL.path) && executable.map { FileManager.default.fileExists(atPath: $0.path) } == true
        if !valid { stopped = true; removed() }
        return valid
    }
    deinit { sources.forEach { $0.cancel() } }
}
