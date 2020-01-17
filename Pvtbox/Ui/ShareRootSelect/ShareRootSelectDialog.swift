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
import MaterialComponents

class ShareRootSelectDialog: UIViewController {
    @IBOutlet weak var containerView: UINavigationController?
    
    private var controller = MDCDialogTransitionController()
    
    private var shareUrl: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func setup(url: URL) {
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self.controller
        shareUrl = url
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        if let vc = segue.destination as? UINavigationController {
            containerView = vc
        }
    }
    
    @IBAction func okClicked(_ sender: Any) {
        guard let vc = containerView?.topViewController as? ShareRootSelectVC else { return }
        let root = vc.root
        BFLog("ShareRootSelectDialog::okClicked: selected root: %@",
              root?.name ?? Strings.allFiles)
        PvtboxService.downloadShare(
            shareUrl, to: root == nil ? nil : FileRealm(value: root!))
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func cancelClicked(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
}
