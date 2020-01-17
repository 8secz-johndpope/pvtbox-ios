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

class SendFileDocumentPickerDelegate: NSObject, UIDocumentPickerDelegate,
        UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let delegate: MenuDelegate?
    
    init(_ delegate: MenuDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]) {
        delegate?.menuDelegateSendFile(at: urls)
        controller.dismiss(animated: true, completion: nil)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        UIApplication.shared.keyWindow?.makeToast(Strings.actionCancelled)
        controller.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        delegate?.menuDelegateSendPhoto(info: info)
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        UIApplication.shared.keyWindow?.makeToast(Strings.actionCancelled)
        picker.dismiss(animated: true, completion: nil)
    }
}
