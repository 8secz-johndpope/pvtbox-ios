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
    
    public func createFolder(
        eventUuid: String, parentUuid: String, name: String,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?)->()) {
        requestsQueue.async {
            let data: Parameters = [
                "event_uuid": eventUuid,
                "parent_folder_uuid": parentUuid,
                "folder_name": name,
                ]
            self.makeRequest(
                api: "events",
                action: "folder_event_create", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
    public func copyFolder(
        eventUuid: String, uuid: String, parentUuid: String, name: String, lastEventId: Int,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?)->()) {
        requestsQueue.async {
            let data: Parameters = [
                "event_uuid": eventUuid,
                "target_parent_folder_uuid": parentUuid,
                "target_folder_name": name,
                "source_folder_uuid": uuid,
                "last_event_id": lastEventId,
                ]
            self.makeRequest(
                api: "events",
                action: "folder_event_copy", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
    public func moveFolder(
        eventUuid: String, uuid: String, parentUuid: String, name: String, lastEventId: Int,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?)->()) {
        requestsQueue.async {
            let data: Parameters = [
                "event_uuid": eventUuid,
                "folder_uuid": uuid,
                "new_folder_name": name,
                "new_parent_folder_uuid": parentUuid,
                "last_event_id": lastEventId,
            ]
            self.makeRequest(
                api: "events",
                action: "folder_event_move", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
    public func deleteFolder(
        eventUuid: String, uuid: String, lastEventId: Int,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?)->()) {
        requestsQueue.async {
            let data: Parameters = [
                "event_uuid": eventUuid,
                "folder_uuid": uuid,
                "last_event_id": lastEventId,
            ]
            self.makeRequest(
                api: "events",
                action: "folder_event_delete", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }

    public func createFile(
        eventUuid: String, parentUuid: String, name: String, size: Int, hash: String,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?)->()) {
        requestsQueue.async {
            let data: Parameters = [
                "event_uuid": eventUuid,
                "folder_uuid": parentUuid,
                "file_name": name,
                "file_size": size,
                "hash": hash,
                "diff_file_size": 0
            ]
            self.makeRequest(
                api: "events",
                action: "file_event_create", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
    public func updateFile(
        eventUuid: String, uuid: String, size: Int, hash: String, lastEventId: Int,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?)->()) {
        requestsQueue.async {
            let data: Parameters = [
                "event_uuid": eventUuid,
                "file_uuid": uuid,
                "file_size": size,
                "hash": hash,
                "last_event_id": lastEventId,
                ]
            self.makeRequest(
                api: "events",
                action: "file_event_update", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
    public func moveFile(
        eventUuid: String, uuid: String, parentUuid: String, name: String, lastEventId: Int,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?)->()) {
        requestsQueue.async {
            let data: Parameters = [
                "event_uuid": eventUuid,
                "file_uuid": uuid,
                "new_file_name": name,
                "new_folder_uuid": parentUuid,
                "last_event_id": lastEventId
            ]
            self.makeRequest(
                api: "events",
                action: "file_event_move", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
    public func deleteFile(
        eventUuid: String, uuid: String, lastEventId: Int,
        onSuccess: @escaping (JSON)->(), onError: @escaping (JSON?)->()) {
        requestsQueue.async {
            let data: Parameters = [
                "event_uuid": eventUuid,
                "file_uuid": uuid,
                "last_event_id": lastEventId
            ]
            self.makeRequest(
                api: "events",
                action: "file_event_delete", data: data,
                onSuccess: onSuccess,
                onError: onError)
        }
    }
    
}
