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

import UIKit
import JASON
import RealmSwift

class NotificationsVC: UIViewController, UITableViewDelegate, UITableViewDataSource, UITableViewDataSourcePrefetching {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var noRecordsFound: UIScrollView!
    @IBOutlet weak var loading: UIView!
    private let tableViewRefreshControl = UIRefreshControl()
    private let noRecordsRefreshControl = UIRefreshControl()
        
    private let defaultLimit = 30
    private var notifications = [JSON]()
    private var fetchInProgress = false
    private var loadedAll = false
    
    private var realm: Realm?
    private var ownDevice: DeviceRealm?
    private var ownDeviceSubscription: NotificationToken?

    override func viewDidLoad() {
        super.viewDidLoad()
        loading.transform = CGAffineTransform(scaleX: 2, y: 2)
        
        tableViewRefreshControl.tintColor = .orange
        tableViewRefreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = tableViewRefreshControl
        
        noRecordsRefreshControl.tintColor = .orange
        noRecordsRefreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        noRecordsFound.refreshControl = noRecordsRefreshControl
    }
    
    override func viewDidAppear(_ animated: Bool) {
        subscribeForNotificationsCount()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        ownDeviceSubscription?.invalidate()
        ownDeviceSubscription = nil
        ownDevice = nil
        realm = nil
        notifications.removeAll()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notifications.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "notificationCell", for: indexPath) as! NotificationCell
        cell.displayContent(notifications[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        if fetchInProgress || loadedAll {
            BFLog("NotificationsVC::prefetchRows fetch already in progress or loaded all")
            return
        }
        BFLog("NotificationsVC::prefetchRows first %d, last %d", indexPaths.first?.row ?? 0, indexPaths.last?.row ?? 0)
        if indexPaths.last?.row ?? 0 > notifications.count - defaultLimit {
            loadNotifications(
                from: notifications.last?["notification_id"].int ?? 0,
                limit: defaultLimit)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let notification = notifications[indexPath.row]
        switch notification["action"].stringValue {
        case "collaboration_include", "collaboration_join":
            var index = 0;
            for s in notification["search"].jsonArrayValue {
                if s.stringValue == "{folder_name}" {
                    break
                }
                index += 1
            }
            let folderName = notification["replace"][index].stringValue
            (parent?.parent as! MainVC).openAllFiles(folder: folderName)
        case "collaboration_invite":
            var index = 0;
            for s in notification["search"].jsonArrayValue {
                if s.stringValue == "{colleague_id}" {
                    break
                }
                index += 1
            }
            let colleagueId = notification["replace"][index].intValue
            UIApplication.shared.beginIgnoringInteractionEvents()
            SnackBarManager.showSnack(Strings.acceptingInvitation, showNew: true, showForever: true)
            HttpClient.shared.collaborationJoin(
                colleagueId: colleagueId,
                onSuccess: { response in
                    SnackBarManager.showSnack(Strings.acceptedInvitation, showNew: false, showForever: false)
                    DispatchQueue.main.async {
                        UIApplication.shared.endIgnoringInteractionEvents()
                    }
                },
                onError: { error in
                    SnackBarManager.showSnack(
                                       error?["info"].string ?? Strings.operationError,
                                       showNew: false, showForever: false)
                    DispatchQueue.main.async {
                        UIApplication.shared.endIgnoringInteractionEvents()
                    }
                })
        default:
            break;
        }
        if !notification["read"].boolValue {
            var notif: [String: Any] = notification.dictionary!
            notif["read"] = true
            notifications[indexPath.row] = JSON(notif)
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }
    
    @objc func refresh() {
        if let notificationsCount = ownDevice?.notificationsCount,
            notificationsCount > 0 || notifications.isEmpty {
            let limit = notificationsCount < defaultLimit ? defaultLimit : notificationsCount
            notifications.removeAll()
            loadedAll = false
            tableView.reloadData()
            tableView.isHidden = true
            noRecordsFound.isHidden = true
            loading.isHidden = false
            loadNotifications(
                from: 0,
                limit: limit)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.endRefreshing()
            }
        }
    }
    
    private func endRefreshing() {
        if tableViewRefreshControl.isRefreshing {
            tableViewRefreshControl.endRefreshing()
        }
        if noRecordsRefreshControl.isRefreshing {
            noRecordsRefreshControl.endRefreshing()
        }
    }
    
    private func loadNotifications(from: Int, limit: Int) {
        fetchInProgress = true
        HttpClient.shared.getNotifications(
            from: from, limit: limit,
            onSuccess: { [weak self] response in
                self?.onNotificationsReceived(response)
            },
            onError: { [weak self] error in
                DispatchQueue.main.async { [weak self] in
                    self?.showNoRecordsFound()
                }
            })
    }
    
    private func onNotificationsReceived(_ response: JSON) {
        let newNotifications = response["data"].jsonArrayValue
        DispatchQueue.main.async { [weak self] in
            self?.updateNotifications(newNotifications)
        }
    }
    
    private func updateNotifications(_ newNotifications: [JSON]) {
        fetchInProgress = false
        if newNotifications.count < defaultLimit {
            loadedAll = true
        }
        endRefreshing()
        let count = notifications.count
        notifications.append(contentsOf: newNotifications)
        tableView.insertRows(
            at: (count...count+newNotifications.count-1)
                .map({IndexPath(row: $0, section: 0)}),
            with: .none)
        if notifications.count > 0 {
            loading.isHidden = true
            noRecordsFound.isHidden = true
            tableView.isHidden = false
        } else {
            showNoRecordsFound()
        }
    }
    
    private func showNoRecordsFound() {
        loading.isHidden = true
        if notifications.count > 0 {
            noRecordsFound.isHidden = true
            tableView.isHidden = false
        } else {
            noRecordsFound.isHidden = false
            tableView.isHidden = true
        }
        fetchInProgress = false;
        loadedAll = false;
        endRefreshing()
    }
    
    private func subscribeForNotificationsCount() {
        if self.realm == nil {
            guard let realm = try? Realm() else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                    [weak self] in self?.subscribeForNotificationsCount()
                })
                return
            }
            self.realm = realm
        }
        ownDevice = realm?.object(ofType: DeviceRealm.self, forPrimaryKey: "own")
        if ownDevice == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                [weak self] in self?.subscribeForNotificationsCount()
            })
            return
        }
        ownDeviceSubscription = ownDevice!.observe { [weak self] change in
            switch change {
            case .change(let properties):
                for property in properties {
                    if property.name == "notificationsCount" {
                        DispatchQueue.main.async { [weak self] in
                            self?.onNotificationsCountChanged() }
                    }
                }
            case .error(let error):
                BFLogErr("An error occurred: %@", error)
            case .deleted:
                BFLogErr("The ownDevice object was deleted.")
            }
        }
        var limit = ownDevice?.notificationsCount ?? defaultLimit
        if limit < defaultLimit {
            limit = defaultLimit
        }
        loadNotifications(from: 0, limit: limit)
    }
    
    private func onNotificationsCountChanged() {
        let limit = ownDevice?.notificationsCount ?? 0
        if limit > 0 {
            if fetchInProgress {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    [weak self] in self?.onNotificationsCountChanged()
                }
            } else {
                refresh()
            }
        }
    }
}
