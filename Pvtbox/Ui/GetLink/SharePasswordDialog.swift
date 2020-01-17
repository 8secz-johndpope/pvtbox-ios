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

class SharePasswordDialog: UIViewController, UIPopoverPresentationControllerDelegate {
    private var inputController: MDCTextInputControllerLegacyDefault!
    @IBOutlet weak var input: MDCTextField!
    
    weak var switchView: UISwitch!
    var file: FileRealm!
    private var actionConfirmed = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.layer.cornerRadius = 4
        inputController = MDCTextInputControllerLegacyDefault(textInput: input)
        inputController.activeColor = .orange
        inputController.floatingPlaceholderActiveColor = .orange
        inputController.textInputFont = .systemFont(ofSize: 20)
        inputController.inlinePlaceholderFont = .systemFont(ofSize: 20)
        inputController.placeholderText = Strings.enterPassword
        if #available(iOS 13.0, *) {
            inputController.inlinePlaceholderColor = .quaternaryLabel
            input.textColor = .label
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.sizeToFit()
        var size = self.view.frame.size
        size.height = 180
        self.preferredContentSize = size
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        input.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !actionConfirmed {
            switchView.isOn = false
        }
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    @IBAction func cancelClicked(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func okClicked(_ sender: Any) {
        actionConfirmed = true
        dismiss(animated: true, completion: nil)
        UIApplication.shared.beginIgnoringInteractionEvents()
        SnackBarManager.showSnack(
            Strings.updatingShare, showNew: true, showForever: true)
        HttpClient.shared.shareEnable(
            uuid: file.uuid!, ttl: file.shareExpire, password: input.text, keepPassword: false,
            onSuccess: { _ in
                DispatchQueue.main.async {
                    UIApplication.shared.endIgnoringInteractionEvents()
                }
                SnackBarManager.showSnack(
                    Strings.updatedShare, showNew: false, showForever: false)
            },
            onError: { [weak self] json in
                DispatchQueue.main.async { [weak self] in
                    self?.switchView.isOn = false
                    UIApplication.shared.endIgnoringInteractionEvents()
                }
                SnackBarManager.showSnack(
                    String(format: "%@:\n%@",
                           Strings.operationError,
                           json?["info"].string ?? Strings.networkError),
                    showNew: false, showForever: false)
        })
    }
}
