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

class AlertDialog: UIViewController {
    
    enum DialogType {
        case delete
    }
    
    private var dialogType: DialogType!
    private var controller = MDCDialogTransitionController()
    
    private var actionPerformed = false
    
    private var delegate: MenuDelegate!
    
    @IBOutlet weak var header: UILabel!
    @IBOutlet weak var message: UILabel!
    
    private var titleText: String?
    private var messageText: String?
    
    func setup(type: DialogType, title: String?, message: String?, delegate: MenuDelegate) {
        self.dialogType = type
        
        self.titleText = title
        self.messageText = message
        
        self.delegate = delegate
        
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self.controller
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.layer.cornerRadius = 4
        self.header.text = titleText
        self.message.text = messageText
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.sizeToFit()
        preferredContentSize = CGSize(
            width: max(UIScreen.main.bounds.width, UIScreen.main.bounds.height),
            height: 180)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !actionPerformed {
            delegate.menuDelegateDismiss()
        }
    }
    
    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    @IBAction func OnCancel(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onOk(_ sender: Any) {
        actionPerformed = true
        self.delegate.menuDelegateDelete()
        self.dismiss(animated: true, completion: nil)
    }
}
