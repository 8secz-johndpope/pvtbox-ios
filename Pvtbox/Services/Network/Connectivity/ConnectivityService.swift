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
import WebRTC

class ConnectivityService : ConnectionListener {
    private static let hardConnectionsLimit = 8
    
    private let dispatchQueue = DispatchQueue(
        label: "net.pvtbox.service.network.connectivity", qos: .utility)
    private weak var signalServer: SignalServerClient?
    private weak var speedCalculator: SpeedCalculator?
    private weak var dataBaseService: DataBaseService?
    
    private var nodes = Dictionary<String, Node>()
    
    private var incomingConnections = Dictionary<String, Connection>()
    private var incomingNodesConnections = Dictionary<String, Set<String>>()
    public  var incomingConnectedNodes = Set<String>()
    
    private var outgoingConnections = Dictionary<String, Connection>()
    private var outgoingNodesConnections = Dictionary<String, Set<String>>()
    public  var outgoingConnectedNodes = Set<String>()
    
    private var factory: RTCPeerConnectionFactory!
    private var iceServers: [RTCIceServer] = [RTCIceServer]()
    
    private var refreshConnectionsWorkItem: DispatchWorkItem? = nil
    
    init(servers: [JSON], signalServerClient: SignalServerClient?,
         speedCalculator: SpeedCalculator?, dataBaseService: DataBaseService?) {
        self.signalServer = signalServerClient
        self.speedCalculator = speedCalculator
        self.dataBaseService = dataBaseService
        
        dispatchQueue.async { [weak self] in
            self?.initWebRtc(servers)
        }
    }
    
    public func stop() {
        dispatchQueue.sync {
            factory = nil
        }

        nodes.removeAll()
        incomingConnections.removeAll()
        incomingNodesConnections.removeAll()
        outgoingConnections.removeAll()
        outgoingNodesConnections.removeAll()
        refreshConnectionsWorkItem?.cancel()
        refreshConnectionsWorkItem = nil
    }
    
    public var incomingNodeConnected: ((String) -> ())?
    public var incomingNodeDisconnected: ((String) -> ())?
    public var outgoingNodeConnected: ((String) -> ())?
    public var outgoingNodeDisconnected: ((String) -> ())?
    
    public var messageReceived: ((Data, String) -> ())?
    
    private func initWebRtc(_ servers: [JSON]) {
        BFLog("ConnectivityService::initWebRtc")
        RTCConfiguration.initialize()
        RTCInitializeSSL()
        factory = RTCPeerConnectionFactory()
        for server in servers {
            switch server["server_type"].stringValue {
            case "TURN":
                let addr = "turn:" + server["server_url"].string!
                let login = server["server_login"].string!
                let password = server["server_password"].string!
                iceServers.append(RTCIceServer(
                    urlStrings: [addr], username: login, credential: password))
            case "STUN":
                let addr = "stun:" + server["server_url"].string!
                iceServers.append(RTCIceServer(urlStrings: [addr]))
            default:
                continue
            }
        }
    }
    
