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
import RealmSwift

class DataBaseService {
    class RealmError : Error {
        
    }
    
    init() {
        DataBaseService.initConfiguration()
    }
    
    public var onCameraFolderDeleted: (() -> ())?
    public var onSynced: (() -> ())?
    
    private static func initConfiguration() {
        var config = Realm.Configuration()
        config.deleteRealmIfMigrationNeeded = false
        config.schemaVersion = 5
        config.migrationBlock = { migration, oldShemaVersion in
            if oldShemaVersion < 4 {
                migration.enumerateObjects(ofType: DeviceRealm.className()) { oldObject, newObject in
                    newObject!["isLogoutInProgress"] = false
                    newObject!["isWipeInProgress"] = false
                }
            }
            if oldShemaVersion < 5 {
                migration.enumerateObjects(ofType: DeviceRealm.className()) { oldObject, newObject in
                    newObject!["notificationsCount"] = 0
                }
            }
        }
        config.shouldCompactOnLaunch = { total, used in
            return (total > 10 * 1024 * 1024) && (Double(used) / Double(total)) < 0.5
        }
        let dbDir = FileTool.dbDirectory
        FileTool.createDirectory(dbDir)
        try! FileManager.default.setAttributes(
            [FileAttributeKey.protectionKey: FileProtectionType.none],
            ofItemAtPath: dbDir.path)
        
        config.fileURL = dbDir.appendingPathComponent("default.realm", isDirectory: false)
        Realm.Configuration.defaultConfiguration = config
        
        autoreleasepool {
            do {
                let _ = try Realm()
            } catch {
                BFLogErr("DataBaseService::initConfiguration error: %@", String(describing: error))
                FileTool.delete(config.fileURL!)
            }
        }
    }
    
    public static func dropDataBase() {
        initConfiguration()
        if let realm = try? Realm() {
            try? realm.write {
                realm.deleteAll()
            }
        }
    }
}
