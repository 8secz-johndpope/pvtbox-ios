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
import BTree
import Photos

class DownloadManager: BackgroundWorker {
    public static let emptyCopyHash = "d41d8cd98f00b204e9800998ecf8427e"
    public static let emptyCopyUrl = FileTool.copiesDirectory.appendingPathComponent(
        DownloadManager.emptyCopyHash, isDirectory: false)
    
    private weak var dataBaseService: DataBaseService?
    private weak var connectivityService: ConnectivityService?
    private weak var temporaryFilesManager: TemporaryFilesManager?
    private var realm: Realm?
    private var fileDownloads: Results<FileRealm>?
    private var subscription: NotificationToken?
    private var availabilityInfoConsumer: AvailabilityInfoConsumer?
    
    private var availabilityInfoSupplier: AvailabilityInfoSupplier?
    private var dataSupplier: DataSupplier?
    
    internal var paused: Bool
    private let shareMode: Bool
    private var initialSyncDone = false
    internal var currentTask: DownloadTask?
    internal var downloadTasks = Dictionary<String, DownloadTask>()
    internal var readyDownloadsQueue = SortedSet<DownloadTask>()
    
    init(_ dataBaseService: DataBaseService?, _ connectivity: ConnectivityService?,
         _ temporaryFilesManager: TemporaryFilesManager?,
         shareMode: Bool = false, paused: Bool = false) {
        BFLog("DownloadManager::init")
        self.shareMode = shareMode
        self.paused = paused
        super.init()
        self.dataBaseService = dataBaseService
        self.connectivityService = connectivity
        self.temporaryFilesManager = temporaryFilesManager
        connectivity?.messageReceived = { [weak self] data, nodeId in
            self?.async {
                self?.onDataReceived(data, from: nodeId)
            }
        }
        connectivity?.incomingNodeDisconnected = { [weak self] nodeId in
            self?.async {
                self?.onIncomingNodeDisconnected(nodeId)
            }
        }
        connectivity?.outgoingNodeDisconnected = { [weak self] nodeId in
            self?.async {
                self?.onOutgoingNodeDisconnected(nodeId)
            }
        }
        
        start { [weak self] in
            BFLog("DownloadManager::init start block")
            guard let strongSelf = self else { return }
            strongSelf.availabilityInfoConsumer = AvailabilityInfoConsumer(
                strongSelf.async, strongSelf.connectivityService)
            if !shareMode {
                strongSelf.availabilityInfoSupplier = AvailabilityInfoSupplier(
                    strongSelf.async, strongSelf.connectivityService,
                    strongSelf, strongSelf.dataBaseService)
                strongSelf.dataSupplier = DataSupplier(
                    strongSelf.async, strongSelf.connectivityService,
                    strongSelf, strongSelf.dataBaseService,
                    strongSelf.temporaryFilesManager)
                strongSelf.subscribe()
            }
        }
    }
    
    override func stop() {
        BFLog("DownloadManager::stop")
        initialSyncDone = false
        for download in downloadTasks.values {
            download.cancel()
        }
        downloadTasks.removeAll()
        readyDownloadsQueue.removeAll()
        currentTask?.cancel()
        currentTask = nil
        self.subscription?.invalidate()
        self.subscription = nil
        self.realm = nil
        self.availabilityInfoConsumer?.stop()
        self.availabilityInfoConsumer = nil
        self.availabilityInfoSupplier?.stop()
        self.availabilityInfoSupplier = nil
        self.dataSupplier?.stop()
        self.dataSupplier = nil
        super.stop()
    }
    
