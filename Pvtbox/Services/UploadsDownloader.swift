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

class UploadsDownloader {
    private static let retryLimit = 3
    
    private let dq = DispatchQueue(
        label: "net.pvtbox.service.uploads", qos: .background)
    
    private weak var dataBaseService: DataBaseService?
    private weak var speedCalculator: SpeedCalculator?
    private weak var signalServerService: SignalServerService?
    
    private var tasks = [Int: JSON]()
    private var currentTask: Int? = nil
    private var retries = 0
    
    init(_ dataBaseService: DataBaseService?,
         _ speedCalculator: SpeedCalculator?,
         _ signalServerService: SignalServerService?) {
        self.dataBaseService = dataBaseService
        self.speedCalculator = speedCalculator
        self.signalServerService = signalServerService
    }
    
    public func add(_ upload: JSON) {
        dq.async { [weak self] in
            BFLog("UploadsDownloader::add %@", String(describing: upload))
            if let id = upload["upload_id"].int {
                self?.tasks[id] = upload
                if self?.currentTask == nil {
                    self?.startNextTask()
                }
            }
        }
    }
    
    public func cancel(_ upload: JSON) {
        dq.async { [weak self] in
            BFLog("UploadsDownloader::cancel %@", String(describing: upload))
            self?.tasks.removeValue(forKey: upload.int!)
            if self?.currentTask == upload.int! {
                self?.stopTask(upload.int!)
                self?.startNextTask()
            }
        }
    }
    
    public func stop() {
        BFLog("UploadsDownloader::stop")
        currentTask = nil
        retries = 0
        tasks.removeAll()
    }
    
    private func startNextTask() {
        guard let (id, upload) = tasks.first else { return }
        let name = upload["upload_name"].string!
        SnackBarManager.showSnack(
            String(format: "%@ \"%@\"...\n", Strings.downloadingFile, name),
            showNew: true, showForever: true)
        currentTask = id
        let url = FileTool.tmpDirectory.appendingPathComponent(String(format: "%d", id))
        FileTool.createFile(url)
        let fileHandle = try? FileHandle(forWritingTo: url)
        var downloaded = 0.0
        var lastDownloaded = 0.0
        let size = upload["upload_size"].doubleValue
        let formattedSize = ByteFormatter.instance.string(fromByteCount: Int64(size))
        HttpClient.shared.downloadUpload(
            id,
            onSuccess: { [weak self] json in
                self?.dq.async { [weak self] in
                    BFLog("UploadsDownloader::onSuccess")
                    fileHandle?.closeFile()
                    self?.onTaskCompleted(id, url, upload)
                }
            },
            onError: { [weak self] json in
                self?.dq.async { [weak self] in
                    BFLog("UploadsDownloader::onError")
                    fileHandle?.closeFile()
                    self?.onTaskError(id)
                }
            },
            onData: { [weak self] data, request in
                self?.dq.async { [weak self] in
                    BFLog("UploadsDownloader::onData %d", data.count)
                    if self?.currentTask != id {
                        request?.cancel()
                        fileHandle?.closeFile()
                        FileTool.delete(url)
                        SnackBarManager.showSnack(
                            Strings.downloadCancelled,
                            showNew: false, showForever: false)
                        self?.startNextTask()
                        return
                    }
                    fileHandle?.write(data)
                    let count = Double(data.count)
                    self?.speedCalculator?.onDataDownloaded(count)
                    downloaded += count
                    if (downloaded - lastDownloaded) / size > 0.01 {
                        lastDownloaded = downloaded
                        self?.onTaskProgress(
                            id, Int(lastDownloaded / size * 100), name, formattedSize)
                    }
                }
        })
    }
    
    private func stopTask(_ id: Int) {
        self.currentTask = nil
        retries = 0
    }
    
    private func onTaskCompleted(_ id: Int, _ url: URL, _ upload: JSON) {
        let size = Int(FileTool.size(ofFile: url))
        let expectedSize = upload["upload_size"].intValue
        if size != expectedSize {
            BFLogWarn("UploadsDownloader::onTaskCompleted %d, size missmatch, expected: %d, actual: %d",
                      id, expectedSize, size)
            FileTool.delete(url)
            onTaskError(id)
            return
        }
        let hash = FileTool.getFileHash(url)
        let expectedHash = upload["upload_md5"].string!
        if hash != expectedHash {
            BFLogWarn("UploadsDownloader::onTaskCompleted %d, hash missmatch, expected: %d, actual: %d",
                      id, expectedHash, String(describing: hash))
            FileTool.delete(url)
            onTaskError(id)
            return
        }
    
        guard let hashsum = FileTool.getFileHashViaSignature(url) else {
            BFLogWarn("UploadsDownloader::onTaskCompleted %d, failed to calculate hashsum", id)
            FileTool.delete(url)
            onTaskError(id)
            return
        }
        let copyUrl = FileTool.copiesDirectory.appendingPathComponent(
            hashsum, isDirectory: false)
        if !FileTool.exists(copyUrl) {
            FileTool.move(from: url, to: copyUrl)
        }
        
        createFile(id, upload["upload_name"].string!, upload["folder_uuid"].string, size, hashsum)
    }
    
