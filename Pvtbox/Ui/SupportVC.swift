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
import JASON
import IQKeyboardManagerSwift

class SupportVC: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate, UIPopoverPresentationControllerDelegate {
    public var enableIQKeyboard = true
    private static let displaySubjects = ["---Select Subject---", "Technical Question", "Other Questions", "Feedback"]
    private static let subjects = ["", "TECHNICAL", "OTHER", "FEEDBACK"]
    
    @IBOutlet weak var sendBarItem: UIBarButtonItem!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var textField: UITextView!
    @IBOutlet weak var subjectPicker: UIPickerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = sendBarItem
        setup(active: true)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        IQKeyboardManager.shared.enable = enableIQKeyboard
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        IQKeyboardManager.shared.enable = false
    }
    
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
    
    private func setup(active: Bool) {
        sendButton.backgroundColor = UIColor.orange.withAlphaComponent(active ? 1 : 0.5)
        sendBarItem.tintColor = UIColor.orange.withAlphaComponent(active ? 1 : 0.5)
        sendButton.setTitle(active ? Strings.send : Strings.sending, for: .normal)
        view.isUserInteractionEnabled = active
    }

    @IBAction func sendAction(_ sender: Any) {
        BFLog("SupportVC::sendAction")
        view.endEditing(true)
        let subject = subjectPicker.selectedRow(inComponent: 0)
        if subject == 0 {
            view.window?.hideAllToasts()
            view.window?.makeToast(Strings.pleaseSelectSubject)
            return
        }
        let text = textField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            view.window?.hideAllToasts()
            view.window?.makeToast(Strings.messageEmpty)
            return
        }
        setup(active: false)
        HttpClient.shared.support(
            text: text, subject: SupportVC.subjects[subject],
            onSuccess: sentSuccessfully, onError: onError)
    }
    
    private func sentSuccessfully(_ json: JSON) {
        guard let result = json["result"].string,
            result == "success" else {
            onError(json)
            return
        }
        SnackBarManager.showSnack(Strings.messageSent)
        DispatchQueue.main.async {
            self.dismiss(animated: true, completion: nil)
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    private func onError(_ json: JSON?) {
        SnackBarManager.showSnack(Strings.messageSendError)
        DispatchQueue.main.async {
            self.setup(active: true)
        }
    }
    
    func numberOfComponents(in: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_: UIPickerView, numberOfRowsInComponent: Int) -> Int {
        return SupportVC.displaySubjects.count
    }
    
    func pickerView(
        _: UIPickerView, viewForRow row: Int, forComponent: Int,
        reusing view: UIView?) -> UIView {
        var pickerLabel: UILabel? = (view as? UILabel)
        if pickerLabel == nil {
            pickerLabel = UILabel()
            pickerLabel?.font = .systemFont(ofSize: 20)
            pickerLabel?.textAlignment = .center
            if #available(iOS 13.0, *) {
                pickerLabel?.textColor = .label
            } else {
                pickerLabel?.textColor = .black
            }
        }
        pickerLabel?.text = SupportVC.displaySubjects[row]
        
        return pickerLabel!
    }
    
}
