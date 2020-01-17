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

class MainMenu: UITableViewController, UIPopoverPresentationControllerDelegate {
    
    @IBOutlet weak var sortByNameCell: UITableViewCell!
    @IBOutlet weak var sortByDateCell: UITableViewCell!
    
    var sortingChangeListener: SortingChangeListener!
    var modeProvider: ModeProvider!
    var selectionController: SelectionController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if PreferenceService.sortingByName {
            sortByNameCell.accessoryType = .checkmark
            sortByDateCell.accessoryType = .none
        } else {
            sortByNameCell.accessoryType = .none
            sortByDateCell.accessoryType = .checkmark
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.sizeToFit()
        var size = self.tableView.contentSize
        switch modeProvider.viewMode {
        case .recent, .downloads:
            sortByDateCell.isHidden = true
            sortByNameCell.isHidden = true
            let rowsCount = tableView.numberOfRows(inSection: 0)
            let rowHeigth = size.height / CGFloat(rowsCount)
            size.height = CGFloat(rowsCount - 2) * rowHeigth
        default:
            break
        }
        size.width -= 120
        
        self.preferredContentSize = size
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.item {
        case 0:
            PreferenceService.sortingByName = true
            sortByNameCell.accessoryType = .checkmark
            sortByDateCell.accessoryType = .none
            sortingChangeListener.sortingChanged()
        case 1:
            PreferenceService.sortingByName = false
            sortByNameCell.accessoryType = .none
            sortByDateCell.accessoryType = .checkmark
            sortingChangeListener.sortingChanged()
        case 2:
            selectionController.startSelection()
        default:
            break
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let view = tableView.cellForRow(at: indexPath), view.isHidden else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
        return 0
    }
}
