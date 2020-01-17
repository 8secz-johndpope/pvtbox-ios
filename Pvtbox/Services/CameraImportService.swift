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
import Photos

class CameraImportService: NSObject, PHPhotoLibraryChangeObserver {
    private let dq = DispatchQueue(
        label: "net.pvtbox.service.camera", qos: .background)
    
    private weak var dataBaseService: DataBaseService?
    private weak var temporaryFilesManager: TemporaryFilesManager?
    
    private var photos: PHFetchResult<PHAsset>?
    private var count: Int = 0
    private var importing = false
    private var index: Int = 0
    
    private var hasUpdates = false
    
    init(_ dataBaseService: DataBaseService?, _ temporaryFilesManager: TemporaryFilesManager?) {
        self.dataBaseService = dataBaseService
        self.temporaryFilesManager = temporaryFilesManager
        super.init()
        dq.async { [weak self] in
            self?.start()
        }
    }
    
    public func start() {
        if PreferenceService.importCameraEnabled {
            let status = PHPhotoLibrary.authorizationStatus()
            if status == .authorized {
                importCamera()
            } else {
                UIApplication.shared.keyWindow?.makeToast(
                    Strings.cameraSyncDisabledByPermission)
                PreferenceService.importCameraEnabled = false
                SnackBarManager.showSnack(
                    Strings.importCameraCancelled,
                    showNew: true,
                    showForever: false)
            }
        }
    }
    
    public func stop() {
        BFLog("CameraImportService::stop")
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        if importing {
            importing = false
            SnackBarManager.showSnack(
                Strings.importCameraCancelled,
                showNew: true,
                showForever: false)
            dataBaseService?.updateOwnDeviceStatus(importingCamera: false)
        }
        hasUpdates = false
    }
    
    private func importCamera() {
        BFLog("CameraImportService::importCamera")
        if PreferenceService.cameraFolderUuid == nil {
            dataBaseService?.updateOwnDeviceStatus(importingCamera: true)
            SnackBarManager.showSnack(Strings.importingCamera, showNew: true, showForever: true)
            createCameraFolder()
        } else {
            importObjects(subscribe: true)
        }
    }
    
    private func createCameraFolder(_ name: String? = nil) {
        guard let dataBaseService = dataBaseService else { return }
        var name = dataBaseService.generateUniqName(
            parentPath: nil,
            baseName: String(format: "Camera from %@", Const.nodeName),
            isFolder: true,
            suffix: "")
        let uuid = UUID().uuidString
        let file = FileRealm()
        let eventUuid = md5(fromString: uuid)
        file.uuid = uuid
        file.name = name
        file.isFolder = true
        let now = Date()
        file.dateCreated = now
        file.dateModified = now
        file.parentUuid = nil
        file.path = FileTool.buildPath(nil, name)
        file.isProcessing = true
        file.downloadStatus = Strings.processingStatus
        var processing = false
        defer {
            if !processing {
                dataBaseService.deleteFile(byUuid: uuid)
            }
        }
        dataBaseService.addFile(file)
        HttpClient.shared.createFolder(
            eventUuid: eventUuid,
            parentUuid: "",
            name: name,
            onSuccess: { [weak self] json in
                self?.dq.async { [weak self] in
                    guard let result = json["result"].string,
                        result == "success",
                        let data = json["data"].jsonDictionary else {
                            self?.dataBaseService?.deleteFile(byUuid: uuid)
                            self?.createCameraFolder()
                            return
                    }
                    let event = EventRealm()
                    event.id = data["event_id"]!.int!
                    event.uuid = data["event_uuid"]!.string!
                    event.fileUuid = data["folder_uuid"]!.string!
                    let date = Date(timeIntervalSince1970: data["timestamp"]!.double!)
                    
                    self?.dataBaseService?.updateFileWithEvent(
                        uuid, event, date: date)
                    PreferenceService.cameraFolderUuid = data["folder_uuid"]!.string!
                    self?.importObjects(notify: true, subscribe: true)
                }
            },
            onError: { [weak self] json in
                self?.dq.async { [weak self] in
                    guard let strongSelf = self,
                        let dataBaseService = strongSelf.dataBaseService else { return }
                    dataBaseService.deleteFile(byUuid: uuid)
                    
                    if json?["errcode"].string == "WRONG_DATA",
                        let varFileName = json?["error_data"]["var_file_name"].string {
                        strongSelf.createCameraFolder(varFileName)
                    } else {
                        strongSelf.createCameraFolder()
                    }
                }
        })
        processing = true
    }
    