    private func createFile(
        _ id: Int, _ name: String, _ folderUuid: String?, _ size: Int, _ hashsum: String) {
        SnackBarManager.showSnack(
            String(format: "%@ \"%@\"...\n", Strings.addingFile, name),
            showNew: false, showForever: true)
        
        let uuid = UUID().uuidString
        let eventUuid = md5(fromString: uuid)
        let file = FileRealm()
        file.uuid = uuid
        file.eventUuid = eventUuid
        var name = name
        let now = Date()
        var parent: FileRealm? = nil
        if let parentUuid = folderUuid {
            parent = dataBaseService?.getFile(byUuid: parentUuid)
            if parent == nil {
                BFLogWarn("UploadsDownloader::createFIle %d, can't find parent in db", id)
                onTaskError(id)
                return
            }
        }
        name = dataBaseService?.generateUniqName(
            parentPath: parent?.path, baseName: name, isFolder: false, suffix: "") ?? name
        file.name = name
        file.isFolder = false
        file.isDownload = true
        file.isOnlyDownload = false
        file.dateCreated = now
        file.dateModified = now
        file.parentUuid = parent?.uuid ?? nil
        file.path = FileTool.buildPath(parent?.path, name)
        file.isProcessing = true
        file.downloadStatus = Strings.processingStatus
        file.size = size
        let event = EventRealm()
        event.uuid = eventUuid
        event.size = size
        event.hashsum = hashsum
        dataBaseService?.addEvent(event)
        var processing = false
        defer {
            if !processing {
                dataBaseService?.deleteFile(byUuid: uuid)
            }
        }
        dataBaseService?.addFile(file)
        
        HttpClient.shared.createFile(
            eventUuid: eventUuid,
            parentUuid: file.parentUuid ?? "",
            name: name,
            size: size,
            hash: hashsum,
            onSuccess: { [weak self] json in
                self?.dq.async { [weak self] in
                    guard let result = json["result"].string,
                        result == "success",
                        let data = json["data"].jsonDictionary else {
                            self?.dataBaseService?.deleteFile(byUuid: uuid)
                            self?.onTaskError(id)
                            return
                    }
                    let event = EventRealm()
                    event.id = data["event_id"]!.int!
                    event.uuid = data["event_uuid"]!.string!
                    event.size = data["file_size_after_event"]!.int!
                    event.fileUuid = data["file_uuid"]!.string!
                    event.hashsum = data["file_hash"]!.string!
                    let date = Date(timeIntervalSince1970: data["timestamp"]!.double!)
                    
                    self?.dataBaseService?.updateFileWithEvent(uuid, event, date: date)
                    self?.onTaskDone(id)
                }
            },
            onError: { [weak self] json in
                self?.dq.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.dataBaseService?.deleteFile(byUuid: uuid)
                    if json?["errcode"].string == "WRONG_DATA",
                        let varFileName = json?["error_data"]["var_file_name"].string {
                        strongSelf.createFile(id, varFileName, folderUuid, size, hashsum)
                    } else {
                        BFLogWarn("UploadsDownloader::createFIle %d, can't find parent in db", id)
                        self?.onTaskError(id)
                    }
                }
        })
        processing = true
    }
    
    private func onTaskError(_ id: Int) {
        if currentTask == nil {
            startNextTask()
            return
        }
        let msg: [String: Any] = ["operation": "upload_failed", "data": [
            "upload_id": id,
            ]]
        let message = JSONCoder.encode(msg)!
        signalServerService?.send(message)
        
        SnackBarManager.showSnack(
            String(format: "%@", Strings.operationError),
            showNew: false, showForever: false)
        
        currentTask = nil
        retries += 1
        if retries >= UploadsDownloader.retryLimit {
            tasks.removeValue(forKey: id)
            retries = 0
        }
        startNextTask()
    }
    
    private func onTaskDone(_ id: Int) {
        let msg: [String: Any] = ["operation": "upload_complete", "data": [
            "upload_id": id,
            ]]
        let message = JSONCoder.encode(msg)!
        signalServerService?.send(message)
        
        SnackBarManager.showSnack(
            String(format: "%@", Strings.downloadedAndAddedFile),
            showNew: false, showForever: false)
        
        currentTask = nil
        retries = 0
        tasks.removeValue(forKey: id)
        startNextTask()
    }
    
    private func onTaskProgress(_ id: Int, _ progress: Int, _ name: String, _ formattedSize: String) {
        if currentTask == nil {
            return
        }
        let msg: [String: Any] = ["operation": "upload_progress", "data": [
            "upload_id": id,
            "progress": progress,
            ]]
        let message = JSONCoder.encode(msg)!
        signalServerService?.send(message)
        SnackBarManager.showSnack(
            String(format: "%@ \"%@\"...\n%d%% %@ %@ %@",
                   Strings.downloadingFile,
                   name,
                   progress,
                   Strings.of,
                   formattedSize,
                   Strings.total),
            showNew: false, showForever: true)
    }
}
