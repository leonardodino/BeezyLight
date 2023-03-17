//
// Copyright (c) 2020 - 2022 Stephen F. Booth <me@sbooth.org>
// Part of https://github.com/sbooth/SFBAudioEngine
// MIT license
//

import Foundation
import CoreAudio
import os.log

/// A HAL audio object
public class AudioObject: CustomDebugStringConvertible {
    /// The underlying audio object ID
    public let objectID: AudioObjectID

    /// Initializes an `AudioObject` with `objectID`
    /// - precondition: `objectID` != `kAudioObjectUnknown`
    /// - parameter objectID: The HAL audio object ID
    init(_ objectID: AudioObjectID) {
        precondition(objectID != kAudioObjectUnknown)
        self.objectID = objectID
    }

    /// Registered audio object property listeners
    private var listenerBlocks = [PropertyAddress: AudioObjectPropertyListenerBlock]()

    deinit {
        for (property, listenerBlock) in listenerBlocks {
            var address = property.rawValue
            let result = AudioObjectRemovePropertyListenerBlock(objectID, &address, DispatchQueue.global(qos: .background), listenerBlock)
            if result != kAudioHardwareNoError {
                os_log(.error, log: audioObjectLog, "AudioObjectRemovePropertyListenerBlock (0x%x, %{public}@) failed: '%{public}@'", objectID, property.description, UInt32(result).fourCC)
            }
        }
    }

    /// A block called with one or more changed audio object properties
    /// - parameter changes: An array of changed property addresses
    public typealias PropertyChangeNotificationBlock = (_ changes: [PropertyAddress]) -> Void

    /// Registers `block` to be performed when `property` changes
    /// - parameter property: The property to observe
    /// - parameter block: A closure to invoke when `property` changes or `nil` to remove the previous value
    /// - throws: An error if the property listener could not be registered
    public final func whenPropertyChanges(_ property: PropertyAddress, perform block: PropertyChangeNotificationBlock?) throws {
        var address = property.rawValue

        // Remove the existing listener block, if any, for the property
        if let listenerBlock = listenerBlocks.removeValue(forKey: property) {
            let result = AudioObjectRemovePropertyListenerBlock(objectID, &address, DispatchQueue.global(qos: .background), listenerBlock)
            guard result == kAudioHardwareNoError else {
                os_log(.error, log: audioObjectLog, "AudioObjectRemovePropertyListenerBlock (0x%x, %{public}@) failed: '%{public}@'", objectID, property.description, UInt32(result).fourCC)
                let userInfo = [NSLocalizedDescriptionKey: NSLocalizedString("The listener block for the property \(property.selector) on audio object 0x\(String(objectID, radix: 16, uppercase: false)) could not be removed.", comment: "")]
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: userInfo)
            }
        }

        if let block = block {
            let listenerBlock: AudioObjectPropertyListenerBlock = { inNumberAddresses, inAddresses in
                let count = Int(inNumberAddresses)
                let addresses = UnsafeBufferPointer(start: inAddresses, count: count)
                let array = [PropertyAddress](unsafeUninitializedCapacity: count) { (buffer, initializedCount) in
                    for i in 0 ..< count {
                        buffer[i] = PropertyAddress(addresses[i])
                    }
                    initializedCount = count
                }
                block(array)
            }

            let result = AudioObjectAddPropertyListenerBlock(objectID, &address, DispatchQueue.global(qos: .background), listenerBlock)
            guard result == kAudioHardwareNoError else {
                os_log(.error, log: audioObjectLog, "AudioObjectAddPropertyListenerBlock (0x%x, %{public}@) failed: '%{public}@'", objectID, property.description, UInt32(result).fourCC)
                let userInfo = [NSLocalizedDescriptionKey: NSLocalizedString("The listener block for the property \(property.selector) on audio object 0x\(String(objectID, radix: 16, uppercase: false)) could not be added.", comment: "")]
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(result), userInfo: userInfo)
            }

