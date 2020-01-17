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

class FilesMenu: UITableViewController, UIPopoverPresentationControllerDelegate {
    
    @IBOutlet var icons: [UIImageView]!
    @IBOutlet var labels: [UILabel]!
    @IBOutlet weak var offlineSwitch: UISwitch!
    @IBOutlet weak var offlineLabel: UILabel!
    @IBOutlet weak var offlineIcon: UIImageView!
    
    @IBOutlet weak var offlineCell: UITableViewCell!
    @IBOutlet weak var copyCell: UITableViewCell!
    @IBOutlet weak var moveCell: UITableViewCell!
    @IBOutlet weak var cancelDownloadCell: UITableViewCell!
    
    var modeProvider: ModeProvider!
    var selectionProvider: SelectionProvider!
    var selectionController: SelectionController!
    var viewPresenter: ViewPresenter!
    var delegate: MenuDelegate!
    
    private var offlineInaprioriate = false
    private var hiddenRows = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        switch modeProvider.viewMode {
        case .recent, .downloads:
            hiddenRows = 3
        default:
            hiddenRows = 1
        }
        update()
    }
    
    private func update() {
        setActionsEnabled(selectionProvider.selectedCount > 0
            && !PvtboxService.isProcessingOperation()
        )
        let selectedFiles = selectionProvider.selectedFiles
        var offlinesCount = 0
        for file in selectedFiles {
            if file.isOffline || file.isDownload && !file.isOnlyDownload {
                offlinesCount += 1
            } else if offlinesCount > 0 {
                break
            }
        }
        if offlinesCount != 0 && offlinesCount != selectedFiles.count {
            offlineIcon.tintColor = .lightGray
            offlineLabel.textColor = .lightGray
            offlineInaprioriate = true
            offlineSwitch.isOn = false
        } else{
            offlineSwitch.isOn = offlinesCount != 0
        }
        Timer.scheduledTimer(
            withTimeInterval: 1.0, repeats: false, block: { [weak self] timer in
                timer.invalidate()
                self?.update()
        })
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.sizeToFit()
        var size = self.tableView.contentSize
        let rowsCount = tableView.numberOfRows(inSection: 0)
        let rowHeigth = size.height / CGFloat(rowsCount)
        size.height = CGFloat(rowsCount - hiddenRows) * rowHeigth
        size.width = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        self.preferredContentSize = size
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
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.item == 0 {
            selectionController.selectAll()
            update()
            return
        } else if indexPath.item == 1 {
            selectionController.dropSelection()
            self.dismiss(animated: true, completion: nil)
            return
        }
        if selectionProvider.selectedCount == 0 {
            self.view.window?.hideAllToasts()
            self.view.window?.makeToast(Strings.nothingSelected)
            return
        }
        
        let isProcessingOperation = PvtboxService.isProcessingOperation()
        if isProcessingOperation {
            self.view.window?.hideAllToasts()
            self.view.window?.makeToast(Strings.actionDisabled)
            return
        }
        
        var delayDismiss = false
        
        switch indexPath.item {
        case 2:
            if offlineInaprioriate {
                self.view.window?.hideAllToasts()
                self.view.window?.makeToast(Strings.noAppropriateOfflineState)
                return
            }
            if offlineSwitch.isOn {
                delegate.menuDelegateRemoveOffline()
            } else {
                delegate.menuDelegateAddOffline()
            }
            offlineSwitch.setOn(!offlineSwitch.isOn, animated: true)
            delayDismiss = true
        case 3:
            delegate.menuDelegateCopy()
        case 4:
            delegate.menuDelegateMove()
        case 5:
            delegate.menuDelegateCancelDownload()
        case 6:
            let dialog = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
                withIdentifier: "alertDialog") as! AlertDialog
            dialog.setup(
                type: .delete,
                title: nil,
                message: String(
                    format: "%@ %d %@ %@?",
                    Strings.deleteQuestion,
                    selectionProvider.selectedCount,
                    Strings.objects,
                    Strings.fromAllYourDevices),
                delegate: delegate)
            self.dismiss(animated: true, completion: nil)
            self.viewPresenter.present(dialog)
            return
        default:
            break
        }
        if delayDismiss {
            DispatchQueue.main.asyncAfter(
                deadline: .now() + 0.2,
                execute: { [weak self] in self?.dismiss(animated: true, completion: nil) })
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.item {
        case 2: /*offline copy*/
            return modeProvider.viewMode == .downloads ? 0 :
                super.tableView(tableView, heightForRowAt: indexPath)
        case 3, 4: /*copy, move*/
            return modeProvider.viewMode == .downloads ||
                modeProvider.viewMode == .recent ? 0 :
                    super.tableView(tableView, heightForRowAt: indexPath)
        case 5: /*cancel downloads*/
            return modeProvider.viewMode != .downloads ? 0 :
                super.tableView(tableView, heightForRowAt: indexPath)
        default:
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }
}
