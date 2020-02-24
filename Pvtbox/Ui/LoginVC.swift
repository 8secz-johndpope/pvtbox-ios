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
import DLRadioButton
import IQKeyboardManagerSwift
import HS_Google_Material_Design_Icons
import JASON

class LoginVC: UIViewController, UITextFieldDelegate, UIDocumentInteractionControllerDelegate {
    
    @IBOutlet weak var email: MDCTextField!
    @IBOutlet weak var password: MDCTextField!
    @IBOutlet weak var acceptRulesView: UIView!
    @IBOutlet weak var acceptRulesRulesButton: UIButton!
    @IBOutlet weak var acceptRulesPrivacyPolicyButton: UIButton!
    @IBOutlet weak var remindPasswordButton: UIButton!
    @IBOutlet weak var actionButton: UIButton!
    @IBOutlet weak var selfHostedButton: UIButton!
    @IBOutlet weak var selfHosted: MDCTextField!

    
    var emailController: MDCTextInputControllerLegacyDefault!
    var passwordController: MDCTextInputControllerLegacyDefault!
    var selfHostedController: MDCTextInputControllerLegacyDefault!
    
    var timer: Timer?

    override func viewDidLoad() {
        super.viewDidLoad()

        let mailIcon = UILabel()
        mailIcon.GMDIcon = .gmdMail
        mailIcon.textColor = .white
        mailIcon.sizeToFit()
        mailIcon.frame.size.width = 24
        
        let passwordIcon = UILabel()
        passwordIcon.GMDIcon = .gmdLock
        passwordIcon.textColor = .white
        passwordIcon.sizeToFit()
        passwordIcon.frame.size.width = 24
        
        let hostIcon = UILabel()
        hostIcon.GMDIcon = .gmdLanguage
        hostIcon.textColor = .white
        hostIcon.sizeToFit()
        hostIcon.frame.size.width = 24
        
        emailController = MDCTextInputControllerLegacyDefault(textInput: email)
        emailController.activeColor = .orange
        emailController.inlinePlaceholderColor = .white
        emailController.textInputClearButtonTintColor = .white
        emailController.floatingPlaceholderNormalColor = .white
        emailController.floatingPlaceholderActiveColor = .orange
        emailController.textInput?.textColor = .white
        emailController.textInputFont = .systemFont(ofSize: 20)
        emailController.inlinePlaceholderFont = .systemFont(ofSize: 20)
        email.leftViewMode = .always
        email.leftView = mailIcon
        
        passwordController = MDCTextInputControllerLegacyDefault(textInput: password)
        passwordController.activeColor = .orange
        passwordController.inlinePlaceholderColor = .white
        passwordController.textInputClearButtonTintColor = .white
        passwordController.floatingPlaceholderNormalColor = .white
        passwordController.floatingPlaceholderActiveColor = .orange
        passwordController.textInput?.textColor = .white
        passwordController.textInputFont = .systemFont(ofSize: 20)
        passwordController.inlinePlaceholderFont = .systemFont(ofSize: 20)
        password.leftViewMode = .always
        password.leftView = passwordIcon
        
        selfHostedController = MDCTextInputControllerLegacyDefault(textInput: selfHosted)
        selfHostedController.activeColor = .orange
        selfHostedController.inlinePlaceholderColor = .white
        selfHostedController.textInputClearButtonTintColor = .white
        selfHostedController.floatingPlaceholderNormalColor = .white
        selfHostedController.floatingPlaceholderActiveColor = .orange
        selfHostedController.textInput?.textColor = .white
        selfHostedController.textInputFont = .systemFont(ofSize: 16)
        selfHostedController.inlinePlaceholderFont = .systemFont(ofSize: 16)
        selfHosted.leftViewMode = .always
        selfHosted.leftView = hostIcon
        
        if PreferenceService.isSelfHosted {
            selfHosted.isHidden = false
            selfHosted.text = PreferenceService.host
            selfHostedButton.setTitle(Strings.regularUser, for: .normal)
        } else {
            selfHosted.isHidden = true
            selfHostedButton.setTitle(Strings.selfHostedUser, for: .normal)
        }
            
        email.text = PreferenceService.email
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        IQKeyboardManager.shared.enable = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = false
        timer?.invalidate()
    }

    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    @IBAction private func onSelfHostedButtonClick() {
        if selfHosted.isHidden {
            selfHosted.isHidden = false
            selfHostedButton.setTitle(Strings.regularUser, for: .normal)
        } else {
            selfHosted.isHidden = true
            selfHostedButton.setTitle(Strings.selfHostedUser, for: .normal)
        }
    }
    