    public func pause() {
        async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.paused = true
            if let currentTask = strongSelf.currentTask {
                currentTask.stop()
                strongSelf.readyDownloadsQueue.insert(currentTask)
            }
            strongSelf.currentTask = nil
            strongSelf.dataBaseService?.setDownloadStatus(
                Strings.paused,
                forEvents: Set<String>(strongSelf.downloadTasks.keys),
                withoutNotifying: strongSelf.subscription)
        }
    }
    
    public func resume() {
        async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.dataBaseService?.setDownloadStatus(
                Strings.startingDownloadStatus,
                forEvents: Set<String>(strongSelf.downloadTasks.keys),
                withoutNotifying: strongSelf.subscription)
            strongSelf.paused = false
            strongSelf.startNextTask()
        }
    }
    
    deinit {
        BFLog("DownloadManager::deinit")
    }
    
    public func onInitialSyncDone() {
        BFLog("DownloadManager::onInitialSyncDone")
        async { [weak self] in
            self?.initialSyncDone = true
            self?.checkDownloads()
        }
    }
    
    public func getDownloadedChunks(_ objId: String) -> Map<UInt64, UInt64>? {
        return downloadTasks[objId]?.getDownloadedChunks()
    }
    
    public func addDownload(
        _ objId: String, _ name: String,
        _ size: Int, _ hashsum: String,
        onProgress: @escaping (Int) -> (),
        onCompleted: @escaping () -> ()) {
        
        let copyUrl = FileTool.copiesDirectory.appendingPathComponent(hashsum)
        if FileTool.exists(copyUrl) {
            onCompleted()
            return
        }
        
        createDownload(
            nil, objId, name, size, hashsum,
            onProgress: { task in
                onProgress(Int(Double(task.received) / Double(task.size) * 100))
        },
            onFinishing: nil,
            onFinished: { [weak self] _ in
                onCompleted()
                self?.checkDownloadTasksFinished()
            }
        )
        
        Timer.scheduledTimer(
            withTimeInterval: DownloadTask.timeoutCheckInterval,
            repeats: false,
            block: { [weak self] _ in
                self?.checkDownloadsAndResubscribe()
        })
        async { [weak self] in
            self?.availabilityInfoConsumer?.subscribe([objId])
        }
    }
    
    private func subscribe() {
        async { [weak self] in
            guard let strongSelf = self else { return }
            BFLog("DownloadManager::subscribe")
            do {
                strongSelf.realm = try Realm()
            } catch {
                strongSelf.subscribe()
                return
            }
            guard let realm = strongSelf.realm else { return }
            strongSelf.fileDownloads = realm.objects(FileRealm.self)
                .filter("isDownload = true")
                .filter("isProcessing = false")
            strongSelf.subscription = strongSelf.fileDownloads?.observe {
                [weak self] (changes: RealmCollectionChange) in
                guard let strongSelf = self,
                    strongSelf.initialSyncDone else { return }
                switch changes {
                case .initial, .update:
                    strongSelf.async { [weak self] in
                        self?.checkDownloads()
                    }
                case .error(let error):
                    BFLogErr("realm error: %@", String(describing: error))
                }
            }
        }
    }
    
    private func checkDownloads() {
        if shareMode { return }
        BFLog("DownloadManager::checkDownloads")
        var newDownloads = Set<String>()
        for file in fileDownloads! {
            guard let objId = file.eventUuid else { continue }
            newDownloads.insert(objId)
        }
        let oldDownloads = Set<String>(downloadTasks.keys)
        let toAdd = newDownloads.subtracting(oldDownloads)
        let toDel = oldDownloads.subtracting(newDownloads)
        if !toDel.isEmpty {
            cancelDownloads(toDel)
        }
        if !toAdd.isEmpty {
            addDownloads(toAdd)
        }
    }
    
    private func cancelDownloads(_ downloads: Set<String>) {
        BFLog("DownloadManager::cancelDownloads")
        availabilityInfoConsumer?.unsubscribe(downloads)
        for objId in downloads {
            if let task = downloadTasks.removeValue(forKey: objId) {
                readyDownloadsQueue.remove(task)
                task.cancel()
            }
        }
    }
    
    fileprivate func createDownload(
        _ fileUuid: String?, _ obId: String, _ name: String,
        _ size: Int, _ hashsum: String,
        onProgress: ((DownloadTask) -> ())?,
        onFinishing: ((DownloadTask) -> ())?,
        onFinished: ((DownloadTask) -> ())?) {
        let task = DownloadTask(
            priority: 1000, fileUuid: fileUuid, objId: obId,
            name: name, size: size, hashsum: hashsum,
            connectivityService: connectivityService)
        downloadTasks[obId] = task
        task.onReady = { [weak self] task in
            self?.async { [weak self] in
                self?.onDownloadTaskReady(task)
            }
        }
        task.onCompleted = { [weak self] task in
            self?.async { [weak self] in
                self?.onDownloadTaskCompleted(task)
            }
        }
        task.onNotReady = { [weak self] task in
            self?.async { [weak self] in
                self?.onDownloadTaskNotReady(task)
            }
        }
        task.onPartDownloaded = { [weak self] objId, offset, length in
            self?.async { [weak self] in
                self?.availabilityInfoSupplier?.onNewDataDownloaded(
                    objId, offset: offset, length: length)
            }
        }
        task.onProgress = onProgress
        task.onFinishing = onFinishing
        task.onFinished = onFinished
    }
    
    private func addDownloads(_ downloads: Set<String>) {
        BFLog("DownloadManager::addDownloads")
        var toSubscribe = Set<String>()
        for download in downloads {
            guard let file = fileDownloads?.filter("eventUuid = %@", download).first,
                let eventUuid = file.eventUuid,
                let fileUuid = file.uuid,
                let event = realm?.object(ofType: EventRealm.self, forPrimaryKey: eventUuid),
                let name = file.name,
                let hashsum = event.hashsum else { continue }
            let size = file.size
            if size > 0 {
                let copyUrl = FileTool.copiesDirectory.appendingPathComponent(hashsum)
                if FileTool.exists(copyUrl) {
                    dataBaseService?.downloadCompleted(
                        for: fileUuid, eventUuid: eventUuid, hashsum: hashsum, copyUrl: copyUrl,
                        withoutNotifying: subscription)
                    continue
                }
                if file.localIdentifier != nil {
                    if copyFromCamera(
                        file.localIdentifier!, file.convertedToJpeg, fileUuid, eventUuid,
                        name, size, hashsum, copyUrl) {
                        continue
                    }
                }
                
                createDownload(
                    fileUuid, download, name, size, hashsum,
                    onProgress: onTaskProgress, onFinishing: onTaskFinishing, onFinished: onTaskFinished)
                toSubscribe.insert(download)
            } else {
                dataBaseService?.downloadCompleted(
                    for: fileUuid, eventUuid: eventUuid, hashsum: hashsum, copyUrl: DownloadManager.emptyCopyUrl,
                    withoutNotifying: subscription)
            }
        }
        if !toSubscribe.isEmpty {
            dataBaseService?.setDownloadStatus(
                paused ? Strings.paused : Strings.startingDownloadStatus,
                forEvents: toSubscribe,
                withoutNotifying: subscription)
            Timer.scheduledTimer(
                withTimeInterval: DownloadTask.timeoutCheckInterval,
                repeats: false,
                block: { [weak self] _ in
                    self?.checkDownloadsAndResubscribe()
            })
            async { [weak self] in
                self?.availabilityInfoConsumer?.subscribe(toSubscribe)
            }
        }
    }
    
    private func onDataReceived(_ data: Data, from nodeId: String) {
        guard let message = try? Proto_Message(serializedData: data) else {
            guard let messages = try? Proto_Messages(serializedData: data) else {
                BFLogWarn("DownloadManager::onDataReceived cannot parse received data")
                return
            }
            onMessagesReceived(messages.msg, from: nodeId)
            return
        }
        onMessageReceived(message, from: nodeId)
    }
    
    private func onMessageReceived(_ message: Proto_Message, from nodeId: String) {
        BFLog("DownloadManager::onMessageReceived: type: %@, objId: %@, from node: %@",
              String(describing: message.mtype), message.objID, nodeId)
        if let response = processReceivedMessage(message, from: nodeId) {
            let data = try! response.serializedData()
            connectivityService?.sendMessage(data, nodeId: nodeId, sendThroughIncomingConnection: true)
        }
    }
    
    private func onMessagesReceived(
        _ messages: [Proto_Message], from nodeId: String, responses: [Proto_Message] = []) {
        var responses = responses
        var messages = messages
        let message = messages.removeFirst()
        if let response = processReceivedMessage(message, from: nodeId) {
            responses.append(response)
        }
        if messages.isEmpty {
            if !responses.isEmpty {
                var message = Proto_Messages()
                message.msg.append(contentsOf: responses)
                let data = try! message.serializedData()
                connectivityService?.sendMessage(data, nodeId: nodeId, sendThroughIncomingConnection: true)
            }
        } else {
            async { [weak self] in
                self?.onMessagesReceived(messages, from: nodeId, responses: responses)
            }
        }
    }
    
    func processReceivedMessage(
        _ message: Proto_Message, from nodeId: String) -> Proto_Message? {
        if message.objType != .file { return nil }
        
        switch message.mtype {
        case .availabilityInfoResponse:
            guard let task = downloadTasks[message.objID],
                !message.info.isEmpty else { return nil }
            task.onAvailabilityInfoReceived(message.info, from: nodeId)
        case .dataResponse:
            guard let task = downloadTasks[message.objID],
                !message.info.isEmpty,
                message.hasData else { return nil }
            task.onDataReceived(message.info[0], message.data, from: nodeId)
        case .dataFailure, .availabilityInfoFailure:
            guard let task = downloadTasks[message.objID] else { return nil }
            task.onNodeDisconnected(nodeId)
        case .availabilityInfoRequest:
            return availabilityInfoSupplier?.onRequest(message, from: nodeId)
        case .availabilityInfoAbort:
            availabilityInfoSupplier?.onAbort(message, from: nodeId)
        case .dataRequest:
            dataSupplier?.onRequest(message, from: nodeId)
        case .dataAbort:
            dataSupplier?.onAbort(message, from: nodeId)
        }
        return nil
    }
    
    private func onIncomingNodeDisconnected(_ nodeId: String) {
        availabilityInfoSupplier?.onNodeDisconnected(nodeId)
        dataSupplier?.onNodeDisconnected(nodeId)
    }
    
    private func onOutgoingNodeDisconnected(_ nodeId: String) {
        for task in downloadTasks.values {
            task.onNodeDisconnected(nodeId)
        }
    }
    
    internal func onDownloadTaskReady(_ task: DownloadTask) {
        BFLog("DownloadManager::onDownloadTaskReady: %@", task.objId)
        guard let task = downloadTasks[task.objId] else { return }
        readyDownloadsQueue.insert(task)
        if currentTask == nil {
            async { [weak self] in
                self?.startNextTask()
            }
        }
    }
    
    internal func onDownloadTaskNotReady(_ task: DownloadTask) {
        BFLog("DownloadManager::onDownloadTaskNotReady: %@", task.objId)
        readyDownloadsQueue.remove(task)
        BFLog("DownloadManager::onDownloadTaskNotReady: ready downloads count: %d",
              readyDownloadsQueue.count)
        if currentTask?.objId == task.objId {
            currentTask = nil
            async { [weak self] in
                self?.startNextTask()
            }
        }
    }
    
    internal func startNextTask() {
        if paused {
            BFLog("DownloadManager::startNextTask paused")
            return
        }
        if currentTask != nil {
            BFLog("DownloadManager::startNextTask current task is not nil")
            return
        }
        guard let task = readyDownloadsQueue.popFirst() else {
            BFLog("DownloadManager::startNextTask do not have ready tasks")
            if !shareMode {
                dataBaseService?.updateOwnDeviceStatus(currentDownloadName: "")
            }
            if !downloadTasks.isEmpty && !shareMode {
                dataBaseService?.setDownloadStatus(
                    Strings.waitingNodesStatus,
                    forEvents: Set<String>(downloadTasks.keys),
                    withoutNotifying: subscription)
            }
            return
        }
        currentTask = task
        BFLog("DownloadManager::startNextTask starting task %@", task.objId)
        if (!task.start()) {
            BFLogErr("DownloadManager::startNextTask task completed already")
            onDownloadTaskCompleted(task)
            return
        }
        if !shareMode {
            dataBaseService?.updateOwnDeviceStatus(currentDownloadName: task.name)
            dataBaseService?.setDownloadStatus(
                Strings.downloadingStatus, for: task.fileUuid!, withoutNotifying: subscription)
        }
        if downloadTasks.count > 1 && !shareMode {
            var downloads = Set<String>(downloadTasks.keys)
            downloads.remove(task.objId)
            dataBaseService?.setDownloadStatus(
                Strings.waitingOtherDownloadsStatus, forEvents: downloads,
                withoutNotifying: subscription)
        }
    }
    
    internal func onDownloadTaskCompleted(_ task: DownloadTask) {
        BFLog("DownloadManager::onDownloadTaskCompleted: %@", task.objId)
        downloadTasks.removeValue(forKey: task.objId)
        readyDownloadsQueue.remove(task)
        availabilityInfoConsumer?.unsubscribe(task.objId)
        finishTask(task)
        if currentTask?.objId == task.objId {
            BFLog("Current task finished, schedule startNextTask")
            currentTask = nil
            async { [weak self] in
                self?.startNextTask()
            }
        }
    }
    
    private func finishTask(_ task: DownloadTask) {
        task.onReady = nil
        task.onCompleted = nil
        task.onNotReady = nil
        task.onPartDownloaded = nil
    }
    
    private func checkDownloadsAndResubscribe() {
        BFLog("DownloadManager::checkDownloadsAndResubscribe")
        if readyDownloadsQueue.count == downloadTasks.count {
            BFLog("DownloadManager::checkDownloadsAndResubscribe all downlaods ready")
            return
        }
        availabilityInfoConsumer?.resubscribe()
        if currentTask != nil {
            BFLog("DownloadManager::checkDownloadsAndResubscribe currentTask is not nil")
            return
        }
        if !readyDownloadsQueue.isEmpty {
            startNextTask()
        } else {
            dataBaseService?.setDownloadStatus(
                Strings.waitingNodesStatus,
                forEvents: Set<String>(downloadTasks.keys),
                withoutNotifying: subscription)
        }
    }
    
    private func copyFromCamera(
        _ localIdentifier: String, _ convertToJpeg: Bool, _ fileUuid: String, _ eventUuid: String,
        _ name: String, _ size: Int, _ hashsum: String, _ copyUrl: URL)  -> Bool {
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [localIdentifier], options: fetchOptions)
            .firstObject,
            let resource = PHAssetResource.assetResources(for: asset).first else {
                return false
        }
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        
        let temp = copyUrl.appendingPathExtension("tmp")
        FileTool.createFile(temp)
        guard let fileHandle = try? FileHandle(forWritingTo: temp) else {
            FileTool.delete(temp)
            return false
        }
        
        PHAssetResourceManager.default().requestData(
            for: resource, options: options,
            dataReceivedHandler: { data in
                fileHandle.write(data)
        },
            completionHandler: { [weak self] error in
                self?.async { [weak self] in
                    fileHandle.closeFile()
                    if error != nil {
                        FileTool.delete(temp)
                        self?.createDownload(
                            fileUuid, eventUuid, name, size, hashsum,
                            onProgress: self?.onTaskProgress,
                            onFinishing: self?.onTaskFinishing,
                            onFinished: self?.onTaskFinished)
                        self?.dataBaseService?.setDownloadStatus(
                            self?.paused ?? false ? Strings.paused : Strings.startingDownloadStatus,
                            forEvents: [eventUuid],
                            withoutNotifying: self?.subscription)
                        self?.availabilityInfoConsumer?.subscribe([eventUuid])
                        return
                    } else {
                        if convertToJpeg {
                            guard let image = CIImage(contentsOf: temp),
                                let data = CIContext().jpegRepresentation(
                                    of: image, colorSpace: CGColorSpaceCreateDeviceRGB()) else {
                                        FileTool.delete(temp)
                                        self?.createDownload(
                                            fileUuid, eventUuid, name, size, hashsum,
                                            onProgress: self?.onTaskProgress,
                                            onFinishing: self?.onTaskFinishing,
                                            onFinished: self?.onTaskFinished)
                                        self?.dataBaseService?.setDownloadStatus(
                                            self?.paused ?? false ? Strings.paused : Strings.startingDownloadStatus,
                                            forEvents: [eventUuid],
                                            withoutNotifying: self?.subscription)
                                        self?.availabilityInfoConsumer?.subscribe([eventUuid])
                                        return
                            }
                            FileTool.delete(temp)
                            try? data.write(to: copyUrl)
                        } else {
                            FileTool.move(from: temp, to: copyUrl)
                        }
                        self?.dataBaseService?.downloadCompleted(
                            for: fileUuid, eventUuid: eventUuid, hashsum: hashsum,
                            copyUrl: copyUrl,
                            withoutNotifying: self?.subscription)
                    }
                }
        })
        return true
    }
    
    private func onTaskProgress(_ task: DownloadTask) {
        dataBaseService?.setDownloadedSize(
            Int(task.received), for: task.fileUuid!, withoutNotifying: subscription)
    }
    
    private func onTaskFinishing(_ task: DownloadTask) {
        BFLog("DownloadManager::onTaskFinishing %@", task.objId)
        dataBaseService?.setDownloadStatus(
            Strings.finishingDownloadStatus, for: task.fileUuid!, withoutNotifying: subscription)
    }
    
    private func onTaskFinished(_ task: DownloadTask) {
        BFLog("DownloadManager::onTaskFinished %@", task.objId)
        dataBaseService?.downloadCompleted(
            for: task.fileUuid!, eventUuid: task.objId, hashsum: task.hashsum, copyUrl: task.fileUrl,
            withoutNotifying: subscription)
    }
    
    private func checkDownloadTasksFinished() {
        BFLog("DownloadManager::checkDownloadTasksFinished")
        for task in downloadTasks.values {
            task.check()
        }
    }
}
