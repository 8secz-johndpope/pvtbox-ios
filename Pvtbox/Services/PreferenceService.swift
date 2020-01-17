/**
*  
*  Pvtbox. Fast and secure file transfer & sync directly across your devices. 
*  Copyright © 2020  Pb Private Cloud Solutions Ltd. 
*  
*  Licensed under the Apache License, Version 2.0 (the "License");
*  you may not use this file except in compliance with the License.
*  You may obtain a copy of the License at
*     http://www.apache.org/licenses/LICENSE-2.0
*  
*  Unless required by applicable law or agreed to in writing, software
*  distributed under the License is distributed on an "AS IS" BASIS,
*  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*  See the License for the specific language governing permissions and
*  limitations under the License.
*  
**/

import Foundation
import SwiftKeychainWrapper

class PreferenceService {
    static func clear() {
        KeychainWrapper.standard.removeAllKeys()
    }
    
    static var firstLaunch: Bool {
        set {
            UserDefaults.init(suiteName: "persistent")?.set(newValue, forKey: "firstLaunch")
        }
        get {
            return UserDefaults.init(suiteName: "persistent")?.value(forKey: "firstLaunch") as! Bool? ?? true
        }
    }

    static var isLoggedIn: Bool? {
        set {
            if newValue == nil {
                KeychainWrapper.standard.removeObject(forKey: "isLoggedIn")
            } else {
                KeychainWrapper.standard.set(newValue!, forKey: "isLoggedIn")
            }
        }
        get {
            return KeychainWrapper.standard.bool(forKey: "isLoggedIn")
        }
    }
    
    static var email: String? {
        set {
            if newValue == nil {
                KeychainWrapper.standard.removeObject(forKey: "email")
            } else {
                KeychainWrapper.standard.set(newValue!, forKey: "email")
            }
        }
        get {
            return KeychainWrapper.standard.string(forKey: "email")
        }
    }
    
    static var nodeSign: String? {
        set {
            if newValue == nil {
                KeychainWrapper.standard.removeObject(forKey: "nodeSign")
            } else {
                KeychainWrapper.standard.set(newValue!, forKey: "nodeSign")
            }
        }
        get {
            return KeychainWrapper.standard.string(forKey: "nodeSign")
        }
    }
    
    static var nodeHash: String? {
        set {
            if newValue == nil {
                KeychainWrapper.standard.removeObject(forKey: "nodeHash")
            } else {
                KeychainWrapper.standard.set(newValue!, forKey: "nodeHash")
            }
        }
        get {
            return KeychainWrapper.standard.string(forKey: "nodeHash")
        }
    }
    
    static var userHash: String? {
        set {
            if newValue == nil {
                KeychainWrapper.standard.removeObject(forKey: "userHash")
            } else {
                KeychainWrapper.standard.set(newValue!, forKey: "userHash")
            }
        }
        get {
            return KeychainWrapper.standard.string(forKey: "userHash")
        }
    }
    
    static var license: String {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "license")
        }
        get {
            return KeychainWrapper.standard.string(forKey: "license") ?? Const.unknownLicense
        }
    }
    
    static var mediaDownloadEnabled: Bool {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "mediaDownloadEnabled")
        }
        get {
            return KeychainWrapper.standard.bool(forKey: "mediaDownloadEnabled") ?? false
        }
    }
    
    static var convertHeicEnabled: Bool {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "convertHeicEnabled")
        }
        get {
            return KeychainWrapper.standard.bool(forKey: "convertHeicEnabled") ?? false
        }
    }
    
    static var importCameraEnabled: Bool {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "importCameraEnabled")
        }
        get {
            return KeychainWrapper.standard.bool(forKey: "importCameraEnabled") ?? false
        }
    }
    
    static var sendStatisticEnabled: Bool {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "sendStatisticEnabled")
        }
        get {
            return KeychainWrapper.standard.bool(forKey: "sendStatisticEnabled") ?? true
        }
    }
    
    static var cellularEnabled: Bool {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "cellularEnabled")
        }
        get {
            return KeychainWrapper.standard.bool(forKey: "cellularEnabled") ?? true
        }
    }
    
    static var sortingByName: Bool {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "sortingByName")
        }
        get {
            return KeychainWrapper.standard.bool(forKey: "sortingByName") ?? false
        }
    }
    
    static var cameraFolderUuid: String? {
        set {
            if newValue == nil {
                KeychainWrapper.standard.removeObject(forKey: "cameraFolderUuid")
            } else {
                KeychainWrapper.standard.set(newValue!, forKey: "cameraFolderUuid")
            }
        }
        get {
            return KeychainWrapper.standard.string(forKey: "cameraFolderUuid")
        }
    }
    
    static var cameraLastPhotoCreationDate: Date? {
        set {
            if newValue == nil {
                KeychainWrapper.standard.removeObject(forKey: "cameraLastPhotoCreationDate")
            } else {
                KeychainWrapper.standard.set(newValue!.timeIntervalSince1970, forKey: "cameraLastPhotoCreationDate")
            }
        }
        get {
            return Date(timeIntervalSince1970: KeychainWrapper.standard.double(
                forKey: "cameraLastPhotoCreationDate") ?? 0)
        }
    }
    
    static var askSetPasscode: Bool {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "askSetPasscode")
        }
        get {
            return KeychainWrapper.standard.bool(
                forKey: "askSetPasscode") ?? true
        }
    }
    
    static var isSelfHosted: Bool {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "selfHosted")
        }
        get {
            return KeychainWrapper.standard.bool(
                forKey: "selfHosted") ?? false
        }
    }
    
    static var host: String {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "host")
        }
        get {
            return KeychainWrapper.standard.string(forKey: "host") ?? Const.serverAddress
        }
    }
    
    static var currentHost: String {
        set {
            KeychainWrapper.standard.set(newValue, forKey: "currentHost")
        }
        get {
            return KeychainWrapper.standard.string(forKey: "currentHost") ?? Const.serverAddress
        }
    }
}
