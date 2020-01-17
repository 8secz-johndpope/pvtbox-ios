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

class AvailabilityInfoConsumer {
    private weak var connectivityService: ConnectivityService?
    private var subscriptions = Set<String>()
    private var async: ((@escaping () -> ()) -> ())?
    
    init(_ async: @escaping (@escaping () -> ()) -> (), _ connectivity: ConnectivityService?) {
        self.connectivityService = connectivity
        self.async = async
        self.connectivityService?.outgoingNodeConnected = { [weak self] nodeId in
            self?.async? {
                self?.onNodeConnected(nodeId)
            }
        }
    }
    
    func stop() {
        connectivityService?.outgoingNodeConnected = nil
    }
    
    func subscribe(_ objIds: Set<String>) {
        subscriptions.formUnion(objIds)
        guard let connectivity = connectivityService else { return }
        let connectedNodes = connectivity.outgoingConnectedNodes
        if connectedNodes.isEmpty { return }
        let requests = generateRequests(objIds)
        for nodeId in connectedNodes {
            for request in requests {
                connectivity.sendMessage(
                    request, nodeId: nodeId, sendThroughIncomingConnection: false)
            }
        }
    }
    
    func unsubscribe(_ objIds: Set<String>) {
        subscriptions.subtract(objIds)
    }
    
    func unsubscribe(_ objId: String) {
        subscriptions.remove(objId)
    }
    
    func resubscribe() {
        guard let connectivity = connectivityService,
            !subscriptions.isEmpty else { return }
        let connectedNodes = connectivity.outgoingConnectedNodes
        let requests = generateRequests(subscriptions)
        for nodeId in connectedNodes {
            BFLog("AvailabilityInfoConsumer::resubscribe send %d requests to node %@",
                  subscriptions.count, nodeId)
            for request in requests {
                connectivity.sendMessage(
                    request, nodeId: nodeId, sendThroughIncomingConnection: false)
            }
        }
    }
    
    private func onNodeConnected(_ nodeId: String) {
        BFLog("AvailabilityInfoConsumer::onNodeConnected %@", nodeId)
        guard let connectivity = connectivityService,
            !subscriptions.isEmpty else { return }
        let requests = generateRequests(subscriptions)
        BFLog("AvailabilityInfoConsumer::onNodeConnected send %d requests to node %@",
              subscriptions.count, nodeId)
        for request in requests {
            connectivity.sendMessage(
                request, nodeId: nodeId, sendThroughIncomingConnection: false)
        }
    }
    
    private func generateRequests(_ objIds: Set<String>) -> [Data] {
        var requests = [Data]()
        var messages = Proto_Messages()
        var count = 0
        for objId in objIds {
            var message = Proto_Message()
            message.magicCookie = 0x7a52fa73
            message.mtype = .availabilityInfoRequest
            message.objID = objId
            message.objType = .file
            messages.msg.append(message)
            count += 1
            if count >= 99 {
                requests.append(try! messages.serializedData())
                messages = Proto_Messages()
                count = 0
            }
        }
        requests.append(try! messages.serializedData())
        return requests
    }
}
