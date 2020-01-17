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
import Toast_Swift
import MaterialComponents.MaterialBottomSheet
import Nuke
import Photos
import RealmSwift

class FileMenu: UITableViewController {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var name: UILabel!
    
    @IBOutlet weak var offlineSwitch: UISwitch!
    
    @IBOutlet weak var shareCell: UITableViewCell!
    @IBOutlet weak var offlineCell: UITableViewCell!
    @IBOutlet weak var copyCell: UITableViewCell!
    @IBOutlet weak var moveCell: UITableViewCell!
    @IBOutlet weak var cancelDownloadCell: UITableViewCell!
    @IBOutlet weak var renameCell: UITableViewCell!
    @IBOutlet weak var redirectCell: UITableViewCell!
    
    
    @IBOutlet var icons: [UIImageView]!
    @IBOutlet var labels: [UILabel]!
    
    var file: FileRealm!
    var url: URL!
    var selectionProvider: SelectionProvider!
    var viewPresenter: ViewPresenter!
    var modeProvider: ModeProvider!
    var delegate: MenuDelegate!
    var realm: Realm?
    weak var root: FileRealm?
    
    private var imageRequestId: PHImageRequestID?
    private var nukeTask: ImageTask?
    
    var actionPerformed = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let selectedFile = selectionProvider.selectedFile else {
            self.dismiss(animated: true, completion: nil)
            return
        }
        file = selectedFile
        url = FileTool.syncDirectory.appendingPathComponent(file.path!)
        name.text = file.name
        if !FileTool.isImageFile(file.name!) ||
            file.size > Const.maxSizeForPreview || 
            file.hashsum == nil && file.localIdentifier == nil {
            icon.image = FileTool.getIcon(forFile: file)
        } else {
            if file.hashsum == nil {
                imageRequestId = icon.loadWithLocalIdentifier(
                    file.localIdentifier!, completion: { [weak self] err in
                        guard let strongSelf = self else { return }
                        if err != nil {
                            strongSelf.icon.image = FileTool.getIcon(
                                forFile: strongSelf.file)
                        }
                })
            } else {
                let url = FileTool.syncDirectory.appendingPathComponent(file.path!)
                let request = ImageRequest(
                    url: url)
                nukeTask = Nuke.loadImage(
                    with: request, into: icon, completion: { [weak self] res, err in
                        guard let strongSelf = self else { return }
                        if err != nil {
                            strongSelf.icon.image = FileTool.getIcon(
                                forFile: strongSelf.file)
                        }
                })
            }
        }
        
        offlineSwitch.isOn = file.isOffline || file.isDownload && !file.isOnlyDownload
        tableView.delegate = self
        
        setActionsEnabled(!PvtboxService.isProcessingOperation())
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !actionPerformed {
            delegate.menuDelegateDismiss()
        }
        if imageRequestId != nil {
            PHImageManager.default().cancelImageRequest(imageRequestId!)
            imageRequestId = nil
        }
        nukeTask?.cancel()
        nukeTask = nil
    }
    
    private func setActionsEnabled(_ enabled: Bool) {
        for icon in icons {
            if #available(iOS 13.0, *) {
                icon.tintColor = enabled ? .secondaryLabel : .quaternaryLabel
            } else {
                icon.tintColor = enabled ? .darkGray : .lightGray
            }
        }
        for label in labels {
            if #available(iOS 13.0, *) {
                label.textColor = enabled ? .label : .quaternaryLabel
            } else {
                label.textColor = enabled ? .darkText : .lightGray
            }
        }
        Timer.scheduledTimer(
            withTimeInterval: 1.0, repeats: false, block: { [weak self] timer in
                timer.invalidate()
                self?.setActionsEnabled(!PvtboxService.isProcessingOperation())
        })
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.item == 0 {
            return
        } else if indexPath.item == 1 {
            self.dismiss(animated: true, completion: nil)
            let docController = UIDocumentInteractionController(url: url)
            viewPresenter.presentDocumentMenu(docController)
            return
        } else if indexPath.item == 9 {
            self.dismiss(animated: true, completion: nil)
            let propertiesVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "propertiesVC") as! PropertiesVC
            propertiesVC.file = file
            self.viewPresenter.presentWithNavigation(propertiesVC)
            return
        }
        
        actionPerformed = true
        
        let isProcessingOperation = PvtboxService.isProcessingOperation()
        if isProcessingOperation {
            self.view.window?.hideAllToasts()
            self.view.window?.makeToast(Strings.actionDisabled)
            return
        }
        
        var delayDismiss = false
        
        switch indexPath.item {
        case 2:
            if file.isFolder {
                let menu = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                    withIdentifier: "shareMenu") as! ShareMenu
                menu.file = file
                menu.delegate = delegate
                menu.viewPresenter = viewPresenter
                let bottomSheet = MDCBottomSheetController(contentViewController: menu)
                dismiss(animated: true, completion: nil)
                viewPresenter.present(bottomSheet)
            } else {
                let getLink = UIStoryboard(name: "Main", bundle: nil)
                    .instantiateViewController(withIdentifier: "getlinkvc") as! GetLinkVC
                dismiss(animated: true, completion: nil)
                getLink.file = file
                delegate.menuDelegateDismiss()
                viewPresenter.presentWithNavigation(getLink)
            }
        case 3:
            if offlineSwitch.isOn {
                delegate.menuDelegateRemoveOffline()
            } else {
                delegate.menuDelegateAddOffline()
            }
            offlineSwitch.setOn(!offlineSwitch.isOn, animated: true)
            delayDismiss = true
        case 4:
            delegate.menuDelegateCopy()
        case 5:
            delegate.menuDelegateMove()
        case 6:
            delegate.menuDelegateCancelDownload()
        case 7:
            let dialog = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "inputDialog") as! InputDialog
            guard let file = selectionProvider.selectedFile else { break }
            dialog.setup(
                type: .rename,
                text: file.name!,
                realm: realm, root: root,
                onConfirmedInput: delegate?.menuDelegateRename,
                onCancelled: delegate?.menuDelegateDismiss)
            self.dismiss(animated: true, completion: nil)
            self.viewPresenter.present(dialog)
            return
        case 8:
            guard let file = selectionProvider.selectedFile else { break }
            let dialog = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "alertDialog") as! AlertDialog
            dialog.setup(
                type: .delete,
                title: nil,
                message: String(
                    format: "%@ %@ \"%@\" %@?",
                    Strings.deleteQuestion,
                    file.isFolder ? Strings.folder : Strings.file,
                    file.name!,
                    Strings.fromAllYourDevices),
                delegate: delegate)
            self.dismiss(animated: true, completion: nil)
            self.viewPresenter.present(dialog)
            return
        default:
            return
        }
        
        if delayDismiss {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.2,
                execute: { [weak self] in self?.dismiss(animated: true, completion: nil) })
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    override func tableView(
        _ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.item {
        case 1: /*redirect*/
            return file.isFolder || !FileTool.exists(url) ? 0 :
                super.tableView(tableView, heightForRowAt: indexPath)
        case 2, 3, 7: /*share, create offline, rename*/
            return modeProvider.viewMode == .downloads ? 0 :
                super.tableView(tableView, heightForRowAt: indexPath)
        case 4,5: /*copy, move*/
            return modeProvider.viewMode == .downloads ||
                modeProvider.viewMode == .recent ? 0 :
                    super.tableView(tableView, heightForRowAt: indexPath)
        case 6: /*cancel downloads*/
            return modeProvider.viewMode != .downloads ? 0 :
            super.tableView(tableView, heightForRowAt: indexPath)
        default:
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
}
