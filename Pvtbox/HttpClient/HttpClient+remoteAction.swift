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
    public func remoteActionDone(uuid: String) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "action_uuid": uuid,
                ]
            
            self.makeRequest(
                action: "remote_action_done", data: data,
                onSuccess: {response in },
                onError: { response in })
        }
    }
    
    public func hideNode(
        id: String,
        onSuccess: @escaping (JSON)->(),
        onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "node_id": id,
            ]
            
            self.makeRequest(
                action: "hideNode", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
    public func logoutNode(
        id: String,
        onSuccess: @escaping (JSON)->(),
        onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "action_type": "logout",
                "user_hash": PreferenceService.userHash!,
                "target_node_id": id,
            ]
            
            self.makeRequest(
                action: "execute_remote_action", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
    public func wipeNode(
        id: String,
        onSuccess: @escaping (JSON)->(),
        onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "action_type": "wipe",
                "user_hash": PreferenceService.userHash!,
                "target_node_id": id,
            ]
            
            self.makeRequest(
                action: "execute_remote_action", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
}
