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
import UserNotifications
import AppLocker
import BackgroundTasks

class PvtboxService {
    private static var shared: PvtboxService?
    private static var shareUrl: URL?
    private static var needCheckGroup: Bool = true
    
    private var paused = false
    private var dataBaseService = DataBaseService()
    private var syncService: SyncService?
    private var signalServerService: SignalServerService?
    private var shareSignalServerService: ShareSignalServerService?
    private var operationService: OperationService?
    private var connectivityService: ConnectivityService?
    private var downloadManager: DownloadManager?
    private var statusBroadcaster: StatusBroadcaster?
    private var speedCalculator: SpeedCalculator?
    private var cameraImportService: CameraImportService?
    private var temporaryFilesManager: TemporaryFilesManager?
    private var uploadsDownloader: UploadsDownloader?
    
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    private let dq = DispatchQueue(
        label: "net.pvtbox.service.main", qos: .utility, attributes: [.concurrent])
    
    public static func start(withLoginData loginData: JSON) {
        BFLog("PvtboxService::start withLoginData")
        if PvtboxService.shared == nil {
            PvtboxService.shared = PvtboxService(withLoginData: loginData)
        }
    }
    
    public static func isRunning() -> Bool {
        return PvtboxService.shared != nil
    }
    
    public static func start() {
        BFLog("PvtboxService::start")
        if PvtboxService.shared == nil {
            PvtboxService.shared = PvtboxService()
        }
    }

    public static func stop() {
        BFLog("PvtboxService::stop")
        guard let service =  PvtboxService.shared else { return }
        service.stop()
        PvtboxService.shared = nil
    }
    
    public static func pause() {
        BFLog("PvtboxService::pause")
        PvtboxService.shared?.pause()
    }
    
    public static func resume() {
        BFLog("PvtboxService::resume")
        PvtboxService.shared?.resume()
    }
    
    public static func addOperation(
        _ type: OperationService.OperationType,
        root: FileRealm? = nil,
        newName: String? = nil,
        uuid: String? = nil,
        files: [FileRealm]? = nil,
        data: Data? = nil,
        url: URL? = nil,
        urls: [URL]? = nil,
        deleteAfterImport: Bool = false) {
        BFLog("PvtboxService::addOperation")
        guard let service = PvtboxService.shared else { return }
        service.dq.async { [weak service] in
            service?.operationService?.addOperation(
                type, root: root, newName: newName, uuid: uuid,
                files: files, data:data, url: url, urls: urls,
                deleteAfterImport: deleteAfterImport)
        }
    }
    
    public static var onlineDevicesCount: Int {
        get {
            return PvtboxService.shared?.dataBaseService.getOnlineDevicesCount() ?? 0
        }
    }
    
    public static func syncCamera() {
        BFLog("PvtboxService::syncCamera")
        PvtboxService.shared?.cameraImportService?.start()
    }
    
    public static func downloadFile(_ fileUuid: String) {
        guard let service = PvtboxService.shared else { return }
        service.dataBaseService.downloadFile(fileUuid)
    }
    
    public static func downloadShare(_ url: URL, to folder: FileRealm?) {
        PvtboxService.shared?.shareSignalServerService?.start(
            withUrl: url, downloadTo: folder)
    }
    
    public static func isProcessingOperation() -> Bool {
        guard let service =  PvtboxService.shared else { return false }
        return service.operationService?.isProcessing ?? false
    }

    public static func getRemoteProcessingCount() -> Int {
        return PvtboxService.shared?.syncService?.processingCount ?? 0
    }
    
    public static func logout(byUserAction: Bool, wipe: Bool = false) {
        guard let service = PvtboxService.shared else { return }
        return service.logout(byUserAction: byUserAction, wipe: wipe)
    }
    
    public static func wipe() {
        PreferenceService.cameraFolderUuid = nil
        PreferenceService.cameraLastPhotoCreationDate = nil
        PreferenceService.importCameraEnabled = false
        AppLocker.removePinFromValet()
        PreferenceService.askSetPasscode = true
        DataBaseService.dropDataBase()
        FileTool.delete(FileTool.syncDirectory)
        FileTool.delete(FileTool.copiesDirectory)
    }
    
    public static func setNeedCheckGroup() {
        PvtboxService.needCheckGroup = true
        PvtboxService.shared?.checkGroup()
    }
    
    public static func setShareUrl(_ url: URL) {
        PvtboxService.shareUrl = url
        PvtboxService.shared?.handleShareUrl()
    }
    
    private init(withLoginData loginData: JSON) {
        BFLog("PvtboxService::init withLoginData")
        dq.async {
            self.start(loginData)
        }
    }
    
