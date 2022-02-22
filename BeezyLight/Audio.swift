//
//  MicUtils.swift
//  micSwitch
//
//  Created by dstd on 13/11/2017.
//  Copyright © 2017 Denis Stanishevskiy. All rights reserved.
//
//  https://github.com/dstd/micSwitch/blob/master/micSwitch/Classes/AudioUtils.swift
//

import CoreAudio
import Foundation

struct AudioObjectAddress {
    static var inputDevice = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    static var deviceName = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    static var isRunning = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
}

class Audio {
    static let shared = Audio()
    typealias DeviceStateListener = () -> Void

    var inputDevice: AudioDeviceID?
    var inputDeviceName: String? {
        guard let deviceId = inputDevice else { return nil }
        return Self.nameOfDevice(id: deviceId)
    }

    var isRunning: Bool {
        guard let inputDevice = inputDevice else { return false }

        var value: UInt32 = 0
        var size = UInt32(MemoryLayout.size(ofValue: value))

        let error = AudioObjectGetPropertyData(
            inputDevice, &AudioObjectAddress.isRunning,
            0, nil,
            &size, &value
        )

        return error == kAudioHardwareNoError ? value == 1 : false
    }

    func addDeviceStateListener(listener: @escaping Audio.DeviceStateListener) -> Int {
        let listenerId = nextListenerId
        nextListenerId += 1
        listeners[listenerId] = listener
        listener()

        return listenerId
    }

    func removeDeviceStateListener(listenerId: Int) {
        listeners.removeValue(forKey: listenerId)
    }

    private static func getInputDevice() -> AudioDeviceID? {
        var deviceId = kAudioObjectUnknown
        var deviceIdSize = UInt32(MemoryLayout.size(ofValue: deviceId))

        let error = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &AudioObjectAddress.inputDevice,
            0, nil,
            &deviceIdSize, &deviceId
        )

        return error == kAudioHardwareNoError && deviceId != kAudioObjectUnknown ? deviceId : nil
    }

    private static func nameOfDevice(id deviceId: AudioDeviceID) -> String? {
        var name = "" as CFString
        var nameSize = UInt32(MemoryLayout.size(ofValue: name))

        let error = AudioObjectGetPropertyData(
            deviceId,
            &AudioObjectAddress.deviceName,
            0, nil,
            &nameSize, &name
        )

        return error == kAudioHardwareNoError ? name as String : nil
    }

    private func notifyListeners() {
        listeners.forEach { $0.value() }
    }

    private func registerDeviceStateListener() {
        guard let inputDevice = inputDevice else { return }
        AudioObjectAddPropertyListenerBlock(inputDevice, &AudioObjectAddress.isRunning, DispatchQueue.main, deviceStateListener)

        listeners.forEach { $0.value() }
    }

    private func unregisterDeviceStateListener() {
        guard let inputDevice = inputDevice else { return }
        AudioObjectRemovePropertyListenerBlock(inputDevice, &AudioObjectAddress.isRunning, DispatchQueue.main, deviceStateListener)
    }

    private func registerDefaultMicListener() {
        let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &AudioObjectAddress.inputDevice, DispatchQueue.main, defaultMicListener)
        print("#mic added listener to \(inputDevice ?? 11_111_111) = \(status)")
    }

    private func unregisterDefaultMicListener() {
        AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &AudioObjectAddress.inputDevice, DispatchQueue.main, defaultMicListener)
    }

    private func updateMicListeners() {
        unregisterDeviceStateListener()
        inputDevice = Self.getInputDevice()
        registerDeviceStateListener()
    }

    private lazy var defaultMicListener: AudioObjectPropertyListenerBlock = { _, _ in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.updateMicListeners() }
    }

    private lazy var deviceStateListener: AudioObjectPropertyListenerBlock = { _, _ in
        DispatchQueue.main.async { self.notifyListeners() }
    }

    private var listeners = [Int: Audio.DeviceStateListener]()
    private var nextListenerId: Int = 0

    init() {
        inputDevice = Self.getInputDevice()
        registerDeviceStateListener()
        registerDefaultMicListener()
    }
}
