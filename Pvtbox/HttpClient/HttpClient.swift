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
import Alamofire
import JASON

class HttpClient {
    public var signalServerAddress: String?
    public static var shared = HttpClient()
    internal let responsesQueue = DispatchQueue(
        label: "net.pvtbox.network.http.responses", qos: .utility, attributes: [.concurrent])
    internal let requestsQueue = DispatchQueue(
        label: "net.pvtbox.network.http.requests", qos: .utility, attributes: [.concurrent])
    private static let updateNodeHashErrcodes = Set([
        "USER_NODE_MISMATCH",
        "NODEHASH_EXIST",
        "NODE_EXIST",
        "BAD_NODE_STATUS",
        ])
    private static let updateNodeSignErrcodes = Set([
        "SIGNATURE_INVALID",
        "FLST",
        "NODE_SIGN_NOT_FOUND",
        "USER_NODE_MISMATCH",
        "NODEHASH_EXIST",
        "NODE_EXIST",
    ])
    private static let expectedErrcodes = Set([
        "FS_SYNC",
        "FS_SYNC_NOT_FOUND",
        "FS_SYNC_PARENT_NOT_FOUND",
        "EMAIL_EXIST",
        "USER_NOT_FOUND",
        "WRONG_DATA",
        "OPERATION_DENIED",
        "LOCKED_CAUSE_TOO_MANY_BAD_LOGIN",
        "LICENSE_LIMIT",
        "NODE_LOGOUT_EXIST",
        "NODE_WIPED",
        "FAILED_SEND_EMAIL",
        "ERROR_COLLABORATION_DATA",
    ])
    
    private static let pinnedCertificates = ServerTrustPolicy.certificates()
    private var manager: SessionManager
    private var streamManager: SessionManager
    private init() {
        let serverTrustPolicyManager = ServerTrustPolicyManager(policies: [
            "pvtbox.net": .customEvaluation({ serverTrust, host in
                var serverCertificates = [SecCertificate]()
                for index in 0..<SecTrustGetCertificateCount(serverTrust) {
                    if let certificate = SecTrustGetCertificateAtIndex(serverTrust, index) {
                        serverCertificates.append(certificate)
                    }
                }
                var certificatesValidated = 0
                for serverCertificate in serverCertificates {
                    if HttpClient.pinnedCertificates.contains(serverCertificate) {
                        certificatesValidated += 1
                    }
                }
                return serverCertificates.count == certificatesValidated
                })
            ])
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForResource = 10
        config.timeoutIntervalForRequest = 10
        manager = SessionManager(configuration: config, serverTrustPolicyManager: serverTrustPolicyManager)
        
        let streamConfig = URLSessionConfiguration.default
        streamConfig.timeoutIntervalForRequest = 30
        streamManager = SessionManager(configuration: streamConfig, serverTrustPolicyManager: serverTrustPolicyManager)
    }
    
    internal func makeRequest(
        api: String = "",
        action: String, data: Parameters,
        streamed: Bool = false,
        onSuccess: @escaping (JSON)->(),
        onError: @escaping (JSON?) -> (),
        onData: ((Data, DataRequest?) -> ())? = nil) {
        makeRequest(
            api: api,
            action: action, data: data,
            streamed: streamed,
            forceUpdateNodeHash: false,
            forceUpdateNodeSign: false,
            retryCount: 0,
            onSuccess: onSuccess,
            onError: onError,
            onData: onData)
    }
    
    private func makeRequest(
        api: String,
        action: String, data: Parameters,
        streamed: Bool,
        forceUpdateNodeHash: Bool,
        forceUpdateNodeSign: Bool,
        retryCount: Int,
        onSuccess: @escaping (JSON)->(),
        onError: @escaping (JSON?) -> (),
        onData: ((Data, DataRequest?) -> ())?) {
        var data = data
        if api == "events" {
            guard let userHash = PreferenceService.userHash else { return }
            data["user_hash"] = userHash
        }
        data["node_hash"] = getNodeHash(forceUpdate: forceUpdateNodeHash)
        getNodeSign(forceUpdate: forceUpdateNodeSign, completition: { nodeSign in
            guard (nodeSign != nil) else {
                onError("Network error")
                return
            }
            data["node_sign"] = nodeSign
            let request: Parameters = ["action": action, "data": data]
            self.executeRequest(
                api: api, request, streamed: streamed, retryCount: retryCount,
                onSuccess: onSuccess, onError: onError, onData: onData);
        })
    }
    
