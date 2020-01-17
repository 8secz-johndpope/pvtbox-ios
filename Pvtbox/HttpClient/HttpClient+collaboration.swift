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
import Alamofire

extension HttpClient {
    public func colleagueAdd(
        uuid: String, email: String, permission: String,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "uuid": uuid,
                "colleague_email": email,
                "access_type": permission,
                ]
            
            self.makeRequest(
                api: "sharing", action: "colleague_add", data: data,
                onSuccess: {response in onSuccess(response)},
                onError: { response in onError(response)})
        }
    }
    
    public func colleagueDelete(
        uuid: String, id: Int,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "uuid": uuid,
                "colleague_id": id,
                ]
            
            self.makeRequest(
                api: "sharing", action: "colleague_delete", data: data,
                onSuccess: {response in onSuccess(response)},
                onError: { response in onError(response)})
        }
    }
    
    public func colleagueEdit(
        uuid: String, id: Int, permission: String,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "uuid": uuid,
                "colleague_id": id,
                "access_type": permission,
                ]
            
            self.makeRequest(
                api: "sharing", action: "colleague_edit", data: data,
                onSuccess: {response in onSuccess(response)},
                onError: { response in onError(response)})
        }
    }
    
    public func collaborationInfo(
        uuid: String,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "uuid": uuid,
                ]
            
            self.makeRequest(
                api: "sharing", action: "collaboration_info", data: data,
                onSuccess: {response in onSuccess(response)},
                onError: { response in onError(response)})
        }
    }
    
    public func collaborationCancel(
        uuid: String,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "uuid": uuid,
                ]
            
            self.makeRequest(
                api: "sharing", action: "collaboration_cancel", data: data,
                onSuccess: {response in onSuccess(response)},
                onError: { response in onError(response)})
        }
    }
    
    public func collaborationJoin(
        colleagueId: Int,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "colleague_id": colleagueId,
                ]
            
            self.makeRequest(
                api: "sharing", action: "collaboration_join", data: data,
                onSuccess: {response in onSuccess(response)},
                onError: { response in onError(response)})
        }
    }
}