            listenerBlocks[property] = listenerBlock;
        }
    }

    // A textual representation of this instance, suitable for debugging.
    public var debugDescription: String {
        return "<\(type(of: self)): 0x\(String(objectID, radix: 16, uppercase: false))>"
    }
}

extension AudioObject: Hashable {
    public static func == (lhs: AudioObject, rhs: AudioObject) -> Bool {
        return lhs.objectID == rhs.objectID
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(objectID)
    }
}

// MARK: - Scalar Properties

extension AudioObject {
    /// Returns the numeric value of `property`
    /// - note: The underlying audio object property must be backed by an equivalent native C type of `T`
    /// - parameter property: The address of the desired property
    /// - parameter type: The underlying numeric type
    /// - parameter qualifier: An optional property qualifier
    /// - parameter initialValue: An optional initial value for `outData` when calling `AudioObjectGetPropertyData`
    /// - throws: An error if `self` does not have `property` or the property value could not be retrieved
    public func getProperty<T: Numeric>(_ property: PropertyAddress, type: T.Type, qualifier: PropertyQualifier? = nil, initialValue: T = 0) throws -> T {
        return try getAudioObjectProperty(property, from: objectID, type: type, qualifier: qualifier, initialValue: initialValue)
    }

    /// Returns the Core Foundation object value of `property`
    /// - note: The underlying audio object property must be backed by a Core Foundation object and return a `CFType` with a +1 retain count
    /// - parameter property: The address of the desired property
    /// - parameter type: The underlying `CFType`
    /// - parameter qualifier: An optional property qualifier
    /// - throws: An error if `self` does not have `property` or the property value could not be retrieved
    public func getProperty<T: CFTypeRef>(_ property: PropertyAddress, type: T.Type, qualifier: PropertyQualifier? = nil) throws -> T {
        return try getAudioObjectProperty(property, from: objectID, type: type, qualifier: qualifier)
    }

    /// Returns the `AudioValueRange` value of `property`
    /// - note: The underlying audio object property must be backed by `AudioValueRange`
    /// - parameter property: The address of the desired property
    /// - throws: An error if `self` does not have `property` or the property value could not be retrieved
    public func getProperty(_ property: PropertyAddress) throws -> AudioValueRange {
        var value = AudioValueRange()
        try readAudioObjectProperty(property, from: objectID, into: &value)
        return value
    }

    /// Returns the `AudioStreamBasicDescription` value of `property`
    /// - note: The underlying audio object property must be backed by `AudioStreamBasicDescription`
    /// - parameter property: The address of the desired property
    /// - throws: An error if `self` does not have `property` or the property value could not be retrieved
    public func getProperty(_ property: PropertyAddress) throws -> AudioStreamBasicDescription {
        var value = AudioStreamBasicDescription()
        try readAudioObjectProperty(property, from: objectID, into: &value)
        return value
    }
}

// MARK: - Array Properties

extension AudioObject {
    /// Returns the array value of `property`
    /// - note: The underlying audio object property must be backed by a C array of `T`
    /// - parameter property: The address of the desired property
    /// - parameter type: The underlying array element type
    /// - parameter qualifier: An optional property qualifier
    /// - throws: An error if `self` does not have `property` or the property value could not be retrieved
    public func getProperty<T>(_ property: PropertyAddress, elementType type: T.Type, qualifier: PropertyQualifier? = nil) throws -> [T] {
        return try getAudioObjectProperty(property, from: objectID, elementType: type, qualifier: qualifier)
    }
}

// MARK: - Base Audio Object Properties

extension AudioObject {
    /// Returns the base class of the underlying HAL audio object
    /// - remark: This corresponds to the property `kAudioObjectPropertyBaseClass`
    public func baseClass() throws -> AudioClassID {
        return try getProperty(PropertyAddress(kAudioObjectPropertyBaseClass), type: AudioClassID.self)
    }

    /// Returns the class of the underlying HAL audio object
    /// - remark: This corresponds to the property `kAudioObjectPropertyClass`
    public func `class`() throws -> AudioClassID {
        return try getProperty(PropertyAddress(kAudioObjectPropertyClass), type: AudioClassID.self)
    }