    private func executeRequest(
        api: String,
        _ data: Parameters,
        streamed: Bool,
        retryCount: Int,
        onSuccess: @escaping (JSON)->(),
        onError: @escaping (JSON?) -> (),
        onData: ((Data, DataRequest?) -> ())? ) {
        let retryCount = retryCount + 1;
        BFLog("request: %@", String(describing: JSON(data)))
        let reqManager = streamed ? streamManager : manager
        let request = reqManager.request(
            PreferenceService.host + Const.api + api, method: .post, parameters: data, encoding: JSONEncoding.default)
            .response(
                queue: self.responsesQueue,
                responseSerializer: DataRequest.JASONReponseSerializer(),
                completionHandler: { response in
                    guard let res = response.result.value else {
                        if retryCount > 3 || streamed {
                            onError(nil)
                        } else {
                            self.requestsQueue.asyncAfter(
                                deadline: .now() + 1,
                                execute: { [weak self] in self?.executeRequest(
                                    api: api, data, streamed: streamed, retryCount: retryCount,
                                    onSuccess: onSuccess, onError: onError, onData: onData)})
                        }
                        return
                    }
                    BFLog("response: code: %@, data: %@",
                          String(describing: response.response?.statusCode),
                          String(describing: res))
                    if streamed && response.response?.statusCode == 200 && res.object == nil {
                        return onSuccess(res)
                    }
                    
                    switch res["result"].string {
                    case "success", "queued":
                        onSuccess(res)
                    default:
                        self.processError(
                            api: api, res, data: data, streamed: streamed, retryCount: retryCount,
                            onSuccess: onSuccess, onError: onError, onData: onData)
                    }
            }
        )
        if streamed {
            request.stream(closure: { [weak request] data in onData?(data, request) })
        }
    }
    
    private func processError(
        api: String,
        _ res: JSON, data: Parameters, streamed: Bool, retryCount: Int,
        onSuccess: @escaping (JSON) -> (), onError: @escaping (JSON?) -> (),
        onData: ((Data, DataRequest?) -> ())?) {
        if retryCount > 3 {
            onError(res)
        } else {
            guard let errcode = res["errcode"].string else {
                self.requestsQueue.asyncAfter(
                    deadline: .now() + 1,
                    execute: { [weak self] in
                        if streamed {
                            onError(nil)
                        } else {
                            self?.executeRequest(
                                api: api, data, streamed: streamed, retryCount: retryCount,
                                onSuccess: onSuccess, onError: onError, onData: onData)
                        }
                    })
                return
            }
            let expectedErrcodesContainsErrcode = HttpClient.expectedErrcodes.contains(errcode)
            if expectedErrcodesContainsErrcode {
                onError(res)
                return
            }
            
            let updateNodeHashErrcodesContainsErrcode = HttpClient.updateNodeHashErrcodes.contains(errcode)
            let updateNodeSignErrcodesContainsErrcode = HttpClient.updateNodeSignErrcodes.contains(errcode)
            
            if  updateNodeHashErrcodesContainsErrcode ||
                updateNodeSignErrcodesContainsErrcode {
                self.makeRequest(
                    api: api,
                    action: data["action"] as! String,
                    data: data["data"] as! Parameters,
                    streamed: streamed,
                    forceUpdateNodeHash: updateNodeHashErrcodesContainsErrcode,
                    forceUpdateNodeSign: updateNodeSignErrcodesContainsErrcode,
                    retryCount: retryCount,
                    onSuccess: onSuccess,
                    onError: onError,
                    onData: onData)
                return
            }
            
            if streamed {
                onError(nil)
            } else {
                self.requestsQueue.asyncAfter(
                    deadline: .now() + 1,
                    execute: { [weak self] in self?.executeRequest(
                        api: api, data, streamed: streamed, retryCount: retryCount,
                        onSuccess: onSuccess, onError: onError, onData: onData)})
            }
        }
    }
    
    private func getNodeHash(forceUpdate: Bool) -> String {
        var nodeHash: String?
        if forceUpdate {
            nodeHash = generateNodeHash()
        } else {
            nodeHash = PreferenceService.nodeHash
            if nodeHash == nil {
                nodeHash = generateNodeHash()
            }
        }
        return nodeHash!
    }
    
    private func generateNodeHash() -> String {
        let nodeHash = sha512(fromString:UUID().uuidString)
        PreferenceService.nodeHash = nodeHash
        return nodeHash
    }
    
    private func getNodeSign(forceUpdate: Bool, completition: @escaping (String?)->()) {
        if forceUpdate {
            generateNodeSign(completition: completition)
        } else {
            guard let nodeSign = PreferenceService.nodeSign else {
                generateNodeSign(completition: completition)
                return
            }
            completition(nodeSign)
        }
    }
    
    private func generateNodeSign(completition: @escaping (String?)->()) {
        getIp(completition: { ip in
            guard let ip = ip else {
                completition(nil)
                return
            }
            let nodeSign = sha512(fromString: self.getNodeHash(forceUpdate: false) + ip)
            PreferenceService.nodeSign = nodeSign
            completition(nodeSign)
        })
    }
    
    private func getIp(completition: @escaping (String?)->()) {
        let data: Parameters = ["action": "stun",
                                "data": [
                                    "get": "candidate"
                                ]]
        executeRequest(
            api: "",
            data,
            streamed: false,
            retryCount: 0,
            onSuccess: { response in
                let ip = String(response["info"].intValue)
                completition(ip)
            },
            onError: {_ in
                completition(nil)
            },
            onData: nil)
    }
}
