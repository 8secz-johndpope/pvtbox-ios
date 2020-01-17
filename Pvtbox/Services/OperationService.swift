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

class OperationService {
    private let dispatchQueue = DispatchQueue(
        label: "net.pvtbox.service.operation", qos: .userInteractive)
    
    private weak var dataBaseService: DataBaseService?
    private weak var signalServerService: SignalServerClient?
    
    private var currentProcessingFile: FileRealm!
    private var currentProcessingFileUuid: String!
    private var currentProcessingOperation: OperationType!
    private var currentProcessingFilePath: String!
    private var currentEventUuid: String!
    
    private var enabled = true
    
    init(_ dataBaseService: DataBaseService?, _ signalServerService: SignalServerService?) {
        self.dataBaseService = dataBaseService
        self.signalServerService = signalServerService
    }
    
    enum OperationType {
        case createFolder
        case renameFolder, renameFile
        case delete, deleteFolder, deleteFile
        case move, moveFolder, moveFile
        case copy, copyFolder, copyFile
        case addOffline, addOfflineFolder, addOfflineFile
        case removeOffline, removeOfflineFolder, removeOfflineFile
        case addPhoto, importVideo, importFiles, sendFiles, sendPhoto, sendVideo
        case cancelDownload, cancelDownloads, pauseDownloads, resumeDownloads
    }
    
    public var isProcessing: Bool {
        get {
            return currentProcessingOperation != nil
        }
    }
    
    public func addOperation(
        _ type: OperationService.OperationType,
        root: FileRealm?,
        newName: String?,
        uuid: String?,
        files: [FileRealm]?,
        data: Data?,
        url: URL?,
        urls: [URL]?,
        deleteAfterImport: Bool) {
        BFLog("OperationService::addOperation")
        dispatchQueue.async { [weak self] in
            if self == nil || self?.currentProcessingOperation != nil { return }
            self?.dataBaseService?.updateOwnDeviceStatus(processingOperation: true)
            self?.currentProcessingOperation = type
            self?.processOperation(
                type, root:root, newName: newName, uuid: uuid,
                files: files, data: data, url: url, urls: urls,
                deleteAfterImport: deleteAfterImport)
        }
    }
    
    public func suspend() {
        BFLog("OperationService::suspend")
        BFLog("current processing file uuid: %@", String(describing: currentProcessingFileUuid))
        BFLog("current event uuid: %@", String(describing: currentEventUuid))
    }
    
    public func resume() {
        BFLog("OperationServie::resume")
        BFLog("current processing file uuid: %@", String(describing: currentProcessingFileUuid))
        BFLog("current event uuid: %@", String(describing: currentEventUuid))
    }
    
    public func stop() {
        BFLog("OperationService::stop")
        if isProcessing {
            SnackBarManager.dismiss()
        }
        enabled = false
        dispatchQueue.sync {
            dataBaseService = nil
            signalServerService = nil
            operationDone()
        }
    }
    
    private func processOperation(
        _ type: OperationService.OperationType,
        root: FileRealm?,
        newName: String?,
        uuid: String?,
        files: [FileRealm]?,
        data: Data?,
        url: URL?,
        urls: [URL]?,
        deleteAfterImport: Bool) {
        BFLog("OperationService::processOperation")
        var operationStr: String
        switch type {
        case .createFolder:
            operationStr = Strings.creatingFolder
        case .renameFolder:
            operationStr = Strings.renamingFolder
        case .renameFile:
            operationStr = Strings.renamingFile
        case .deleteFile:
            operationStr = Strings.deletingFile
        case .deleteFolder:
            operationStr = Strings.deletingFolder
        case .delete:
            operationStr = String(
                format: "%@\n1 %@ %d %@",
                Strings.deletingObjects,
                Strings.of,
                files!.count,
                Strings.total
            )
        case .moveFile:
            operationStr = Strings.movingFile
        case .moveFolder:
            operationStr = Strings.movingFolder
        case .move:
            operationStr = String(
                format: "%@\n1 %@ %d %@",
                Strings.movingObjects,
                Strings.of,
                files!.count,
                Strings.total
            )
        case .copyFile:
            operationStr = Strings.copyingFile
        case .copyFolder:
            operationStr = Strings.copyingFolder
        case .copy:
            operationStr = String(
                format: "%@\n1 %@ %d %@",
                Strings.copyingObjects,
                Strings.of,
                files!.count,
                Strings.total
            )
        case .addOffline:
            operationStr = String(
                format: "%@\n1 %@ %d %@",
                Strings.addingObjectsToOffline,
                Strings.of,
                files!.count,
                Strings.total
            )
        case .addOfflineFolder:
            operationStr = Strings.addingFolderToOffline
        case .addOfflineFile:
            operationStr = Strings.addingFileToOffline
        case .removeOffline:
            operationStr = String(
                format: "%@\n1 %@ %d %@",
                Strings.removingObjectsFromOffline,
                Strings.of,
                files!.count,
                Strings.total
            )
        case .removeOfflineFolder:
            operationStr = Strings.removingFolderFromOffline
        case .removeOfflineFile:
            operationStr = Strings.removingFileFromOffline
        case .cancelDownload:
            operationStr = Strings.cancellingDownload
        case .cancelDownloads:
            operationStr = Strings.cancellingDownloads
        case .pauseDownloads, .resumeDownloads:
            operationStr = "not implemented"
        case .addPhoto, .sendPhoto:
            operationStr = Strings.addingPhoto
        case .importVideo, .sendVideo:
            operationStr = Strings.addingVideoFile
        case .importFiles, .sendFiles:
            operationStr = Strings.adding
        }
        
        SnackBarManager.showSnack(operationStr, showForever: true)
        
        switch type {
        case .addOffline, .addOfflineFolder, .addOfflineFile:
            self.processAddOffline(files!)
        case .removeOffline, .removeOfflineFolder, .removeOfflineFile:
            self.processRemoveOffline(files!)
        case .cancelDownload, .cancelDownloads:
            self.processCancelDownloads(files!)
        default:
            do {
                try checkOrWaitSignalServerConnected(indefinite: deleteAfterImport)
            } catch  {
                BFLogErr("OperationService::processOperation error")
                SnackBarManager.showSnack(
                    String(format: "%@:\n%@",
                           Strings.operationError,
                           Strings.networkError),
                    showNew: false)
                operationDone()
                return
            }
            switch type {
            case .createFolder:
                self.proccessFolderCreation(root, newName!)
            case .renameFolder, .renameFile:
                self.proccessRename(uuid!, newName!, type == .renameFolder)
            case .delete, .deleteFolder, .deleteFile:
                self.processDelete(files!.makeIterator(), count: 1, total: files!.count)
            case .move, .moveFolder, .moveFile:
                self.processMove(root, files!.makeIterator(), count: 1, total: files!.count)
            case .copy, .copyFolder, .copyFile:
                self.processCopy(root, files!.makeIterator(), count: 1, total: files!.count)
            case .addPhoto:
                self.processAddPhoto(root, data!, false)
            case .sendPhoto:
                self.processAddPhoto(root, data!, true)
            case .importVideo:
                self.processImportVideo(root, url!, false)
            case .sendVideo:
                self.processImportVideo(root, url!, true)
            case .importFiles:
                self.processImportFiles(root, urls!, deleteAfterImport, false)
            case .sendFiles:
                self.processImportFiles(root, urls!, deleteAfterImport, true)
            default:
                fatalError("unsupported case")
            }
        }
    }
    
