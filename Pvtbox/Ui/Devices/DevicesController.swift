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

class DevicesController {
    private var devices: Results<DeviceRealm>?
    private var subscription: NotificationToken?
    private var realm: Realm?
    
    var dataLoaded: (() -> Void)?
    var dataChanged: ((_ deletions: [Int], _ insertions: [Int], _ modifications: [Int]) -> Void)?
    
    init() {
        initRealm()
    }
    
    private func initRealm() {
        guard let realm = try? Realm() else {
            DispatchQueue.main.async { [weak self] in
                self?.initRealm()
            }
            return
        }
        self.realm = realm
    }
    
    var deviceCount: Int {
        get {
            return devices?.count ?? 0
        }
    }
    var onlineDevicesCount: Int {
        get {
            return ownDevice?.online ?? false ? (devices?.filter("online = true").count ?? 0) : 0
        }
    }
    var ownDevice: DeviceRealm? {
        get {
            return devices?.first
        }
    }
    
    func device(at index: IndexPath) -> DeviceRealm {
        return devices![index.item]
    }
    
    func deleteNode(_ id: String) {
        try? autoreleasepool {
            guard let realm = realm else { return }
            try realm.write {
                if let device = realm.object(ofType: DeviceRealm.self, forPrimaryKey: id) {
                    realm.delete(device)
                }
            }
        }
    }
    
    func enable() {
        guard let realm = self.realm else {
            DispatchQueue.main.async { [weak self] in
                self?.enable()
            }
            return
        }
        devices = realm.objects(DeviceRealm.self)
            .filter("status > 0")
            .sorted(by: [
                SortDescriptor(keyPath: "own", ascending: false),
                SortDescriptor(keyPath: "online", ascending: false),
                SortDescriptor(keyPath: "id", ascending: false),
                ])
        subscription = devices!.observe { [weak self] (changes: RealmCollectionChange) in
            switch changes {
            case .initial:
                self?.dataLoaded?()
            case .update(_, let deletions, let insertions, let modifications):
                self?.dataChanged?(deletions, insertions, modifications)
            case .error(let error):
                BFLogErr("realm error: %@", String(describing: error))
            }
        }
    }
    
    func disable() {
        subscription?.invalidate()
    }
}