    @IBAction private func onAcceptRulesRulesButtonClick() {
        let url = Bundle.main.url(forResource: "terms", withExtension: "rtf")!
        let docController = UIDocumentInteractionController(url: url)
        docController.name = Strings.rules
        docController.delegate = self
        docController.presentPreview(animated: true)
    }
    
    @IBAction private func onAcceptRulesPrivacyPolicyButtonClick() {
        let url = Bundle.main.url(forResource: "privacy", withExtension: "rtf")!
        let docController = UIDocumentInteractionController(url: url)
        docController.name = Strings.privacyPolicy
        docController.delegate = self
        docController.presentPreview(animated: true)
    }
    
    @IBAction private func onRemindPasswordClick() {
        emailController?.setErrorText(nil, errorAccessibilityValue: nil)
        guard let emailText = email.text?.trimmingCharacters(in: .whitespaces),
            !emailText.isEmpty else {
                emailController?.setErrorText(Strings.emailEmpty, errorAccessibilityValue: nil)
                return
        }
        if !EmailValidator.isValid(emailText) {
            emailController?.setErrorText(Strings.emailWrong, errorAccessibilityValue: nil)
            return
        }
        if var host = selfHosted.isHidden ? nil : selfHosted.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !host.isEmpty {
            if !host.starts(with: "https://") {
                host = "https://" + host
            }
            PreferenceService.host = host
        } else {
            PreferenceService.host = Const.serverAddress
        }
        
        UIApplication.shared.beginIgnoringInteractionEvents()
        actionButton.setTitle(Strings.pleaseWait, for: .normal)
        actionButton.backgroundColor = UIColor.orange.withAlphaComponent(0.5)
        HttpClient.shared.remindPassword(
            email: emailText,
            onSuccess: { response in
                DispatchQueue.main.async {
                    self.onActionDone(response["info"].string ?? "Network Error", response)
                }
            },
            onError: { error in
                DispatchQueue.main.async {
                    self.onActionDone(error == nil ? "Network Error" :
                        (error!["info"].string ?? "Network Error"), error)
                }
            })
    }
    
    @IBAction private func onActionButtonClick() {
        UIApplication.shared.beginIgnoringInteractionEvents()
        
        let (isValid, email, password, host) = validate()
        if var host = host, !host.isEmpty {
            if !host.starts(with: "https://") {
                host = "https://" + host
            }
            PreferenceService.host = host
        } else {
            PreferenceService.host = Const.serverAddress
        }
        if email != nil {
            PreferenceService.email = email
        }
        if !isValid {
            UIApplication.shared.endIgnoringInteractionEvents()
            return
        }
        actionButton.setTitle(Strings.pleaseWait, for: .normal)
        actionButton.backgroundColor = UIColor.orange.withAlphaComponent(0.5)
        
        HttpClient.shared.login(
            email: email!, password: password!,
            onSuccess: onLoggedIn, onError: onError)
    
    }
    
