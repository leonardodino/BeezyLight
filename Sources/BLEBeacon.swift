import Foundation
import AppKit
import CoreBluetooth

fileprivate extension UUID {
    var data: Data { withUnsafeBytes(of: self.uuid, { Data($0) }) }
}

final class BLEBeacon: NSObject, Identifiable {
    let id: UUID
    private let callback: (CBManagerState) -> Void
    private var emitter: CBPeripheralManager?
    private var isAdvertising = false
    private var wasAdvertisingBeforeSleep = false
    
    func start() {
        guard let emitter, isAdvertising != true else { return }
        emitter.startAdvertising(advertisementData)
    }
    
    func stop() {
        guard let emitter, emitter.isAdvertising else { return }
        emitter.stopAdvertising()
        isAdvertising = false
    }
    
    init(_ uuid: UUID, callback: @escaping ((CBManagerState) -> Void)) {
        self.id = uuid
        self.callback = callback
        super.init()
        emitter = CBPeripheralManager(delegate: self, queue: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
    }
    deinit {
        stop()
    }
}

extension BLEBeacon {
    @objc
    func willSleep(_: Notification) {
        if let emitter, emitter.isAdvertising {
            wasAdvertisingBeforeSleep = true
            stop()
        } else {
            wasAdvertisingBeforeSleep = false
        }
    }
    
    @objc
    func didWake(_: Notification) {
        guard wasAdvertisingBeforeSleep else { return }
        start()
    }
}

extension BLEBeacon {
    var advertisementData: [String: Data] {
        let major: UInt16 = 0
        let minor: UInt16 = 0
        let measuredPower: Int8 = -59
        
        var advBytes = Data(capacity: 21)
        advBytes.append(id.data)
        advBytes.append(contentsOf: [
            UInt8((major >> 8)),
            UInt8(major & 255),
            
            UInt8((minor >> 8) & 255),
            UInt8(minor & 255),
            
            UInt8(bitPattern: measuredPower),
        ])
        
        return ["kCBAdvDataAppleBeaconKey": advBytes]
    }
}


extension BLEBeacon: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        callback(state)
    }
    
    
    func peripheralManagerDidStartAdvertising(_: CBPeripheralManager, error _: Error?) {
        if let emitter, emitter.isAdvertising { isAdvertising = true }
    }
    
    var state: CBManagerState { emitter?.state ?? .unknown }
    
    var status: String {
        switch state {
            case .poweredOff: return "powered off"
            case .poweredOn: return "powered on"
            case .unauthorized: return "not authorized"
            case .unknown: return "unknown"
            case .resetting: return "resetting"
            case .unsupported: return "unsupported"
            @unknown default: return "unknown"
        }
    }
}
