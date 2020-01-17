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

class FileRealm: Object {
    @objc dynamic var uuid: String? = nil
    @objc dynamic var parentUuid: String? = nil
    @objc dynamic var eventUuid: String? = nil
    @objc dynamic var eventId: Int = 0
    
    @objc dynamic var path: String?
    @objc dynamic var name: String?
    @objc dynamic var hashsum: String? = nil
    
    @objc dynamic var dateCreated: Date? = nil
    @objc dynamic var dateModified: Date? = nil
    
    @objc dynamic var size: Int = 0
    @objc dynamic var downloadedSize: Int = 0
    
    @objc dynamic var filesCount: Int = 0
    @objc dynamic var offlineFilesCount: Int = 0
    
    @objc dynamic var isDownload: Bool = false
    @objc dynamic var isOnlyDownload: Bool = false
    @objc dynamic var isOffline: Bool = false
    @objc dynamic var isDownloadActual: Bool = false
    
    @objc dynamic var isProcessing: Bool = false
    
    @objc dynamic var downloadStatus: String? = nil
    
    @objc dynamic var isFolder: Bool = false
    @objc dynamic var isCollaborated: Bool = false
    @objc dynamic var isShared: Bool = false
    
    @objc dynamic var shareLink: String? = nil
    @objc dynamic var shareSecured: Bool = false
    @objc dynamic var shareExpire: Int = 0
    
    @objc dynamic var localIdentifier: String? = nil
    @objc dynamic var convertedToJpeg: Bool = false
    
    override static func primaryKey() -> String? {
        return "uuid"
    }
    
    override static func indexedProperties() -> [String] {
        return ["parentUuid", "hashsum"]
    }
}
