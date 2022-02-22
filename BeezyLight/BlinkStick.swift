import Foundation
import IOKit.hid

private let matchingCallback: IOHIDDeviceCallback = { context, result, _, device in
    guard result == kIOReturnSuccess else { return }
    guard let pointer = context else { return }
    BlinkStick.getInstance(pointer).onConnected(device)
}

private let removalCallback: IOHIDDeviceCallback = { context, _, _, _ in
    guard let pointer = context else { return }
    BlinkStick.getInstance(pointer).onDisconnected()
}

class BlinkStick {
    private let vendorId = 0x20A0
    private let productId = 0x41E5
    private let thread = DispatchQueue(label: "\(Bundle.main.bundleIdentifier ?? "unknown").\(String(describing: BlinkStick.self)).thread")

    private var device: IOHIDDevice?
    private var data: [UInt8] = [1, 0, 0, 0]

    fileprivate static func getInstance(_ pointer: UnsafeRawPointer) -> BlinkStick {
        return Unmanaged<BlinkStick>.fromOpaque(pointer).takeUnretainedValue()
    }

    func setColor(r: UInt8, g: UInt8, b: UInt8) {
        data = [1, r, g, b] // if device is not connected, save value for later
        guard let device = device else { return }
        IOHIDDeviceSetReport(device, kIOHIDReportTypeFeature, CFIndex(data[0]), data, data.count)
    }

    func onConnected(_ deviceRef: IOHIDDevice) {
        device = deviceRef
        setColor(r: data[0], g: data[1], b: data[2])
    }

    func onDisconnected() {
        device = nil
    }

    init() {
        let pointer = Unmanaged.passRetained(self).toOpaque()
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        IOHIDManagerSetDeviceMatching(
            manager,
            [kIOHIDProductIDKey: productId, kIOHIDVendorIDKey: vendorId] as CFDictionary
        )

        thread.async {
            IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerRegisterDeviceMatchingCallback(manager, matchingCallback, pointer)
            IOHIDManagerRegisterDeviceRemovalCallback(manager, removalCallback, pointer)
            IOHIDManagerOpen(manager, 0)
            print()
            RunLoop.current.run()
        }
    }
}
