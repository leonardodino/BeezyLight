import Foundation

class Debouncer {
    private var callback: () -> Void
    private var delay: Double
    private weak var timer: Timer?

    init(delay: Double, callback: @escaping (() -> Void)) {
        self.delay = delay
        self.callback = callback
    }

    func callAsFunction() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in self.callback() }
    }
}