    public func setNodeList(_ nodes: [JSON]) {
        dispatchQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            BFLog("ConnectivityService::setNodeList")
            for node in nodes {
                if node["is_online"].boolValue {
                    strongSelf.addNode(node["id"].string!, node["type"].string!, node["own"].bool!)
                }
            }
            strongSelf.refreshConnections()
        }
    }
    
    public func onNodeConnected(_ node: JSON) {
        dispatchQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            BFLog("ConnectivityService::onNodeConnected")
            if node["is_online"].boolValue {
                strongSelf.addNode(node["id"].string!, node["type"].string!, node["own"].bool!)
                strongSelf.refreshConnections()
            }
        }
    }
    
    public func onNodeDisconnected(_ id: String) {
        dispatchQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            BFLog("ConnectivityService::onNodeDisconnected")
            strongSelf.disconnectConnections(
                id, disconnectIncomingConnections: true, disconnectOutgoingConnections: true)
            strongSelf.nodes.removeValue(forKey: id)
        }
    }
    
    public func onDisconnectedFromServer() {
        dispatchQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            BFLog("ConnectivityService::onDisconnectedFromServer")
            for nodeId in strongSelf.nodes.keys {
                strongSelf.disconnectConnections(
                    nodeId, disconnectIncomingConnections: true, disconnectOutgoingConnections: true)
            }
            strongSelf.nodes.removeAll()
        }
    }
    
    public func onSdpMessage(_ message: String, from nodeId: String, _ connectionId: String) {
        dispatchQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            BFLog("ConnectivityService::onSdpMessage %@", message)
            if strongSelf.nodes[nodeId] == nil { return }
            
            var connection = strongSelf.incomingConnections[connectionId] ?? strongSelf.outgoingConnections[connectionId]
            
            if connection == nil {
                var nodeConnections = strongSelf.incomingNodesConnections[nodeId]
                if nodeConnections?.count ?? 0 < ConnectivityService.hardConnectionsLimit {
                    connection = Connection(
                        id: connectionId, nodeId: nodeId, listener: self,
                        signalServerClient: self?.signalServer,
                        dispatchQueue: strongSelf.dispatchQueue)
                    strongSelf.incomingConnections[connectionId] = connection
                    strongSelf.createConnection(connection!)
                    if nodeConnections == nil {
                        nodeConnections = Set<String>()
                    }
                    nodeConnections?.insert(connectionId)
                    strongSelf.incomingNodesConnections[nodeId] = nodeConnections
                    strongSelf.dispatchQueue.asyncAfter(
                        deadline: .now() + 20, execute: { [weak self] in
                            self?.checkConnected(connectionId, isIncoming: true)
                    })
                } else {
                    return
                }
            }
            connection?.onSdpMessage(message)
        }
    }
    
    public func sendMessage(_ message: Data, nodeId: String, sendThroughIncomingConnection: Bool) {
        dispatchQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            guard let nodeConnections = sendThroughIncomingConnection ?
                strongSelf.incomingNodesConnections[nodeId] :
                strongSelf.outgoingNodesConnections[nodeId] else { return }
            BFLog("ConnectivityService::sendMessage")
            for connectionId in nodeConnections.shuffled() {
                if let connection = sendThroughIncomingConnection ?
                    strongSelf.incomingConnections[connectionId] :
                    strongSelf.outgoingConnections[connectionId],
                    connection.open,
                    !connection.isOverflowed {
                    connection.send(message)
                    self?.speedCalculator?.onDataUploaded(Double(message.count))
                    BFLog("ConnectivityService::sendMessage sent successfully")
                    return
                }
            }
        }
    }
    
    public func sendMessages(
        _ messages: [Data], nodeId: String, onSent: @escaping ()->(), checkFunc: @escaping ()->Bool) {
        dispatchQueue.async {
            var messages = messages
            guard let nodeConnections = self.incomingNodesConnections[nodeId],
                checkFunc() else {
                onSent()
                return
            }
            while true {
                for connectionId in nodeConnections {
                    if let connection = self.incomingConnections[connectionId],
                        connection.open,
                        !connection.isOverflowed {
                        guard let message = messages.popLast() else {
                            onSent()
                            return
                        }
                        connection.send(message)
                        self.speedCalculator?.onDataUploaded(Double(message.count))
                    } else {
                        self.dispatchQueue.asyncAfter(
                            deadline: .now() + 0.25, execute: { [weak self] in
                                self?.sendMessages(messages, nodeId: nodeId, onSent: onSent, checkFunc: checkFunc)
                        })
                        return
                    }
                }
            }
        }
    }
    
    public func reconnect(to nodeId: String) {
        BFLog("ConnectivityService::reconnect to node: %@", nodeId)
        self.dispatchQueue.async { [weak self] in
            self?.disconnectConnections(
                nodeId, disconnectIncomingConnections: false, disconnectOutgoingConnections: true)
            self?.refreshConnections()
        }
    }
    
    private func addNode(_ id: String, _ nodeType: String, _ isOwn: Bool) {
        BFLog("ConnectivityService::addNode %@", id)
        let node = Node(id: id, type: nodeType, own: isOwn)
        if nodes[id] != nil {
            disconnectConnections(
                id, disconnectIncomingConnections: true, disconnectOutgoingConnections: true)
        }
        nodes[id] = node
    }
    
    private func refreshConnections() {
        if refreshConnectionsWorkItem != nil { return }
        refreshConnectionsWorkItem = DispatchWorkItem { [weak self] in
            self?.refreshConnectionsWorkItem = nil
            self?.executeRefreshConnections()
        }
        
        self.dispatchQueue.asyncAfter(
            deadline: .now() + 1, execute: refreshConnectionsWorkItem!)
    }
    
    private func executeRefreshConnections() {
        guard let signal = signalServer, signal.isConnected else { return }
        BFLog("ConnectivityService::refreshConnections")
        for (nodeId, node) in nodes {
            if node.type != "node" { continue }
            var nodeConnections = outgoingNodesConnections[nodeId]
            if nodeConnections?.count ?? 0 < (5 / nodes.count + 1) {
                let connectionId = UUID().uuidString
                let connection = Connection(
                    id: connectionId, nodeId: nodeId, listener: self,
                    signalServerClient: signalServer, dispatchQueue: dispatchQueue)
                outgoingConnections[connectionId] = connection
                if nodeConnections == nil {
                    nodeConnections = Set<String>()
                }
                nodeConnections?.insert(connectionId)
                outgoingNodesConnections[nodeId] = nodeConnections
                
                createConnection(connection)
                connection.initiateConnection()
                dispatchQueue.asyncAfter(deadline: .now() + 20, execute: { [weak self] in
                    self?.checkConnected(connectionId, isIncoming: false)
                })
            }
        }
    }
    
    private func createConnection(_ connection: Connection) {
        let config = RTCConfiguration()
        config.iceServers = iceServers
        config.bundlePolicy = .maxBundle
        config.continualGatheringPolicy = .gatherOnce
        config.sdpSemantics = .unifiedPlan
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        
        let pc = factory.peerConnection(
            with: config, constraints:constraints, delegate: connection)
        connection.setPeerConnection(pc)
    }
    
    private func disconnectConnections(
            _ nodeId: String,
            disconnectIncomingConnections: Bool,
            disconnectOutgoingConnections: Bool) {
        BFLog("ConnectivityService::disconnectConnections %@", nodeId)
        if disconnectIncomingConnections,
                let nodeConnections = incomingNodesConnections[nodeId] {
            for connId in nodeConnections {
                let connection = incomingConnections.removeValue(forKey: connId)
                connection?.disconnect()
            }
            incomingNodesConnections.removeValue(forKey: nodeId)
            if incomingConnectedNodes.contains(nodeId) {
                incomingConnectedNodes.remove(nodeId)
                incomingNodeDisconnected?(nodeId)
            }
        }
        if disconnectOutgoingConnections,
                let nodeConnections = outgoingNodesConnections[nodeId] {
            for connId in nodeConnections {
                let connection = outgoingConnections.removeValue(forKey: connId)
                connection?.disconnect()
            }
            outgoingNodesConnections.removeValue(forKey: nodeId)
            if outgoingConnectedNodes.contains(nodeId) {
                outgoingConnectedNodes.remove(nodeId)
                outgoingNodeDisconnected?(nodeId)
            }
        }
        dataBaseService?.updateOwnDeviceStatus(connectedNodes: outgoingConnectedNodes.count)
    }
    
    private func checkConnected(_ connectionId: String, isIncoming: Bool) {
        BFLog("ConnectivityService::checkConnected %@", connectionId)
        guard let connection = isIncoming ?
            incomingConnections[connectionId] : outgoingConnections[connectionId],
            !connection.open else { return }
        BFLog("ConnectivityService::checkConnected %@, not connected", connectionId)
        if isIncoming {
            incomingConnections.removeValue(forKey: connectionId)
            var nodeConnections = incomingNodesConnections[connection.nodeId]!
            nodeConnections.remove(connectionId)
            if !nodeConnections.isEmpty {
                incomingNodesConnections[connection.nodeId] = nodeConnections
            }
        } else {
            outgoingConnections.removeValue(forKey: connectionId)
            var nodeConnections = outgoingNodesConnections[connection.nodeId]!
            nodeConnections.remove(connectionId)
            if !nodeConnections.isEmpty {
                outgoingNodesConnections[connection.nodeId] = nodeConnections
            }
        }
        self.refreshConnections()
    }
    
    // ConnectionListener protocol
    func onConnected(_ connection: Connection) {
        dispatchQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            BFLog("ConnectivityService::on_connected")
            let isIncoming = strongSelf.incomingConnections[connection.id] != nil
            let isOutgoing = strongSelf.outgoingConnections[connection.id] != nil
            if !isIncoming && !isOutgoing {
                connection.disconnect()
                return
            }
            if isIncoming && !strongSelf.incomingConnectedNodes.contains(connection.nodeId) {
                strongSelf.incomingConnectedNodes.insert(connection.nodeId)
                strongSelf.incomingNodeConnected?(connection.nodeId)
            } else if isOutgoing && !strongSelf.outgoingConnectedNodes.contains(connection.nodeId) {
                strongSelf.outgoingConnectedNodes.insert(connection.nodeId)
                BFLog("Node connected: %@", connection.nodeId)
                strongSelf.dataBaseService?.updateOwnDeviceStatus(
                        connectedNodes: strongSelf.outgoingConnectedNodes.count)
                    strongSelf.dispatchQueue.asyncAfter(
                        deadline: .now() + 1, execute: { [weak self] in
                            self?.outgoingNodeConnected?(connection.nodeId)
                    })
            }
            strongSelf.refreshConnections()
        }
    }
    
    func onDisconnected(_ connection: Connection) {
        dispatchQueue.async { [weak self, weak connection] in
            connection?.disconnect()
            guard let strongSelf = self,
                let connection = connection else { return }
            BFLog("ConnectivityService::on_disconnected %@", connection.id)
            let isIncoming = strongSelf.incomingConnections[connection.id] != nil
            let isOutgoing = strongSelf.outgoingConnections[connection.id] != nil
            if !isIncoming && !isOutgoing { return }
            if isIncoming {
                strongSelf.incomingConnections.removeValue(forKey: connection.id)
                strongSelf.incomingNodesConnections[connection.nodeId]?.remove(connection.id)
                if strongSelf.incomingNodesConnections[connection.nodeId]?.isEmpty ?? false {
                    strongSelf.disconnectConnections(
                        connection.nodeId,
                        disconnectIncomingConnections: true,
                        disconnectOutgoingConnections: false)
                }
            } else {
                strongSelf.outgoingConnections.removeValue(forKey: connection.id)
                strongSelf.outgoingNodesConnections[connection.nodeId]?.remove(connection.id)
                strongSelf.disconnectConnections(
                    connection.nodeId,
                    disconnectIncomingConnections: false,
                    disconnectOutgoingConnections: true)
            }
            
            strongSelf.refreshConnections()
        }
    }
    
    func onMessage(_ connection: Connection, data: Data) {
        dispatchQueue.async { [weak self] in
            guard let strongSelf = self else { return }
            BFLog("ConnectivityService::on_message")
            strongSelf.messageReceived?(data, connection.nodeId)
            self?.speedCalculator?.onDataDownloaded(Double(data.count))
        }
    }
}
