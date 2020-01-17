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

class SignalServerService : SignalServerClient {
    private var serverAddress: String?
    weak var syncService: SyncService?
    weak var dataBaseService: DataBaseService?
    weak var connectivityService: ConnectivityService?
    weak var uploadsDownloader: UploadsDownloader?
    
    public func start(withAddress address: String) {
        serverAddress = address
        dispatchQueue.async {
            self.start()
        }
    }
    
    public func setConnectivityService(_ cs: ConnectivityService?) {
        connectivityService = cs
    }
    
    public var onConnectedToServer: (() -> ())?
    
    public var onNodeConnected: ((String?) -> ())?
    
    public func sendEventsCheck() throws {
        BFLog("SignalServerService::sendEventsCheck")
        guard let db = dataBaseService else { return }
        let (_, checkedEventId, _) = try db.getLastEventId()
        let request: [String: Any] = [
            "operation": "last_file_events",
            "data": [
                "last_event_id": String(checkedEventId),
                "checked_event_id": String(checkedEventId),
                "events_count_check": String(0)
            ]]
        let message = JSONCoder.encode(request)!
        send(message)
    }
    
    internal override func getUrl() throws -> String {
        guard let db = dataBaseService else { throw "exiting" }
        let (lastEventId, checkedEventId, eventsCount) = try db.getLastEventId()
        guard let serverAddress = serverAddress,
            let userHash = PreferenceService.userHash,
            let nodeHash = PreferenceService.nodeHash else {
                throw "exiting"
        }
        return String(
            format: "%@/ws/node/%@/%@?last_event_id=%d&checked_event_id=%d&events_count_check=%d&no_send_changed_files=1&max_events_per_request=%d&max_events_total=%d&node_without_backup=1",
            serverAddress, userHash, nodeHash,
            lastEventId, checkedEventId, eventsCount, Const.eventsPackSize, Const.maxEventsTotal)
    }

    internal override func handleMessage(_ message: JSON) {
        let operation = message["operation"].stringValue
        BFLog("SignalServerService::handleMessage: %@", operation)
        do {
            switch operation {
            case "file_events":
                syncService?.onFileEvents(
                    message["data"].jsonArrayValue, nodeId: message["node_id"].string)
            case "peer_list":
                let nodes = message["data"].jsonArrayValue
                try dataBaseService?.setDeviceList(nodes)
                connectivityService?.setNodeList(nodes)
            case "peer_connect":
                let node = message["data"].json
                try dataBaseService?.onDeviceConnected(node)
                connectivityService?.onNodeConnected(node)
                onNodeConnected?(node["id"].string)
            case "peer_disconnect":
                let nodeId = message["node_id"].string
                try dataBaseService?.onDeviceDisconnected(nodeId!)
                connectivityService?.onNodeDisconnected(nodeId!)
            case "node_status":
                try dataBaseService?.onDeviceStatusUpdated(
                    message["node_id"].stringValue, message["data"])
            case "sdp":
                connectivityService?.onSdpMessage(
                    message["data"]["message"].string!,
                    from: message["node_id"].string!,
                    message["data"]["conn_uuid"].string!)
            case "sharing_list":
                syncService?.setShare(message["data"].jsonArrayValue)
            case "sharing_enable":
                syncService?.addShare(message["data"].json)
            case "sharing_disable":
                syncService?.removeShare(message["data"].json)
            case "collaborated_folders":
                syncService?.setCollaboratedFolders(message["data"].jsonArrayValue)
            case "remote_action":
                PvtboxService.handleRemoteAction(message["data"].json)
            case "upload_add":
                uploadsDownloader?.add(message["data"].json)
            case "upload_cancel":
                uploadsDownloader?.cancel(message["data"].json)
            case "license_type":
                PvtboxService.onLicenseChanged(message["data"].string!)
            case "new_notifications_count":
                let count = Int(message["data"]["count"].stringValue) ?? message["data"]["count"].intValue
                PvtboxService.onNotificationsCountChanged(count)
            default:
                BFLogWarn("Unsupported operation: %@", String(describing: operation))
                return
            }
        } catch {
            BFLogErr("SignalServerService::handleMessage error")
            handleMessage(message)
        }
    }
    
    override func onConnected() {
        dataBaseService?.updateOwnDeviceStatus(online: true, fetchingChanges: true)
        onConnectedToServer?()
    }
    
    override func onDisconnected(_ error: Error?) {
        dataBaseService?.updateOwnDeviceStatus(online: false)
        connectivityService?.onDisconnectedFromServer()
        
        if (error as? WSError)?.code == 403 {
            processingDispatchQueue.async {
                PvtboxService.stop()
                PvtboxService.start()
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
