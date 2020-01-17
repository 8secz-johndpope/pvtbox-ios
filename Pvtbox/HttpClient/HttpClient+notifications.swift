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
    public func getNotifications(
        from: Int,
        limit: Int,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?) -> ()) {
        requestsQueue.async {
            let data: Parameters = [
                "user_hash": PreferenceService.userHash!,
                "from": from,
                "limit": limit,
                ]
            
            self.makeRequest(
                api: "", action: "getNotifications", data: data,
                onSuccess: {response in onSuccess(response)},
                onError: { response in onError(response)})
        }
    }
}
