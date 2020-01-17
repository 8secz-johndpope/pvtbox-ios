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
import RealmSwift

extension DataBaseService {
    public func setWaitingInitialSyncForAllDownloads() {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                let files = realm.objects(FileRealm.self)
                    .filter("isDownload = true")
                for file in files {
                    file.downloadStatus = Strings.waitingInitialSyncStatus
                }
            }
        }
    }
    
    public func cancelAllDownloads() {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                let files = realm.objects(FileRealm.self)
                    .filter("isDownload = true")
                for file in files {
                    file.isDownload = false
                }
            }
        }
    }
    
    public func cancelDownloads(_ fileUuids: Set<String>) {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                let files = realm.objects(FileRealm.self)
                    .filter("isDownload = true")
                    .filter("uuid in %@", fileUuids)
                for file in files {
                    file.isDownload = false
                }
            }
        }
    }
    
    public func setDownloadedSize(
        _ size: Int, for fileUuid: String,
        withoutNotifying: NotificationToken? = nil) {
        try? autoreleasepool {
            let realm = try Realm()
            guard let file = realm.object(
                ofType: FileRealm.self, forPrimaryKey: fileUuid),
                file.isDownload,
                file.size >= size else { return }
            realm.beginWrite()
            let difference = size - file.downloadedSize
            changeDownloadedSize(of: file, difference, realm)
            try commitWrite(realm, withoutNotifying)
        }
    }
    
    public func setDownloadStatus(
        _ status: String?, forEvents uuids: Set<String>,
        withoutNotifying: NotificationToken? = nil) {
        BFLog("DataBaseService::setDownloadStatus: %@", String(describing: status))
        try? autoreleasepool {
            let realm = try Realm()
            let files = realm.objects(FileRealm.self)
                .filter("eventUuid in %@", uuids)
                .filter("downloadStatus != %@", status as Any)
            if files.isEmpty { return }
            realm.beginWrite()
            for file in files {
                file.downloadStatus = status
            }
            try commitWrite(realm, withoutNotifying)
        }
    }
    
    public func setDownloadStatus(
        _ status: String?, for fileUuid: String,
        withoutNotifying: NotificationToken? = nil) {
        BFLog("DataBaseService::setDownloadStatus: %@", String(describing: status))
        try? autoreleasepool {
            let realm = try Realm()
            realm.beginWrite()
            let file = realm.object(ofType: FileRealm.self, forPrimaryKey: fileUuid)
            file?.downloadStatus = status
            try commitWrite(realm, withoutNotifying)
        }
    }
    
    public func downloadCompleted(
        for fileUuid: String, eventUuid: String, hashsum: String, copyUrl: URL,
        withoutNotifying: NotificationToken? = nil) {
        let copiesFolderSize = FileTool.size(ofDirectory: FileTool.copiesDirectory)
        try? autoreleasepool {
            let realm = try Realm()
            realm.beginWrite()
            guard let file = realm.object(
                ofType: FileRealm.self, forPrimaryKey: fileUuid),
                file.isDownload,
                file.eventUuid == eventUuid else {
                    try commitWrite(realm, withoutNotifying)
                    return
            }
            
            setFileDownloaded(file, hashsum: hashsum, copyUrl: copyUrl, realm)
            try commitWrite(realm, withoutNotifying)
            
            realm.beginWrite()
            let eventsWithSameHash = realm.objects(EventRealm.self)
                .filter("hashsum = %@", hashsum)
            if !eventsWithSameHash.isEmpty {
                let files = realm.objects(FileRealm.self)
                    .filter("isDownload = true")
                    .filter("eventUuid in %@", Array(eventsWithSameHash.map({ $0.uuid! })))
                for file in files {
                    setFileDownloaded(file, hashsum: hashsum, copyUrl: copyUrl, realm)
                }
            }
            updateOwnDeviceStatus(diskUsage: copiesFolderSize, realm: realm)
            try commitWrite(realm, nil)
        }
    }
    
    private func setFileDownloaded(_ file: FileRealm, hashsum: String, copyUrl: URL, _ realm: Realm) {
        file.downloadStatus = nil
        file.isDownload = false
        if !file.isOnlyDownload {
            file.isOffline = true
            changeOfflineFilesCount(of: file, 1, realm)
        }
        file.isDownloadActual = true
        file.hashsum = hashsum
        let difference = file.size - file.downloadedSize
        if difference != 0 {
            changeDownloadedSize(of: file, difference, realm)
        }
        
        if let parentPath = FileTool.getParentPath(file.path!) {
            let fileParentPath = FileTool.syncDirectory.appendingPathComponent(parentPath)
            FileTool.createDirectory(fileParentPath)
        }
        let filePath = FileTool.syncDirectory.appendingPathComponent(file.path!)
        FileTool.makeLink(from: copyUrl, to: filePath)
    }
    
    public func downloadFile(_ uuid: String) {
        try? autoreleasepool {
            let realm = try Realm()
            guard let file = realm.object(
                ofType: FileRealm.self, forPrimaryKey: uuid),
                !file.isDownload else { return }
            try realm.write {
                if !file.isInvalidated {
                    file.isDownload = true
                }
            }
        }
    }
    
    private func commitWrite(_ realm: Realm, _ withoutNotifying: NotificationToken?) throws {
        if let notiicationToken = withoutNotifying {
            try realm.commitWrite(withoutNotifying: [notiicationToken])
        } else {
            try realm.commitWrite()
        }
    }
}
