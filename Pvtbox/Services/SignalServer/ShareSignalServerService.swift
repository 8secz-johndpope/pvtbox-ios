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
import Starscream
import JASON

class ShareSignalServerService: SignalServerClient {
    private var serverAddress: String?
    private var connectivityServers = [JSON]()
    private var shareHash: String?
    private var shareFolder: FileRealm?
    private var connectivityService: ConnectivityService?
    private var downloadManager: DownloadManager?
    private weak var dataBaseService: DataBaseService?
    private weak var speedCalculator: SpeedCalculator?
    
    private var downloadTasks = Set<String>()
    private var folderCreationTasksCount = 0
    private var infoProcessed = false
    private var shareInfoReceived = false

    init(_ speedCalculator: SpeedCalculator?, _ dataBaseService: DataBaseService?) {
        self.speedCalculator = speedCalculator
        self.dataBaseService = dataBaseService
    }
    
    public func setSignalServerAddress(_ address: String) {
        serverAddress = address
    }
    
    public func setConnectivityServers(_ servers: [JSON]) {
        connectivityServers = servers
    }
    
    public func start(withUrl url: URL, downloadTo folder: FileRealm?) {
        infoProcessed = false
        shareInfoReceived = false
        folderCreationTasksCount = 0
        SnackBarManager.showSnack(
            Strings.startingShareDownload, showNew: true, showForever: true,
            actionText: Strings.cancel, actionBlock: { [weak self] in
                SnackBarManager.showSnack(
                    Strings.shareDownloadCancelled,
                    showNew: true, showForever: false)
                self?.stop()
        })
        if let query = url.query {
            shareHash = String(format: "%@?%@", url.lastPathComponent, query)
        } else {
            shareHash = url.lastPathComponent
        }
        shareFolder = folder
        dispatchQueue.async {
            self.dataBaseService?.updateOwnDeviceStatus(processingShare: true)
            self.connectivityService = ConnectivityService(
                servers: self.connectivityServers,
                signalServerClient: self,
                speedCalculator: self.speedCalculator,
                dataBaseService: nil)
            self.downloadManager = DownloadManager(
                nil, self.connectivityService!, nil, shareMode: true)
            self.start()
        }
    }
    
    override public func stop() {
        connectivityService?.stop()
        downloadManager?.stop()
        super.stop()
        self.dataBaseService?.updateOwnDeviceStatus(processingShare: false)
        
        connectivityService = nil
        downloadManager = nil
    }
    
    internal override func getUrl() throws -> String {
        return String(
            format: "%@/ws/webshare/%@",
            serverAddress!, shareHash!)
    }
    
    internal override func handleMessage(_ message: JSON) {
        if !enabled { return }
        let operation = message["operation"].string
        switch operation {
        case "share_info":
            if !shareInfoReceived {
                shareInfoReceived = true
                handleShareInfo(message["data"].json)
            }
        case "peer_list":
            let nodes = message["data"].jsonArrayValue
            connectivityService?.setNodeList(nodes)
        case "peer_connect":
            let node = message["data"].json
            connectivityService?.onNodeConnected(node)
        case "peer_disconnect":
            let nodeId = message["node_id"].string
            connectivityService?.onNodeDisconnected(nodeId!)
        case "sdp":
            connectivityService?.onSdpMessage(
                message["data"]["message"].string!,
                from: message["node_id"].string!,
                message["data"]["conn_uuid"].string!)
        default:
            BFLogWarn("Unsupported operation: %@", String(describing: operation))
            return
        }
    }
    
    private func handleShareInfo(_ info: JSON) {
        processShare(info, folder: shareFolder)
    }
    
    private func processShare(_ info: JSON, folder: FileRealm?) {
        if !enabled { return }
        if let childs = info["childs"].jsonArray {
            processFolder(info["name"].string!, parent: folder, childs: childs)
        } else {
            processFile(
                info["name"].string!, info["file_hash"].string!, info["file_size"].int!,
                eventUuid: info["event_uuid"].string!, parent: folder)
        }
        processingDispatchQueue.async { [weak self] in
            self?.processingDispatchQueue.async { [weak self] in
                self?.checkDone()
            }
        }
    }