    /// Returns the audio object's name
    /// - remark: This corresponds to the property `kAudioObjectPropertyName`
    public func name() throws -> String {
        return try getProperty(PropertyAddress(kAudioObjectPropertyName), type: CFString.self) as String
    }
}

// MARK: - Helpers

extension AudioObjectPropertyAddress: Hashable {
    public static func == (lhs: AudioObjectPropertyAddress, rhs: AudioObjectPropertyAddress) -> Bool {
        return lhs.mSelector == rhs.mSelector && lhs.mScope == rhs.mScope && lhs.mElement == rhs.mElement
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(mSelector)
        hasher.combine(mScope)
        hasher.combine(mElement)
    }
}

/// Returns the value of `kAudioObjectPropertyClass` for `objectID` or `0` on error
func AudioObjectClass(_ objectID: AudioObjectID) -> AudioClassID {
    do {
        var value: AudioClassID = 0
        try readAudioObjectProperty(PropertyAddress(kAudioObjectPropertyClass), from: objectID, into: &value)
        return value
    }
    catch {
        return 0
    }
}

/// Returns the value of `kAudioObjectPropertyBaseClass` for `objectID` or `0` on error
func AudioObjectBaseClass(_ objectID: AudioObjectID) -> AudioClassID {
    do {
        var value: AudioClassID = 0
        try readAudioObjectProperty(PropertyAddress(kAudioObjectPropertyBaseClass), from: objectID, into: &value)
        return value
    }
    catch {
        return 0
    }
}

/// The log for `AudioObject` and subclasses
let audioObjectLog = OSLog(subsystem: "org.sbooth.AudioEngine", category: "AudioObject")

// MARK: - AudioObject Creation

// Class clusters in the Objective-C sense can't be implemented in Swift
// since Swift initializers don't return a value.
//
// Ideally `AudioObject.init(_ objectID: AudioObjectID)` would initialize and return
// the appropriate subclass, but since that isn't possible,
// `AudioObject.init(_ objectID: AudioObjectID)` has internal access and
// the factory method `AudioObject.make(_ objectID: AudioObjectID)` is public.

extension AudioObject {
    /// Creates and returns an initialized `AudioObject`
    ///
    /// Whenever possible this will return a specialized subclass exposing additional functionality
    /// - precondition: `objectID` != `kAudioObjectUnknown`
    /// - parameter objectID: The audio object ID
    public class func make(_ objectID: AudioObjectID) -> AudioObject {
        precondition(objectID != kAudioObjectUnknown)

        if objectID == kAudioObjectSystemObject {
            return AudioSystemObject.instance
        }

        let objectClass = AudioObjectClass(objectID)
        let objectBaseClass = AudioObjectBaseClass(objectID)

        switch objectBaseClass {
        case kAudioObjectClassID:
            switch objectClass {
            case kAudioDeviceClassID: return AudioDevice(objectID)
            default:
                os_log(.debug, log: audioObjectLog, "Unknown audio object class '%{public}@'", objectClass.fourCC)
                return AudioObject(objectID)
            }

        default:
            os_log(.debug, log: audioObjectLog, "Unknown audio object base class '%{public}@'", objectClass.fourCC)
            return AudioObject(objectID)
        }
    }
}

// MARK: -

/// A thin wrapper around a HAL audio object property selector for a specific `AudioObject` subclass
public struct AudioObjectSelector<T: AudioObject> {
    /// The underlying `AudioObjectPropertySelector` value
    let rawValue: AudioObjectPropertySelector

    /// Creates a new instance with the specified value
    /// - parameter value: The value to use for the new instance
    init(_ value: AudioObjectPropertySelector) {
        self.rawValue = value
    }
}

extension AudioObjectSelector: CustomStringConvertible {
    public var description: String {
        return "\(type(of: T.self)): '\(rawValue.fourCC)'"
    }
}