    private func importObjects(notify: Bool = false, subscribe: Bool = false) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        fetchOptions.predicate = NSPredicate(format: "creationDate > %@", PreferenceService.cameraLastPhotoCreationDate! as NSDate)
        photos = PHAsset.fetchAssets(with: fetchOptions)
        if subscribe {
            PHPhotoLibrary.shared().register(self)
        }
        
        index = 0
        count = photos?.count ?? 0
        if count > 0 {
            importing = true
            dataBaseService?.updateOwnDeviceStatus(importingCamera: true)
            importObject()
        } else {
             importing = false
            if notify {
                if hasUpdates {
                    hasUpdates = false
                    importObjects(notify: notify)
                    return
                }
                dataBaseService?.updateOwnDeviceStatus(importingCamera: false)
                SnackBarManager.showSnack(
                    Strings.importedCamera,
                    showNew: false,
                    showForever: false)
            }
        }
    }
    
    private func importObject() {
        if !PreferenceService.importCameraEnabled {
            stop()
            return
        }
        if index < count {
            SnackBarManager.showSnack(
                String(format: "%@\n%d %@ %d %@\n",
                       Strings.importingCamera,
                       index + 1,
                       Strings.of,
                       count,
                       Strings.total),
                showNew: false,
                showForever: true)
        } else {
            if hasUpdates {
                hasUpdates = false
                importObjects(notify: true)
                return
            }
            SnackBarManager.showSnack(
                Strings.importedCamera,
                showNew: false,
                showForever: false)
            dataBaseService?.updateOwnDeviceStatus(importingCamera: false)
            importing = false
            return
        }
        guard let object = photos?.object(at: index) else {
            importing = false
            dataBaseService?.updateOwnDeviceStatus(importingCamera: false)
            return
        }
        guard let resource = PHAssetResource.assetResources(for: object).first else {
            index += 1
            self.importObject()
            return
        }
        
        let tempFile = TemporaryFile()
        FileTool.createFile(tempFile.url)
        guard let fileHandle = try? FileHandle(forWritingTo: tempFile.url) else {
            self.importObject()
            return
        }
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        options.progressHandler = { [weak self] progress in
            guard let strongSelf = self,
                strongSelf.importing else { return }
            BFLog("CameraImportService::importObject progress: %f", progress)
            SnackBarManager.showSnack(
                String(format: "%@\n%d %@ %d %@\n%d%%",
                       Strings.importingCamera,
                       strongSelf.index + 1,
                       Strings.of,
                       strongSelf.count,
                       Strings.total,
                       Int(progress * 100)),
                showNew: false,
                showForever: true)
        }
        PHAssetResourceManager.default().requestData(
            for: resource, options: options,
            dataReceivedHandler: { data in
                fileHandle.write(data)
            },
            completionHandler: { [weak self] error in
                fileHandle.closeFile()
                if error != nil {
                    BFLogErr("CameraImportService::importObject error: %@",
                             String(describing: error))
                    self?.importObject()
                    return
                } else {
                    self?.dq.async { [weak self] in
                        self?.createFile(
                            resource.originalFilename, tempFile,
                            resource.assetLocalIdentifier,
                            photoCreationDate: object.creationDate)
                    }
                }
                
        })
    }

    private func createFile(_ name: String, _ tmpFile: TemporaryFile,
                            _ localIdentifier: String, photoCreationDate: Date?) {
        guard let parentUuid = PreferenceService.cameraFolderUuid,
            let dataBaseService = dataBaseService else {
            stop()
            return
        }
        
        if dataBaseService.getFile(byLocalIdentifier: localIdentifier, with: parentUuid) != nil {
            index += 1
            importObject()
            return
        }
        
        let url = tmpFile.url
        
        let isHeic = name.lowercased().hasSuffix(".heic")
        let isHeif = name.lowercased().hasSuffix(".heif")
        var wasConverted = false
        var name = name
        if PreferenceService.convertHeicEnabled && (isHeic || isHeif) {
            if let image = CIImage(contentsOf: url),
                let data = CIContext().jpegRepresentation(
                    of: image, colorSpace: CGColorSpaceCreateDeviceRGB()) {
                try? data.write(to: url)
                name.replaceSubrange(name.lowercased().range(of: isHeic ? ".heic" : ".heif", options: .backwards)!, with: ".jpeg")
                wasConverted = true
            }
        }
        
        guard let hashsum = FileTool.getFileHashViaSignature(url) else {
            importObject()
            return
        }
        
        let uuid = UUID().uuidString
        let eventUuid = md5(fromString: uuid)
        let file = FileRealm()
        file.uuid = uuid
        file.localIdentifier = localIdentifier
        file.convertedToJpeg = wasConverted
        file.eventUuid = eventUuid
        let now = Date()
        file.name = name
        file.isFolder = false
        file.dateCreated = now
        file.dateModified = now
        file.parentUuid = parentUuid
        file.isProcessing = true
        file.downloadStatus = Strings.processingStatus
        let size = Int(FileTool.size(ofFile: url))
        file.size = size
        let event = EventRealm()
        event.uuid = eventUuid
        event.size = size
        event.hashsum = hashsum
        dataBaseService.addEvent(event)
        let tmpUrl = FileTool.tmpDirectory.appendingPathComponent(hashsum)
        FileTool.move(from: tmpFile.url, to: tmpUrl)
        temporaryFilesManager?.touch(tmpUrl)
        var processing = false
        defer {
            if !processing {
                dataBaseService.deleteFile(byUuid: uuid)
                importObject()
            }
        }
        dataBaseService.addFile(file, generateUniqName: true)
        
        HttpClient.shared.createFile(
            eventUuid: eventUuid,
            parentUuid: parentUuid,
            name: file.name!,
            size: size,
            hash: hashsum,
            onSuccess: { [weak self] json in
                self?.dq.async {
                    guard let result = json["result"].string,
                        result == "success",
                        let data = json["data"].jsonDictionary else {
                            self?.dataBaseService?.deleteFile(byUuid: uuid)
                            self?.importObject()
                            return
                    }
                    let event = EventRealm()
                    event.id = data["event_id"]!.int!
                    event.uuid = data["event_uuid"]!.string!
                    event.size = data["file_size_after_event"]!.int!
                    event.fileUuid = data["file_uuid"]!.string!
                    event.hashsum = data["file_hash"]!.string!
                    let date = Date(timeIntervalSince1970: data["timestamp"]!.double!)
                    
                    self?.dataBaseService?.updateFileWithEvent(
                        uuid, event, date: date)
                    if photoCreationDate != nil {
                        PreferenceService.cameraLastPhotoCreationDate = photoCreationDate!
                    }
                    self?.index += 1
                    self?.importObject()
                }
            },
            onError: { [weak self] json in
                self?.dq.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.dataBaseService?.deleteFile(byUuid: uuid)
                    if json?["errcode"].string == "WRONG_DATA",
                        let varFileName = json?["error_data"]["var_file_name"].string {
                        strongSelf.createFile(
                            varFileName, tmpFile, localIdentifier,
                            photoCreationDate: photoCreationDate)
                    } else {
                        self?.importObject()
                    }
                }
        })
        processing = true
    }

    internal func photoLibraryDidChange(_ changeInstance: PHChange) {
        dq.async { [weak self] in
            guard let strongSelf = self else { return }
            if let details = changeInstance.changeDetails(for: strongSelf.photos!),
                details.hasIncrementalChanges,
                details.insertedObjects.count > 0 {
                BFLog("CameraImportService::photoLibraryDidChange: %@ (%@)", String(describing: changeInstance), String(describing: details))
                if strongSelf.importing {
                    strongSelf.hasUpdates = true
                } else {
                    strongSelf.importObjects()
                }
            }
        }
    }
}
