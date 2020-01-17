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
import BTree
import RealmSwift

class DownloadTask: Comparable {
    internal static let downloadPartSize: UInt64 = 1024 * 1024
    internal static let downloadChunkSize: UInt64 = 64 * 1024
    internal static let maxNodeChunkRequests: UInt64 = 128
    internal static let timeoutCheckInterval: Double = 15
    internal static let timeout: Double = 20
    internal static let timeoutsLimit = 2

    let priority: Int
    let fileUuid: String?
    let objId: String
    let name: String
    let size: UInt64
    let hashsum: String
    
    internal let fileUrl: URL
    internal let downloadUrl: URL
    internal let infoKeysUrl: URL
    internal let infoValuesUrl: URL
    
    private weak var connectivityService: ConnectivityService?
    
    internal var received: UInt64 = 0
    internal var lastReceived: UInt64 = 0
    
    internal var ready: Bool = false {
        willSet {
            if self.ready != newValue {
                if newValue {
                    onReady?(self)
                } else {
                    stop()
                    onNotReady?(self)
                }
            }
        }
    }
    
    internal var started = false
    internal var finished = false
    internal var initialized = false
    
    internal var nodesAvailableChunks = Dictionary<String, Map<UInt64, UInt64>>()
    internal var nodesRequestedChunks = Dictionary<String, Map<UInt64, UInt64>>()
    internal var nodesLastReceiveTime = Dictionary<String, Date>()
    internal var nodesDownloadedChunksCount = Dictionary<String, Int32>()
    internal var nodesTimeoutsCount = Dictionary<String, Int8>()
    
    internal var wantedChunks = Map<UInt64, UInt64>()
    internal var downloadedChunks = Map<UInt64, UInt64>()
    
    private var timeoutTimer: Timer? = nil
    
    init(priority: Int, fileUuid: String?, objId: String, name: String,
         size: Int, hashsum: String,
         connectivityService: ConnectivityService?) {
        self.priority = priority
        self.fileUuid = fileUuid
        self.objId = objId
        self.name = name
        self.size = UInt64(size)
        self.hashsum = hashsum
        
        BFLog("DownloadTask::%@::init", objId)
        
        fileUrl = FileTool.copiesDirectory.appendingPathComponent(hashsum, isDirectory: false)
        downloadUrl = fileUrl.appendingPathExtension("download")
        infoKeysUrl = fileUrl.appendingPathExtension("info_keys")
        infoValuesUrl = fileUrl.appendingPathExtension("info_values")
        
        self.connectivityService = connectivityService
        self.initWantedChunks()
    }
    
    deinit {
        BFLog("DownloadTask::%@::deinit", objId)
    }
    
    static func < (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        let res = lhs == rhs ? false :
            (lhs.priority == rhs.priority ? (
                lhs.size - lhs.received == rhs.size - rhs.received ? (
                    lhs.objId < rhs.objId) : lhs.size - lhs.received < rhs.size - rhs.received) :
                lhs.priority > rhs.priority)
        BFLog("Task(%@, size-received: %d, priority: %d) < Task(%@, size-received: %d, priority: %d) = %@",
              lhs.objId, lhs.size-lhs.received, lhs.priority,
              rhs.objId, rhs.size-rhs.received, rhs.priority,
              String(describing: res))
        return res
    }
    
    static func <= (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        let res = lhs == rhs ||
            (lhs.priority == rhs.priority ? (
                lhs.size - lhs.received == rhs.size - rhs.received ? (
                    lhs.objId < rhs.objId) : lhs.size - lhs.received < rhs.size - rhs.received) :
                lhs.priority >= rhs.priority)
        BFLog("Task(%@, size-received: %d, priority: %d) < Task(%@, size-received: %d, priority: %d) = %@",
              lhs.objId, lhs.size-lhs.received, lhs.priority,
              rhs.objId, rhs.size-lhs.received, rhs.priority,
              String(describing: res))
        return res
    }
    