    private func operationDone() {
        BFLog("OperationService::operationDone")
        currentProcessingFile = nil
        currentProcessingFileUuid = nil
        currentProcessingOperation = nil
        currentProcessingFilePath = nil
        currentEventUuid = nil
        if enabled {
            dataBaseService?.updateOwnDeviceStatus(processingOperation: false)
        }
    }
    
    private func error(_ json: JSON?) {
        BFLog("OperationService::error")
        dataBaseService?.setProcessing(false, forFile: currentProcessingFileUuid)
        var operationErrorStr: String
        switch currentProcessingOperation! {
        case .createFolder:
            operationErrorStr = Strings.createFolderError
        case .renameFolder, .renameFile:
            operationErrorStr = Strings.renameError
        case .delete, .deleteFile, .deleteFolder:
            operationErrorStr = Strings.deleteError
        case .move, .moveFile, .moveFolder:
            operationErrorStr = Strings.moveError
        case .copy, .copyFile, .copyFolder:
            operationErrorStr = Strings.copyError
        case .addOffline, .addOfflineFile, .addOfflineFolder,
             .removeOffline, .removeOfflineFile, .removeOfflineFolder,
             .cancelDownload, .cancelDownloads, .pauseDownloads, .resumeDownloads:
            fatalError("unsupported case")
        case .addPhoto, .importVideo, .importFiles, .sendFiles, .sendPhoto, .sendVideo:
            operationErrorStr = Strings.addError
        }
        SnackBarManager.showSnack(String(format:
            "%@:\n%@", operationErrorStr, (
                json?["info"].string ??
                    json?["info"]["error_file_name"][0].string ??
                Strings.networkError)
            ),
            showNew: false)
        operationDone()
    }
    
    private func checkOrWaitSignalServerConnected(indefinite: Bool) throws {
        var retryCount = 0
        guard let signalServerService = self.signalServerService else { return }
        while enabled && !signalServerService.isConnected {
            BFLog("OperationService::checkOrWaitSignalServerConnected:" +
                "not connected, recheck in 1 sec")
            if indefinite || retryCount < 3 {
                retryCount += 1
                Thread.sleep(forTimeInterval: 1)
            } else {
                throw Strings.networkError
            }
        }
        BFLog("OperationService::checkOrWaitSignalServerConnected: connected")
    }
    
    private func proccessFolderCreation(_ root: FileRealm?, _ name: String) {
        BFLog("OperationService::proccessFolderCreation")
        createFolder(root, name, onDone: { [weak self] json in
            self?.dispatchQueue.async { [weak self] in
                self?.folderCreationSuccess(json)
            }
        })
    }
    
