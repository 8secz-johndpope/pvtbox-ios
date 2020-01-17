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
import JASON
import RealmSwift

extension DataBaseService {
    public func setDeviceList(_ json: [JSON]) throws {
        BFLog("DataBaseService::setDeviceList")
        try autoreleasepool {
            let realm = try Realm()
            try realm.write {
                realm.delete(realm.objects(DeviceRealm.self).filter("id != 'own'"))
                for deviceJson in json {
                    createOrUpdateDevice(deviceJson, realm)
                }
            }
        }
    }
    
    public func onDeviceConnected(_ json: JSON) throws {
        BFLog("DataBaseService::onDeviceConnected")
        try autoreleasepool {
            let realm = try Realm()
            try realm.write {
                createOrUpdateDevice(json, realm)
            }
        }
    }
    
    public func onDeviceDisconnected(_ id: String) throws {
        BFLog("DataBaseService::onDeviceDisconnected")
        try autoreleasepool {
            let realm = try Realm()
            try realm.write {
                guard let device = realm.object(ofType: DeviceRealm.self, forPrimaryKey: id) else { return }
                if device.status != 5 && device.status != 6 /*logged out, wiped*/ {
                    device.status = 7 /*power off*/
                }
                device.isLogoutInProgress = false
                device.isWipeInProgress = false
                device.online = false
            }
        }
    }
    
    public func onDeviceStatusUpdated(_ id: String, _ json: JSON) throws {
        BFLog("DataBaseService::onDeviceStatusUpdated")
        try autoreleasepool {
            let realm = try Realm()
            try realm.write {
                guard let device = realm.object(ofType: DeviceRealm.self, forPrimaryKey: id) else { return }
                updateDeviceStatus(device, json)
            }
        }
    }
    
