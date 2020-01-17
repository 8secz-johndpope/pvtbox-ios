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

extension HttpClient {
    public func register(
        email: String, password: String,
        onSuccess: @escaping (JSON)->(),
        onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "node_devicetype": Const.nodeType,
                "node_ostype": Const.nodeOsType,
                "node_osname": Const.nodeOsName,
                "node_name": Const.nodeName,
                "user_email": email,
                "user_password": sha512(fromString: password),
                ]
            self.makeRequest(
                action: "signup", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
    public func login(
        email: String, password: String,
        onSuccess: @escaping (JSON)->(),
        onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "node_devicetype": Const.nodeType,
                "node_ostype": Const.nodeOsType,
                "node_osname": Const.nodeOsName,
                "node_name": Const.nodeName,
                "user_email": email,
                "user_password": sha512(fromString: password),
                ]
            self.makeRequest(
                action: "login", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
    public func login(
        userHash: String,
        onSuccess: @escaping (JSON)->(),
        onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "node_devicetype": Const.nodeType,
                "node_ostype": Const.nodeOsType,
                "node_osname": Const.nodeOsName,
                "node_name": Const.nodeName,
                "user_hash": userHash,
                ]
            self.makeRequest(
                action: "login", data: data,
                onSuccess: onSuccess,
                onError: { response in onError(response)})
        }
    }
    
    public func logout(userHash: String) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": userHash,
                ]
            self.makeRequest(
                action: "logout", data: data,
                onSuccess: {_ in },
                onError: {_ in })
        }
    }
    
    public func remindPassword(
        email: String,
        onSuccess: @escaping (JSON)->(),
        onError: @escaping (JSON?)->()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_email": email
            ]
            self.makeRequest(
                action: "resetpassword", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
}
