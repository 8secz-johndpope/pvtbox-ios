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
    public func getLastEventId() throws -> (Int, Int, Int) {
        return try autoreleasepool {
            let realm = try Realm()
            var lastEventId: Int = 0
            var lastCheckedEventId: Int = 0
            var eventsCount: Int = 0
            try realm.write {
                lastEventId = realm.objects(EventRealm.self)
                    .filter("id != 0")
                    .max(ofProperty: "id") as Int? ?? 0
                lastCheckedEventId = realm.objects(EventRealm.self)
                    .filter("id != 0")
                    .filter("checked = true")
                    .max(ofProperty: "id") as Int? ?? 0
                eventsCount = realm.objects(EventRealm.self)
                    .filter("id != 0")
                    .filter("id > %d", lastCheckedEventId)
                    .filter("id < %d", lastEventId)
                    .count
                BFLog("DataBaseService::getLastEventId: last: %d, checked: %d, count: %d",
                      lastEventId, lastCheckedEventId, eventsCount)
            }
            return (lastEventId, lastCheckedEventId, eventsCount)
        }
    }
    
    public func setAllEventsUnchecked() {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                let events = realm.objects(EventRealm.self)
                    .filter("checked = true")
                for event in events {
                    event.checked = false
                }
            }
        }
    }
    
    public func saveFileEvents(
        _ events: [JSON], markChecked: Bool, isInitialSync: Bool,
        onEventProcessed: () -> Bool) throws {
        try autoreleasepool {
            let realm = try Realm()
            try realm.write {
                for event in events {
                    let eventUuid = event["event_uuid"].string!
                    let fileUuid = event["uuid"].string!
                    let eventType = event["event_type"].string!
                    let existingEvent = getExistingEvent(
                        eventUuid, eventType == "delete" ? nil : fileUuid, realm)
                    if existingEvent == nil {
                        onFileEvent(
                            event, isInitialSync: isInitialSync,
                            markChecked: markChecked, realm)
                    } else if (markChecked) {
                        existingEvent!.checked = true
                    }
                    if !onEventProcessed() {
                        return
                    }
                }
            }
        }
    }
    
    private func getExistingEvent(
        _ uuid: String, _ fileUuid: String?, _ realm: Realm) -> EventRealm? {
        var result = realm.objects(EventRealm.self)
            .filter("uuid = %@", uuid)
        if fileUuid != nil {
            result = result.filter("fileUuid = %@", fileUuid!)
        }
        return result.first
    }
    
    private func onFileEvent(
        _ event: JSON, isInitialSync: Bool, markChecked: Bool, _ realm: Realm) {
        var eventType = event["event_type"].string!
        if eventType == "restore" {
            eventType = "create"
        }
        let parentUuid = event["parent_folder_uuid"].string
        var parent: FileRealm? = nil
        if parentUuid != nil {
            parent = getFile(byUuid: parentUuid!, realm)
            if parent == nil {
                BFLogWarn("Parent folder uuid set but file object not found for event %@",
                         String(describing: event["event_uuid"].string))
            }
        }
        let eventId = event["event_id"].int!
        let eventUuid = event["event_uuid"].string!
        let fileUuid = event["uuid"].string!
        let hashsum = event["file_hash_after_event"].string ??
            event["file_hash_before_event"].string
        let size = event["file_size_after_event"].int ??
            event["file_size_before_event"].int ??
            event["file_size"].intValue
        let fileRealm = getFile(byUuid: fileUuid, realm)
        if fileRealm == nil {
            switch(eventType) {
            case "update", "move":
                eventType = "create"
            case "delete":
                return
            default: break
            }
            onNewFileEvent(
                eventUuid, eventId, eventType, fileUuid, parentUuid, parent,
                hashsum, size, event,
                isInitialSync: isInitialSync, realm)
        } else {
            onExistingFileEvent(
                eventUuid, eventId, eventType, fileRealm!, parent,
                hashsum, size, event,
                isInitialSync: isInitialSync, realm)
        }
        let eventRealm = getOrCreateEventRealm(eventId, eventUuid, realm)
        eventRealm.fileUuid = fileUuid
        eventRealm.id = eventId
        eventRealm.hashsum = hashsum
        eventRealm.localIdentifier = fileRealm?.isInvalidated ?? true ? nil : fileRealm?.localIdentifier
        eventRealm.size = size
        eventRealm.checked = markChecked
    }
    
    private func getOrCreateEventRealm(_ id: Int, _ uuid: String, _ realm: Realm) -> EventRealm {
        var eventRealm = realm.objects(EventRealm.self)
            .filter("id = %d", id)
            .first
        if eventRealm == nil {
            eventRealm = EventRealm()
            eventRealm?.uuid = uuid
            realm.add(eventRealm!, update: .modified)
        }
        return eventRealm!
    }
    
    public func getFile(byUuid uuid: String) -> FileRealm? {
        return autoreleasepool {
            guard let realm = try? Realm() else { return nil }
            return getFile(byUuid:uuid, realm)
        }
    }
    
    private func getFile(byUuid uuid: String, _ realm: Realm) -> FileRealm? {
        return realm.object(ofType: FileRealm.self, forPrimaryKey: uuid)
    }
    
    public func getFile(byPath path: String?) -> FileRealm? {
        guard let path = path else { return nil }
        return autoreleasepool {
            guard let realm = try? Realm() else { return nil }
            return getFile(byPath:path, realm)
        }
    }
    
    private func getFile(byPath path: String, _ realm: Realm) -> FileRealm? {
        return realm.objects(FileRealm.self).filter("path = %@", path).first
    }
    
    public func getFile(byLocalIdentifier identifier: String, with parentUuid: String) -> FileRealm? {
        return autoreleasepool {
            guard let realm = try? Realm() else { return nil }
            return realm.objects(FileRealm.self)
                .filter("localIdentifier = %@", identifier)
                .filter("parentUuid == %@", parentUuid)
                .first
        }
    }
    
    public func getRootParent(_ file: FileRealm?) -> FileRealm? {
        guard let parentUuid = file?.parentUuid else { return file }
        return autoreleasepool {
            guard let realm = try? Realm() else { return nil }
            return getRootParent(parentUuid, realm)
        }
    }
    
    private func getRootParent(_ parentUuid: String, _ realm: Realm) -> FileRealm? {
        guard let file = realm.object(ofType: FileRealm.self, forPrimaryKey: parentUuid) else {
            return nil
        }
        guard let parentUuid = file.parentUuid else {
            return file
        }
        return getRootParent(parentUuid, realm)
    }
    
    private func onNewFileEvent(
        _ eventUuid: String, _ eventId: Int, _ eventType: String, _ fileUuid: String,
        _ parentUuid: String?, _ parent: FileRealm?, _ hashsum: String?, _ size: Int,
        _ event: JSON, isInitialSync: Bool, _ realm: Realm) {
        let fileName = getFileNameFromEvent(event)
        let path = FileTool.buildPath(parent?.path, fileName)
        var localIdentifier: String? = nil
        if let existingFile = getFile(byPath: path, realm),
            existingFile.parentUuid == parentUuid {
            localIdentifier = existingFile.localIdentifier
            if existingFile.parentUuid != nil,
                let parent = realm.object(
                    ofType: FileRealm.self, forPrimaryKey: existingFile.parentUuid!) {
                onFileSwitchedParent(added: false, existingFile, parent, realm)
            }
            realm.delete(existingFile)
        }
        let file = FileRealm()
        file.uuid = fileUuid
        realm.add(file)
        file.parentUuid = parentUuid
        file.eventUuid = eventUuid
        file.eventId = eventId
        file.name = fileName
        file.path = path
        let isFolder = event["is_folder"].bool!
        file.isFolder = isFolder
        let timestamp = Date(timeIntervalSince1970: event["timestamp"].double!)
        if let fileCreated = event["file_created"].double {
            let fileCreatedDate = Date(timeIntervalSince1970: fileCreated)
            file.dateCreated = fileCreatedDate
        } else {
            file.dateCreated = timestamp
        }
        file.dateModified = isFolder ? file.dateCreated : timestamp
        if isFolder {
            file.isOffline = parent?.isOffline ?? false
            handleMissingParentCaseFor(parent: file, realm)
        } else {
            file.size = size
            changeFileCount(of: parent, 1, realm)
            if size > 0 {
                changeSize(of: parent, size, realm)
            }
            if localIdentifier == nil {
                localIdentifier = realm.objects(EventRealm.self)
                    .filter("localIdentifier != nil")
                    .filter("hashsum = %@", hashsum!).first?.localIdentifier
            }
            file.localIdentifier = localIdentifier
            file.isOnlyDownload = !(parent?.isOffline ?? false)
            let isDownload = parent?.isOffline ?? false ||
                file.localIdentifier == nil && checkNeedDownload(fileName, size)
            file.isDownload = isDownload
            if isDownload && isInitialSync {
                file.downloadStatus = Strings.waitingInitialSyncStatus
            }
        }
    }
    
    private func handleMissingParentCaseFor(parent: FileRealm, _ realm: Realm) {
        autoreleasepool {
            let childs = realm.objects(FileRealm.self)
                .filter("parentUuid = %@", parent.uuid!)
            for child in childs {
                onFileSwitchedParent(added: true, child, parent, realm)
                updatePath(for: child, withParent: parent, realm)
            }
        }
    }
    
    private func updatePath(for file: FileRealm, withParent parent: FileRealm, _ realm: Realm) {
        file.path = FileTool.buildPath(parent.path, file.name!)
        if file.isFolder {
            let childs = realm.objects(FileRealm.self)
                .filter("parentUuid = %@", file.uuid!)
            for child in childs {
                updatePath(for: child, withParent: file, realm)
            }
        }
    }
    
    private func onExistingFileEvent(
        _ eventUuid: String, _ eventId: Int, _ eventType: String, _ file: FileRealm,
        _ parent: FileRealm?, _ hashsum: String?, _ size: Int, _ event: JSON,
        isInitialSync: Bool, _ realm: Realm) {
        if eventType == "delete" {
            onDeleteFileEvent(file, parent, realm)
            return;
        }
        file.eventUuid = eventUuid
        file.eventId = eventId
        let fileName = getFileNameFromEvent(event)
        let path = FileTool.buildPath(parent?.path, fileName)
        
        if path != file.path {
            onMoveFileEvent(file, parent, newPath: path, newName: fileName, realm)
        }
        let isFolder = file.isFolder
        let timestamp = Date(timeIntervalSince1970: event["timestamp"].double!)
        if eventType != "move" {
            file.dateModified = timestamp
        }
        if isFolder {
            file.isOffline = file.isOffline || parent?.isOffline ?? file.isOffline 
        } else {
            let oldSize = file.size
            let oldHash = file.hashsum
            if oldHash != hashsum  || oldSize != size {
                onUpdateFileEvent(
                    file, parent, hashsum!, size, event,
                    isInitialSync: isInitialSync, realm)
            }
            if oldHash == hashsum {
                if (file.localIdentifier == nil) {
                    file.isDownloadActual = true
                }
            } else {
                file.localIdentifier = nil
            }
        }
    }
    
    private func onUpdateFileEvent(
        _ file: FileRealm, _ parent: FileRealm?, _ newHash: String, _ newSize: Int,
        _ event: JSON, isInitialSync: Bool, _ realm: Realm) {
        let oldSize = file.size
        let oldDownloadedSize = file.downloadedSize
        if oldDownloadedSize > 0 {
            changeDownloadedSize(of: parent, -oldDownloadedSize, realm)
            file.downloadedSize = 0
        }
        if oldSize != newSize {
            changeSize(of: parent, newSize - oldSize, realm)
            file.size = newSize
        }
        if file.hashsum != newHash {
            file.localIdentifier = nil
            file.isDownloadActual = false
        }
        file.isOnlyDownload = !(file.isOffline || parent?.isOffline ?? false)
        file.isDownload = file.isOffline || parent?.isOffline ??
            (file.localIdentifier ==  nil && checkNeedDownload(file.name!, newSize))
        if !file.isFolder && file.isDownload && isInitialSync {
            file.downloadStatus = Strings.waitingInitialSyncStatus
        }
    }
    
    private func onDeleteFileEvent(_ file: FileRealm, _ parent: FileRealm?, _ realm: Realm) {
        if file.isFolder && PreferenceService.cameraFolderUuid != nil {
            checkCameraFolderDeleted(file, realm)
        }
        onFileSwitchedParent(added: false, file, parent, realm)
        if file.isFolder {
            deleteChilds(of: file.uuid!, realm)
        }
        realm.delete(
            realm.objects(EventRealm.self)
                .filter("fileUuid = %@", file.uuid!))
        FileTool.delete(FileTool.syncDirectory.appendingPathComponent(file.path!))
        realm.delete(file)
    }
    
    @discardableResult
    private func checkCameraFolderDeleted(_ file: FileRealm, _ realm: Realm) -> Bool {
        if file.uuid == PreferenceService.cameraFolderUuid {
            PreferenceService.cameraFolderUuid = nil
            PreferenceService.cameraLastPhotoCreationDate = nil
            if PreferenceService.importCameraEnabled {
                PreferenceService.importCameraEnabled = false
                onCameraFolderDeleted?()
            }
            return true
        }
        let subFolders = realm.objects(FileRealm.self)
            .filter("parentUuid = %@", file.uuid!)
            .filter("isFolder = true")
        for subFolder in subFolders {
            if checkCameraFolderDeleted(subFolder, realm) {
                return true
            }
        }
        return false
    }
    
    private func onFileSwitchedParent(added: Bool, _ file: FileRealm, _ parent: FileRealm?, _ realm: Realm) {
        let multiplier = added ? 1 : -1
        let fileSize = file.size
        if fileSize > 0 {
            changeSize(of: parent, fileSize * multiplier, realm)
        }
        let downloadedSize = file.downloadedSize
        if downloadedSize > 0 {
            changeDownloadedSize(of: parent, downloadedSize * multiplier, realm)
        }
        if file.isFolder {
            let filesCount = file.filesCount
            if filesCount > 0 {
                changeFileCount(of: parent, filesCount * multiplier, realm)
            }
            let offlineFilesCount = file.offlineFilesCount
            if offlineFilesCount > 0 {
                changeOfflineFilesCount(of: parent, offlineFilesCount * multiplier, realm)
            }
        } else {
            changeFileCount(of: parent, 1 * multiplier, realm)
            if file.isOffline {
                changeOfflineFilesCount(of: parent, 1 * multiplier, realm)
            }
        }
    }
    
    private func deleteChilds(of fileUuid: String, _ realm: Realm) {
        let childs = realm.objects(FileRealm.self)
            .filter("parentUuid = %@", fileUuid)
        for child in childs {
            if child.isFolder {
                deleteChilds(of: child.uuid!, realm)
            }
            realm.delete(
                realm.objects(EventRealm.self)
                    .filter("fileUuid = %@", child.uuid!))
            realm.delete(child)
        }
    }
    
    private func onMoveFileEvent(
        _ file: FileRealm, _ parent: FileRealm?, newPath: String, newName: String, _ realm: Realm) {
        if file.parentUuid != parent?.uuid {
            if file.parentUuid != nil {
                let oldParent = getFile(byUuid: file.parentUuid!, realm)
                onFileSwitchedParent(added: false, file, oldParent, realm)
            }
            if parent != nil {
                onFileSwitchedParent(added: true, file, parent, realm)
            }
        }
        let oldFilePath = file.path
        file.name = newName
        file.path = newPath
        file.parentUuid = parent?.uuid
        moveChilds(
            of: file.uuid!, newPath: newPath, setOffline: parent?.isOffline ?? false && !file.isOffline, realm)
        FileTool.move(from: FileTool.syncDirectory.appendingPathComponent(oldFilePath!), to: FileTool.syncDirectory.appendingPathComponent(file.path!))
        if !file.isFolder && !file.isOffline && parent?.isOffline ?? false {
            file.isDownload = true
            file.isOnlyDownload = false
        }
    }
    
    private func moveChilds(of fileUuid: String, newPath: String, setOffline: Bool, _ realm: Realm) {
        let childs = realm.objects(FileRealm.self)
            .filter("parentUuid = %@", fileUuid)
        for child in childs {
            let newChildPath = FileTool.buildPath(newPath, child.name!)
            child.path = newChildPath
            if child.isFolder {
                if setOffline {
                    child.isOffline = true
                }
                moveChilds(of: child.uuid!, newPath: newChildPath, setOffline: setOffline, realm)
            } else if setOffline {
                if !child.isDownload {
                    child.isDownload = true
                }
                child .isOnlyDownload = false
            }
        }
    }
    
    private func changeFileCount(of file: FileRealm?, _ count: Int, _ realm: Realm) {
        file?.filesCount += count
        guard let parentUuid = file?.parentUuid else { return }
        let parent = getFile(byUuid: parentUuid, realm)
        changeFileCount(of: parent, count, realm)
    }
    
    internal func changeOfflineFilesCount(of file: FileRealm?, _ count: Int, _ realm: Realm) {
        guard let file = file else { return }
        if file.isFolder {
            file.offlineFilesCount += count
        }
        guard let parentUuid = file.parentUuid,
            let parent = getFile(byUuid: parentUuid, realm) else { return }
        changeOfflineFilesCount(of: parent, count, realm)
    }
    
    private func changeSize(of file: FileRealm?, _ size: Int, _ realm: Realm) {
        file?.size += size
        guard let parentUuid = file?.parentUuid else { return }
        let parent = getFile(byUuid: parentUuid, realm)
        changeSize(of: parent, size, realm)
    }
    
    internal func changeDownloadedSize(of file: FileRealm?, _ size: Int, _ realm: Realm) {
        file?.downloadedSize += size
        guard let parentUuid = file?.parentUuid,
            let parent = getFile(byUuid: parentUuid, realm) else { return }
        changeDownloadedSize(of: parent, size, realm)
    }
    
    private func getFileNameFromEvent(_ event: JSON) -> String {
        var fileName = event["file_name_after_event"].string
        if fileName == nil {
            fileName = event["file_name"].string
        }
        return fileName!
    }
    
    private func checkNeedDownload(_ fileName: String, _ size: Int) -> Bool {
        return PreferenceService.mediaDownloadEnabled
            && size < Const.maxSizeForPreview
            && FileTool.isImageOrVideoFile(fileName)
    }
    
    public func addFile(_ file: FileRealm, generateUniqName: Bool = false) {
        autoreleasepool {
            guard let realm = try? Realm() else { return }
            try? realm.write {
                realm.add(file)
                var parent: FileRealm? = nil
                if let parentUuid = file.parentUuid,
                    let existingParent = realm.object(
                        ofType: FileRealm.self, forPrimaryKey: parentUuid) {
                    parent = existingParent
                    onFileSwitchedParent(added: true, file, existingParent, realm)
                }
                if generateUniqName {
                    file.name = self.generateUniqName(
                        parentPath: parent?.path, baseName: file.name!,
                        isFolder: file.isFolder, suffix: "", realm)
                }
                if file.path == nil || generateUniqName {
                    file.path = FileTool.buildPath(parent?.path, file.name!)
                }
            }
        }
    }
    
    public func deleteFile(byUuid uuid: String) {
        autoreleasepool {
            guard let realm = try? Realm() else { return  }
            try? realm.write {
                guard let file = realm.object(
                    ofType: FileRealm.self, forPrimaryKey: uuid) else { return }
                FileTool.delete(FileTool.syncDirectory.appendingPathComponent(file.path!))
                if let parentUuid = file.parentUuid,
                    let parent = realm.object(
                        ofType: FileRealm.self, forPrimaryKey: parentUuid) {
                    onFileSwitchedParent(added: false, file, parent, realm)
                }
                if file.isFolder {
                    if PreferenceService.cameraFolderUuid != nil {
                        checkCameraFolderDeleted(file, realm)
                    }
                    
                    deleteChilds(of: file.uuid!, realm)
                }
                realm.delete(
                    realm.objects(EventRealm.self)
                        .filter("fileUuid = %@", file.uuid!))
                realm.delete(file)
            }
        }
    }
    
    public func deleteEvent(byUuid uuid: String) {
        autoreleasepool {
            guard let realm = try? Realm() else { return  }
            try? realm.write {
                guard let event = realm.object(
                    ofType: FileRealm.self, forPrimaryKey: uuid) else { return }
                realm.delete(event)
            }
        }
    }
    
    public func updateFileWithEvent(
        _ fileUuid: String, _ event: EventRealm,
        date: Date? = nil, newName: String? = nil, newParentUuid: String? = nil) {
        autoreleasepool {
            guard let realm = try? Realm() else { return }
            try? realm.write {
                realm.add(event, update: .modified)
                guard var file = realm.object(
                    ofType: FileRealm.self, forPrimaryKey: fileUuid) else { return }
                if file.uuid != event.fileUuid {
                    let newFile = FileRealm(value: file)
                    newFile.uuid = event.fileUuid
                    newFile.dateCreated = date!
                    realm.add(newFile)
                    realm.delete(file)
                    file = newFile
                }
                
                if date != nil {
                    file.dateModified = date
                }
                if newName != nil {
                    file.name = newName
                    let newPath = FileTool.buildPath(FileTool.getParentPath(file.path!), newName!)
                    FileTool.move(
                        from: FileTool.syncDirectory.appendingPathComponent(file.path!),
                        to: FileTool.syncDirectory.appendingPathComponent(newPath))
                    file.path = newPath
                    if file.isFolder {
                        let childs = realm.objects(FileRealm.self)
                            .filter("parentUuid = %@", file.uuid!)
                        for child in childs {
                            updatePath(for: child, withParent: file, realm)
                        }
                    }
                }
                if newParentUuid != nil {
                    if file.parentUuid != nil {
                        let oldParent = getFile(byUuid: file.parentUuid!, realm)
                        onFileSwitchedParent(added: false, file, oldParent, realm)
                    }
                    let parentUuid = newParentUuid!
                    if parentUuid.isEmpty {
                        file.parentUuid = nil
                        FileTool.move(
                            from: FileTool.syncDirectory.appendingPathComponent(file.path!),
                            to: FileTool.syncDirectory.appendingPathComponent(file.name!))
                        file.path = file.name
                        if file.isFolder {
                            let childs = realm.objects(FileRealm.self)
                                .filter("parentUuid = %@", file.uuid!)
                            for child in childs {
                                updatePath(for: child, withParent: file, realm)
                            }
                        }
                    } else {
                        file.parentUuid = parentUuid
                        let newParent = getFile(byUuid: parentUuid, realm)
                        let newPath = FileTool.buildPath(newParent!.path, file.name!)
                        FileTool.move(
                            from: FileTool.syncDirectory.appendingPathComponent(file.path!),
                            to: FileTool.syncDirectory.appendingPathComponent(newPath))
                        file.path = newPath
                        onFileSwitchedParent(added: true, file, newParent, realm)
                        if file.isFolder {
                            moveChilds(
                                of: file.uuid!, newPath: newPath,
                                setOffline: newParent?.isOffline ?? false && !file.isOffline, realm)
                        } else if newParent?.isOffline ?? false && !file.isOffline {
                            file.isDownload = true
                            file.isOnlyDownload = false
                        }
                    }
                }
                file.eventUuid = event.uuid
                file.eventId = event.id
                event.localIdentifier = file.localIdentifier
                file.isProcessing = false
                let parent = file.parentUuid == nil ? nil :
                    realm.object(ofType: FileRealm.self, forPrimaryKey: file.parentUuid!)
                if file.isFolder {
                    file.isOffline = file.isOffline || parent?.isOffline ?? false
                } else {
                    file.isOnlyDownload = !(parent?.isOffline ?? false || !file.isOnlyDownload)
                    file.isDownload = file.isDownload || parent?.isOffline ?? false ||
                        file.localIdentifier == nil && checkNeedDownload(
                            file.name!, file.size)
                }
            }
        }
    }
    
    public func setProcessing(_ processing: Bool, forFile uuid: String) {
        autoreleasepool {
            guard let realm = try? Realm() else { return }
            try? realm.write {
                guard let file = realm.object(
                    ofType: FileRealm.self, forPrimaryKey: uuid) else { return }
                file.isProcessing = processing
            }
        }
    }
    
    public func getHashAndSize(byEventUuid uuid: String) throws -> (String, Int) {
        return try autoreleasepool {
            guard let realm = try? Realm(),
                let event = realm.object(ofType: EventRealm.self, forPrimaryKey: uuid) else {
                    throw "event not found"
            }
            return (event.hashsum!, event.size)
        }
    }
    
    public func getFile(byEventUuid uuid: String) -> FileRealm? {
        return autoreleasepool {
            let realm = try? Realm()
            return realm?.objects(FileRealm.self)
                .filter("eventUuid = %@", uuid)
                .first
        }
    }
    
    public func addOffline(fileUuid uuid: String) {
        autoreleasepool {
            guard let realm = try? Realm() else { return }
            try? realm.write {
                guard let file = realm.object(
                    ofType: FileRealm.self, forPrimaryKey: uuid) else { return }
                addOffline(file: file, realm)
            }
        }
    }
    
    private func addOffline(file: FileRealm, _ realm: Realm) {
        if file.isFolder {
            file.isOffline = true
            addOffline(filesOfParent: file.uuid!, realm)
        } else if !file.isOffline{
            file.isDownload = true
            file.isOnlyDownload = false
        }
    }
    
    private func addOffline(filesOfParent uuid: String, _ realm: Realm) {
        let childs = realm.objects(FileRealm.self).filter("parentUuid = %@", uuid)
        for child in childs {
            addOffline(file: child, realm)
        }
    }
    
    public func removeOffline(fileUuid uuid: String) {
        autoreleasepool {
            guard let realm = try? Realm() else { return }
            try? realm.write {
                guard let file = realm.object(
                    ofType: FileRealm.self, forPrimaryKey: uuid) else { return }
                removeOffline(isRoot: true, file: file, realm)
            }
        }
    }
    
    private func removeOffline(isRoot: Bool, file: FileRealm, _ realm: Realm) {
        if isRoot {
            changeOfflineFilesCount(of: file, -file.offlineFilesCount, realm)
        }
        file.isOffline = false
        file.isDownload = false
        if file.isFolder {
            file.isDownload = false
            removeOffline(filesOfParent: file.uuid!, realm)
        } else {
            file.isOnlyDownload = true
        }
    }
    
    private func removeOffline(filesOfParent uuid: String, _ realm: Realm) {
        let childs = realm.objects(FileRealm.self).filter("parentUuid = %@", uuid)
        for child in childs {
            removeOffline(isRoot: false, file: child, realm)
        }
    }
    
    public func generateUniqName(
        parentPath: String?, baseName: String, isFolder: Bool,
        suffix: String = " copy") -> String {
        return autoreleasepool {
            guard let realm = try? Realm() else { fatalError("cant open realm") }
            return generateUniqName(
                parentPath: parentPath, baseName: baseName,
                isFolder: isFolder, suffix: suffix, realm)
        }
    }
    
    private func generateUniqName(
        parentPath: String?, baseName: String, isFolder: Bool,
        suffix: String, _ realm: Realm) -> String {
        var name = baseName
        var path = FileTool.buildPath(parentPath, name)
        var (namePrefix, nameSuffix) = isFolder ?
            (name, "") : FileTool.getFileNameAndExtension(fromName: name)
        var count = 0
        while !realm.objects(FileRealm.self).filter("path = %@", path).isEmpty {
            name = String(
                format: "%@%@%@",
                namePrefix,
                suffix,
                count > 0 ? String(format: " %d%@", count, nameSuffix) : nameSuffix)
            name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let nameBytes = name.lengthOfBytes(using: .utf8)
            if nameBytes >= 255 {
                if namePrefix.count >= nameSuffix.count {
                    namePrefix = String(namePrefix.prefix(namePrefix.count - (nameBytes - 255) - 1))
                } else {
                    nameSuffix = "." + nameSuffix.suffix(nameSuffix.count - (nameBytes - 255) - 2)
                }
                name = String(
                    format: "%@%@%@",
                    namePrefix,
                    suffix,
                    count > 0 ? String(format: " %d%@", count, nameSuffix) : nameSuffix)
                name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            path = FileTool.buildPath(parentPath, name)
            count += 1
        }
        return name
    }
    
    public func addEvent(_ event: EventRealm) {
        autoreleasepool {
            guard let realm = try? Realm() else { return }
            try? realm.write {
                realm.add(event)
            }
        }
    }
    
    public func getAllFilesHashes() -> Set<String>? {
        return try? autoreleasepool {
            let realm = try Realm()
            if realm.objects(FileRealm.self)
                .filter("isDownload = true or isProcessing = true")
                .first != nil {
                throw "some file downloading"
            }
            let files = realm.objects(FileRealm.self)
                .filter("isFolder = false")
                .filter("hashsum != nil")
            var hashes = Set<String>()
            for file in files {
                hashes.insert(file.hashsum!)
            }
            return hashes
        }
    }
    
    public func cleanProcessing() {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                let processingFiles = realm.objects(FileRealm.self)
                    .filter("isProcessing = true")
                for file in processingFiles {
                    guard let event = realm.objects(EventRealm.self)
                        .filter("uuid = %@", file.eventUuid!)
                        .first else {
                            realm.delete(file)
                            continue
                    }
                    if event.id == 0 {
                        realm.delete(event)
                    }
                    guard let prevEvent = realm.objects(EventRealm.self)
                        .filter("fileUuid = %@", file.uuid!)
                        .sorted(byKeyPath: "id", ascending: false)
                        .first else {
                        realm.delete(file)
                        continue
                    }
                    file.eventUuid = prevEvent.uuid
                    file.eventId = prevEvent.id
                    file.isProcessing = false
                }
            }
        }
    }
}
