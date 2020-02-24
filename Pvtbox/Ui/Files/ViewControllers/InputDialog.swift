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
import RealmSwift

class InputDialog: UIViewController {

    enum DialogType {
        case rename
        case createFolder
        case insertLink
        case requestSharePassword
    }
    
    private var dialogType: DialogType!
    private var controller = MDCDialogTransitionController()
    private var inputController: MDCTextInputControllerLegacyDefault!
    
    private var text: String?
    private var shareHash: String?
    
    private var actionPerformed = false
    
    private var onConfirmedInput: ((String) -> ())?
    private var onCancelled: (() -> ())?
    private var realm: Realm?
    private weak var root: FileRealm?
    
    @IBOutlet weak var header: UILabel!
    @IBOutlet weak var input: MDCTextField!
    @IBOutlet weak var inputMultiline: UITextView!
    
    func setup(type: DialogType, text: String?,
               realm: Realm?, root: FileRealm?,
               onConfirmedInput: ((String) -> ())?,
               onCancelled: (() -> ())?) {
        self.dialogType = type
        self.text = text
        
        self.realm = realm
        self.root = root
        self.onConfirmedInput = onConfirmedInput
        self.onCancelled = onCancelled
        
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self.controller
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.layer.cornerRadius = 4
        inputController = MDCTextInputControllerLegacyDefault(textInput: input)
        inputController.activeColor = .orange
        inputController.floatingPlaceholderActiveColor = .orange
        inputController.textInputFont = .systemFont(ofSize: 20)
        inputController.inlinePlaceholderFont = .systemFont(ofSize: 20)
        if #available(iOS 13.0, *) {
            inputController.textInputClearButtonTintColor = .label
            inputController.inlinePlaceholderColor = .quaternaryLabel
            input.textColor = .label
        }
        inputMultiline.isHidden = true
        input.isUserInteractionEnabled = true
        input.isSecureTextEntry = false
        switch self.dialogType! {
        case .rename:
            header.text = Strings.rename
            input.text = self.text
            input.placeholder = Strings.renamePlaceholder
        case .createFolder:
            header.text = Strings.newFolder
            input.placeholder = Strings.newFolderPlaceholder
        case .insertLink:
            header.text = Strings.insertLink
            input.placeholder = nil
            input.isUserInteractionEnabled = false
            inputMultiline.isHidden = false
            inputMultiline.text = UIPasteboard.general.url?.absoluteString
        case .requestSharePassword:
            header.text = Strings.insertLink
            input.placeholder = Strings.enterPassword
            input.text = nil
            input.isSecureTextEntry = true
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.view.sizeToFit()
        preferredContentSize = CGSize(
            width: max(UIScreen.main.bounds.width, UIScreen.main.bounds.height),
            height: 210)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let _ = dialogType == .insertLink ?
            inputMultiline.becomeFirstResponder() : input.becomeFirstResponder()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if !actionPerformed && dialogType == .rename {
            onCancelled?()
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
        let text = (dialogType == .insertLink ?
            inputMultiline.text : input.text)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let error = checkInput(text, realm: realm)
        
        if error == nil {
            if dialogType == .insertLink {
                shareHash = URL(string: text!)!.lastPathComponent
                let url = String(
                    format: "%@/ws/webshare/%@",
                    HttpClient.shared.signalServerAddress!.replacingOccurrences(
                        of: "wss://", with: "https://"),
                    shareHash!)
                HttpClient.shared.checkSharePassword(
                    url: url,
                    onSuccess: { [weak self] in
                        DispatchQueue.main.async { [weak self] in
                            self?.actionPerformed = true
                            self?.onConfirmedInput?(url)
                            self?.dismiss(animated: true, completion: nil)
                        }},
                    onWrongPassword: { [weak self] in
                        DispatchQueue.main.async { [weak self] in
                            self?.input.placeholder = Strings.enterPassword
                            self?.input.isSecureTextEntry = true
                            self?.input.text = nil
                            self?.dialogType = .requestSharePassword
                            self?.inputMultiline.isHidden = true
                            self?.input.isUserInteractionEnabled = true
                            self?.input.becomeFirstResponder()
                        }},
                    onLocked: { [weak self] in
                        DispatchQueue.main.async { [weak self] in
                            self?.view?.window?.makeToast(
                                Strings.lockedAfterTooManyIncorrectAttempts)
                            self?.dismiss(animated: true, completion: nil)
                        }},
                    onError: { [weak self] err in
                        DispatchQueue.main.async { [weak self] in
                            self?.view?.window?.makeToast(
                                Strings.errorProcessingLink)
                            self?.dismiss(animated: true, completion: nil)
                        }})
                return
            } else if dialogType == .requestSharePassword {
                let url = String(
                    format: "%@/ws/webshare/%@?passwd=%@",
                    HttpClient.shared.signalServerAddress!.replacingOccurrences(
                        of: "wss://", with: "https://"),
                    shareHash!, base64(fromString: text!))
                HttpClient.shared.checkSharePassword(
                    url: url,
                    onSuccess: { [weak self] in
                        DispatchQueue.main.async { [weak self] in
                            self?.actionPerformed = true
                            self?.onConfirmedInput?(url)
                            self?.dismiss(animated: true, completion: nil)
                        }},
                    onWrongPassword: { [weak self] in
                        DispatchQueue.main.async { [weak self] in
                            self?.inputController.setErrorText(
                                Strings.wrongPassword, errorAccessibilityValue: nil)
                        }},
                    onLocked: { [weak self] in
                        DispatchQueue.main.async { [weak self] in
                            self?.view?.window?.makeToast(
                                Strings.lockedAfterTooManyIncorrectAttempts)
                            self?.dismiss(animated: true, completion: nil)
                        }},
                    onError: { [weak self] _ in
                        DispatchQueue.main.async { [weak self] in
                            self?.view?.window?.makeToast(
                                Strings.errorProcessingLink)
                            self?.dismiss(animated: true, completion: nil)
                        }})
                return
            }
            actionPerformed = true
            onConfirmedInput?(text!)
            self.dismiss(animated: true, completion: nil)
        } else {
            inputController.setErrorText(error, errorAccessibilityValue: nil)
        }
    }
    
    private func checkInput(_ input: String?, realm: Realm?) -> String? {
        guard let input = input, !input.isEmpty else {
            return dialogType == .insertLink ? Strings.linkEmpty :
                dialogType == .requestSharePassword ? Strings.passwordEmpty :
                Strings.nameEmpty
        }
        if dialogType == .insertLink {
            guard let url = URL(string: input),
                ["https", "http"].contains(url.scheme),
                let host = url.host,
                let ownUrl = URL(string: PreferenceService.host),
                let ownHost = ownUrl.host,
                host.lowercased() == ownHost.lowercased(),
                url.pathComponents.count == 3,
                url.lastPathComponent.count == 32 else {
                return Strings.linkInvalid
            }
            return nil
        } else if dialogType == .requestSharePassword {
            if input.count > 32 {
                return Strings.passwordBig
            }
            return nil
        }
        var conflicts = realm?.objects(FileRealm.self)
            .filter("name = %@", input)
        if root == nil {
            conflicts = conflicts?.filter("parentUuid = nil")
        } else {
            conflicts = conflicts?.filter("parentUuid = %@", root!.uuid!)
        }
        if !(conflicts?.isEmpty ?? true) {
            if conflicts?.first?.isFolder ?? true {
                return Strings.folderAlreadyExists
            } else {
                return Strings.fileAlreadyExists
            }
        }
        return nil
    }
}