    private func createFolder(
        _ root: FileRealm?, _ name: String, generateUniqName: Bool = false,
        onDone: @escaping (JSON) -> ()) {
        var name = generateUniqName ? dataBaseService?.generateUniqName(
            parentPath: root?.path, baseName: name, isFolder: true, suffix: "") ?? name : name
        currentProcessingFile = FileRealm()
        currentProcessingFileUuid = UUID().uuidString
        currentEventUuid = md5(fromString: currentProcessingFileUuid)
        currentProcessingFile.uuid = currentProcessingFileUuid
        currentProcessingFile.eventUuid = currentEventUuid
        currentProcessingFile.name = name
        currentProcessingFile.isFolder = true
        let now = Date()
        currentProcessingFile.dateCreated = now
        currentProcessingFile.dateModified = now
        currentProcessingFile.parentUuid = root?.uuid ?? nil
        currentProcessingFile.path = FileTool.buildPath(root?.path, name)
        currentProcessingFilePath = currentProcessingFile.path
        currentProcessingFile.isProcessing = true
        currentProcessingFile.downloadStatus = Strings.processingStatus
        var processing = false
        defer {
            if !processing {
                dataBaseService?.deleteFile(byUuid: self.currentProcessingFileUuid)
                error(nil)
            }
        }
        dataBaseService?.addFile(currentProcessingFile)
        HttpClient.shared.createFolder(
            eventUuid: currentEventUuid,
            parentUuid: currentProcessingFile.parentUuid ?? "",
            name: name,
            onSuccess: onDone,
            onError: { [weak self] json in
                self?.dispatchQueue.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.dataBaseService?.deleteFile(byUuid: strongSelf.currentProcessingFileUuid)
                    
                    if json?["errcode"].string == "WRONG_DATA",
                        let varFileName = json?["error_data"]["var_file_name"].string {
                        strongSelf.createFolder(
                            root, varFileName, generateUniqName: true,
                            onDone: onDone)
                    } else {
                        strongSelf.error(json)
                    }
                }
        })
        processing = true
    }
    
    func folderCreationSuccess(_ json: JSON) {
        guard let result = json["result"].string,
            result == "success",
            let data = json["data"].jsonDictionary,
            enabled else {
                dataBaseService?.deleteFile(byUuid: self.currentProcessingFileUuid)
                error(json)
                return
        }
        let event = EventRealm()
        event.id = data["event_id"]!.int!
        event.uuid = data["event_uuid"]!.string!
        event.fileUuid = data["folder_uuid"]!.string!
        let date = Date(timeIntervalSince1970: data["timestamp"]!.double!)
        
        dataBaseService?.updateFileWithEvent(
            currentProcessingFileUuid, event, date: date)

        SnackBarManager.showSnack(Strings.folderCreated, showNew: false)
        operationDone()
    }
    
    private func proccessRename(_ uuid: String, _ name: String, _ isFolder: Bool) {
        BFLog("OperationService::proccessRename")
        guard let dataBaseService = self.dataBaseService, enabled else { return }
        currentEventUuid = md5(fromString: UUID().uuidString)
        currentProcessingFile = dataBaseService.getFile(byUuid: uuid)
        currentProcessingFileUuid = uuid
        var processing = false
        defer {
            if !processing {
                error(nil)
            }
        }
        dataBaseService.setProcessing(true, forFile: currentProcessingFileUuid)
        if isFolder {
            HttpClient.shared.moveFolder(
                eventUuid: currentEventUuid,
                uuid: currentProcessingFileUuid,
                parentUuid: currentProcessingFile.parentUuid ?? "",
                name: name,
                lastEventId: currentProcessingFile.eventId,
                onSuccess: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.renameSuccess(json, newName: name)
                    }
                },
                onError: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.error(json)
                    }
                })
        } else {
            HttpClient.shared.moveFile(
                eventUuid: currentEventUuid,
                uuid: currentProcessingFileUuid,
                parentUuid: currentProcessingFile.parentUuid ?? "",
                name: name,
                lastEventId: currentProcessingFile.eventId,
                onSuccess: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.renameSuccess(json, newName: name)
                    }
                },
                onError: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.error(json)
                    }
                })
        }
        processing = true
    }
    
    private func renameSuccess(_ json: JSON, newName: String) {
        BFLog("OperationService::renameSuccess")
        guard let result = json["result"].string,
            result == "success",
            let data = json["data"].jsonDictionary,
            enabled else {
                error(json)
                return
        }
        let event = EventRealm()
        event.id = data["event_id"]!.int!
        event.uuid = data["event_uuid"]!.string!
        event.hashsum = data["file_hash"]?.string
        event.size = data["file_size_after_event"]?.intValue ?? 0
        event.fileUuid = currentProcessingFileUuid
        dataBaseService?.updateFileWithEvent(
            currentProcessingFileUuid, event, newName: newName)
        SnackBarManager.showSnack(Strings.renamed, showNew: false)
        operationDone()
    }
    
    private func processDelete(
        _ filesIterator: IndexingIterator<[FileRealm]>, count: Int, total: Int) {
        BFLog("OperationService::processDelete")
        guard let dataBaseService = self.dataBaseService,
            enabled else { return }
        var filesIterator = filesIterator
        let count = count + 1
        guard let file = filesIterator.next() else {
            error(nil)
            return
        }
        currentEventUuid = md5(fromString: UUID().uuidString)
        currentProcessingFileUuid = file.uuid
        currentProcessingFile = dataBaseService.getFile(byUuid: currentProcessingFileUuid)
        var processing = false
        defer {
            if !processing {
                error(nil)
            }
        }
        dataBaseService.setProcessing(true, forFile: currentProcessingFileUuid)
        if currentProcessingFile.isFolder {
            HttpClient.shared.deleteFolder(
                eventUuid: currentEventUuid,
                uuid: currentProcessingFileUuid,
                lastEventId: currentProcessingFile.eventId,
                onSuccess: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.deleteSuccess(json, filesIterator, count, total)
                    }
                },
                onError: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        if json?["errcode"].string == "FS_SYNC_NOT_FOUND" ||
                            json?["errcode"].string == "FS_SYNC_PARENT_NOT_FOUND" {
                            self?.deleteSuccess(json!, filesIterator, count, total)
                        } else {
                            self?.error(json)
                        }
                    }
                })
        } else {
            HttpClient.shared.deleteFile(
                eventUuid: currentEventUuid,
                uuid: currentProcessingFileUuid,
                lastEventId: currentProcessingFile.eventId,
                onSuccess: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.deleteSuccess(json, filesIterator, count, total)
                    }
                },
                onError: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        if json?["errcode"].string == "FS_SYNC_NOT_FOUND" ||
                            json?["errcode"].string == "FS_SYNC_PARENT_NOT_FOUND" {
                            self?.deleteSuccess(json!, filesIterator, count, total)
                        } else {
                            self?.error(json)
                        }
                    }
                })
        }
        processing = true
    }
    
    private func deleteSuccess(
        _ json: JSON, _ filesIterator: IndexingIterator<[FileRealm]>, _ count: Int, _ total: Int) {
        BFLog("OperationService::deleteSuccess")
        guard let result = json["result"].string,
            result == "success" || result == "error" ,
            enabled else {
                error(json)
                return
        }
        dataBaseService?.deleteFile(byUuid: currentProcessingFileUuid)
        
        if count > total {
            let operationStr = Strings.deleted
            SnackBarManager.showSnack(operationStr, showNew: false, showForever: false)
            operationDone()
            return
        }
        let operationStr = String(
            format: "%@\n%d %@ %d %@",
            Strings.deletingObjects,
            count,
            Strings.of,
            total,
            Strings.total)
        SnackBarManager.showSnack(operationStr, showNew: false, showForever: true)
        processDelete(filesIterator, count: count, total: total)
    }
    
    private func processMove(
        _ root: FileRealm?, _ filesIterator: IndexingIterator<[FileRealm]>,
        count: Int, total: Int) {
        var filesIterator = filesIterator
        let count = count + 1
        guard let file = filesIterator.next(),
            let dataBaseService = self.dataBaseService,
            enabled else {
            error(nil)
            return
        }
        currentEventUuid = md5(fromString: UUID().uuidString)
        currentProcessingFileUuid = file.uuid
        currentProcessingFile = dataBaseService.getFile(byUuid: currentProcessingFileUuid)
        var processing = false
        defer {
            if !processing {
                error(nil)
            }
        }
        dataBaseService.setProcessing(true, forFile: currentProcessingFileUuid)
        
        if currentProcessingFile.isFolder {
            HttpClient.shared.moveFolder(
                eventUuid: currentEventUuid,
                uuid: currentProcessingFileUuid,
                parentUuid: root?.uuid ?? "",
                name: currentProcessingFile.name!,
                lastEventId: currentProcessingFile.eventId,
                onSuccess: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.moveSuccess(json, root, filesIterator, count, total)
                    }
                },
                onError: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.error(json)
                    }
                })
        } else {
            HttpClient.shared.moveFile(
                eventUuid: currentEventUuid,
                uuid: currentProcessingFileUuid,
                parentUuid: root?.uuid ?? "",
                name: currentProcessingFile.name!,
                lastEventId: currentProcessingFile.eventId,
                onSuccess: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.moveSuccess(json, root, filesIterator, count, total)
                    }
                },
                onError: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.error(json)
                    }
                })
        }
        processing = true
    }
    
    private func moveSuccess(
        _ json: JSON, _ root: FileRealm?, _ filesIterator: IndexingIterator<[FileRealm]>,
        _ count: Int, _ total: Int) {
        BFLog("OperationService::moveSuccess")
        guard let result = json["result"].string,
            result == "success",
            let data = json["data"].jsonDictionary,
            enabled else {
                error(json)
                return
        }
        let event = EventRealm()
        event.id = data["event_id"]!.int!
        event.uuid = data["event_uuid"]!.string!
        event.hashsum = data["file_hash"]?.string
        event.size = data["file_size_after_event"]?.intValue ?? 0
        event.fileUuid = currentProcessingFileUuid
        dataBaseService?.updateFileWithEvent(
            currentProcessingFileUuid, event, newParentUuid: root?.uuid ?? "")
    
        if count > total {
            let operationStr = Strings.moved
            SnackBarManager.showSnack(operationStr, showNew: false, showForever: false)
            operationDone()
            return
        }
        let operationStr = String(
            format: "%@\n%d %@ %d %@",
            Strings.movingObjects,
            count,
            Strings.of,
            total,
            Strings.total)
        SnackBarManager.showSnack(operationStr, showNew: false, showForever: true)
        processMove(root, filesIterator, count: count, total: total)
    }
    
    private func processCopy(
        _ root: FileRealm?, _ filesIterator: IndexingIterator<[FileRealm]>, count: Int, total: Int) {
        BFLog("OperationService::processCopy")
        var filesIterator = filesIterator
        let count = count + 1
        guard let file = filesIterator.next(),
            let dataBaseService = self.dataBaseService,
            enabled else {
            error(nil)
            return
        }
        currentEventUuid = md5(fromString: UUID().uuidString)
        currentProcessingFile = FileRealm(value: file)
        currentProcessingFileUuid = UUID().uuidString
        currentProcessingFile.uuid = currentProcessingFileUuid
        currentProcessingFile.eventUuid = currentEventUuid
        currentProcessingFile.parentUuid = root?.uuid
        currentProcessingFile.isOffline = false
        currentProcessingFile.isShared = false
        currentProcessingFile.shareLink = nil
        currentProcessingFile.shareSecured = false
        currentProcessingFile.shareExpire = 0
        currentProcessingFile.isDownload = false
        currentProcessingFile.downloadedSize = 0
        currentProcessingFile.offlineFilesCount = 0
        currentProcessingFile.isDownloadActual = false
        currentProcessingFile.hashsum = nil
        let now = Date()
        currentProcessingFile.dateCreated = now
        currentProcessingFile.dateModified = now
        currentProcessingFile.name = dataBaseService.generateUniqName(
            parentPath: root?.path, baseName:file.name!, isFolder: file.isFolder)
        currentProcessingFile.path = FileTool.buildPath(root?.path, currentProcessingFile.name!)
        currentProcessingFile.isProcessing = true
        currentProcessingFile.downloadStatus = Strings.processingStatus
        let isFolder = currentProcessingFile.isFolder
        var processing = false
        defer {
            if !processing {
                error(nil)
            }
        }
        dataBaseService.addFile(currentProcessingFile)
        
        if currentProcessingFile.isFolder {
            HttpClient.shared.copyFolder(
                eventUuid: currentEventUuid,
                uuid: file.uuid!,
                parentUuid: root?.uuid ?? "",
                name: currentProcessingFile.name!,
                lastEventId: file.eventId,
                onSuccess: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.copySuccess(json, isFolder, root, filesIterator, count, total)
                    }
                },
                onError: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.dataBaseService?.deleteFile(
                            byUuid: strongSelf.currentProcessingFileUuid)
                        strongSelf.error(json)
                    }
                })
        } else {
            HttpClient.shared.createFile(
                eventUuid: currentEventUuid,
                parentUuid: root?.uuid ?? "",
                name: currentProcessingFile.name!,
                size: currentProcessingFile.size,
                hash: (try? dataBaseService.getHashAndSize(byEventUuid: file.eventUuid!).0) ?? "",
                onSuccess: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        self?.copySuccess(json, isFolder, root, filesIterator, count, total)
                    }
                },
                onError: { [weak self] json in
                    self?.dispatchQueue.async { [weak self] in
                        guard let strongSelf = self else { return }
                        strongSelf.dataBaseService?.deleteFile(
                            byUuid: strongSelf.currentProcessingFileUuid)
                        strongSelf.error(json)
                    }
                })
        }
        processing = true
    }
    
    private func copySuccess(
        _ json: JSON, _ isFolder: Bool,
        _ root: FileRealm?, _ filesIterator: IndexingIterator<[FileRealm]>,
        _ count: Int, _ total: Int) {
        BFLog("OperationService::copySuccess")
        if isFolder {
            guard let result = json["result"].string,
                result == "queued" || result == "success",
                enabled else {
                    BFLog("OperationService::copySuccess not expected response for folder")
                    self.dataBaseService?.deleteFile(byUuid: self.currentProcessingFileUuid)
                    error(json)
                    return
            }
        } else {
            guard let result = json["result"].string,
                result == "success",
                let data = json["data"].jsonDictionary,
                enabled else {
                     BFLog("OperationService::copySuccess not expected response for file")
                    self.dataBaseService?.deleteFile(byUuid: self.currentProcessingFileUuid)
                    error(json)
                    return
            }
            let event = EventRealm()
            event.id = data["event_id"]!.int!
            event.uuid = data["event_uuid"]!.string!
            event.fileUuid = data["file_uuid"]!.string!
            event.hashsum = data["file_hash"]!.string!
            event.size = data["file_size_after_event"]?.intValue ?? 0
            let date = Date(timeIntervalSince1970: data["timestamp"]!.double!)
            
            dataBaseService?.updateFileWithEvent(
                currentProcessingFileUuid, event, date: date)
        }
        
        if count > total {
            let operationStr = Strings.copied
            SnackBarManager.showSnack(operationStr, showNew: false, showForever: false)
            operationDone()
            return
        }
        let operationStr = String(
            format: "%@\n%d %@ %d %@",
            Strings.copyingObjects,
            count,
            Strings.of,
            total,
            Strings.total)
        SnackBarManager.showSnack(operationStr, showNew: false, showForever: true)
        processCopy(root, filesIterator, count: count, total: total)
    }
    
    private func processAddOffline(_ files: [FileRealm]) {
        var count = 0
        let total = files.count
        for file in files {
            if !enabled { return }
            count += 1
            if count > 1 {
                let operationStr = String(
                    format: "%@\n%d %@ %d %@",
                    Strings.addingObjectsToOffline,
                    count,
                    Strings.of,
                    total,
                    Strings.total)
                SnackBarManager.showSnack(operationStr, showNew: false, showForever: true)
            }
            dataBaseService?.addOffline(fileUuid: file.uuid!)
        }
        let operationStr = Strings.addedToOffline
        SnackBarManager.showSnack(operationStr, showNew: false, showForever: false)
        operationDone()
    }
    
    private func processRemoveOffline(_ files: [FileRealm]) {
        var count = 0
        let total = files.count
        for file in files {
            if !enabled { return }
            count += 1
            if count > 1 {
                let operationStr = String(
                    format: "%@\n%d %@ %d %@",
                    Strings.removingObjectsFromOffline,
                    count,
                    Strings.of,
                    total,
                    Strings.total)
                SnackBarManager.showSnack(operationStr, showNew: false, showForever: true)
            }
            dataBaseService?.removeOffline(fileUuid: file.uuid!)
        }
        let operationStr = Strings.removedFromOffline
        SnackBarManager.showSnack(operationStr, showNew: false, showForever: false)
        operationDone()
    }
    
    private func processCancelDownloads(_ files: [FileRealm]) {
        var fileUuids = Set<String>()
        for file in files {
            fileUuids.insert(file.uuid!)
        }
        dataBaseService?.cancelDownloads(fileUuids)
        let operationStr = files.count > 1 ?
            Strings.cancelledDownload : Strings.cancelledDownloads
        SnackBarManager.showSnack(operationStr, showNew: false, showForever: false)
        operationDone()
    }
    
    private func createFile(_ root: FileRealm?, _ copyUrl: URL, _ hashsum: String,
                            name: String? = nil, prefix: String? = nil, ext: String? = nil,
                            onDone: @escaping (JSON) -> ()) {
        currentEventUuid = md5(fromString: UUID().uuidString)
        currentProcessingFile = FileRealm()
        currentProcessingFileUuid = UUID().uuidString
        currentProcessingFile.uuid = currentProcessingFileUuid
        currentProcessingFile.eventUuid = currentEventUuid
        var name = name
        let now = Date()
        if name == nil {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd_HHmmss"
            name = String(
                format: "%@_%@.%@", prefix!, dateFormatter.string(from: now), ext!)
        }
        name = dataBaseService?.generateUniqName(
            parentPath: root?.path, baseName: name!, isFolder: false, suffix: "") ?? name!
        currentProcessingFile.name = name!
        currentProcessingFile.isFolder = false
        currentProcessingFile.isDownload = true
        currentProcessingFile.isOnlyDownload = false
        currentProcessingFile.dateCreated = now
        currentProcessingFile.dateModified = now
        currentProcessingFile.parentUuid = root?.uuid ?? nil
        currentProcessingFile.path = FileTool.buildPath(root?.path, name!)
        currentProcessingFilePath = currentProcessingFile.path
        currentProcessingFile.isProcessing = true
        currentProcessingFile.downloadStatus = Strings.processingStatus
        let size = Int(FileTool.size(ofFile: copyUrl))
        currentProcessingFile.size = size
        let event = EventRealm()
        event.uuid = currentEventUuid
        event.size = size
        event.hashsum = hashsum
        var processing = false
        defer {
            if !processing {
                dataBaseService?.deleteEvent(byUuid: self.currentEventUuid)
                error(nil)
            }
        }
        dataBaseService?.addEvent(event)
        defer {
            if !processing {
                dataBaseService?.deleteFile(byUuid: self.currentProcessingFileUuid)
                error(nil)
            }
        }
        dataBaseService?.addFile(currentProcessingFile)
        
        HttpClient.shared.createFile(
            eventUuid: currentEventUuid,
            parentUuid: currentProcessingFile.parentUuid ?? "",
            name: name!,
            size: size,
            hash: hashsum,
            onSuccess: { [weak self] json in
                self?.dispatchQueue.async {
                    onDone(json)
                }
            },
            onError: { [weak self] json in
                self?.dispatchQueue.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.dataBaseService?.deleteFile(byUuid: strongSelf.currentProcessingFileUuid)
                    strongSelf.dataBaseService?.deleteEvent(byUuid: strongSelf.currentEventUuid)
                    if json?["errcode"].string == "WRONG_DATA",
                        let varFileName = json?["error_data"]["var_file_name"].string {
                        strongSelf.createFile(
                            root, copyUrl, hashsum, name: varFileName, onDone: onDone)
                    } else {
                        strongSelf.error(json)
                    }
                }
        })
        processing = true
    }
    
    private func processAddPhoto(_ root: FileRealm?, _ data: Data, _ share: Bool) {
        BFLog("OperationService::processAddPhoto")
        guard let hashsum = FileTool.getFileHashViaSignature(data) else {
            self.error(nil)
            return
        }
        let copyUrl = FileTool.copiesDirectory.appendingPathComponent(
            hashsum, isDirectory: false)
        if !FileTool.exists(copyUrl) {
            do {
                try data.write(to: copyUrl)
            } catch {
                self.error(nil)
                return
            }
        }
        createFile(
            root, copyUrl, hashsum, prefix: "IMG", ext: "jpg",
            onDone: { [weak self] json in
                self?.addFileSuccess(json, share)
        })
    }
    
    func addFileSuccess(_ json: JSON, _ share: Bool) {
        guard let result = json["result"].string,
            result == "success",
            let data = json["data"].jsonDictionary,
            enabled else {
                BFLog("OperationService::addFileSuccess not expected response for file")
                self.dataBaseService?.deleteFile(byUuid: self.currentProcessingFileUuid)
                self.dataBaseService?.deleteEvent(byUuid: self.currentEventUuid)
                error(json)
                return
        }
        let event = EventRealm()
        event.id = data["event_id"]!.int!
        event.uuid = data["event_uuid"]!.string!
        event.fileUuid = data["file_uuid"]!.string!
        event.hashsum = data["file_hash"]!.string!
        event.size = data["file_size_after_event"]?.intValue ?? 0
        let date = Date(timeIntervalSince1970: data["timestamp"]!.double!)
        
        dataBaseService?.updateFileWithEvent(
            currentProcessingFileUuid, event, date: date)
        
        if share {
            HttpClient.shared.shareEnable(
                uuid: data["file_uuid"]!.string!, ttl: 0, password: "", keepPassword: false,
                onSuccess: { [weak self] response in
                    let shareUrl = response["data"]["share_link"].string!
                    DispatchQueue.main.async {
                        let activityViewController = UIActivityViewController(
                            activityItems: [shareUrl], applicationActivities: nil)
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        appDelegate.window?.rootViewController?.present(
                            activityViewController, animated: true, completion: nil)
                    }
                    SnackBarManager.showSnack(Strings.addedSuccessfully, showNew: false)
                    self?.operationDone()
                },
                onError: { [weak self] error in
                    SnackBarManager.showSnack(Strings.addedSuccessfully, showNew: false)
                    self?.operationDone()
            })
        } else {
            SnackBarManager.showSnack(Strings.addedSuccessfully, showNew: false)
            operationDone()
        }
    }
    
    private func processImportVideo(_ root: FileRealm?, _ url: URL, _ share: Bool) {
        BFLog("OperationService::processImportVideo")
        guard let hashsum = FileTool.getFileHashViaSignature(url) else {
            self.error(nil)
            return
        }
        let copyUrl = FileTool.copiesDirectory.appendingPathComponent(
            hashsum, isDirectory: false)
        if !FileTool.exists(copyUrl) {
            FileTool.copy(from: url, to: copyUrl)
        }
        createFile(
            root, copyUrl, hashsum, prefix: "VID", ext: url.pathExtension,
            onDone: { [weak self] json in
                self?.addFileSuccess(json, share)
        })
    }
    
    private func processImportFiles(
        _ root: FileRealm?, _ urls: [URL], _ deleteAfterImport: Bool, _ share: Bool) {
        var dirsToImport = [(URL, URL)]()
        var filesToImport = [(URL, URL)]()
        for url in urls {
            guard let resourceValues = try? url.resourceValues(
                forKeys: Set<URLResourceKey>([.isDirectoryKey])),
                let isDir = resourceValues.isDirectory else {
                    self.error(nil)
                    return
            }
            let rootUrl = url.deletingLastPathComponent()
            if isDir {
                dirsToImport.append((rootUrl, url))
                let (dirs, files) = getChilds(of: url)
                dirsToImport.append(contentsOf: dirs.map({ (rootUrl, $0) }))
                filesToImport.append(contentsOf: files.map({ (rootUrl, $0) }))
            } else {
                filesToImport.append((rootUrl, url))
            }
        }
        let urlsCount = dirsToImport.count + filesToImport.count
        BFLog("OperationService::processImportFiles, urlsCount: %d",
             urlsCount)
        if urlsCount > 1 {
            SnackBarManager.showSnack(
                String(format: "%@\n1 %@ %d %@",
                       Strings.addingObjects,
                       Strings.of,
                       urlsCount,
                       Strings.total),
                showNew: false,
                showForever: true)
        }
        processImport(
            root, urls, share, dirsToImport.makeIterator(), filesToImport.makeIterator(),
            count: 1, total: urlsCount, onDone: {
                if deleteAfterImport {
                    for url in urls {
                        FileTool.delete(url)
                    }
                }
        })
    }
    
    private func processImport(
        _ root: FileRealm?, _ urls: [URL], _ share: Bool,
        _ dirsToImportIterator: IndexingIterator<[(URL, URL)]>,
        _ filesToImportIterator: IndexingIterator<[(URL, URL)]>,
        count: Int, total: Int, onDone: (() -> ())?,
        renamedPaths: [String: String] = [:],
        sharingUrls: [String] = []) {
        if !enabled { return }
        
        var dirsToImportIterator = dirsToImportIterator
        var filesToImportIterator = filesToImportIterator
        
        if let (dir, subDir) = dirsToImportIterator.next() {
            importDir(
                root, dir, subDir, count: count, total: total,
                share: share && urls.contains(subDir), sharingUrls: sharingUrls,
                onDone: { [weak self] count, sharingUrls in
                    var renamedPaths = renamedPaths
                    renamedPaths[subDir.relativePath(from: dir)!] = self?.currentProcessingFilePath
                    self?.processImport(
                        root, urls, share, dirsToImportIterator, filesToImportIterator,
                        count: count, total: total, onDone: onDone,
                        renamedPaths: renamedPaths, sharingUrls: sharingUrls)
                },
                renamedPaths: renamedPaths)
        } else if let (dir, subFile) = filesToImportIterator.next() {
            importFile(
                root, dir, subFile, count: count, total: total,
                share: share && urls.contains(subFile), sharingUrls: sharingUrls,
                onDone: { [weak self] count, sharingUrls in
                    self?.processImport(
                        root, urls, share, dirsToImportIterator, filesToImportIterator,
                        count: count, total: total, onDone: onDone,
                        renamedPaths: renamedPaths, sharingUrls: sharingUrls)
                },
                renamedPaths: renamedPaths)
        } else {
            if !sharingUrls.isEmpty {
                DispatchQueue.main.async {
                    let activityViewController = UIActivityViewController(
                        activityItems: sharingUrls, applicationActivities: nil)
                    let appDelegate = UIApplication.shared.delegate as! AppDelegate
                    appDelegate.window?.rootViewController?.present(
                        activityViewController, animated: true, completion: nil)
                }
            }
            let operationStr = Strings.addedSuccessfully
            SnackBarManager.showSnack(operationStr, showNew: false, showForever: false)
            operationDone()
            onDone?()
            return
        }
    }
    
    private func importDir(
        _ root: FileRealm?, _ dir: URL, _ subDir: URL,
        count: Int, total: Int, share: Bool, sharingUrls: [String],
        onDone: @escaping (Int, [String]) -> (),
        renamedPaths: [String: String]) {
        guard let dataBaseService = self.dataBaseService,
            enabled else {
            error(nil)
            return
        }
        let count = count + 1
        let relPath = subDir.relativePath(from: dir)!
        let name = FileTool.getNameFromPath(relPath)
        let parentPath = FileTool.getParentPath(relPath)
        let renamedParentPath = renamedPaths[parentPath ?? ""]
        let fullParentPath = parentPath == nil ?
            root?.path : (renamedParentPath == nil ?
                FileTool.buildPath(root?.path, parentPath!) : renamedParentPath)
        var parentFile = dataBaseService.getFile(byPath: fullParentPath)
        if parentFile == nil && root != nil {
            error(nil)
            return
        }
        parentFile = parentFile == nil ? nil : FileRealm(value: parentFile!)
        
        createFolder(parentFile, name, generateUniqName: true,
                     onDone: { [weak self] json in
            self?.dispatchQueue.async { [weak self] in
                self?.folderImportSuccess(
                    json, count: count, total: total, share: share, sharingUrls: sharingUrls,
                    onDone: onDone)
            }
        })
    }
    
    private func folderImportSuccess(
        _ json: JSON, count: Int, total: Int, share: Bool, sharingUrls: [String],
        onDone: @escaping (Int, [String]) -> ()) {
        guard let result = json["result"].string,
            result == "success",
            let data = json["data"].jsonDictionary,
            enabled else {
                dataBaseService?.deleteFile(byUuid: self.currentProcessingFileUuid)
                error(json)
                return
        }
        let event = EventRealm()
        event.id = data["event_id"]!.int!
        event.uuid = data["event_uuid"]!.string!
        event.fileUuid = data["folder_uuid"]!.string!
        let date = Date(timeIntervalSince1970: data["timestamp"]!.double!)
        
        dataBaseService?.updateFileWithEvent(
            currentProcessingFileUuid, event, date: date)
        
        if share {
            HttpClient.shared.shareEnable(
                uuid: data["folder_uuid"]!.string!, ttl: 0, password: "", keepPassword: false,
                onSuccess: { [weak self] response in
                    var sharingUrls = sharingUrls
                    sharingUrls.append(response["data"]["share_link"].string!)
                    self?.importItemDone(
                        count: count, total: total, sharingUrls: sharingUrls, onDone: onDone)
                },
                onError: { [weak self] error in
                    self?.importItemDone(
                        count: count, total: total, sharingUrls: sharingUrls, onDone: onDone)
                })
        } else {
            importItemDone(
                count: count, total: total, sharingUrls: sharingUrls, onDone: onDone)
        }
    }
    
    private func importFile(
        _ root: FileRealm?, _ dir: URL, _ subFile: URL,
        count: Int, total: Int, share: Bool, sharingUrls: [String],
        onDone: @escaping (Int, [String]) -> (),
        renamedPaths: [String: String]) {
        guard let dataBaseService = self.dataBaseService,
            enabled,
            let hashsum = FileTool.getFileHashViaSignature(subFile) else {
                error(nil)
                return
        }
       
        let count = count + 1
        let relPath = subFile.relativePath(from: dir)!
        let name = FileTool.getNameFromPath(relPath)
        let parentPath = FileTool.getParentPath(relPath)
        let renamedParentPath = renamedPaths[parentPath ?? ""]
        let fullParentPath = parentPath == nil ?
            root?.path : (renamedParentPath == nil ?
                FileTool.buildPath(root?.path, parentPath!) : renamedParentPath)
        var parentFile = dataBaseService.getFile(byPath: fullParentPath)
        if parentFile == nil && root != nil {
            error(nil)
            return
        }
        parentFile = parentFile == nil ? nil : FileRealm(value: parentFile!)
        
        let copyUrl = FileTool.copiesDirectory.appendingPathComponent(
            hashsum, isDirectory: false)
        if !FileTool.exists(copyUrl) {
            FileTool.copy(from: subFile, to: copyUrl)
        }
        createFile(parentFile, copyUrl, hashsum, name: name, onDone: { [weak self] json in
            self?.fileImportSuccess(
                json, count: count, total: total, share: share, sharingUrls: sharingUrls,
                onDone: onDone)
        })
    }
    
    private func fileImportSuccess(
        _ json: JSON, count: Int, total: Int, share: Bool, sharingUrls: [String],
        onDone: @escaping (Int, [String]) -> ()) {
        guard let result = json["result"].string,
            result == "success",
            let data = json["data"].jsonDictionary,
            enabled else {
                dataBaseService?.deleteFile(byUuid: self.currentProcessingFileUuid)
                error(json)
                return
        }
        let event = EventRealm()
        event.id = data["event_id"]!.int!
        event.uuid = data["event_uuid"]!.string!
        event.size = data["file_size_after_event"]!.int!
        event.fileUuid = data["file_uuid"]!.string!
        event.hashsum = data["file_hash"]!.string!
        let date = Date(timeIntervalSince1970: data["timestamp"]!.double!)
        
        dataBaseService?.updateFileWithEvent(
            currentProcessingFileUuid, event, date: date)
        
        if share {
            HttpClient.shared.shareEnable(
                uuid: data["file_uuid"]!.string!, ttl: 0, password: "", keepPassword: false,
                onSuccess: { [weak self] response in
                    var sharingUrls = sharingUrls
                    sharingUrls.append(response["data"]["share_link"].string!)
                    self?.importItemDone(
                        count: count, total: total, sharingUrls: sharingUrls, onDone: onDone)
                },
                onError: { [weak self] error in
                    self?.importItemDone(
                        count: count, total: total, sharingUrls: sharingUrls, onDone: onDone)
                })
        } else {
            importItemDone(
                count: count, total: total, sharingUrls: sharingUrls, onDone: onDone)
        }
    }
    
    private func importItemDone(
        count: Int, total: Int, sharingUrls: [String],
        onDone: @escaping (Int, [String]) -> ()) {
        if count <= total {
            let operationStr = String(
                format: "%@\n%d %@ %d %@",
                Strings.addingObjects,
                count,
                Strings.of,
                total,
                Strings.total)
            SnackBarManager.showSnack(operationStr, showNew: false, showForever: true)
        }
        onDone(count, sharingUrls)
    }
    
    private func getChilds(of url: URL) -> ([URL], [URL]) {
        let resourceKeys : [URLResourceKey] = [.isDirectoryKey]
        var dirsToImport = [URL]()
        var filesToImport = [URL]()
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: resourceKeys, options: [],
            errorHandler: { (url, error) -> Bool in
                BFLogErr("OperationService::getChilds directoryEnumerator error at %@: %@",
                         url.path, error.localizedDescription)
                return true
        }) else { return (dirsToImport, filesToImport) }
        
        for case let fileUrl as URL in enumerator {
            guard let resourceValues = try? fileUrl.resourceValues(
                forKeys: Set(resourceKeys)),
                let isDirectory = resourceValues.isDirectory else { continue }
            if isDirectory {
                dirsToImport.append(fileUrl)
            } else {
                filesToImport.append(fileUrl)
            }
        }
        return (dirsToImport, filesToImport)
    }
}