    private init() {
        BFLog("PvtboxService::init")
        dq.async {
            self.start(nil)
        }
    }
    
    private func start(_ loginData: JSON?) {
        BFLog("PvtboxService::start")
        FileTool.createDirectory(FileTool.copiesDirectory)
        FileTool.createFile(DownloadManager.emptyCopyUrl)
        FileTool.createDirectory(FileTool.dbDirectory)
        FileTool.delete(FileTool.tmpDirectory)
        FileTool.createDirectory(FileTool.tmpDirectory)
        FileTool.createDirectory(FileTool.shareGroupDirectory)
        FileTool.createDirectory(FileTool.addGroudDirectory)
        
        temporaryFilesManager = TemporaryFilesManager()
        speedCalculator = SpeedCalculator(dataBaseService)
        try? dataBaseService.setupOwnDevice()
        dataBaseService.setWaitingInitialSyncForAllDownloads()
        signalServerService = SignalServerService()
        shareSignalServerService = ShareSignalServerService(speedCalculator, dataBaseService)
        uploadsDownloader = UploadsDownloader(dataBaseService, speedCalculator, signalServerService)
        operationService = OperationService(dataBaseService, signalServerService)
        cameraImportService = CameraImportService(dataBaseService, temporaryFilesManager)
        dataBaseService.onCameraFolderDeleted = { [weak self] in
            self?.dq.async {
                [weak self] in self?.cameraImportService?.stop()
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    if settings.authorizationStatus != .authorized { return }
                        
                    let content = UNMutableNotificationContent()
                    content.title = Strings.cameraFolderDeleted
                    content.subtitle = Strings.importCameraCancelled
                    content.body = Strings.setAddPhotosInSettings
                    if #available(iOS 12.0, *) {
                        content.sound = .defaultCritical
                    } else {
                        content.sound = .default
                    }
                        
                    let request = UNNotificationRequest(
                        identifier: Strings.cameraFolderDeleted, content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(
                        request, withCompletionHandler: nil)
                }
            }
        }
        dataBaseService.onSynced = { [weak self] in
            self?.dq.async { [weak self] in self?.onSynced() }
        }
        syncService = SyncService(
            signalServerService: signalServerService!, dataBaseService: dataBaseService)
        signalServerService?.syncService = syncService
        signalServerService?.dataBaseService = dataBaseService
        signalServerService?.uploadsDownloader = uploadsDownloader
        syncService?.onInitialSyncDone = { [weak self] in
            BFLog("PvtboxService::onInitialSyncDone")
            self?.syncService?.onInitialSyncDone = nil
            self?.dq.async { [weak self] in
                self?.checkGroup()
                self?.downloadManager?.onInitialSyncDone()
            }
        }
        signalServerService?.onConnectedToServer = { [weak self] in
            self?.dq.async { [weak self] in
                guard let strongSelf = self,
                    strongSelf.statusBroadcaster == nil else {
                        self?.statusBroadcaster?.checkAndBroadcastStatus(force: true)
                        return
                }
                strongSelf.statusBroadcaster = StatusBroadcaster(
                    strongSelf.dataBaseService, strongSelf.signalServerService)
            }
        }
        signalServerService?.onNodeConnected = { [weak self] _ in
            self?.dq.async { [weak self] in
                self?.statusBroadcaster?.checkAndBroadcastStatus(force: true)
            }
        }
        registerBackgroundTask()
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        NotificationCenter.default
            .addObserver(self, selector: #selector(reinstateBackgroundTask),
                         name: UIApplication.didBecomeActiveNotification, object: nil)
        login(loginData)
        