    public func updateDeviceLogoutInProgress(_ id: String) {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                guard let device = realm.object(ofType: DeviceRealm.self, forPrimaryKey: id) else {
                    return
                }
                device.isLogoutInProgress = true
            }
        }
    }
    
    public func updateDeviceWipeInProgress(_ id: String) {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                guard let device = realm.object(ofType: DeviceRealm.self, forPrimaryKey: id) else {
                    return
                }
                device.isWipeInProgress = true
            }
        }
    }
    
    fileprivate func updateOwnDeviceStatus(
        _ online: Bool?, _ remoteCount: Int?, _ fetchingChanges: Bool?,
        _ processingOperation: Bool?, _ importingCamera: Bool?,
        _ currentDownloadName: String?,
        _ diskUsage: Double?, _ uploadSpeed: Double?, _ downloadSpeed: Double?,
        _ uploadedSize: Double?, _ downloadedSize: Double?, _ connectedNodes: Int?,
        _ processingShare: Bool?, _ notificationsCount: Int?,
        _ realm: Realm) {
        var device = realm.object(ofType: DeviceRealm.self, forPrimaryKey: "own")
        if device == nil {
            device = setupOwnDevice(realm)
        }
        let dev = device!
        if online != nil {
            dev.online = online!
        }
        if remoteCount != nil {
            dev.remoteCount = remoteCount!
        }
        if fetchingChanges != nil {
            dev.fetchingChanges = fetchingChanges!
        }
        if processingOperation != nil {
            dev.processingOperation = processingOperation!
        }
        if importingCamera != nil {
            dev.importingCamera = importingCamera!
        }
        if processingShare != nil {
            dev.processingShare = processingShare!
        }
        if currentDownloadName != nil {
            dev.currentDownloadName = currentDownloadName!.isEmpty ? nil : currentDownloadName!
        }
        if diskUsage != nil {
            dev.diskUsage = diskUsage!
        }
        if uploadSpeed != nil {
            dev.uploadSpeed = uploadSpeed!
        }
        if downloadSpeed != nil {
            dev.downloadSpeed = downloadSpeed!
        }
        if uploadedSize != nil {
            dev.uploadedSize = uploadedSize!
        }
        if downloadedSize != nil {
            dev.downloadedSize = downloadedSize!
        }
        if connectedNodes != nil {
            dev.connectedNodes = connectedNodes!
        }
        if notificationsCount != nil {
            dev.notificationsCount = notificationsCount!
        }
        
        dev.downloadsCount = realm.objects(FileRealm.self)
            .filter("isFolder = false")
            .filter("isDownload = true")
            .count
        
        let status = !dev.online ? 10 : (
            dev.remoteCount > 0
                || dev.fetchingChanges
                || dev.processingOperation
                || dev.importingCamera
                || dev.downloadsCount > 0
                || dev.processingShare) ? 3 : 4
        if dev.status != status {
            dev.status = status
            if dev.status == 4 {
                onSynced?()
            }
        }
    }
    
    public func getOwnDevice() -> DeviceRealm? {
        return autoreleasepool {
            let realm = try? Realm()
            let device = realm?.object(
                ofType: DeviceRealm.self, forPrimaryKey: "own")
            return device == nil ? nil : DeviceRealm(value: device!)
        }
    }
    
    public func updateOwnDeviceStatus(
        online: Bool? = nil, remoteCount: Int? = nil, fetchingChanges: Bool? = nil,
        processingOperation: Bool? = nil, importingCamera: Bool? = nil,
        currentDownloadName: String? = nil,
        diskUsage: Double? = nil, uploadSpeed: Double? = nil, downloadSpeed: Double? = nil,
        uploadedSize: Double? = nil, downloadedSize: Double? = nil, connectedNodes: Int? = nil,
        processingShare: Bool? = nil, notificationsCount: Int? = nil,
        realm: Realm? = nil) {
        BFLog("DataBaseService::updateOwnDeviceStatus")
        if realm != nil {
            updateOwnDeviceStatus(
                online, remoteCount, fetchingChanges,
                processingOperation, importingCamera,
                currentDownloadName,
                diskUsage, uploadSpeed, downloadSpeed,
                uploadedSize, downloadedSize, connectedNodes,
                processingShare, notificationsCount,
                realm!)
            return
        }
        autoreleasepool {
            guard let realm = try? Realm() else { return }
            try? realm.write {
                updateOwnDeviceStatus(
                    online, remoteCount, fetchingChanges,
                    processingOperation, importingCamera,
                    currentDownloadName,
                    diskUsage, uploadSpeed, downloadSpeed,
                    uploadedSize, downloadedSize, connectedNodes,
                    processingShare, notificationsCount,
                    realm)
            }
        }
    }
    
    private func createOrUpdateDevice(_ deviceJson: JSON, _ realm: Realm) {
        guard let type = deviceJson["type"].string,
            let own = deviceJson["own"].bool,
            let id = deviceJson["id"].string,
            own,
            type == "node" else { return }
        var device = realm.object(ofType: DeviceRealm.self, forPrimaryKey: id)
        if device == nil {
            device = DeviceRealm()
            device!.id = id
            realm.add(device!)
        }
        let dev = device!
        dev.online = deviceJson["is_online"].bool ?? false
        dev.name = deviceJson["node_name"].string!
        dev.deviceType = deviceJson["node_devicetype"].string!
        dev.os = deviceJson["node_osname"].string!
        dev.osType = deviceJson["node_ostype"].string!
        
        updateDeviceStatus(dev, deviceJson)
    }
    
    private func updateDeviceStatus(_ device: DeviceRealm, _ json: JSON) {
        if let diskUsage = json["disk_usage"].double {
            device.diskUsage = diskUsage
        }
        device.uploadSpeed = json["upload_speed"].doubleValue
        device.downloadSpeed = json["download_speed"].doubleValue
        var status: Int = json["node_status"].int ?? Int(json["node_status"].string ?? "7") ?? 7
        switch (device.online, status) {
        case (true, 0), (true, 1), (true, 2), (true, 5), (true, 6), (true, 7), (true, 10):
            status = 3
        case (false, 1), (false, 2), (false, 3), (false, 4), (false, 8), (false, 9), (false, 10) :
            status = 7
        default:
            break
        }
        if device.status != status {
            device.status = status
            device.isLogoutInProgress = false
            device.isWipeInProgress = false
        }
    }
    
    func setupOwnDevice() throws {
        BFLog("DataBaseService::setupOwnDevice")
        try autoreleasepool {
            let realm = try Realm()
            try realm.write {
                let _ = setupOwnDevice(realm)
            }
        }
    }
    
    private func setupOwnDevice(_ realm: Realm) -> DeviceRealm {
        BFLog("DataBaseService::setupOwnDevice")
        var device = realm.object(ofType: DeviceRealm.self, forPrimaryKey: "own")
        if device == nil {
            device = DeviceRealm()
            device!.id = "own"
            device!.own = true
            realm.add(device!)
        }
        let dev = device!
        dev.name = Const.nodeName
        dev.deviceType = Const.nodeType
        dev.osType = Const.nodeOsType
        dev.os = Const.nodeOsName
        dev.downloadsCount = 0
        dev.currentDownloadName = nil
        dev.fetchingChanges = true
        dev.downloadSpeed = 0.0
        dev.uploadSpeed = 0.0
        dev.downloadedSize = 0.0
        dev.uploadedSize = 0.0
        dev.connectedNodes = 0
        dev.importingCamera = false
        dev.processingOperation = false
        dev.processingShare = false
        dev.remoteCount = 0
        dev.status = 10
        dev.online = false
        dev.paused = false
        dev.isLogoutInProgress = false
        dev.isWipeInProgress = false
        return dev
    }
    
    public func getOnlineDevicesCount() -> Int {
        return autoreleasepool {
            let realm = try? Realm()
            let ownOnline = realm?.object(
                ofType: DeviceRealm.self, forPrimaryKey: "own")?.online ?? false
            return ownOnline ? realm?.objects(DeviceRealm.self).filter("online = true").count ?? 0 : 0
        }
    }
    
    public func setOwnDevicePaused(_ value: Bool) {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                guard let device = realm.object(
                    ofType: DeviceRealm.self, forPrimaryKey: "own") else { return }
                device.paused = value
            }
        }
    }
}
