import Foundation
import IOKit.ps

/// When the big first pass (backfill) may run: with the Mac cool (thermal state nominal or fair), not in Low Power
/// Mode. When indexing on battery is off, all indexing and Mail synchronization wait for AC power.
///
/// Event-driven: power-source, thermal and Low Power Mode changes call `onChange`; nothing polls.
final class PowerPolicy {
    private var indexOnBattery: Bool
    private let onChange: (String?, String?) -> Void
    private let hasACPower: () -> Bool
    nonisolated(unsafe) private var powerSource: CFRunLoopSource?   // main thread, and deinit
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []
    private(set) var blocker: String?
    private(set) var updateBlocker: String?

    /// `onChange` receives the backfill reason and the hard power gate, each nil when allowed.
    init(indexOnBattery: Bool, hasACPower: @escaping () -> Bool = { PowerPolicy.onACPower() },
         onChange: @escaping (String?, String?) -> Void) {
        self.indexOnBattery = indexOnBattery
        self.hasACPower = hasACPower
        self.onChange = onChange
        let onAC = hasACPower()
        blocker = Self.backfillBlocker(indexOnBattery: indexOnBattery, onACPower: onAC)
        updateBlocker = Self.updateBlocker(indexOnBattery: indexOnBattery, onACPower: onAC)

        let me = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource(powerSourceChanged, me)?.takeRetainedValue() {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
            powerSource = source
        }
        for name in [ProcessInfo.thermalStateDidChangeNotification, Notification.Name.NSProcessInfoPowerStateDidChange] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) {
                [weak self] _ in
                MainActor.assumeIsolated { self?.reevaluate() }
            })
        }
    }

    deinit {
        if let powerSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), powerSource, .defaultMode) }
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// The "index on battery too" setting changed.
    func setIndexOnBattery(_ on: Bool) {
        indexOnBattery = on
        reevaluate()
    }

    func reevaluate() {
        let onAC = hasACPower()
        let now = Self.backfillBlocker(indexOnBattery: indexOnBattery, onACPower: onAC)
        let update = Self.updateBlocker(indexOnBattery: indexOnBattery, onACPower: onAC)
        guard now != blocker || update != updateBlocker else { return }
        blocker = now
        updateBlocker = update
        log("power: backfill \(now.map { "waits (\($0))" } ?? "may run")")
        onChange(now, update)
    }

    nonisolated static func updateBlocker(indexOnBattery: Bool, onACPower: Bool) -> String? {
        !indexOnBattery && !onACPower ? "正在使用电池，接通电源后继续" : nil
    }

    nonisolated static func backfillBlocker(indexOnBattery: Bool, onACPower: Bool) -> String? {
        let info = ProcessInfo.processInfo
        if info.isLowPowerModeEnabled { return "低电量模式" }
        switch info.thermalState {
        case .serious, .critical: return "Mac 温度较高"
        default: break
        }
        if !indexOnBattery, !onACPower { return "正在使用电池" }
        return nil
    }

    nonisolated static func onACPower() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(snapshot)?.takeUnretainedValue() as String?
        else { return true }   // no power-source info: a desktop Mac
        return type == kIOPMACPowerKey
    }
}

/// IOKit calls this on the main run loop when the power source changes.
private nonisolated func powerSourceChanged(_ context: UnsafeMutableRawPointer?) {
    guard let context else { return }
    let address = UInt(bitPattern: context)
    MainActor.assumeIsolated {
        Unmanaged<PowerPolicy>.fromOpaque(UnsafeRawPointer(bitPattern: address)!).takeUnretainedValue().reevaluate()
    }
}
