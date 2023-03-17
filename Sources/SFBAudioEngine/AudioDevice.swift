//
// Copyright (c) 2020 - 2022 Stephen F. Booth <me@sbooth.org>
// Part of https://github.com/sbooth/SFBAudioEngine
// MIT license
//

import Foundation
import CoreAudio

/// A HAL audio device object
///
/// This class has four scopes (`kAudioObjectPropertyScopeGlobal`, `kAudioObjectPropertyScopeInput`, `kAudioObjectPropertyScopeOutput`, and `kAudioObjectPropertyScopePlayThrough`), a main element (`kAudioObjectPropertyElementMain`), and an element for each channel in each stream
/// - remark: This class correponds to objects with base class `kAudioDeviceClassID`
public class AudioDevice: AudioObject {
    /// Returns the available audio devices
    /// - remark: This corresponds to the property`kAudioHardwarePropertyDevices` on `kAudioObjectSystemObject`
    public class func devices() throws -> [AudioDevice] {
        try AudioSystemObject.instance.getProperty(PropertyAddress(kAudioHardwarePropertyDevices), elementType: AudioObjectID.self).map { AudioObject.make($0) as! AudioDevice }
    }

    /// Returns an initialized `AudioDevice` with `uid` or `nil` if unknown
    /// - remark: This corresponds to the property `kAudioHardwarePropertyTranslateUIDToDevice` on `kAudioObjectSystemObject`
    /// - parameter uid: The UID of the desired device
    public class func makeDevice(forUID uid: String) throws -> AudioDevice? {
        guard let objectID = try AudioSystemObject.instance.deviceID(forUID: uid) else {
            return nil
        }
        return (AudioObject.make(objectID) as! AudioDevice)
    }

    /// Returns `true` if the device supports input
    ///
    /// - note: A device supports input if it has buffers in `kAudioObjectPropertyScopeInput` for the property `kAudioDevicePropertyStreamConfiguration`
    public func supportsInput() throws -> Bool {
        try streamConfiguration(inScope: .input).numberBuffers > 0
    }

    // A textual representation of this instance, suitable for debugging.
    public override var debugDescription: String {
        do {
            return "<\(type(of: self)): 0x\(String(objectID, radix: 16, uppercase: false)) \"\(try name())\">"
        }
        catch {
            return super.debugDescription
        }
    }
}

// MARK: - Audio Device Base Properties

// MARK: - Audio Device Properties

extension AudioDevice {
    /// Returns any error codes loading the driver plugin
    /// - remark: This corresponds to the property `kAudioDevicePropertyPlugIn`
    public func plugIn() throws -> OSStatus {
        return try getProperty(PropertyAddress(kAudioDevicePropertyPlugIn), type: OSStatus.self)
    }

    /// Returns `true` if the device is running somewhere
    /// - remark: This corresponds to the property `kAudioDevicePropertyDeviceIsRunningSomewhere`
    public func isRunningSomewhere() throws -> Bool {
        return try getProperty(PropertyAddress(kAudioDevicePropertyDeviceIsRunningSomewhere), type: UInt32.self) != 0
    }

    /// Returns the stream configuration
    /// - remark: This corresponds to the property `kAudioDevicePropertyStreamConfiguration`
    public func streamConfiguration(inScope scope: PropertyScope) throws -> AudioBufferListWrapper {
        let property = PropertyAddress(PropertySelector(kAudioDevicePropertyStreamConfiguration), scope: scope)
        let dataSize = try audioObjectPropertySize(property, from: objectID)
        let mem = UnsafeMutablePointer<UInt8>.allocate(capacity: dataSize)
        do {
            try readAudioObjectProperty(property, from: objectID, into: mem, size: dataSize)
        } catch let error {
            mem.deallocate()
            throw error
        }
        return AudioBufferListWrapper(mem)
    }
}

// MARK: - Audio Device Properties Implemented by Audio Controls

extension AudioDevice {
    /// Registers `block` to be performed when `selector` in `scope` on `element` changes
    /// - parameter selector: The selector of the desired property
    /// - parameter scope: The desired scope
    /// - parameter element: The desired element
    /// - parameter block: A closure to invoke when the property changes or `nil` to remove the previous value
    /// - throws: An error if the property listener could not be registered
    public func whenSelectorChanges(_ selector: AudioObjectSelector<AudioDevice>, inScope scope: PropertyScope = .global, onElement element: PropertyElement = .main, perform block: PropertyChangeNotificationBlock?) throws {
        try whenPropertyChanges(PropertyAddress(PropertySelector(selector.rawValue), scope: scope, element: element), perform: block)
    }
}

extension AudioObjectSelector where T == AudioDevice {
    /// The property selector `kAudioDevicePropertyDeviceHasChanged`
    // public static let hasChanged = AudioObjectSelector(kAudioDevicePropertyDeviceHasChanged)
    /// The property selector `kAudioDevicePropertyDeviceIsRunningSomewhere`
    public static let isRunningSomewhere = AudioObjectSelector(kAudioDevicePropertyDeviceIsRunningSomewhere)
}
