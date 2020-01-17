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
import WebRTC
import JASON

class Connection : NSObject, RTCPeerConnectionDelegate, RTCDataChannelDelegate {
    
    let id: String
    let nodeId: String
    var open = false
    private var listener: ConnectionListener?
    private weak var signalServerClient: SignalServerClient?
    private var dispatchQueue: DispatchQueue
    private var peerConnection: RTCPeerConnection?
    private var dataChannels: [RTCDataChannel?] = [RTCDataChannel]()
    private var iceCandidates: [RTCIceCandidate]? = [RTCIceCandidate]()
    private var channelSelector = 0
    var isOverflowed: Bool {
        get {
            for channel in dataChannels {
                if channel?.bufferedAmount ?? 0 < 8 * 1024 * 1024 {
                    return false
                }
            }
            return true
        }
    }
    
    init(id: String, nodeId: String, listener: ConnectionListener?,
         signalServerClient: SignalServerClient?, dispatchQueue: DispatchQueue) {
        self.id = id
        self.nodeId = nodeId
        self.listener = listener
        self.signalServerClient = signalServerClient
        self.dispatchQueue = dispatchQueue
    }
    
    func setPeerConnection(_ peerConnection: RTCPeerConnection) {
        self.peerConnection = peerConnection
    }
    
    func initiateConnection() {
        let config = RTCDataChannelConfiguration()
        config.isNegotiated = false
        config.isOrdered = false
        let channel1 = peerConnection?.dataChannel(forLabel: id + "_1", configuration: config)
        channel1?.delegate = self
        dataChannels.append(channel1)
        //let channel2 = peerConnection?.dataChannel(forLabel: id + "_2", configuration: config)
        //channel2?.delegate = self
        //dataChannels.append(channel2)
        
        peerConnection?.offer(
            for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil),
            completionHandler: onLocalDescriptionCreated)
    }
    
    func onSdpMessage(_ message: String) {
        let json = JSON(message)
        if let candidate = json["candidate"].string,
            let sdpMid = json["sdpMid"].string,
            let sdpMLineIndex = json["sdpMLineIndex"].int {
                addIceCandidate(RTCIceCandidate(
                    sdp: candidate, sdpMLineIndex: Int32(sdpMLineIndex), sdpMid: sdpMid))
        } else if let type = json["type"].string,
            let sdp = json["sdp"].string {
                self.peerConnection?.setRemoteDescription(RTCSessionDescription(
                    type: RTCSessionDescription.type(for: type),
                    sdp: sdp), completionHandler: onDescriptionSet)
        }
    }
    
    func disconnect() {
        open = false
        peerConnection?.delegate = nil
        for channel in dataChannels {
            channel?.delegate = nil
            channel?.close()
        }
        dataChannels.removeAll()
        peerConnection?.close()
        peerConnection = nil
    }
    
    func send(_ message: Data) {
        for _ in 0...dataChannels.count {
            channelSelector += 1
            if (channelSelector >= dataChannels.count) {
                channelSelector = 0
            }
            let channel = dataChannels[channelSelector]
            if channel?.readyState ?? .closed == .open &&
                    channel?.bufferedAmount ?? 0 < 15 * 1024 * 1024 {
                channel?.sendData(RTCDataBuffer(data: message, isBinary: true))
                return
            }
        }
    }
    
    private func onLocalDescriptionCreated(_ sdp: RTCSessionDescription?, _ error: Error?) {
        if error != nil {
            BFLogErr("Connection::acceptConnection onLocalDescriptionCreated error: %@",
                     error.debugDescription)
        }
        dispatchQueue.async { [weak self] in
            guard let sdp = sdp else { return }
            self?.peerConnection?.setLocalDescription(
                sdp, completionHandler: self?.onDescriptionSet)
            self?.sendLocalDescription(sdp)
        }
    }
    
    private func onDescriptionSet(_ error: Error?) {
        BFLog("Connection::onDescriptionSet")
        if error != nil {
            BFLogErr("Connection::acceptConnection onDescriptionSet error: %@",
                     error.debugDescription)
        }
        dispatchQueue.async { [weak self] in
            guard let _ = self?.peerConnection?.remoteDescription,
                let _ = self?.peerConnection?.localDescription else {
                    guard let _ = self?.peerConnection?.remoteDescription else {
                        return
                    }
                    BFLog("Connection::onDescriptionSet create answer")
                    self?.peerConnection?.answer(
                        for: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil),
                        completionHandler: self?.onLocalDescriptionCreated)
                    return
            }
            self?.drainCandidates()
        }
    }
    
    private func sendLocalDescription(_ sdp: RTCSessionDescription) {
        let msg: [String: Any] = [
            "operation": "sdp",
            "node_id": nodeId,
            "data":  [
                "conn_uuid": id,
                "message": JSONCoder.encode([
                    "type": RTCSessionDescription.string(for: sdp.type),
                    "sdp": sdp.sdp
                    ])
                ]
            ]
        let message = JSONCoder.encode(msg)!
        signalServerClient?.send(message)
    }
    
    private func addIceCandidate(_ candidate: RTCIceCandidate) {
        if iceCandidates != nil {
            iceCandidates?.append(candidate)
        } else {
            peerConnection?.add(candidate)
        }
    }
    
    private func drainCandidates() {
        BFLog("Connection::drainCandidates")
        guard let candidates = iceCandidates else { return }
        for candidate in candidates {
            peerConnection?.add(candidate)
        }
        iceCandidates = nil
    }
    
    // RTCPeerConnectionDelegate
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        BFLog("Connection::peerConnection signalling state changed: %d", stateChanged.rawValue)
    }
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {
        BFLog("Connection::peerConnectionShouldNegotiate")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        BFLog("Connection::peerConnection ice connection new state: %d", newState.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        BFLog("Connection::peerConnection ice gathering new state: %d", newState.rawValue)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        dispatchQueue.async { [weak self] in
            self?.sendLocalCandidate(candidate)
        }
    }
    
    private func sendLocalCandidate(_ candidate: RTCIceCandidate) {
        BFLog("Connection::peerConnection generated candidate: %@", candidate)
        let msg: [String: Any] = [
            "operation": "sdp",
            "node_id": nodeId,
            "data":  [
                "conn_uuid": id,
                "message": JSONCoder.encode([
                    "sdpMLineIndex": candidate.sdpMLineIndex,
                    "sdpMid": candidate.sdpMid ?? "",
                    "candidate": candidate.sdp
                ])
            ]
        ]
        let message = JSONCoder.encode(msg)!
        signalServerClient?.send(message)
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        BFLog("Connection::peerConnection dataChannel opened")
        dataChannels.append(dataChannel)
        dataChannel.delegate = self
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {
    }
    
    // RTCDataChannelDelegate
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        BFLog("Connection::dataChannelDidChangeState new state: %d", dataChannel.readyState.rawValue)
        if dataChannel.readyState == .open && !open {
            open = true
            listener?.onConnected(self)
        } else if (dataChannel.readyState == .closing || dataChannel.readyState == .closed) && open {
            open = false
            listener?.onDisconnected(self)
        }
    }
    
    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        BFLog("Connection::dataChannel message received")
        listener?.onMessage(self, data: buffer.data)
    }
}
