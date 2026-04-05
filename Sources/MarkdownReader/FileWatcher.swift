import Foundation

// Watches a file for write events using GCD DispatchSource
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private let callback: () -> Void
    private var fileDescriptor: Int32 = -1

    init(path: String, callback: @escaping () -> Void) {
        self.callback = callback
        startWatching(path: path)
    }

    private func startWatching(path: String) {
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename],
            queue: .main
        )

        src.setEventHandler { [weak self] in
            self?.callback()
        }

        src.setCancelHandler { [weak self] in
            guard let self = self else { return }
            if self.fileDescriptor >= 0 {
                close(self.fileDescriptor)
                self.fileDescriptor = -1
            }
        }

        src.resume()
        self.source = src
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
