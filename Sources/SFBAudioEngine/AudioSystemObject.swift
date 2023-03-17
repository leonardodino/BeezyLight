//
// Copyright (c) 2020 - 2021 Stephen F. Booth <me@sbooth.org>
// Part of https://github.com/sbooth/SFBAudioEngine
// MIT license
//

import Foundation
import CoreAudio

/// The HAL audio system object
///
/// This class has a single scope (`kAudioObjectPropertyScopeGlobal`) and a single element (`kAudioObjectPropertyElementMain`)
/// - remark: This class correponds to the object with id `kAudioObjectSystemObject` and class `kAudioSystemObjectClassID`
public class AudioSystemObject: AudioObject {
    /// The singleton audio system object
    public static var instance = AudioSystemObject()

    @available(*, unavailable, message: "Use instance instead")
    private override init(_ objectID: AudioObjectID) {
        fatalError()
    }

    /// Initializes an `AudioSystemObject` with the`kAudioObjectSystemObject` object ID
    private init() {
        super.init(AudioObjectID(kAudioObjectSystemObject))
    }
}

extension AudioSystemObject {
    /// Returns the `AudioObjectID` for the audio device with `uid` or `nil` if unknown
    /// - remark: This corresponds to the property `kAudioHardwarePropertyTranslateUIDToDevice`
    /// - parameter uid: The UID of the desired device
    public func deviceID(forUID uid: String) throws -> AudioObjectID? {
        var qualifier = uid as CFString
        let objectID = try getProperty(PropertyAddress(kAudioHardwarePropertyTranslateUIDToDevice), type: AudioObjectID.self, qualifier: PropertyQualifier(&qualifier))
        guard objectID != kAudioObjectUnknown else {
            return nil
        }
        return objectID
    }
}

extension AudioSystemObject {
    /// Registers `block` to be performed when `selector` changes
    /// - parameter selector: The selector of the desired property
    /// - parameter block: A closure to invoke when the property changes or `nil` to remove the previous value
    /// - throws: An error if the property listener could not be registered
    public func whenSelectorChanges(_ selector: AudioObjectSelector<AudioSystemObject>, perform block: PropertyChangeNotificationBlock?) throws {
        try whenPropertyChanges(PropertyAddress(PropertySelector(selector.rawValue)), perform: block)
    }
}

extension AudioObjectSelector where T == AudioSystemObject {
    /// The property selector `kAudioHardwarePropertyDevices`
    public static let devices = AudioObjectSelector(kAudioHardwarePropertyDevices)
}
