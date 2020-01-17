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
    public func shareEnable(
        uuid: String, ttl: Int?, password: String?, keepPassword: Bool = true,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "uuid": uuid,
                "share_ttl": ttl as Any,
                "share_password": password as Any,
                "share_keep_password": keepPassword,
                ]
            
            self.makeRequest(
                api: "sharing", action: "sharing_enable", data: data,
                onSuccess: {response in onSuccess(response)},
                onError: { response in onError(response)})
        }
    }
    
    public func shareDisable(
        uuid: String,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "uuid": uuid,
                ]
            
            self.makeRequest(
                api: "sharing", action: "sharing_disable", data: data,
                onSuccess: {response in onSuccess(response)},
                onError: { response in onError(response)})
        }
    }
    
    public func checkSharePassword(
        url: String,
        onSuccess: @escaping ()->(), onWrongPassword: @escaping () -> (),
        onLocked: @escaping ()->(), onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            Alamofire.request(url, method: .get).response(
                queue: self.responsesQueue,
                responseSerializer: DataRequest.JASONReponseSerializer(),
                completionHandler: { response in
                    guard let res = response.result.value else {
                        if response.response?.statusCode == 400 {
                            onSuccess()
                        } else {
                            onError(nil)
                        }
                        return
                    }
                    if response.response?.statusCode == 403 &&
                            res["errcode"].stringValue == "SHARE_WRONG_PASSWORD" {
                        onWrongPassword()
                    } else if response.response?.statusCode == 400 {
                        onSuccess()
                    } else if res["errcode"].stringValue == "LOCKED_CAUSE_TOO_MANY_BAD_LOGIN" {
                        onLocked()
                    } else {
                        onError(res)
                    }
                
            })
        }
    }
}
