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
import JASON

extension DataBaseService {
    public func setShare(_ shareInfo: [String: JSON]) {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                let uuids = Array(shareInfo.keys)
                let toRemoveShare = realm.objects(FileRealm.self)
                    .filter("isShared = true")
                    .filter("not uuid in %@", uuids)
                for file in toRemoveShare {
                    file.isShared = false
                    file.shareLink = nil
                    file.shareSecured = false
                    file.shareExpire = 0
                }
                let toAddShare = realm.objects(FileRealm.self)
                    .filter("uuid in %@", uuids)
                for file in toAddShare {
                    let info = shareInfo[file.uuid!]!
                    file.isShared = true
                    file.shareLink = info["share_link"].string!
                    file.shareExpire = info["share_ttl_info"].intValue
                    file.shareSecured = info["share_password"].boolValue
                }
            }
        }
    }
    
    public func addShare(_ share: JSON) {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                guard let file = realm.object(
                    ofType: FileRealm.self,
                    forPrimaryKey: share["uuid"].string!) else { return }
                
                file.isShared = true
                file.shareLink = share["share_link"].string!
                file.shareExpire = share["share_ttl_info"].intValue
                file.shareSecured = share["share_password"].boolValue
            }
        }
    }
    
    public func removeShare(_ share: JSON) {
        try? autoreleasepool {
            let realm = try Realm()
            try realm.write {
                guard let file = realm.object(
                    ofType: FileRealm.self,
                    forPrimaryKey: share["uuid"].string!) else { return }
                
                file.isShared = false
                file.shareLink = nil
                file.shareSecured = false
                file.shareExpire = 0
            }
        }
    }
}
