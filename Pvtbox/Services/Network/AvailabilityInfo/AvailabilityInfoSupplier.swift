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

class AvailabilityInfoSupplier {
    private weak var connectivityService: ConnectivityService?
    private weak var downloadManager: DownloadManager?
    private weak var dataBaseService: DataBaseService?
    private var dataSubscriptions = [String: Set<String>]()
    private var async: ((@escaping () -> ()) -> ())?
    
    init(_ async: @escaping (@escaping () -> ()) -> (),
         _ connectivity: ConnectivityService?,
         _ downloadManager: DownloadManager?,
         _ dataBaseService: DataBaseService?) {
        self.connectivityService = connectivity
        self.downloadManager = downloadManager
        self.dataBaseService = dataBaseService
        self.async = async
    }
    
    public func stop() {
        BFLog("AvailabilityInfoSupplier::stop")
    }
    
    public func onNodeDisconnected(_ nodeId: String) {
        BFLog("AvailabilityInfoSupplier::onNodeDisconnected: %@", nodeId)
        var newSubscriptions = [String: Set<String>]()
        for (objId, subscribedNodes) in dataSubscriptions {
            var subscribedNodes = subscribedNodes
            subscribedNodes.remove(nodeId)
            if !subscribedNodes.isEmpty {
                newSubscriptions[objId] = subscribedNodes
            }
        }
        dataSubscriptions = newSubscriptions
    }
    
    public func onRequest(_ message: Proto_Message, from nodeId: String) -> Proto_Message? {
        BFLog("AvailabilityInfoSupplier::onRequest from nodeId: %@", nodeId)
        var res: Proto_Message? = nil
        guard let hashAndSize = try? dataBaseService?.getHashAndSize(
            byEventUuid: message.objID) else { return res }
        
        let (hash, size) = hashAndSize
        
        if FileTool.exists(
            FileTool.copiesDirectory.appendingPathComponent(hash)) {
            var msg = message
            msg.mtype = .availabilityInfoResponse
            var info = Proto_Info()
            info.offset = 0
            info.length = UInt64(size)
            msg.info.append(info)
            res = msg
        } else {
            var subscribe = true
            if let downloadedChunks = downloadManager?.getDownloadedChunks(
                message.objID) {
                var msg = message
                msg.mtype = .availabilityInfoResponse
                for (offset, length) in downloadedChunks {
                    var info = Proto_Info()
                    info.offset = offset
                    info.length = length
                    msg.info.append(info)
                }
                res = msg
            } else {
                if let localIdentifier = dataBaseService?.getFile(
                    byEventUuid: message.objID)?.localIdentifier {
                    let fetchOptions = PHFetchOptions()
                    fetchOptions.fetchLimit = 1
                    if let _ = PHAsset.fetchAssets(
                        withLocalIdentifiers: [localIdentifier], options: fetchOptions)
                        .firstObject {
                        subscribe = false
                        var msg = message
                        msg.mtype = .availabilityInfoResponse
                        var info = Proto_Info()
                        info.offset = 0
                        info.length = UInt64(size)
                        msg.info.append(info)
                        res = msg
                    }
                }
            }
            if subscribe {
                var subscribedNodes = dataSubscriptions[message.objID]
                if subscribedNodes == nil {
                    subscribedNodes = Set<String>()
                }
                subscribedNodes!.insert(nodeId)
                dataSubscriptions[message.objID] = subscribedNodes
            }
        }
        
        return res
    }
    
    public func onAbort(_ message: Proto_Message, from nodeId: String) {
        BFLog("AvailabilityInfoSupplier::onAbort from nodeId: %@", nodeId)
        if var subscribedNodes = dataSubscriptions[message.objID] {
            subscribedNodes.remove(nodeId)
            if !subscribedNodes.isEmpty {
                dataSubscriptions[message.objID] = subscribedNodes
            }
        }
    }
    
    public func onNewDataDownloaded(_ objId: String, offset: UInt64, length: UInt64) {
        BFLog("AvailabilityInfoSupplier::onNewDataDownloaded for %@", objId)
        guard let subscribedNodes = dataSubscriptions[objId] else { return }
        var msg = Proto_Message()
        msg.magicCookie = 0x7a52fa73
        msg.mtype = .availabilityInfoResponse
        msg.objType = .file
        msg.objID = objId
        var info = Proto_Info()
        info.offset = offset
        info.length = length
        msg.info.append(info)
        guard let data = try? msg.serializedData() else { return }
        
        for nodeId in subscribedNodes {
            connectivityService?.sendMessage(
                data, nodeId: nodeId, sendThroughIncomingConnection: true)
        }
    }
}
