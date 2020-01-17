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

class SignalServerClient : WebSocketDelegate, WebSocketPongDelegate {
    private static let pingTimeout = 50.0
    internal let dispatchQueue = DispatchQueue(
        label: "net.pvtbox.service.signal", qos: .utility)
    internal let processingDispatchQueue = DispatchQueue(
        label: "net.pvtbox.service.signal.processing", qos: .utility)
    private var webSocket: WebSocket?
    private var lastPing: Date?
    private var checkPingsWork: DispatchWorkItem?
    private var reconnectIfNotConnectedWork: DispatchWorkItem?
    internal var enabled = true
    private final var security: SSLSecurity
    
    public var isConnected: Bool {
        get {
            return webSocket?.isConnected ?? false
        }
    }
    
    internal init() {
        var certPath = Bundle.main.path(forResource: "pvtbox_net", ofType: "cer")!
        let pvtboxCertData = try! Data(contentsOf: URL(fileURLWithPath: certPath))
        certPath = Bundle.main.path(forResource: "comodo_dvssca", ofType: "cer")!
        let comodoDvsscaCertData = try! Data(contentsOf: URL(fileURLWithPath: certPath))
        certPath = Bundle.main.path(forResource: "comodo_ca", ofType: "cer")!
        let comodoCaCertData = try! Data(contentsOf: URL(fileURLWithPath: certPath))
        security = SSLSecurity(
            certs: [
                SSLCert(data: pvtboxCertData),
                SSLCert(data: comodoDvsscaCertData),
                SSLCert(data: comodoCaCertData),
            ], usePublicKeys: false)
    }
    
    public func stop() {
        BFLog("SignalServerClient::stop")
        dispatchQueue.sync {
            disconnect(updateStatus: false)
            BFLog("SignalServerClient::stop done")
        }
    }
    
    private func disconnect(updateStatus: Bool = true) {
        enabled = false
        checkPingsWork?.cancel()
        reconnectIfNotConnectedWork?.cancel()
        webSocket?.delegate = nil
        webSocket?.disconnect()
        webSocket = nil
        onDisconnected(nil)
    }
    
    public func send(_ message: String) {
        dispatchQueue.async {
            self.webSocket?.write(string: message)
        }
        BFLog("SignalServerClient::send: %@", message)
    }
    
    internal func start() {
        BFLog("SignalServerClient::start")
        guard let url = try? getUrl() else {
            dispatchQueue.asyncAfter(deadline: .now() + 2, execute: { [weak self] in
                self?.start()
            })
            return
        }
        BFLog("SignalServerClient::start: Connecting to signal server by url: %@", url)
        enabled = true
        var urlRequest = URLRequest(url: URL(string: url)!)
        urlRequest.timeoutInterval = TimeInterval(10)
        reconnectIfNotConnectedWork = DispatchWorkItem() { [weak self] in self?.reconnect() }
        dispatchQueue.asyncAfter(deadline: .now() + 10, execute: reconnectIfNotConnectedWork!)
        webSocket = WebSocket(request: urlRequest)
        webSocket!.enableCompression = false
        if !PreferenceService.isSelfHosted {
            webSocket!.security = security
        }
        webSocket!.delegate = self
        webSocket!.pongDelegate = self
        webSocket!.callbackQueue = dispatchQueue
        webSocket!.connect()
    }
    
    internal func getUrl() throws -> String {
        throw "NotImplemented"
    }
    
    internal func handleMessage(_ message: JSON) {
        return
    }
    
    func websocketDidConnect(socket: WebSocketClient) {
        BFLog("SignalServerClient::websocketDidConnect")
        reconnectIfNotConnectedWork?.cancel()
        onConnected()
        checkPingsWork = DispatchWorkItem() { [weak self] in self?.checkPings() }
        dispatchQueue.asyncAfter(deadline: .now() + 60, execute: checkPingsWork!)
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        BFLog("SignalServerClient::websocketDidDisconnect")
        if !enabled { return }
        checkPingsWork?.cancel()
        reconnectIfNotConnectedWork?.cancel()
        onDisconnected(error)
    }
    
    func onConnected() {}
    
    func onDisconnected(_ error: Error?) {}
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        let json = JSON(text)
        BFLog("SignalServerClient::websocketDidReceiveMessage %@", json["operation"].stringValue)
        processingDispatchQueue.async {
            self.handleMessage(json)
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        BFLog("SignalServerClient::websocketDidReceiveData")
    }
    
    func websocketDidReceivePong(socket: WebSocketClient, data: Data?) {
        BFLog("SignalServerClient::websocketDidReceivePong")
    }
    
    func websocketDidReceivePing(socket: WebSocketClient, data: Data?) {
        BFLog("SignalServerClient::websocketDidReceivePing")
        lastPing = Date()
    }
    
    private func checkPings() {
        guard let timeout = lastPing?.timeIntervalSinceNow,
            enabled else { return }
        if timeout * -1 > SignalServerClient.pingTimeout {
            BFLog("SignalServerClient::checkPings timeout")
            reconnect()
        } else {
            BFLog("SignalServerClient::checkPings ok")
            checkPingsWork = DispatchWorkItem() { [weak self] in self?.checkPings() }
            dispatchQueue.asyncAfter(deadline: .now() + 30, execute: checkPingsWork!)
        }
    }
    
    private func reconnect() {
        BFLog("SignalServerClient::reconnect")
        disconnect()
        start()
    }
}
