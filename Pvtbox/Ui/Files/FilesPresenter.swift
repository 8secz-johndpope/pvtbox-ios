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
import Photos
import RealmSwift

class FilesPresenter: NSObject, UISearchBarDelegate,
    DataProvider, ModeProvider, SelectionProvider, SortingChangeListener,
SelectionController, MenuDelegate, ActionsProvider {
    let root: FileRealm?
    let actionsDelegate: ActionsDelegate
    var sendFileDelegate: SendFileDocumentPickerDelegate?
    var actionsProvider: ActionsProvider
    let viewMode: ViewMode
    var realm: Realm?
    private var files: Results<FileRealm>!
    private var subscription: NotificationToken?
    private var selectedUuids: Set<String> = Set()
    
    private var ownDevice: DeviceRealm?
    private var ownDeviceSubsription: NotificationToken?
    
    var maxRecentCount: Int = 0
    
    private var dataChangeDelegate: DataChangeDelegate?
    internal var selectionProviderDelegate: SelectionProviderDelegate?
    private var networkDelegate: NetworkDelegate?
    private var syncStatusDelegate: SyncStatusDelegate?
    
    private weak var timer: Timer?
    
    private var searchQuery: String?
    
    private var enabled = false
    
    convenience init(
        mode: ViewMode, actionsDelegate: ActionsDelegate, actionsProvider: ActionsProvider) {
        self.init(nil, mode, actionsDelegate, actionsProvider)
    }
    
    convenience init(rootFile: FileRealm, presenter: FilesPresenter) {
        self.init(
            FileRealm(value: rootFile),
            presenter.viewMode, presenter.actionsDelegate, presenter.actionsProvider)
    }
    
    private init(
        _ rootFile: FileRealm?, _ viewMode: ViewMode,
        _ actionsDelegate: ActionsDelegate, _ actionsProvider: ActionsProvider) {
        self.root = rootFile
        self.viewMode = viewMode
        self.actionsDelegate = actionsDelegate
        self.actionsProvider = actionsProvider
        super.init()
        self.sendFileDelegate = SendFileDocumentPickerDelegate(self)
    }
    
    private func getFiles(_ searchQuery: String?) {
        BFLog("getFiles")
        files = realm?.objects(FileRealm.self)
        var sortings: [SortDescriptor] = [SortDescriptor(keyPath: "isFolder", ascending: false)]
        switch viewMode {
        case .all, .offline:
            if self.root == nil {
                files = files.filter("parentUuid = nil")
            } else {
                files = files.filter("parentUuid = %@", self.root!.uuid!)
            }
            if viewMode == .offline {
                files = files.filter("isOffline = true || offlineFilesCount > 0")
            }
            if PreferenceService.sortingByName {
                sortings.append(SortDescriptor(keyPath: "name", ascending: true))
            } else {
                sortings.append(SortDescriptor(keyPath: "dateModified", ascending: false))
            }
        case .recent, .downloads:
            files = files.filter("isFolder = false")
            if viewMode == .downloads {
                files = files.filter("isDownload = true")
                sortings.append(SortDescriptor(keyPath: "downloadStatus", ascending: true))
                sortings.append(SortDescriptor(keyPath: "size", ascending: true))
            } else {
                sortings.append(SortDescriptor(keyPath: "dateModified", ascending: false))
            }
        }
        self.searchQuery = searchQuery
        if !(searchQuery?.isEmpty ?? true) {
            files = files.filter("name BEGINSWITH[cd] %@", searchQuery!)
        }
        
        files = files.sorted(by: sortings)
    }
    
    func enable(dataChangeDelegate: DataChangeDelegate?,
                selectionProviderDelegate: SelectionProviderDelegate?,
                networkDelegate: NetworkDelegate?,
                syncStatusDelegate: SyncStatusDelegate?) {
        if enabled { return }
        BFLog("FilesPresenter::enable")
        guard let realm = try? Realm() else {
            DispatchQueue.main.async { [weak self] in
                self?.enable(
                    dataChangeDelegate: dataChangeDelegate,
                    selectionProviderDelegate: selectionProviderDelegate,
                    networkDelegate: networkDelegate,
                    syncStatusDelegate: syncStatusDelegate)
            }
            return
        }
        self.realm = realm
        enabled = true
        self.dataChangeDelegate = dataChangeDelegate
        self.selectionProviderDelegate = selectionProviderDelegate
        self.networkDelegate = networkDelegate
        self.syncStatusDelegate = syncStatusDelegate
        timer = Timer.scheduledTimer(
            withTimeInterval: 60, repeats: true, block: { [weak self] _ in
                self?.dataChangeDelegate?.onDataLoaded()
        })
        subscription?.invalidate()
        getFiles(searchQuery)
        dataChangeDelegate?.onDataLoaded()
        
        subscription = files.observe { [weak self] (changes: RealmCollectionChange) in
            guard let strongSelf = self else { return }
            switch changes {
            case .initial:
                break
            case .update(let o, let deletions, let insertions, let modifications):
                BFLog("FilesPresenter::update %d %d", o.count, strongSelf.files.count)
                if !deletions.isEmpty && strongSelf.selectionMode {
                    strongSelf.checkSelection()
                }
                if strongSelf.viewMode == .recent {
                    strongSelf.dataChangeDelegate?.onDataLoaded()
                } else {
                    strongSelf.dataChangeDelegate?.onDataChanged(
                        deletions, insertions, modifications)
                }
            case .error(let error):
                BFLogErr("realm error: %@", String(describing: error))
            }
        }
        
        subscribeForOnlineChange()
    }
    
    private func subscribeForOnlineChange() {
        ownDevice = realm?.object(ofType: DeviceRealm.self, forPrimaryKey: "own")
        self.networkDelegate?.networkDelegateOnlineChanged(to: ownDevice?.online ?? false)
        if ownDevice == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in self?.subscribeForOnlineChange()
            })
            return
        }
        ownDeviceSubsription = ownDevice!.observe { [weak self] change in
            guard let strongSelf = self else { return }
            switch change {
            case .change(let properties):
                for property in properties {
                    if property.name == "online" {
                        strongSelf.networkDelegate?.networkDelegateOnlineChanged(
                            to: property.newValue as! Bool)
                    } else if property.name == "downloadSpeed" {
                        strongSelf.networkDelegate?.networkDelegateDownloadChanged(
                            speed: strongSelf.ownDevice?.downloadSpeed ?? 0.0,
                            size: strongSelf.ownDevice?.downloadedSize ?? 0.0)
                    } else if property.name == "uploadSpeed" {
                        strongSelf.networkDelegate?.networkDelegateUploadChanged(
                            speed: strongSelf.ownDevice?.uploadSpeed ?? 0.0,
                            size: strongSelf.ownDevice?.uploadedSize ?? 0.0)
                    } else if property.name == "connectedNodes" {
                        strongSelf.networkDelegate?.networkDelegateConnectedNodesChanged(
                            to: property.newValue as! Int)
                    } else if property.name == "paused" {
                        strongSelf.syncStatusDelegate?.syncStatusDelegatePausedChanged(
                            to: property.newValue as! Bool)
                    }
                }
            case .error(let error):
                BFLogErr("An error occurred: %@", error)
            case .deleted:
                BFLogErr("The ownDevice object was deleted.")
            }
        }
        networkDelegate?.networkDelegateOnlineChanged(to: ownDevice?.online ?? false)
        networkDelegate?.networkDelegateDownloadChanged(
            speed: ownDevice?.downloadSpeed ?? 0.0,
            size: ownDevice?.downloadedSize ?? 0.0)
        networkDelegate?.networkDelegateUploadChanged(
            speed: ownDevice?.uploadSpeed ?? 0.0,
            size: ownDevice?.uploadSpeed ?? 0.0)
        networkDelegate?.networkDelegateConnectedNodesChanged(
            to: ownDevice?.connectedNodes ?? 0)
        syncStatusDelegate?.syncStatusDelegatePausedChanged(
            to: ownDevice?.paused ?? false)
    }
    
    var networkIsOnline: Bool {
        get {
            return ownDevice?.online ?? false
        }
    }
    
    var connectedNodesCount: Int {
        get {
            return ownDevice?.connectedNodes ?? 0
        }
    }
    
    func disable() {
        BFLog("FilesPresenter::disable")
        if !enabled { return }
        enabled = false
        subscription?.invalidate()
        files = nil
        dataChangeDelegate?.onDataLoaded()
        realm = nil
        dataChangeDelegate = nil
        selectionProviderDelegate = nil
        networkDelegate = nil
        syncStatusDelegate = nil
        timer?.invalidate()
        timer = nil
        subscription = nil
        ownDeviceSubsription?.invalidate()
        ownDeviceSubsription = nil
        files = nil
        ownDevice = nil
    }
    
    func refresh() {
        BFLog("FilesPresenter::refresh")
        let dataChangeDelegate = self.dataChangeDelegate
        let selectionProviderDelegate = self.selectionProviderDelegate
        let networkDelegate = self.networkDelegate
        let syncStatusDelegate = self.syncStatusDelegate
        disable()
        DispatchQueue.main.async { [weak self] in
            self?.enable(
                dataChangeDelegate: dataChangeDelegate,
                selectionProviderDelegate: selectionProviderDelegate,
                networkDelegate: networkDelegate,
                syncStatusDelegate: syncStatusDelegate)
        }
    }
    
    var selectionMode: Bool = false {
        willSet {
            BFLog("Selection mode will change to %@", String(describing: newValue))
            if newValue {
                selectionProviderDelegate?.selectionProvider(selectedCountChanged: selectedUuids.count)
            }
        }
        didSet {
            BFLog("Selection mode didSet to %@", String(describing: selectionMode))
            selectionProviderDelegate?.selectionProvider(inSelection: selectionMode)
        }
    }
    
    func startSelection() {
        BFLog("startSelection")
        selectionMode = true
    }
    
    func dropSelection() {
        BFLog("Drop selection")
        selectedUuids.removeAll()
        selectionMode = false
    }
    
    func selectAll() {
        BFLog("selectAll")
        var i = 0
        for file in files {
            if i >= (viewMode == .recent ? self.count : self.files.count) {
                break
            }
            i += 1
            guard let uuid = file.uuid,
                !file.isProcessing else { continue }
            self.selectedUuids.insert(uuid)
        }
        selectionProviderDelegate?.selectionProvider(selectedCountChanged: selectedUuids.count)
        selectionProviderDelegate?.selectionProvider(inSelection: true)
    }
    
    func inSelection() -> Bool {
        return selectionMode
    }
    
    func checkSelection() {
        BFLog("Checking selection change...")
        let selectedUuids = self.selectedUuids
        for uuid in selectedUuids {
            let file = files.filter("uuid = %@", uuid).first
            if file == nil {
                self.selectedUuids.remove(uuid)
            }
        }
        if selectedUuids.count != self.selectedUuids.count {
            selectionProviderDelegate?.selectionProvider(selectedCountChanged: self.selectedUuids.count)
        }
    }
    
    func onFileSelected(at index: IndexPath) {
        guard let uuid = files[index.item].uuid else { return }
        if actionsProviderActive {
            actionsDelegate.actionsDelegateCancel()
        }
        BFLog("onFileSelected: %@", uuid)
        selectedUuids.insert(uuid)
        selectionProviderDelegate?.selectionProvider(selectedCountChanged: selectedUuids.count)
    }
    
    func onFileDeselected(at index: IndexPath) {
        guard let uuid = files[index.item].uuid else { return }
        BFLog("OnFileDeselected: %@", uuid)
        selectedUuids.remove(uuid)
        selectionProviderDelegate?.selectionProvider(selectedCountChanged: selectedUuids.count)
    }
    
    func isSelected(_ index: IndexPath) -> Bool {
        guard index.item < files?.count ?? 0,
            let uuid = files[index.item].uuid else { return false }
        return selectedUuids.contains(uuid)
    }
    
    var selectedCount: Int {
        get {
            return selectedUuids.count
        }
    }
    
    var selectedFile: FileRealm? {
        get {
            guard let selectedUuid = selectedUuids.first,
                let file = files.filter("uuid = %@", selectedUuid).first else { return nil }
            return FileRealm(value: file)
        }
    }
    
    var selectedFiles: [FileRealm] {
        get {
            var result: [FileRealm] = []
            for selectedUuid in selectedUuids {
                guard let file = files.filter("uuid = %@", selectedUuid).first else { continue }
                result.append(FileRealm(value: file))
            }
            return result
        }
    }
    
    var count: Int {
        get {
            BFLog("FilesPresenter::count -> %@", String(describing: files?.count))
            // Hack to make space bettwen last element and screen bottom if '+' button present
            switch viewMode {
            case .all, .offline:
                return (files?.count ?? 0) + 1
            case .downloads:
                return files?.count ?? 0
            case .recent:
                return Int(min(maxRecentCount, files?.count ?? 0))
            }
        }
    }
    
    var isEmpty: Bool {
        get {
            BFLog("FilesPresenter::isEmpty -> %@", String(describing: files?.isEmpty))
            return files?.isEmpty ?? true
        }
    }
    
    var isLoading: Bool {
        get {
            return files == nil
        }
    }
    
    func item(at index: IndexPath) -> FileRealm? {
        return index.item < files?.count ?? 0 ? files[index.item] : nil
    }
    
    func index(for file: FileRealm) -> IndexPath? {
        guard let f = files.filter("uuid = %@", file.uuid!).first,
            let item = files.index(of: f) else { return nil }
        return IndexPath(item: item, section: 0)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        searchQuery = query
        refresh()
    }
    
    var isSearchMode: Bool = false {
        didSet {
            BFLog("Search mode did set to: %@", String(describing: isSearchMode))
            if !isSearchMode {
                searchQuery = nil
                refresh()
            }
        }
    }
    
    func sortingChanged() {
        refresh()
    }
    
    func menuDelegateCreateFolder(newName: String) {
        BFLog("menuDelegateCreateFolder, newName: %@", newName)
        PvtboxService.addOperation(
            OperationService.OperationType.createFolder, root: root, newName: newName)
    }
    
    func menuDelegateAddOffline() {
        BFLog("menuDelegateAddOffline")
        let files = self.selectedFiles
        
        let type: OperationService.OperationType = files.count == 1 ? (files[0].isFolder ?
            .addOfflineFolder : .addOfflineFile) : .addOffline
        PvtboxService.addOperation(type, files: files)
        dropSelection()
    }
    
    func menuDelegateRemoveOffline() {
        BFLog("menuDelegateRemoveOffline")
        let files = self.selectedFiles
        
        let type: OperationService.OperationType = files.count == 1 ? (files[0].isFolder ?
            .removeOfflineFolder : .removeOfflineFile) : .removeOffline
        PvtboxService.addOperation(type, files: files)
        dropSelection()
    }
    
    func menuDelegateCancelDownload() {
        BFLog("menuDelegateCancelDownload")
        let files = self.selectedFiles
        let type: OperationService.OperationType = files.count == 1 ?
            .cancelDownload : .cancelDownloads
        PvtboxService.addOperation(type, files: files)
        dropSelection()
    }
    
    func menuDelegateCopy() {
        BFLog("menuDelegateCopy")
        actionsDelegate.actionsDelegateCopy(files: self.selectedFiles)
        selectionMode = false
    }
    
    func menuDelegateMove() {
        BFLog("menuDelegateMove")
        actionsDelegate.actionsDelegateMove(files: self.selectedFiles)
        selectionMode = false
    }
    
    func menuDelegateRename(newName: String) {
        guard let file = selectedFile else {
            BFLogErr("Performing operation without selected file")
            return
        }
        let type: OperationService.OperationType = file.isFolder ?
            .renameFolder : .renameFile
        PvtboxService.addOperation(
            type, newName: newName, uuid: file.uuid!)
        dropSelection()
    }
    
    func menuDelegateDelete() {
        BFLog("menuDelegateDelete")
        let files = self.selectedFiles
    
        let type: OperationService.OperationType = files.count == 1 ? (files[0].isFolder ?
            .deleteFolder : .deleteFile) : .delete
        PvtboxService.addOperation(
            type, files: files)
        dropSelection()
    }
    
    func menuDelegateDismiss() {
        BFLog("menuDelegateDismiss")
        if !inSelection() {
            dropSelection()
        }
    }
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        BFLog("FilesPresenter::imagePickerController didFinishPickingMediaWithInfo")
        
        if let image = info[.originalImage] as? UIImage {
            let data = image.jpegData(compressionQuality: 0.2)
            PvtboxService.addOperation(.addPhoto, root: root, data: data)
        } else if let videoUrl = info[.mediaURL] as? URL {
            PvtboxService.addOperation(.importVideo, root: root, url: videoUrl)
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        BFLog("FilesPresenter::imagePickerControllerDidCancel")
        UIApplication.shared.keyWindow?.makeToast(Strings.actionCancelled)
        picker.dismiss(animated: true, completion: nil)
    }
    
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]) {
        BFLog("FilesPresenter::documentPicker didPickDocumentsAt")
        PvtboxService.addOperation(.importFiles, root: root, urls: urls)
        controller.dismiss(animated: true, completion: nil)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        BFLog("FilesPresenter::documentPickerWasCancelled")
        UIApplication.shared.keyWindow?.makeToast(Strings.actionCancelled)
        controller.dismiss(animated: true, completion: nil)
    }
    
    func menuDelegateSendFile(at urls: [URL]) {
        PvtboxService.addOperation(.sendFiles, root: root, urls: urls)
    }
    
    func menuDelegateSendPhoto(info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            let data = image.jpegData(compressionQuality: 0.2)
            PvtboxService.addOperation(.sendPhoto, root: root, data: data)
        } else if let videoUrl = info[.mediaURL] as? URL {
            PvtboxService.addOperation(.sendVideo, root: root, url: videoUrl)
        }
    }
    
    func onCancelActions() {
        BFLog("onCancelActions")
        dropSelection()
        self.actionsDelegate.actionsDelegateCancel()
    }
    
    func onPasteAction() {
        BFLog("onPasteAction")
        if actionsProviderCopyActive {
            onCopyAction()
        } else if actionsProviderMoveActive {
            onMoveAction()
        } else {
            fatalError("Paste action without active actions")
        }
    }
    
    private func onCopyAction() {
        let files = getFilesForAction()
        let type: OperationService.OperationType = files.count == 1 ? (files[0].isFolder ?
            .copyFolder : .copyFile) : .copy
        PvtboxService.addOperation(
            type, root: root, files: files)
        self.actionsDelegate.actionsDelegateCancel()
    }
    
    private func onMoveAction() {
        let files = self.actionsProvider.getFilesForAction()
        if !selectedFiles.isEmpty {
            UIApplication.shared.keyWindow?.hideAllToasts()
            UIApplication.shared.keyWindow?.makeToast(Strings.moveToSameLocation)
            return
        }
        let type: OperationService.OperationType = files.count == 1 ?
            (files[0].isFolder ? .moveFolder : .moveFile) : .move
        PvtboxService.addOperation(
            type, root: root, files: files)
        self.actionsDelegate.actionsDelegateCancel()
    }
    
    public func onDownloadsButtonClick() {
        if ownDevice?.paused ?? false {
            PvtboxService.resume()
            syncStatusDelegate?.syncStatusDelegatePausedChanged(to: false)
            SnackBarManager.showSnack(Strings.downloadsResumed)
        } else {
            PvtboxService.pause()
            syncStatusDelegate?.syncStatusDelegatePausedChanged(to: true)
            SnackBarManager.showSnack(Strings.downloadsPaused)
        }
    }
    
    var actionsProviderActive: Bool {
        get {
            return self.actionsProvider.actionsProviderActive
        }
    }
    
    var actionsProviderCopyActive: Bool {
        get {
            return self.actionsProvider.actionsProviderCopyActive
        }
    }
    
    var actionsProviderMoveActive: Bool {
        get {
            return self.actionsProvider.actionsProviderMoveActive
        }
    }
    
    var actionsProviderDelegate: ActionsProviderDelegate? {
        get {
            return self.actionsProvider.actionsProviderDelegate
        }
        set {
            self.actionsProvider.actionsProviderDelegate = newValue
        }
    }
    
    func getFilesForAction() -> [FileRealm] {
        return self.actionsProvider.getFilesForAction()
    }
}