    private func processFolder(_ name: String, parent: FileRealm?, childs: [JSON]) {
        if !enabled {
            return
        }
        var name = dataBaseService?.generateUniqName(
            parentPath: parent?.path, baseName: name, isFolder: true, suffix: "") ?? name
        let uuid = UUID().uuidString
        let eventUuid = md5(fromString: uuid)
        let file = FileRealm()
        file.uuid = uuid
        file.name = name
        file.isFolder = true
        let now = Date()
        file.dateCreated = now
        file.dateModified = now
        file.parentUuid = parent?.uuid ?? nil
        file.path = FileTool.buildPath(parent?.path, name)
        file.isProcessing = true
        file.downloadStatus = Strings.processingStatus
        var processing = false
        defer {
            if !processing {
                dataBaseService?.deleteFile(byUuid: uuid)
            }
        }
        dataBaseService?.addFile(file)
        folderCreationTasksCount += 1
        HttpClient.shared.createFolder(
            eventUuid: eventUuid,
            parentUuid: file.parentUuid ?? "",
            name: name,
            onSuccess: { [weak self] json in
                self?.processingDispatchQueue.async { [weak self] in
                    guard let result = json["result"].string,
                        result == "success",
                        let data = json["data"].jsonDictionary else {
                            self?.dataBaseService?.deleteFile(byUuid: uuid)
                            if self?.enabled ?? false {
                                SnackBarManager.showSnack(
                                    String(format: "%@:\n%@",
                                           Strings.operationError,
                                           (json["info"].string ??
                                            json["info"]["error_file_name"][0].string ??
                                            Strings.networkError)),
                                    showNew: false,
                                    showForever: false,
                                    actionText: Strings.ok)
                                self?.stop()
                            }
                            return
                    }
                    let event = EventRealm()
                    event.id = data["event_id"]!.int!
                    event.uuid = data["event_uuid"]!.string!
                    event.fileUuid = data["folder_uuid"]!.string!
                    let date = Date(timeIntervalSince1970: data["timestamp"]!.double!)
                    
                    self?.dataBaseService?.updateFileWithEvent(
                        uuid, event, date: date)
                    
                    guard let folder = self?.dataBaseService?.getFile(
                        byUuid: data["folder_uuid"]!.string!) else {
                            SnackBarManager.showSnack(
                                String(format: "%@:\n%@",
                                       Strings.operationError,
                                       Strings.networkError),
                                showNew: false,
                                showForever: false,
                                actionText: Strings.ok)
                            self?.stop()
                            return
                    }
                    let folderCopy = FileRealm(value: folder)
                    self?.folderCreationTasksCount -= 1
                    for child in childs {
                        self?.processShare(child, folder: folderCopy)
                    }
                    self?.checkDone()
                }
            },
            onError: { [weak self] json in
                self?.processingDispatchQueue.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.dataBaseService?.deleteFile(byUuid: uuid)
                    if json?["errcode"].string == "WRONG_DATA",
                        let varFileName = json?["error_data"]["var_file_name"].string {
                        strongSelf.processFolder(varFileName, parent: parent, childs: childs)
                    } else if self?.enabled ?? false {
                        SnackBarManager.showSnack(
                            String(format: "%@:\n%@",
                                   Strings.operationError,
                                   (json?["info"].string ??
                                    json?["info"]["error_file_name"][0].string ??
                                    Strings.networkError)),
                            showNew: false,
                            showForever: false,
                            actionText: Strings.ok)
                        self?.stop()
                    }
                }
        })
        processing = true
    }
    
    private func processFile(_ name: String, _ hashsum: String, _ size: Int,
                             eventUuid: String, parent: FileRealm?) {
        BFLog("ShareSignalServerService::processFile")
        if !enabled {
            return
        }
        downloadTasks.insert(eventUuid)
        SnackBarManager.showSnack(
            String(format: "%@...\n%d %@ %@",
                   Strings.downloadingShare,
                   downloadTasks.count,
                   Strings.files,
                   Strings.total),
            showNew: false,
            showForever: true,
            actionText: Strings.cancel,
            actionBlock: { [weak self] in
                SnackBarManager.showSnack(
                    Strings.shareDownloadCancelled,
                    showNew: true, showForever: false)
                self?.stop()
        })
        downloadManager?.addDownload(
            eventUuid, name, size, hashsum,
            onProgress: { [weak self] progress in
                self?.processingDispatchQueue.async { [weak self] in
                    if !(self?.enabled ?? false) {
                        return
                    }
                    SnackBarManager.showSnack(
                        String(format: "%@\n%@...\n%d%% %@ %@, %d %@ %@",
                               Strings.downloadingSharedFile,
                               name,
                               progress,
                               Strings.of,
                               ByteFormatter.instance.string(fromByteCount: Int64(size)),
                               self?.downloadTasks.count ?? 0,
                               Strings.files,
                               Strings.total),
                        showNew: false,
                        showForever: true,
                        actionText: Strings.cancel,
                        actionBlock: { [weak self] in
                            SnackBarManager.showSnack(
                                Strings.shareDownloadCancelled,
                                showNew: true, showForever: false)
                            self?.stop()
                    })
                }
            },
            onCompleted: { [weak self] in
                self?.processingDispatchQueue.async { [weak self] in
                    if !(self?.downloadTasks.contains(eventUuid) ?? false) { return }
                    self?.downloadTasks.remove(eventUuid)
                    BFLog("ShareSignalServerService::processFile OnCompleted")
                    self?.processingDispatchQueue.async { [weak self] in
                        self?.createFile(name, hashsum, size, parent)
                        self?.checkDone()
                        if self?.enabled ?? false {
                            SnackBarManager.showSnack(
                                String(format: "%@...\n%d %@ %@",
                                       Strings.downloadingShare,
                                       self?.downloadTasks.count ?? 0,
                                       Strings.files,
                                       Strings.total),
                                showNew: false,
                                showForever: true,
                                actionText: Strings.cancel,
                                actionBlock: { [weak self] in
                                    SnackBarManager.showSnack(
                                        Strings.shareDownloadCancelled,
                                        showNew: true, showForever: false)
                                    self?.stop()
                            })
                        }
                    }
                }
            }
        )
    }
    
    private func createFile(_ name: String, _ hashsum: String, _ size: Int, _ parent: FileRealm?) {
        BFLog("ShareSignalServerService::createFile %@", name)
        if !enabled {
            return
        }
        if let parentPath = parent?.path {
            let p = dataBaseService?.getFile(byPath: parentPath)
            if p == nil {
                SnackBarManager.showSnack(
                    Strings.shareDownloadCancelled,
                    showNew: true, showForever: false)
                self.stop()
                return
            } else if p!.isProcessing {
                processingDispatchQueue.asyncAfter(deadline: .now() + 1) { [weak self] in
                    self?.createFile(name, hashsum, size, parent)
                }
                return
            }
        }
        var name = dataBaseService?.generateUniqName(
            parentPath: parent?.path, baseName: name, isFolder: false, suffix: "") ?? name
        let uuid = UUID().uuidString
        let eventUuid = md5(fromString: uuid)
        let file = FileRealm()
        file.uuid = uuid
        file.name = name
        file.isDownload = true
        file.isOnlyDownload = true
        file.isFolder = false
        file.size = size
        let now = Date()
        file.dateCreated = now
        file.dateModified = now
        file.parentUuid = parent?.uuid ?? nil
        file.path = FileTool.buildPath(parent?.path, name)
        file.isProcessing = true
        file.downloadStatus = Strings.processingStatus
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
                guard let result = json["result"].string,
                    result == "success",
                    let data = json["data"].jsonDictionary else {
                        BFLog("ShareSignalServerService::createFile not expected response for file")
                        self?.dataBaseService?.deleteFile(byUuid: uuid)
                        self?.dataBaseService?.deleteEvent(byUuid: eventUuid)
                        self?.createFile(name, hashsum, size, parent)
                        return
                }
                let event = EventRealm()
                event.id = data["event_id"]!.int!
                event.uuid = data["event_uuid"]!.string!
                event.fileUuid = data["file_uuid"]!.string!
                event.hashsum = data["file_hash"]!.string!
                event.size = data["file_size_after_event"]?.intValue ?? 0
                let date = Date(timeIntervalSince1970: data["timestamp"]!.double!)
                
                self?.dataBaseService?.updateFileWithEvent(
                    uuid, event, date: date)
            },
            onError: { [weak self] json in
                self?.processingDispatchQueue.async { [weak self] in
                    guard let strongSelf = self else { return }
                    strongSelf.dataBaseService?.deleteFile(byUuid: uuid)
                    strongSelf.dataBaseService?.deleteEvent(byUuid: uuid)
                    if json?["errcode"].string == "WRONG_DATA",
                        let varFileName = json?["error_data"]["var_file_name"].string {
                        strongSelf.createFile(varFileName, hashsum, size, parent)
                    } else {
                        strongSelf.createFile(name, hashsum, size, parent)
                    }
                }
        })
        processing = true
    }
    
    private func checkDone() {
        BFLog("ShareSignalServerService::checkDone: enabled: %@, folder tasks: %d, file tasks: %d",
              String(describing: enabled), folderCreationTasksCount, downloadTasks.count)
        if enabled && folderCreationTasksCount == 0 && downloadTasks.count == 0 {
            let hash = shareHash?.split(separator: "?")[0]
            let request: [String: Any] = [
                "operation": "share_downloaded",
                "data": [
                    "share_hash": hash
                ]]
            let message = JSONCoder.encode(request)!
            send(message)
            SnackBarManager.showSnack(
                Strings.shareDownloaded,
                showNew: false,
                showForever: false,
                actionText: Strings.ok)
            let copiesFolderSize = FileTool.size(ofDirectory: FileTool.copiesDirectory)
            dataBaseService?.updateOwnDeviceStatus(diskUsage: copiesFolderSize)
            stop()
        }
    }
    
    override func onDisconnected(_ error: Error?) {
        connectivityService?.onDisconnectedFromServer()
        if (error as? WSError)?.code == 403 {
            processingDispatchQueue.async { [weak self] in
                self?.stop()
                SnackBarManager.showSnack(
                    Strings.shareUnavailable,
                    showNew: false,
                    showForever: false,
                    actionText: Strings.ok)
            }
        } else {
            dispatchQueue.asyncAfter(deadline: .now() + 2, execute: { [weak self] in
                if self?.enabled ?? false {
                    self?.start()
                }
            })
        }
    }
}
