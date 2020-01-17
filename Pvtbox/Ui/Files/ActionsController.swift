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

class ActionsController: ActionsDelegate, ActionsProvider {
    private var selectedFiles: [FileRealm] = []
    
    var actionsProviderDelegate: ActionsProviderDelegate?
    var actionsProviderActive: Bool {
        get {
            return actionsProviderCopyActive || actionsProviderMoveActive
        }
        set {
            if !newValue {
                actionsProviderCopyActive = false
                actionsProviderMoveActive = false
            }
        }
    }
    var actionsProviderCopyActive: Bool = false {
        didSet {
            BFLog("actionsProviderCopyActive didSet to: %@", String(describing: actionsProviderCopyActive))
            actionsProviderDelegate?.actionsProviderDelegateActiveChanged(
                self.actionsProviderActive)
        }
    }
    var actionsProviderMoveActive: Bool = false {
        didSet {
            BFLog("actionsProviderMoveActive didSet to: %@", String(describing: actionsProviderMoveActive))
            actionsProviderDelegate?.actionsProviderDelegateActiveChanged(
                self.actionsProviderActive)
        }
    }
    
    init() {
        actionsProviderActive = false
    }
    
    func actionsDelegateCopy(files: [FileRealm]) {
        BFLog("actionsDelegateCopy, files count: %d", files.count)
        selectedFiles = files
        actionsProviderCopyActive = true
    }
    
    func actionsDelegateMove(files: [FileRealm]) {
        BFLog("actionsDelegateMove, files count: %d", files.count)
        selectedFiles = files
        actionsProviderMoveActive = true
    }
    
    func actionsDelegateCancel() {
        BFLog("actionsDelegateCancel")
        selectedFiles = []
        actionsProviderActive = false
    }
    
    func getFilesForAction() -> [FileRealm] {
        return selectedFiles
    }

}