        handleShareUrl()
    }
    
    @objc func reinstateBackgroundTask() {
        BFLog("PvtboxService::reinstateBackgroundTask")
        if backgroundTask ==  .invalid {
            registerBackgroundTask()
        }
        operationService?.resume()
    }
    
    private func login(_ loginData: JSON?) {
        BFLog("PvtboxService::login")
        if loginData == nil {
            HttpClient.shared.login(
                userHash: PreferenceService.userHash!,
                onSuccess: { data in self.dq.async {self.onLoggedIn(data)} },
                onError: { data in self.dq.async {self.onLoginError(data)} })
        } else {
            onLoggedIn(loginData!)
        }
    }
    
    private func logout(byUserAction: Bool, wipe: Bool = false) {
        BFLog("PvtboxService::logout byUserAction: %@, wipe: %@",
              String(describing: byUserAction), String(describing: wipe))
        logout(wipe, byUserAction: byUserAction)
        if wipe {
            PvtboxService.wipe()
        }
    }
    
    private func logout(_ wipe: Bool, byUserAction: Bool) {
        BFLog("PvtboxService::logout")
        PreferenceService.isLoggedIn = false
        if let userHash = PreferenceService.userHash,
            !wipe || byUserAction {
            HttpClient.shared.logout(userHash: userHash)
        }
        PvtboxService.stop()
        if wipe {
            PreferenceService.clear()
        }
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            appDelegate.window?.rootViewController?.dismiss(animated: true, completion: nil)
            let loginVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "loginvc") as! LoginVC
            appDelegate.window?.rootViewController = loginVC
            if !byUserAction {
                SnackBarManager.showSnack(Strings.loggedOutByRemoteAction)
            }
        }
    }
    
    private func pause() {
        paused = true
        dataBaseService.setOwnDevicePaused(paused)
        downloadManager?.pause()
    }
    
    private func resume() {
        paused = false
        dataBaseService.setOwnDevicePaused(paused)
        downloadManager?.resume()
    }
    
    private func stop() {
        BFLog("PvtboxService::stop")
        NotificationCenter.default.removeObserver(self)
        
        cameraImportService?.stop()
        uploadsDownloader?.stop()
        speedCalculator?.stop()
        statusBroadcaster?.stop()
        connectivityService?.stop()
        signalServerService?.stop()
        shareSignalServerService?.stop()
        operationService?.stop()
        downloadManager?.stop()
        syncService?.stop()
        temporaryFilesManager?.stop()
        
        endBackgroundTask()
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        cameraImportService = nil
        uploadsDownloader = nil
        syncService = nil
        signalServerService = nil
        shareSignalServerService = nil
        operationService = nil
        connectivityService = nil
        downloadManager = nil
        statusBroadcaster = nil
        speedCalculator = nil
        temporaryFilesManager = nil
        PvtboxService.shared = nil
        
        FileTool.delete(FileTool.tmpDirectory)
    }
    
    private func onLoggedIn(_ loginData: JSON) {
        BFLog("PvtboxService::OnLoggedIn: %@", String(describing: loginData))
        if let remoteActions = loginData["remote_actions"].jsonArray,
            !remoteActions.isEmpty {
            if handleRemoteActions(remoteActions) {
                return
            }
        }
        
        let license = loginData["license_type"].string!
        onLicenseChanged(license)
        
        let servers = loginData["servers"].jsonArrayValue
        connectivityService = ConnectivityService(
            servers: servers, signalServerClient: signalServerService,
            speedCalculator: speedCalculator, dataBaseService: dataBaseService)
        shareSignalServerService?.setConnectivityServers(servers)
        signalServerService?.setConnectivityService(connectivityService)
        downloadManager = DownloadManager(
            dataBaseService, connectivityService, temporaryFilesManager, paused: paused)
        for server in servers {
            switch server["server_type"].stringValue {
            case "SIGN":
                let signalServerAddress = "wss://" + server["server_url"].string!
                signalServerService!.start(withAddress: signalServerAddress)
                shareSignalServerService?.setSignalServerAddress(signalServerAddress)
                HttpClient.shared.signalServerAddress = signalServerAddress
            default:
                continue
            }
        }
    }
    
    public static func onLicenseChanged(_ license: String) {
        shared?.onLicenseChanged(license)
    }
    
    private func onLicenseChanged(_ license: String) {
        if PreferenceService.license == Const.freeLicense && license != Const.freeLicense {
            BFLog("PvtboxService::onLicenseChanged set all events unchecked "
                + "after upgrading from free license")
            dataBaseService.setAllEventsUnchecked()
            try? signalServerService?.sendEventsCheck()
        }
        PreferenceService.license = license
        if license == Const.freeLicense {
            showFreeLicenseNotification()
            dataBaseService.cancelAllDownloads()
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [Strings.licenseIsFree])
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [Strings.licenseIsFree])
        }
    }
    
    public static func onNotificationsCountChanged(_ count: Int) {
        PvtboxService.shared?.onNotificationsCountChanged(count)
    }
    
    private func onNotificationsCountChanged(_ count: Int) {
        dataBaseService.updateOwnDeviceStatus(notificationsCount: count)
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }
    
    public static func handleRemoteAction(_ remoteActions: JSON) {
        PvtboxService.shared?.handleRemoteActions([remoteActions])
    }
    
    @discardableResult
    private func handleRemoteActions(_ remoteActions: [JSON]) -> Bool {
        var stopServiceExecution = false
        for action in remoteActions {
            HttpClient.shared.remoteActionDone(uuid: action["action_uuid"].string!)
            switch action["action_type"].string! {
            case "logout":
                logout(byUserAction: false, wipe: false)
                stopServiceExecution = true
            case "wipe":
                logout(byUserAction: false, wipe: true)
                stopServiceExecution = true
            case "credentials":
                PreferenceService.userHash = action["action_data"]["user_hash"].string!
                PreferenceService.email = action["action_data"]["user_email"].string!
            default:
                BFLogErr("PvtboxService::handleRemoteActions: Unexpected remote action %@",
                         action["actionType"].stringValue)
            }
        }
        return stopServiceExecution
    }

    private func onLoginError(_ loginData: JSON?) {
        BFLog("PvtboxService::onLoginError")
        if let remoteActions = loginData?["remote_actions"].jsonArray,
            !remoteActions.isEmpty {
            if handleRemoteActions(remoteActions) {
                return
            }
        } else if let errcode = loginData?["errcode"].string,
            errcode == "USER_NOT_FOUND" || errcode == "LICENSE_LIMIT" {
            logout(byUserAction: false, wipe: false)
            return
        }
        dq.asyncAfter(deadline: .now() + 10, execute: { self.login(nil) })
    }
    
    private func showFreeLicenseNotification() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus != .authorized { return }
            
            let content = UNMutableNotificationContent()
            content.title = Strings.licenseIsFree
            content.body = Strings.upgradeLicense
            content.subtitle = Strings.syncDisabled
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: Strings.licenseIsFree, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(
                request, withCompletionHandler: nil)
        }
    }
    
    public static func registerBackgroundTask13() {
        if #available(iOS 13.0, *) {
            BFLog("PvtboxService::registerBackgroundTask13")
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: "net.pvtbox.PrivateBox.sync",
                using: DispatchQueue.main) { task in
                    BFLog("PvtboxService::registerBackgroundTask13 callback")
                    PvtboxService.scheduleBackgroundTask()
                    task.expirationHandler = {
                        BFLog("PvtboxService::registerBackgroundTask13 task expired")
                        if UIApplication.shared.applicationState == .background {
                            PvtboxService.stop()
                        }
                        task.setTaskCompleted(success: true)
                    }
            }
        }
    }
    
    private func registerBackgroundTask() {
        BFLog("PvtboxService::registerBackgroundTask")
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            BFLog("PvtboxService::endBackgroundTask task finished")
            PvtboxService.stop()
            self?.endBackgroundTask()
        }
        assert(backgroundTask != .invalid)
    }
    
    public static func scheduleBackgroundTask() {
        if #available(iOS 13.0, *) {
            BFLog("PvtboxService::scheduleBackgroundTask")
            let request = BGProcessingTaskRequest(identifier: "net.pvtbox.PrivateBox.sync")
            request.requiresExternalPower = false
            request.requiresNetworkConnectivity = true
            do {
               try BGTaskScheduler.shared.submit(request)
            } catch {
                BFLog("PvtboxService::scheduleBackgroundTask error: %@",
                      String(describing: error))
            }
        }
    }
    
    private func endBackgroundTask() {
        BFLog("PvtboxService::endBackgroundTask")
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
    
    private func checkGroup() {
        if !PvtboxService.needCheckGroup { return }
        BFLog("PvtboxService::checkGroup")
        var fileUrls = FileTool.contents(of: FileTool.shareGroupDirectory)
        var size = FileTool.size(ofDirectory: FileTool.shareGroupDirectory)
        BFLog("PvtboxService::checkGroup share count: %d, size: %f", fileUrls.count, size)
        
        if fileUrls.count > 0 {
            PvtboxService.addOperation(
                .sendFiles, root: nil, urls: fileUrls, deleteAfterImport: true)
        }
        
        fileUrls = FileTool.contents(of: FileTool.addGroudDirectory)
        size = FileTool.size(ofDirectory: FileTool.addGroudDirectory)
        BFLog("PvtboxService::checkGroup add count: %d, size: %f", fileUrls.count, size)
        
        if fileUrls.count > 0 {
            PvtboxService.addOperation(
                .importFiles, root: nil, urls: fileUrls, deleteAfterImport: true)
        }
    }
    
    private func handleShareUrl() {
        guard let url = PvtboxService.shareUrl else { return }
        PvtboxService.shareUrl = nil
        DispatchQueue.main.async {
            let dialog = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "shareRootSelectDialog") as! ShareRootSelectDialog
            dialog.setup(url: url)
            UIApplication.shared.keyWindow?.rootViewController?.present(
                dialog, animated: true, completion: nil)
        }
    }
    
    private func onSynced() {
        guard let hashes = dataBaseService.getAllFilesHashes() else { return }
        let copies = FileTool.contents(of: FileTool.copiesDirectory)
        for copy in copies {
            let hashsum = copy.lastPathComponent
            if hashsum == DownloadManager.emptyCopyHash || hashes.contains(hashsum) {
                continue
            }
            FileTool.delete(copy)
        }
    }
}