    static func > (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        let res = lhs == rhs ? false :
            (lhs.priority == rhs.priority ? (
                lhs.size - lhs.received == rhs.size - rhs.received ? (
                    lhs.objId > rhs.objId) : lhs.size - lhs.received > rhs.size - rhs.received) :
                lhs.priority <= rhs.priority)
        BFLog("Task(%@, size-received: %d, priority: %d) > Task(%@, size-received: %d, priority: %d) = %@",
              lhs.objId, lhs.size-lhs.received, lhs.priority,
              rhs.objId, rhs.size-rhs.received, rhs.priority,
              String(describing: res))
        return res
    }
    
    static func >= (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        let res = lhs == rhs ||
            (lhs.priority == rhs.priority ? (
                lhs.size - lhs.received == rhs.size - rhs.received ? (
                    lhs.objId > rhs.objId) : lhs.size - lhs.received > rhs.size - rhs.received) :
                lhs.priority <= rhs.priority)
        BFLog("Task(%@, size-received: %d, priority: %d) >= Task(%@, size-received: %d, priority: %d) = %@",
              lhs.objId, lhs.size-lhs.received, lhs.priority,
              rhs.objId, rhs.size-rhs.received, rhs.priority,
              String(describing: res))
        return res
    }
    
    static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        BFLog("Task(%@, size: %d, priority: %d) == Task(%@, size: %d, priority: %d) = %@",
              lhs.objId, lhs.size, lhs.priority, rhs.objId, rhs.size, rhs.priority,
              String(describing: lhs.objId == rhs.objId))
        return lhs.objId == rhs.objId
    }
    
    var onReady: ((DownloadTask) -> ())?
    var onNotReady: ((DownloadTask) -> ())?
    var onCompleted: ((DownloadTask) -> ())?
    var onFinishing: ((DownloadTask) -> ())?
    var onFinished: ((DownloadTask) -> ())?
    var onProgress: ((DownloadTask) -> ())?
    var onPartDownloaded: ((String, UInt64, UInt64) -> ())?
    
    func onNodeDisconnected(
        _ nodeId: String, connectionAlive: Bool = false, timeoutLimitExceed: Bool = true) {
        
        BFLog("DownloadTask::%@::onNodeDisconnected %@, connectionAlive: %@, timeoutLimitExceed: %@",
              objId, nodeId, String(describing: connectionAlive), String(describing: timeoutLimitExceed))
        nodesRequestedChunks.removeValue(forKey: nodeId)
        if timeoutLimitExceed {
            nodesAvailableChunks.removeValue(forKey: nodeId)
            nodesTimeoutsCount.removeValue(forKey: nodeId)
            if connectionAlive {
                connectivityService?.reconnect(to: nodeId)
            }
        }
        nodesLastReceiveTime.removeValue(forKey: nodeId)
        nodesDownloadedChunksCount.removeValue(forKey: nodeId)
        
        if connectionAlive {
            sendAbort(to: nodeId)
        }
        
        if nodesAvailableChunks.isEmpty {
            checkDownloadNotReady(started ? nodesRequestedChunks : nodesAvailableChunks)
        } else {
            downloadChunks()
        }
    }
    
    func onAvailabilityInfoReceived(_ info: [Proto_Info], from nodeId: String) {
        BFLog("DownloadTask::%@::onAvailabilityInfoReceived", objId)
        let newInfoStored = storeAvailabilityInfo(info, from: nodeId)
        if newInfoStored {
            ready = true
        }
        
        if started && !finished {
            downloadNextChunks(from: nodeId)
            cleanNodesLastReceiveTime()
            checkDownloadNotReady(nodesRequestedChunks)
        }
    }
    
    @discardableResult
    func start() -> Bool {
        BFLog("DownloadTask::%@::start", objId)
        if (finished) {
            BFLogErr("DownloadTasl::%@::start task already finished", objId)
            return false
        }
        started = true
        
        if !initialized {
            initialized = true
            loadDownloadedChunksFromPersistentStorage()
            
            for downloadedChunk in downloadedChunks {
                removeFromChunks(downloadedChunk.0, downloadedChunk.1, &wantedChunks)
            }
        
            received = downloadedChunks.values.reduce(0, +)
        }
        
        downloadChunks()
        timeoutTimer = Timer.scheduledTimer(
            withTimeInterval: DownloadTask.timeoutCheckInterval,
            repeats: true,
            block: { [weak self] _ in
                self?.checkTimeouts()
        })
        return true
    }
    
    func check() {
        if !finished && FileTool.exists(fileUrl) {
            stop()
            finished = true
            onFinished?(self)
            onCompleted?(self)
        }
    }
    
    func cancel() {
        BFLog("DownloadTask::%@::cancel", objId)
        completeDownload(force: true)
    }
    
    func getDownloadedChunks() -> Map<UInt64, UInt64>? {
        return downloadedChunks.isEmpty ? nil : downloadedChunks
    }
    
    private func loadDownloadedChunksFromPersistentStorage() {
        guard let keysData = try? Data(contentsOf: infoKeysUrl),
            let valuesData = try? Data(contentsOf: infoValuesUrl),
            let keys = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(
                keysData) as? [UInt64],
            let values = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(
                valuesData) as? [UInt64] else { return }
        
        downloadedChunks = Map<UInt64, UInt64>(zip(keys, values))
    }
    
    private func saveDownloadedChunksToPersistentStorage() {
        let keys = NSKeyedArchiver.archivedData(withRootObject: Array(downloadedChunks.keys))
        try? keys.write(to: infoKeysUrl, options: .atomic)
        let values = NSKeyedArchiver.archivedData(withRootObject: Array(downloadedChunks.values))
        try? values.write(to: infoValuesUrl, options: .atomic)
    }
    
    private func deletePersistentStorage() {
        FileTool.delete(infoKeysUrl)
        FileTool.delete(infoValuesUrl)
    }
    
    public func stop() {
        BFLog("DownloadTask::%@::stop", objId)
        started = false
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        
        for nodeId in nodesLastReceiveTime.keys {
            sendAbort(to: nodeId)
        }
    }
    
    private func initWantedChunks() {
        wantedChunks[0] = size
    }
    
    private func downloadChunks() {
        if !started || finished { return }
        
        for nodeId in nodesAvailableChunks.keys.shuffled() {
            if nodesRequestedChunks[nodeId]?.isEmpty ?? true {
                downloadNextChunks(from: nodeId)
            }
        }
        cleanNodesLastReceiveTime()
        checkDownloadNotReady(nodesRequestedChunks)
    }
    
    internal func removeFromChunks(
        _ offset: UInt64, _ length: UInt64, _ chunks: inout Map<UInt64, UInt64>) {
        if chunks.isEmpty { return }

        let leftChunk = chunks.first(where: { (o, l) in
            return o + l > offset
        })
        
        let rightChunk = chunks.last(where: { (o, l) in
            return o <= offset + length && o + l > offset
        })
        
        if leftChunk != nil && rightChunk != nil {
            let toRemove = chunks.submap(from: leftChunk!.0, through: rightChunk!.0)
            chunks = chunks.excluding(toRemove.keys)
        } else if rightChunk != nil {
            chunks.removeValue(forKey: rightChunk!.0)
        }
        
        if leftChunk != nil && leftChunk!.0 < offset && leftChunk!.0 + leftChunk!.1 >= offset {
            chunks[leftChunk!.0] = offset - leftChunk!.0
        }
        
        if rightChunk != nil && rightChunk!.0 + rightChunk!.1 > offset + length {
            chunks[offset + length] = rightChunk!.0 + rightChunk!.1 - offset - length
        }
    }
    
    private func storeAvailabilityInfo(_ info: [Proto_Info], from nodeId: String) -> Bool {
        var availableChunks = nodesAvailableChunks[nodeId]
        if availableChunks == nil {
            availableChunks = Map<UInt64, UInt64>()
        }
        var chunks = availableChunks!
        var newAdded = false
        for partInfo in info {
            if partInfo.length == 0 { continue }
            if chunks.isEmpty {
                chunks.updateValue(partInfo.length, forKey: partInfo.offset)
                newAdded = true
                continue
            }
            var resultOffset = partInfo.offset
            var resultLength = partInfo.length
            if let leftChunk = chunks.last(where: { (offset, length) in
                return offset <= partInfo.offset
            }) {
                if leftChunk.0 <= partInfo.offset &&
                    leftChunk.0 + leftChunk.1 >= partInfo.offset + partInfo.length {
                    continue
                }
                
                if partInfo.offset <= leftChunk.0 + leftChunk.1 {
                    resultOffset = leftChunk.0
                    resultLength = partInfo.offset + partInfo.length - resultOffset
                }
            }
            
            if let rightChunk = chunks.last(where: { (offset, length) in
                return offset <= resultOffset + resultLength
            }) {
                if partInfo.offset + partInfo.length <= rightChunk.0 + rightChunk.1 {
                    resultLength = rightChunk.0 + rightChunk.1 - resultOffset
                }
            }
            let excludeChunks = chunks.submap(
                from: resultOffset, through: resultOffset + resultLength)
            chunks = chunks.excluding(excludeChunks.keys)
            chunks.updateValue(resultLength, forKey: resultOffset)
            newAdded = true
        }
        
        if newAdded {
            nodesAvailableChunks[nodeId] = chunks
        }
        return newAdded
    }
    
    private func downloadNextChunks(from nodeId: String, _ timeFromLastReceivedChunk: Double=0) {
        if !started || finished { return }
        let totalRequested = nodesRequestedChunks.values.flatMap{$0.values}.reduce(0, +)
        BFLog("DownloadTask::%@::downloadNextChunks from nodeId: %@, "
            + "totalRequested: %u, totalWanted: %d",
              objId, nodeId, totalRequested, wantedChunks.values.reduce(0, +))
        
        var availableChunks:Map<UInt64, UInt64>
        
        if totalRequested + received >= size {
            if nodesRequestedChunks[nodeId] == nil || timeFromLastReceivedChunk > 5.0 {
                availableChunks = getEndRaceChunksToDownload(from: nodeId)
            } else {
                return
            }
        } else {
            availableChunks = getAvailableChunksToDownload(from: nodeId)
        }
        if availableChunks.isEmpty {
            return
        }
        let (availableOffset, availableLength) = availableChunks.randomElement()!
        let partsCount = UInt64(ceil(
            Double(availableLength) / Double(DownloadTask.downloadPartSize))) - 1
        let partToDownload = UInt64.random(in: 0...partsCount)
        let offset = availableOffset + partToDownload * DownloadTask.downloadPartSize
        let length = min(DownloadTask.downloadPartSize, availableOffset + availableLength - offset)
        
        var requestedChunks = nodesRequestedChunks[nodeId] ?? Map<UInt64, UInt64>()
        requestedChunks[offset] = length
        nodesRequestedChunks[nodeId] = requestedChunks
        nodesLastReceiveTime[nodeId] = Date()
        
        requestData(offset, length, from: nodeId)
    }
    
    internal func getEndRaceChunksToDownload(from nodeId: String) -> Map<UInt64, UInt64> {
        guard var availableChunks = nodesAvailableChunks[nodeId] else {
            return Map<UInt64, UInt64>()
        }
        for (downloadedOffset, downloadedLength) in downloadedChunks {
            removeFromChunks(downloadedOffset, downloadedLength, &availableChunks)
        }
        if availableChunks.isEmpty { return Map<UInt64, UInt64>() }
        
        var availableFromOtherNodes = availableChunks
        let nodeRequestedChunks = nodesRequestedChunks[nodeId] ?? Map<UInt64, UInt64>()
        for (downloadedOffset, downloadedLength) in nodeRequestedChunks {
            removeFromChunks(downloadedOffset, downloadedLength, &availableFromOtherNodes)
        }
        if availableFromOtherNodes.isEmpty {
            return availableChunks
        } else {
            return availableFromOtherNodes
        }
    }
    
    internal func getAvailableChunksToDownload(from nodeId: String) -> Map<UInt64, UInt64> {
        guard var availableChunks = nodesAvailableChunks[nodeId] else {
            return Map<UInt64, UInt64>()
        }
        for (_, requestedChunks) in nodesRequestedChunks {
            for (requestedOffset, requestedLength) in requestedChunks {
                removeFromChunks(requestedOffset, requestedLength, &availableChunks)
            }
        }
        if availableChunks.isEmpty { return Map<UInt64, UInt64>() }
        for (downloadedOffset, downloadedLength) in downloadedChunks {
            removeFromChunks(downloadedOffset, downloadedLength, &availableChunks)
        }
        return availableChunks
    }
    
    private func cleanNodesLastReceiveTime() {
        for nodeId in nodesLastReceiveTime.keys {
            if nodesRequestedChunks[nodeId] == nil {
                nodesLastReceiveTime.removeValue(forKey: nodeId)
            }
        }
    }
    
    private func checkDownloadNotReady<T: Collection>(_ checkable: T) {
        if wantedChunks.isEmpty && started {
            completeDownload(force: false)
        }
        if checkable.isEmpty && ready {
            started = false
            ready = false
        }
    }
    
    @discardableResult
    private func completeDownload(force: Bool) -> Bool {
        if finished {
            return false
        }
        if wantedChunks.isEmpty || force {
            BFLog("DownloadTask::%@::completeDownload task is completed (force: %@)",
                  objId, String(describing: force))
            stop()
            
            if !force {
                onFinishing?(self)
                
                let fileHash = FileTool.getFileHashViaSignature(downloadUrl)
                if fileHash == hashsum {
                    FileTool.move(from: downloadUrl, to: fileUrl)
                    deletePersistentStorage()
                    finished = true
                    onFinished?(self)
                } else {
                    BFLogWarn(
                        "DownloadTask::%@::completeDownload hash missmatch, "
                        + "expected: %@, actual: %@",
                        objId, hashsum, String(describing: fileHash))
                    downloadedChunks.removeAll()
                    initWantedChunks()
                    received = 0
                    lastReceived = 0
                    deletePersistentStorage()
                    start()
                    return false
                }
            }
            finished = true
            onCompleted?(self)
            return true
        }
        return false
    }
    
    func onDataReceived(_ info: Proto_Info, _ data: Data, from nodeId: String) {
        if finished { return }
        BFLog("DownloadTask::%@::onDataReceived (%u, %u) from %@",
              objId, info.offset, info.length, nodeId)
        let now = Date()
        let nodeLastReceivedChunkDate = nodesLastReceiveTime[nodeId] ?? now
        nodesLastReceiveTime[nodeId] = now
        nodesTimeoutsCount.removeValue(forKey: nodeId)
        var downloadedCount = nodesDownloadedChunksCount[nodeId] ?? 0
        downloadedCount += 1
        nodesDownloadedChunksCount[nodeId] = downloadedCount
        
        if !isChunkAlreadyDownloaded(info.offset) {
            if !onNewChunkDownloaded(info.offset, info.length, data, from: nodeId) {
                return
            }
        } else {
            BFLogWarn("DownloadTask::%@::onDataReceived: chunk is already downloaded", objId)
        }
        
        let requestedChunks = nodesRequestedChunks[nodeId]
        if var requestedChunks = requestedChunks {
            removeFromChunks(info.offset, info.length, &requestedChunks)
            if requestedChunks.isEmpty {
                nodesRequestedChunks.removeValue(forKey: nodeId)
            } else {
                nodesRequestedChunks[nodeId] = requestedChunks
            }
        }
        
        let requestedCount = requestedChunks == nil ? 0 : (requestedChunks!.values.reduce(0, +) / DownloadTask.downloadChunkSize)
        if downloadedCount * 4 >= requestedCount &&
            requestedCount < DownloadTask.maxNodeChunkRequests {
            downloadNextChunks(
                from: nodeId, nodeLastReceivedChunkDate.timeIntervalSinceNow * -1)
            cleanNodesLastReceiveTime()
            checkDownloadNotReady(nodesRequestedChunks)
        }
    }
    
    internal func isChunkAlreadyDownloaded(_ offset: UInt64) -> Bool {
        if downloadedChunks.isEmpty {
            return false
        }
        let chunk = downloadedChunks.first(where: { (o, l) in
            return o <= offset && o + l > offset
        })
        return chunk != nil
    }
    
    internal func onNewChunkDownloaded(
        _ offset: UInt64, _ length: UInt64, _ data: Data, from nodeId: String) -> Bool {
        if !writeToFile(offset, data) { return false }
        
        received += length
        if (Double(received) - Double(lastReceived)) / Double(size) > 0.01 {
            lastReceived = received
            onProgress?(self)
        }
        
        var newOffset = offset
        var newLength = length
        
        if let leftChunk = downloadedChunks.first(where: { (o, l) in
            return o + l == offset
        }) {
            newOffset = leftChunk.0
            newLength += leftChunk.1
            downloadedChunks.removeValue(forKey: leftChunk.0)
        }
        
        if let rightChunkLength = downloadedChunks[newOffset + newLength] {
            downloadedChunks.removeValue(forKey: newOffset + newLength)
            newLength += rightChunkLength
        }
        
        downloadedChunks[newOffset] = newLength
        
        removeFromChunks(offset, length, &wantedChunks)
        
        let totalWanted = wantedChunks.values.reduce(0, +)
        BFLog("DownloadTask::%@::onNewChunkDownloaded, total received: %u, total downloaded: %u, total wanted: %u",
              objId, received, received, totalWanted)
        
        let partOffset = (offset / DownloadTask.downloadPartSize) * DownloadTask.downloadPartSize
        let partSize = min(DownloadTask.downloadPartSize, size - partOffset)
        if newOffset <= partOffset && newOffset + newLength >= partOffset + partSize {
            BFLog("DownloadTask::%@::onNewChunkDownloaded fully downloaded 1MB part: %u",
                  objId, partOffset)
            onPartDownloaded?(objId, partOffset, partSize)
            saveDownloadedChunksToPersistentStorage()
        }
        
        return !completeDownload(force: false)
    }
    
    private func writeToFile(_ offset: UInt64, _ data: Data) -> Bool {
        return autoreleasepool {
            FileTool.createFile(downloadUrl)
            guard let handle = try? FileHandle(forUpdating: downloadUrl) else { return false }
            defer {
                handle.closeFile()
            }
            handle.seek(toFileOffset: offset)
            handle.write(data)
            return true
        }
    }
    
    private func requestData(_ offset: UInt64, _ length: UInt64, from nodeId: String) {
        var info = Proto_Info()
        info.offset = offset
        info.length = length
        var msg = Proto_Message()
        msg.magicCookie = 0x7a52fa73
        msg.mtype = .dataRequest
        msg.objType = .file
        msg.objID = objId
        msg.info.append(info)
        BFLog("DownloadTask::%@::requestData (%u, %u) from %@",
              objId, offset, length, nodeId)
        try! connectivityService?.sendMessage(msg.serializedData(), nodeId: nodeId, sendThroughIncomingConnection: false)
    }
    
    private func sendAbort(to nodeId: String) {
        BFLog("DownloadTask::%@::sendAbort to nodeId: %@", objId, nodeId)
        var msg = Proto_Message()
        msg.magicCookie = 0x7a52fa73
        msg.mtype = .dataAbort
        msg.objType = .file
        msg.objID = objId
        try! connectivityService?.sendMessage(msg.serializedData(), nodeId: nodeId, sendThroughIncomingConnection: false)
    }
    
    private func checkTimeouts() {
        if !started || finished { return }
        
        BFLog("DownloadTask::%@::checkTimeouts", objId)
        
        var timedOutNodes = Set<String>()
        for (nodeId, lastReceiveTime) in nodesLastReceiveTime {
            if lastReceiveTime.timeIntervalSinceNow * -1 > DownloadTask.timeout {
                timedOutNodes.insert(nodeId)
            }
        }
        for nodeId in timedOutNodes {
            BFLog("DownloadTask::%@::checkTimeouts handle node %@ timed out", objId, nodeId)
            let timeoutCount = (nodesTimeoutsCount.removeValue(forKey: nodeId) ?? 0) + 1
            var timeoutLimitExceed = false
            if timeoutCount >= DownloadTask.timeoutsLimit {
                timeoutLimitExceed = true
            } else {
                timeoutLimitExceed = false
                nodesTimeoutsCount[nodeId] = timeoutCount
            }
            onNodeDisconnected(
                nodeId, connectionAlive: true, timeoutLimitExceed: timeoutLimitExceed)
        }
    }
}
