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
import RealmSwift

class DeviceRealm: Object {
    @objc dynamic var id: String?
    @objc dynamic var name: String?
    @objc dynamic var deviceType: String?
    @objc dynamic var online: Bool = false
    @objc dynamic var os: String?
    @objc dynamic var osType: String?
    @objc dynamic var diskUsage: Double = 0
    @objc dynamic var uploadSpeed: Double = 0
    @objc dynamic var downloadSpeed: Double = 0
    @objc dynamic var uploadedSize: Double = 0
    @objc dynamic var downloadedSize: Double = 0
    @objc dynamic var connectedNodes: Int = 0
    @objc dynamic var status: Int = 0
    @objc dynamic var own: Bool = false
    
    @objc dynamic var remoteCount: Int = 0
    @objc dynamic var fetchingChanges: Bool = true
    @objc dynamic var processingOperation: Bool = false
    @objc dynamic var importingCamera: Bool = false
    @objc dynamic var downloadsCount: Int = 0
    @objc dynamic var currentDownloadName: String? = nil
    @objc dynamic var processingShare: Bool = false
    @objc dynamic var notificationsCount: Int = 0
    
    @objc dynamic var paused: Bool = false
    
    @objc dynamic var isLogoutInProgress: Bool = false
    @objc dynamic var isWipeInProgress: Bool = false
    
    override static func primaryKey() -> String? {
        return "id"
    }
}
