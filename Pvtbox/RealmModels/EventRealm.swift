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

class EventRealm: Object {
    @objc dynamic var uuid: String?
    @objc dynamic var fileUuid: String?
    @objc dynamic var checked: Bool = false
    @objc dynamic var hashsum: String?
    @objc dynamic var localIdentifier: String?
    @objc dynamic var size: Int = 0
    @objc dynamic var id: Int = 0
    
    override static func primaryKey() -> String? {
        return "uuid"
    }
    
    override static func indexedProperties() -> [String] {
        return ["fileUuid", "id",]
    }
}
