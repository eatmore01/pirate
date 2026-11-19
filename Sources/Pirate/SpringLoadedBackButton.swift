import AppKit

final class SpringLoadedBackButton: NSButton {
    var springDelay: TimeInterval = 1
    var canSpring: (() -> Bool)?
    var springHandler: (() -> Void)?

    private var springTimer: Timer?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        armSpring()
        return []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        disarmSpring()
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        disarmSpring()
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        false
    }

    private func armSpring() {
        disarmSpring()
        guard canSpring?() ?? false else { return }
        contentTintColor = Theme.accent
        let timer = Timer(
            timeInterval: springDelay,
            target: self,
            selector: #selector(springTimerFired),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .eventTracking)
        RunLoop.main.add(timer, forMode: .default)
        springTimer = timer
    }

    @objc private func springTimerFired() {
        guard canSpring?() ?? false else {
            disarmSpring()
            return
        }
        springHandler?()
    }

    private func disarmSpring() {
        springTimer?.invalidate()
        springTimer = nil
        contentTintColor = nil
    }
}
