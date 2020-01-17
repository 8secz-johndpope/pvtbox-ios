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

class DataSupplier {
    private static let processingRequestsLimit = 2
    
    private weak var connectivityService: ConnectivityService?
    private weak var dataBaseService: DataBaseService?
    private weak var downloadManager: DownloadManager?
    private weak var temporaryFilesManager: TemporaryFilesManager?
    private var async: ((@escaping () -> ()) -> ())?
    
    private var processingRequests = Set<DataSupplierRequest>()
    private var queuedRequests: [DataSupplierRequest] = []
    
    init(_ async: @escaping (@escaping () -> ()) -> (),
         _ connectivity: ConnectivityService?,
         _ downloadManager: DownloadManager?,
         _ dataBaseService: DataBaseService?,
         _ temporaryFilesManager: TemporaryFilesManager?) {
        self.connectivityService = connectivity
        self.downloadManager = downloadManager
        self.dataBaseService = dataBaseService
        self.temporaryFilesManager = temporaryFilesManager
        self.async = async
    }
    
    public func stop() {
        BFLog("DataSupplier::stop")
        downloadManager = nil
    }
    
    public func onNodeDisconnected(_ nodeId: String) {
        BFLog("DataSupplier::onNodeDisconnected: %@", nodeId)
        queuedRequests.removeAll(where: { request in
            request.nodeId == nodeId
        })
        let toRemove = processingRequests.filter({ request in
            request.nodeId == nodeId
        })
        processingRequests.subtract(toRemove)
    }
    
    public func onRequest(_ message: Proto_Message, from nodeId: String) {
        BFLog("DataSupplier::onRequest from nodeId: %@", nodeId)
        
        queuedRequests.append(DataSupplierRequest(
            nodeId: nodeId, objId: message.objID,
            offset: message.info[0].offset, length: message.info[0].length))
        
        async? { [weak self] in self?.processRequests() }
    }
    
    public func onAbort(_ message: Proto_Message, from nodeId: String) {
        BFLog("DataSupplier::onAbort from nodeId: %@", nodeId)
        let offset = message.info.isEmpty ? nil : message.info[0].offset
        queuedRequests.removeAll(where: { request in
            request.nodeId == nodeId && request.objId == message.objID &&
                (offset != nil ? request.offset == offset : true)
        })
        let toRemove = processingRequests.filter({ request in
            request.nodeId == nodeId && request.objId == message.objID &&  
                (offset != nil ? request.offset == offset : true)
        })
        processingRequests.subtract(toRemove)
    }
    
    private func processRequests() {
        if processingRequests.count >= DataSupplier.processingRequestsLimit ||
            queuedRequests.isEmpty {
            return
        }
        
        let request = queuedRequests.removeFirst()
        processingRequests.insert(request)
        processRequest(request)
    }
    
    private func processRequest(_ request: DataSupplierRequest) {
        guard let hashAndSize = try? dataBaseService?.getHashAndSize(
            byEventUuid: request.objId) else { return }
        
        let (hash, size) = hashAndSize
        if request.offset + request.length > size { return }
        
        let copyUrl = FileTool.copiesDirectory.appendingPathComponent(hash)
        if FileTool.exists(copyUrl) {
            sendResponse(request, copyUrl)
            return
        } else if let downloadedChunks = downloadManager?.getDownloadedChunks(
            request.objId) {
            if let _ = downloadedChunks.first(where: { offset, length in
                return offset <= request.offset &&
                    offset + length >= request.offset + request.length
            }) {
                let downloadUrl = FileTool.copiesDirectory.appendingPathComponent(
                    hash).appendingPathExtension("download")
                sendResponse(request, downloadUrl)
                return
            }
        } else {
            let tmpFile = FileTool.tmpDirectory.appendingPathComponent(hash)
            temporaryFilesManager?.touch(tmpFile)
            if FileTool.exists(tmpFile) {
                sendResponse(request, tmpFile)
                return
            } else {
                if let file = dataBaseService?.getFile(
                    byEventUuid: request.objId),
                    let localIdentifier = file.localIdentifier {
                    fetchFileByLocalIndetifierAndSendResponse(
                        localIdentifier, tmpFile, file.convertedToJpeg, request)
                    return
                }
            }
        }
        
        processingRequests.remove(request)
        async? { [weak self] in self?.processRequests() }
        return
    }
    
    private func fetchFileByLocalIndetifierAndSendResponse(
        _ identifier: String, _ url: URL, _ convertToJpeg: Bool, _ request: DataSupplierRequest) {
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier], options: fetchOptions)
            .firstObject,
            let resource = PHAssetResource.assetResources(for: asset).first else {
                processingRequests.remove(request)
                // send failure
                async? { [weak self] in self?.processRequests() }
                return
        }
        
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true
        let temp = url.appendingPathExtension("tmp")
        FileTool.createFile(temp)
        guard let fileHandle = try? FileHandle(forWritingTo: temp) else {
            FileTool.delete(temp)
            processingRequests.remove(request)
            // send failure
            async? { [weak self] in self?.processRequests() }
            return
        }
        
        PHAssetResourceManager.default().requestData(
            for: resource, options: options,
            dataReceivedHandler: { data in
                fileHandle.write(data)
            },
            completionHandler: { [weak self] error in
                fileHandle.closeFile()
                if error != nil {
                    FileTool.delete(temp)
                    self?.processingRequests.remove(request)
                    // send failure
                    self?.async? { [weak self] in self?.processRequests() }
                    return
                } else {
                    self?.async? { [weak self] in
                        if convertToJpeg {
                            guard let image = CIImage(contentsOf: temp),
                                let data = CIContext().jpegRepresentation(
                                    of: image, colorSpace: CGColorSpaceCreateDeviceRGB()) else {
                                        FileTool.delete(temp)
                                        self?.processingRequests.remove(request)
                                        // send failure
                                        self?.async? { [weak self] in self?.processRequests() }
                                        return
                            }
                            FileTool.delete(temp)
                            self?.temporaryFilesManager?.touch(url)
                            try? data.write(to: url)
                        } else {
                            self?.temporaryFilesManager?.touch(url)
                            FileTool.move(from: temp, to: url)
                        }
                        self?.sendResponse(request, url)
                    }
                }
        })
    }
    
    private func sendResponse(_ request: DataSupplierRequest, _ url:URL) {
        var messages: [Data] = []
        var currentOffset = request.offset
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            async? { [weak self] in
                self?.processingRequests.remove(request)
                self?.processRequests()
            }
            return
        }
        while currentOffset < request.offset + request.length {
            let length = min(
                DownloadTask.downloadChunkSize,
                request.offset + request.length - currentOffset)
            fileHandle.seek(toFileOffset: currentOffset)
            autoreleasepool {
                let data = fileHandle.readData(ofLength: Int(length))
                var msg = Proto_Message()
                msg.magicCookie = 0x7a52fa73
                msg.mtype = .dataResponse
                msg.objType = .file
                msg.objID = request.objId
                msg.data = data
                var info = Proto_Info()
                info.offset = currentOffset
                info.length = length
                msg.info.append(info)
                try! messages.append(msg.serializedData())
            }
            currentOffset += length
        }
        connectivityService?.sendMessages(
            messages, nodeId: request.nodeId,
            onSent: { [weak self] in
                self?.async? { [weak self] in
                    self?.processingRequests.remove(request)
                    self?.processRequests()
                }
            },
            checkFunc: { [weak self] in
                return self?.processingRequests.contains(request) ?? false
        })
    }
}
