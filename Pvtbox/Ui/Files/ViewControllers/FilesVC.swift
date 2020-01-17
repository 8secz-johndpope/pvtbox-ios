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
import AudioToolbox
import MaterialComponents.MaterialBottomSheet
import NVActivityIndicatorView
import Photos
import AVKit
import MarqueeLabel

class FilesVC:
    UIViewController,
    UITableViewDataSource, UITableViewDelegate,
    UIGestureRecognizerDelegate, UIDocumentInteractionControllerDelegate,
    DataChangeDelegate, SelectionProviderDelegate, FileCardDelegate, ViewPresenter,
    NetworkDelegate, ActionsProviderDelegate, SyncStatusDelegate {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var welcome: UIScrollView!
    @IBOutlet weak var emptyFolder: UIScrollView!
    @IBOutlet weak var nothingFound: UIScrollView!
    @IBOutlet weak var loading: UIActivityIndicatorView!
    
    @IBOutlet weak var connectedNodes: MarqueeLabel!
    @IBOutlet weak var download: UILabel!
    @IBOutlet weak var upload: UILabel!
    
    
    @IBOutlet weak var folderHeader: UILabel!
    @IBOutlet weak var logoHeader: UIBarButtonItem!
    @IBOutlet weak var connectingHeader: UIView!
    @IBOutlet weak var connectingHeaderIndicator: NVActivityIndicatorView!
    
    @IBOutlet weak var selectionHeader: UILabel!
    
    @IBOutlet weak var leftIcon: UIBarButtonItem!
    @IBOutlet weak var cancelButton: UIBarButtonItem!
    @IBOutlet weak var searchView: UIView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var searchButton: UIBarButtonItem!
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var clickRecognizer: UITapGestureRecognizer!
    
    @IBOutlet weak var addButton: MDCFloatingButton!
    @IBOutlet weak var pasteActionButton: MDCFloatingButton!
    @IBOutlet weak var cancelActionsButton: MDCFloatingButton!
    @IBOutlet weak var downloadsButton: MDCFloatingButton!
    
    private var waitAlert: UIAlertController?
    
    var presenter: FilesPresenter!
    private var dataProvider: DataProvider!
    private var modeProvider: ModeProvider!
    private var selectionProvider: SelectionProvider!
    private var selectionController: SelectionController!
    private let tableViewRefreshControl = UIRefreshControl()
    private let welcomeRefreshControl = UIRefreshControl()
    private let emptyFolderRefreshControl = UIRefreshControl()
    private let nothingFoundRefreshControl = UIRefreshControl()
    
    private var docVc: UIDocumentInteractionController?
    
    var tag: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loading.transform = CGAffineTransform(scaleX: 2, y: 2)
        presenter = presenter ?? (parent as? FilesNC)?.presenter
        tag = tag ?? (parent as? FilesNC)?.tag
        dataProvider = presenter
        modeProvider = presenter
        selectionProvider = presenter
        selectionController = presenter
        
        tableViewRefreshControl.tintColor = .orange
        tableViewRefreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = tableViewRefreshControl
        
        welcomeRefreshControl.tintColor = .orange
        welcomeRefreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        welcome.refreshControl = welcomeRefreshControl
        
        nothingFoundRefreshControl.tintColor = .orange
        nothingFoundRefreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        nothingFound.refreshControl = nothingFoundRefreshControl
        
        emptyFolderRefreshControl.tintColor = .orange
        emptyFolderRefreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        emptyFolder.refreshControl = emptyFolderRefreshControl
        
        navigationItem.rightBarButtonItems = [menuButton, searchButton]
        searchBar.setImage(UIImage(named: "close"), for: .clear, state: .normal)
        searchBar.delegate = presenter
        
        clickRecognizer.delegate = self
        
        switch modeProvider.viewMode {
        case .recent, .downloads:
            addButton.isHidden = true
        default:
            break
        }

        downloadsButton.isHidden = !(modeProvider.viewMode == .downloads)
        
        if self.enabled {
            presenter.refresh()
        }
        
        BFLog("FilesVC::%@::viewDidLoad %@", tag, String(describing: self))
    }
    
    override func viewDidAppear(_ animated: Bool) {
        presenter.maxRecentCount = max(
            8, Int(max(tableView.bounds.height, tableView.bounds.width) / 70.0))
    }
    
    deinit {
        BFLog("FilesVC::%@::deinit", tag)
    }
    
    @objc func refresh() {
        DispatchQueue.main.async { [weak self] in
            self?.presenter.refresh()
        }
    }
    
    internal func networkDelegateOnlineChanged(to value: Bool) {
        BFLog("FilesVC::%@::networkDelegateOnlineChanged", tag)
        if !modeProvider.isSearchMode && !selectionProvider.inSelection() {
            setupHeaderView()
        }
    }
    
    internal func networkDelegateDownloadChanged(speed: Double, size: Double) {
        BFLog("FilesVC::%@::networkDelegateDownloadChanged", tag)
        download.text = String(
            format: "↓ %@/%@ | %@",
            ByteFormatter.instance.string(fromByteCount: Int64(speed)),
            Strings.secondLetter,
            ByteFormatter.instance.string(fromByteCount: Int64(size))
        )
    }
    
    internal func networkDelegateUploadChanged(speed: Double, size: Double) {
        BFLog("FilesVC::%@::networkDelegateUploadChanged", tag)
        upload.text = String(
            format: "↑ %@/%@ | %@",
            ByteFormatter.instance.string(fromByteCount: Int64(speed)),
            Strings.secondLetter,
            ByteFormatter.instance.string(fromByteCount: Int64(size))
        )
    }
    
    internal func networkDelegateConnectedNodesChanged(to value: Int) {
        BFLog("FilesVC::%@::networkDelegateConnectedNodesChanged", tag)
        connectedNodes.text = String(format: "%d %@", value, value == 1 ?
                Strings.peerConnected : Strings.peersConnected)
        connectedNodes.textColor = .darkGreen
        connectedNodes.labelize = true
        if value == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                if self?.presenter.connectedNodesCount ?? 0 == 0 {
                    self?.connectedNodes.text = Strings.connectNodesToSync
                    self?.connectedNodes.textColor = .red
                    self?.connectedNodes.labelize = false
                }
            }
        }
    }
    
    internal func syncStatusDelegatePausedChanged(to value: Bool) {
        if value{
            downloadsButton.backgroundColor = .orange
            downloadsButton.setImage(UIImage(named: "resume"), for: .normal)
        } else {
            downloadsButton.backgroundColor = .lightGray
            downloadsButton.setImage(UIImage(named: "pause"), for: .normal)
        }
    }
    
    fileprivate func setupHeaderView() {
        BFLog("FilesVC::%@::setupHeaderView", tag)
        if presenter.networkIsOnline {
            connectingHeaderIndicator.stopAnimating()
            if navigationItem.leftBarButtonItem == leftIcon {
                navigationItem.leftBarButtonItem = nil
            }
        } else {
            if navigationItem.titleView != connectingHeader {
                navigationItem.titleView = connectingHeader
                connectingHeaderIndicator.startAnimating()
            }
            if presenter.root == nil {
                navigationItem.leftBarButtonItem = leftIcon
                navigationItem.leftBarButtonItem?.tintColor = .lightGray
            }
            return
        }
        navigationItem.leftBarButtonItem = nil
        if let rootItem = presenter?.root {
            navigationItem.leftBarButtonItem = nil
            folderHeader.text = rootItem.name!
            navigationItem.titleView = folderHeader
        } else {
            navigationItem.titleView = nil
            navigationItem.leftBarButtonItem = logoHeader
        }
    }
    
    var enabled: Bool = false {
        willSet {
            if !self.enabled && newValue {
                enable()
            } else if (self.enabled && !newValue) {
                disable()
            }
        }
    }
    
    private func enable() {
        BFLog("FilesVC::%@::enable", tag)
        
        presenter.actionsProviderDelegate = self
        self.actionsProviderDelegateActiveChanged(self.presenter.actionsProviderActive)
        
        presenter.enable(dataChangeDelegate: self,
                         selectionProviderDelegate: self,
                         networkDelegate: self,
                         syncStatusDelegate: modeProvider.viewMode == .downloads ? self : nil)
        NotificationCenter.default
            .addObserver(self, selector: #selector(onBecomeActive),
                         name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default
            .addObserver(self, selector: #selector(onWillResignActive),
                         name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    private func disable() {
         BFLog("FilesVC::%@::disable", tag)
        presenter.disable()
        presenter.actionsProviderDelegate = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func onBecomeActive() {
        BFLog("FilesVC::%@::onBecomeActive", tag)
        presenter.enable(dataChangeDelegate: self,
                         selectionProviderDelegate: self,
                         networkDelegate: self,
                         syncStatusDelegate: modeProvider.viewMode == .downloads ? self : nil)
        if self.enabled {
            notifyCellsViewDidAppear()
            presenter.refresh()
        }
    }
    
    @objc private func onWillResignActive() {
        BFLog("FilesVC::%@::onWillResignActive", tag)
        presenter.disable()
    }
    
    private func notifyCellsViewDidAppear() {
        BFLog("FilesVC::%@::notifyCellsViewDidAppear", tag)
        for cell in self.tableView.visibleCells {
            guard let cell = cell as? FileCard else { continue }
            cell.viewDidAppear()
        }
    }
    
    func onDataLoaded() {
        BFLog("FilesVC::%@::onDataLoaded", tag)
        if dataProvider.isEmpty {
            hideFileList()
            tableView.reloadData()
        } else {
            showFileList()
            tableView.reloadData()
        }
        if tableViewRefreshControl.isRefreshing {
            tableViewRefreshControl.endRefreshing()
        }
        if welcomeRefreshControl.isRefreshing {
            welcomeRefreshControl.endRefreshing()
        }
        if nothingFoundRefreshControl.isRefreshing {
            nothingFoundRefreshControl.endRefreshing()
        }
        if emptyFolderRefreshControl.isRefreshing {
            emptyFolderRefreshControl.endRefreshing()
        }
    }
    
    private func hideFileList() {
        BFLog("FilesVC::%@::hideFileList", tag)
        tableView.isHidden = true
        if dataProvider.isLoading {
            loading.isHidden = false
            nothingFound.isHidden = true
            emptyFolder.isHidden = true
            welcome.isHidden = true
            return
        }
        loading.isHidden = true
        switch modeProvider.viewMode {
        case .all, .offline:
            nothingFound.isHidden = !modeProvider.isSearchMode
            emptyFolder.isHidden = !nothingFound.isHidden || presenter.root == nil
            welcome.isHidden = !nothingFound.isHidden || !emptyFolder.isHidden
            break
        case .recent, .downloads:
            welcome.isHidden = true
            nothingFound.isHidden = !modeProvider.isSearchMode
            emptyFolder.isHidden = !nothingFound.isHidden
        }
    }
    
    private func showFileList() {
        BFLog("FilesVC::%@::showFileList", tag)
        tableView.isHidden = false
        welcome.isHidden = true
        emptyFolder.isHidden = true
        nothingFound.isHidden = true
        loading.isHidden = true
    }
    
    func onDataChanged(_ deletions: [Int], _ insertions: [Int], _ modifications: [Int]) {
        BFLog("FilesVC::%@::onDataChanged", tag)
        tableView.beginUpdates()
        if !deletions.isEmpty {
            tableView.deleteRows(
                at: deletions.map({IndexPath(row: $0, section: 0)}), with: .none)
        }
        if !insertions.isEmpty {
            tableView.insertRows(
                at: insertions.map({IndexPath(row: $0, section: 0)}), with: .none)
        }
        if !modifications.isEmpty {
            tableView.reloadRows(
                at: modifications.map({IndexPath(row: $0, section: 0)}), with: .none)
        }
        tableView.endUpdates()
        if dataProvider.isEmpty {
            if !tableView.isHidden {
                hideFileList()
            }
        } else {
            if tableView.isHidden {
                showFileList()
            }
        }
    }
    
    func selectionProvider(selectedCountChanged: Int) {
        selectionHeader.text = String(
            format: "%@: %d", Strings.selected, selectedCountChanged)
        selectionHeader.sizeToFit()
    }
    
    func selectionProvider(inSelection: Bool) {
        BFLog("FilesVC::%@::selectionProvider, inSelection: %@", tag, String(describing: inSelection))
        if inSelection {
            navigationItem.titleView = selectionHeader
            navigationItem.leftBarButtonItem = cancelButton
        }
        tableView.reloadData()
        navigationItem.rightBarButtonItems = [menuButton, searchButton]
        if #available(iOS 13.0, *) {
            navigationController?.navigationBar.barTintColor = inSelection ? .secondarySystemFill : nil
        } else {
            navigationController?.navigationBar.barTintColor = inSelection ? .grayHeader : nil
        }
        
        for button in navigationItem.rightBarButtonItems ?? [] {
            button.tintColor = inSelection ? .white : .orange
        }
        navigationItem.leftBarButtonItem?.tintColor = inSelection ? .white : .orange
        searchBar.tintColor = inSelection ? .white : .orange
        if #available(iOS 13.0, *) {
            UITextField.appearance(
            whenContainedInInstancesOf: [UISearchBar.self]).backgroundColor = inSelection ?
            .secondarySystemFill : nil
        } else {
            UITextField.appearance(
            whenContainedInInstancesOf: [UISearchBar.self]).backgroundColor = inSelection ?
                .grayHeader : nil
        }
        
        if modeProvider.isSearchMode {
            onSearchClicked(self)
        }
        if !inSelection && !modeProvider.isSearchMode {
            setupHeaderView()
        }
    }
    
    @IBAction func onCancelClicked(_ sender: Any) {
        BFLog("FilesVC::%@::onCancelClicked", tag)
        if modeProvider.isSearchMode {
            searchBar.text = ""
            presenter.isSearchMode = false
            selectionProvider(inSelection: selectionProvider.inSelection())
            return
        }
        if selectionProvider.inSelection() {
            selectionController.dropSelection()
        }
    }
    
    @IBAction func onSearchClicked(_ sender: Any) {
        BFLog("FilesVC::%@::onSearchClicked", tag)
        navigationItem.titleView = searchView
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.leftBarButtonItem?.tintColor = selectionProvider.inSelection() ? .white : .orange
        navigationItem.rightBarButtonItems = [menuButton]
        presenter.isSearchMode = true
        searchBar.becomeFirstResponder()
    }
    
    
    @IBAction func onMenuClicked(_ sender: UIBarButtonItem) {
        BFLog("FilesVC::%@::onMenuClicked")
        var menu: UIViewController!
        if selectionProvider.inSelection() {
            let filesMenu = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "filesMenu") as! FilesMenu
            filesMenu.modeProvider = modeProvider
            filesMenu.selectionProvider = selectionProvider
            filesMenu.selectionController = selectionController
            filesMenu.viewPresenter = self
            filesMenu.delegate = presenter
            menu = filesMenu
        } else {
            let mainMenu = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "mainMenu") as! MainMenu
            mainMenu.sortingChangeListener = presenter
            mainMenu.modeProvider = modeProvider
            mainMenu.selectionController = selectionController
            menu = mainMenu
        }
        menu.modalPresentationStyle = .popover
        let controller = menu.popoverPresentationController!
        controller.permittedArrowDirections = .up
        controller.barButtonItem = sender
        controller.delegate = (menu as! UIPopoverPresentationControllerDelegate)
        self.present(menu, animated: true, completion: nil)
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataProvider.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let card = tableView.dequeueReusableCell(
            withIdentifier: "fileCard", for: indexPath) as! FileCard
        card.delegate = self
        let file = dataProvider.item(at: indexPath)
        card.displayContent(
            file,
            indexPath,
            isSelected: selectionProvider.isSelected(indexPath),
            isSelectionMode: selectionProvider.inSelection())
        return card
    }
    
    func fileCardDelegate(onMenuClicked file: FileRealm) {
        guard let index = dataProvider.index(for: file) else { return }
        presenter.onFileSelected(at: index)
        self.tableView.reloadRows(at: [index], with: .none)
        let menu = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "fileMenu") as! FileMenu
        menu.selectionProvider = selectionProvider
        menu.viewPresenter = self
        menu.modeProvider = modeProvider
        menu.delegate = presenter
        menu.realm = presenter.realm
        menu.root = presenter.root
        let bottomSheet = MDCBottomSheetController(contentViewController: menu)
        present(bottomSheet)
    }
    
    public func present(_ vc: UIViewController) {
        BFLog("FilesVC::%@::present, vc: %@", tag, String(describing: vc))
        present(vc, animated: true, completion: nil)
    }
    
    public func presentWithNavigation(_ vc: UIViewController) {
        BFLog("FlesVC::%@::presentWithNavigation, vc: %@", tag, String(describing: vc))
        navigationController?.pushViewController(vc, animated: true)
    }
    
    public func presentDocumentMenu(_ vc: UIDocumentInteractionController) {
        vc.presentOpenInMenu(from: view.frame, in: view, animated: true)
        vc.delegate = self
        docVc = vc
    }
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view != nil && touch.view is UIButton && touch.view!.isUserInteractionEnabled {
            return false
        }
        return true
    }
    
    @IBAction func onClick(_ sender: UITapGestureRecognizer) {
        BFLog("FilesVC::%@::onClick", tag)
        guard let indexPath = self.tableView?.indexPathForRow(
            at: sender.location(in: self.tableView)) else { return }
        
        guard let file = dataProvider.item(at: indexPath),
            !file.isProcessing else { return }
        
        if self.selectionProvider.inSelection() {
            if self.presenter.isSelected(indexPath) {
                self.presenter.onFileDeselected(at: indexPath)
            } else {
                self.presenter.onFileSelected(at: indexPath)
            }
            self.tableView.reloadRows(at: [indexPath], with: .none)
        } else {
            if file.isFolder {
                onFolderClicked(file, at: indexPath)
            } else {
                onFileClicked(file)
            }
        }
    }
    
    private func onFolderClicked(_ file: FileRealm, at indexPath: IndexPath) {
        if presenter.actionsProviderActive && selectionProvider.isSelected(indexPath) {
            let error = String(
                format: "%@ %@ %@ \"%@\" %@",
                Strings.cant,
                presenter.actionsProviderCopyActive ? Strings.copy : Strings.move,
                Strings.folder,
                file.name!,
                Strings.toItself
            )
            self.view.window?.hideAllToasts()
            self.view.window?.makeToast(error)
            return
        }
        onCancelClicked(self)
        let newPresenter = FilesPresenter(
            rootFile: file, presenter: presenter)
        let newVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "filesvc") as! FilesVC
        newVC.presenter = newPresenter
        newVC.tag = tag
        self.navigationController?.pushViewController(newVC, animated: true)
    }
    
    private func onFileClicked(_ file: FileRealm) {
        if file.isDownload { return }
        if file.hashsum == nil && file.localIdentifier == nil {
            PvtboxService.downloadFile(file.uuid!)
        } else {
            if file.isDownloadActual || file.localIdentifier != nil {
                openFilePreview(file)
            } else {
                let alert = MDCAlertController(title: nil, message: Strings.fileNotUpToDate)
                alert.cornerRadius = 4
                alert.messageFont = .systemFont(ofSize: 16)
                if #available(iOS 13.0, *) {
                    alert.titleColor = .label
                    alert.messageColor = .secondaryLabel
                    alert.backgroundColor = .secondarySystemBackground
                    alert.buttonTitleColor = .label
                } else {
                    alert.messageColor = .darkGray
                }
                let download = MDCAlertAction(title: Strings.download, handler: {_ in
                    PvtboxService.downloadFile(file.uuid!)
                })
                alert.addAction(download)
                let open = MDCAlertAction(title: Strings.open, handler: {_ in
                    self.openFilePreview(file)
                })
                alert.addAction(open)
                present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func openFilePreview(_ file: FileRealm) {
        if file.hashsum == nil {
            let fetchOptions = PHFetchOptions()
            fetchOptions.fetchLimit = 1
            guard let asset = PHAsset.fetchAssets(
                withLocalIdentifiers: [file.localIdentifier!], options: fetchOptions)
                .firstObject else {
                    view.window?.hideAllToasts()
                    view.window?.makeToast(Strings.fileDeletedFromDeviceCamera)
                    return
            }
            if asset.mediaType == .image {
                let preview = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                    withIdentifier: "phassetphotopreview") as! PHAssetPhotoPreviewVC
                preview.asset = asset
                preview.fileName = file.name!
                presentWithNavigation(preview)
            }
            if asset.mediaType == .video {
                let requestOptions = PHVideoRequestOptions()
                requestOptions.deliveryMode = .fastFormat
                requestOptions.isNetworkAccessAllowed = true
                PHImageManager.default().requestPlayerItem(
                forVideo: asset, options: requestOptions) { [weak self] item, _ in
                    DispatchQueue.main.async { [weak self] in
                        let player = AVPlayer(playerItem: item)
                        let playerViewController = AVPlayerViewController()
                        playerViewController.player = player
                        self?.present(playerViewController, animated: true) {
                            playerViewController.player!.play()
                        }
                    }
                }
            }
        } else {
            let url = FileTool.syncDirectory.appendingPathComponent(file.path!)
            openFilePreview(url)
        }
    }
    
    private func openFilePreview(_ url: URL?) {
        guard let url = url else {
            view.window?.hideAllToasts()
            view.window?.makeToast(Strings.cantPreview)
            return
        }
        
        let docController = UIDocumentInteractionController(url: url)
        docController.delegate = self
        if !docController.presentPreview(animated: true) {
            view.window?.hideAllToasts()
            view.window?.makeToast(Strings.cantPreview)
        }
    }
    
    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    func documentInteractionControllerViewForPreview(_ controller: UIDocumentInteractionController) -> UIView? {
        return tableView
    }
    
    func documentInteractionControllerWillBeginPreview(_ controller: UIDocumentInteractionController) {
        BFLog("FilesVC::%@::documentInteractionControllerWillBeginPreview", tag)
        let activityData = ActivityData(type: .lineSpinFadeLoader, color: .orange)
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(activityData, nil)
        stopActivityIndicatorIfPreviewPresented()
    }
    
    func documentInteractionControllerDidDismissOpenInMenu(_ controller: UIDocumentInteractionController) {
        docVc = nil
    }
    
    private func stopActivityIndicatorIfPreviewPresented() {
        if presentedViewController != nil && !presentedViewController!.isBeingPresented {
            NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                if self == nil {
                    NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
                }
                self?.stopActivityIndicatorIfPreviewPresented()
            }
        }
    }
    
    @IBAction func onLongClick(_ sender: UILongPressGestureRecognizer) {
        if (sender.state != UIGestureRecognizer.State.began) {
            return
        }
        guard let indexPath = self.tableView?.indexPathForRow(
            at: sender.location(in: self.tableView)),
            let file = dataProvider.item(at: indexPath),
            !file.isProcessing else { return }
        BFLog("FilesVC::%@::onLongClick", tag)
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        if self.selectionProvider.inSelection() {
            selectionController.dropSelection()
        } else {
            self.presenter.onFileSelected(at: indexPath)
            self.selectionController.startSelection()
        }
    }

    @IBAction private func onAddClick() {
        BFLog("FilesVC::%@::onAddClick", tag)
        let menu = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "addMenu") as! AddMenu
        menu.delegate = presenter
        menu.sendFileDelegate = presenter.sendFileDelegate
        menu.viewPresenter = self
        menu.realm = presenter.realm
        menu.root = presenter.root
        let bottomSheet = MDCBottomSheetController(contentViewController: menu)
        present(bottomSheet)
    }
    
    @IBAction private func onCancelActionsButton() {
        BFLog("FilesVC::%@::onCancelActionsButton", tag)
        self.presenter.onCancelActions()
    }
    
    @IBAction func onPasteActionButton() {
        BFLog("FilesVC::%@::onPasteActionButton", tag)
        self.presenter.onPasteAction()
    }
    
    @IBAction func onDownloadsButtonClick() {
        BFLog("FilesVC::%@::onDownloadsButtonClick", tag)
        self.presenter.onDownloadsButtonClick()
    }
    
    func actionsProviderDelegateActiveChanged(_ active: Bool) {
        BFLog("FilesVC::%@::actionsProviderDelegateActiveChanged", tag)
        pasteActionButton.isHidden = !active
        cancelActionsButton.isHidden = !active
        if !active {
            self.selectionController.dropSelection()
        }
    }
    
}