    private func onLoggedIn(_ response: JSON) {
        var wipeNeeded = false
        if PreferenceService.currentHost != PreferenceService.host {
            PreferenceService.currentHost = PreferenceService.host
            PreferenceService.isSelfHosted = PreferenceService.host != Const.serverAddress
            wipeNeeded = true
        }
        let userHash = response["user_hash"].string
        if PreferenceService.userHash != userHash || wipeNeeded {
            PvtboxService.wipe()
        }
        PreferenceService.userHash = userHash
        PreferenceService.isLoggedIn = true
        DispatchQueue.main.async {
            let mainVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "mainvc") as! MainVC
            UIApplication.shared.keyWindow?.rootViewController = mainVC
            PvtboxService.start(withLoginData: response)
            UIApplication.shared.endIgnoringInteractionEvents()
        }
    }
    
    private func onError(_ response: JSON?) {
        if let remoteActions = response?["remote_actions"].jsonArray,
            !remoteActions.isEmpty {
            for action in remoteActions {
                PvtboxService.handleRemoteAction(action)
            }
        }
        DispatchQueue.main.async {
            self.onActionDone(response == nil ? "Network Error" :
                (response!["info"].string ?? "Network Error"), response)
        }
    }
    
    private func onActionDone(_ errorText: String?, _ response: JSON?) {
        actionButton.setTitle(Strings.signIn, for: .normal)
        actionButton.backgroundColor = UIColor.orange.withAlphaComponent(1)
        UIApplication.shared.endIgnoringInteractionEvents()
        timer?.invalidate()
        if let res = response,
            let errcode = res["errcode"].string,
            let data = res["data"].jsonDictionary,
            errcode == "LOCKED_CAUSE_TOO_MANY_BAD_LOGIN",
            let lockSeconds = data["bl_lock_seconds"]?.int,
            let current = data["bl_current_timestamp"]?.int,
            let last = data["bl_last_timestamp"]?.int {
            var interval = lockSeconds - current + last
            SnackBarManager.showSnack(
                String(format: Strings.ipBlockedTemplate, interval),
                showNew: false, showForever: false)
            timer = Timer.scheduledTimer(
                withTimeInterval: 1, repeats: true, block: { timer in
                    interval -= 1
                    if interval <= 0 {
                        timer.invalidate()
                        SnackBarManager.showSnack(
                            Strings.ipUnlocked, showNew: false, showForever: false)
                        return
                    }
                    SnackBarManager.showSnack(
                        String(format: Strings.ipBlockedTemplate, interval),
                        showNew: false, showForever: false)
            })
        } else if errorText != nil {
                SnackBarManager.showSnack(errorText!)
        }
    }
    
    private func validate() -> (Bool, String?, String?, String?) {
        emailController?.setErrorText(nil, errorAccessibilityValue: nil)
        passwordController?.setErrorText(nil, errorAccessibilityValue: nil)
        selfHostedController.setErrorText(nil, errorAccessibilityValue: nil)
        
        var valid = true
        
        var host = selfHosted.isHidden ? nil : selfHosted.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if host?.isEmpty ?? true {
            host = nil
        }
        
        if !selfHosted.isHidden && host == nil {
            valid = false
            selfHostedController?.setErrorText(Strings.hostEmpty, errorAccessibilityValue: nil)
        }
        
        guard let emailText = email.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !emailText.isEmpty else {
            emailController?.setErrorText(Strings.emailEmpty, errorAccessibilityValue: nil)
            return (false, nil, nil, host)
        }
        if !EmailValidator.isValid(emailText) {
            emailController?.setErrorText(Strings.emailWrong, errorAccessibilityValue: nil)
            return (false, nil, nil, host)
        }
        
        guard let passwordText = password.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !passwordText.isEmpty else {
            passwordController?.setErrorText(Strings.passwordEmpty, errorAccessibilityValue: nil)
            return (false, emailText, nil, host)
        }
        if passwordText.count < 6 {
            passwordController?.setErrorText(Strings.passwordShort, errorAccessibilityValue: nil)
            return (false, emailText, nil, host)
        }
        
        return (valid, emailText, passwordText, host)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case email:
            password.becomeFirstResponder()
        case password:
            self.view.endEditing(true)
        default:
            textField.resignFirstResponder()
        }
        return false
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let icon = textField.leftView as? UILabel {
            icon.textColor = .orange
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let icon = textField.leftView as? UILabel {
            icon.textColor = .lightGray
        }
    }
}
