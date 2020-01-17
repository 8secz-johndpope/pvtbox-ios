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
import Social
import MobileCoreServices

class ShareViewController: SLComposeServiceViewController {

    private var attachmentsCount = 0
    private let groupUrl = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.pvtbox.net")!
        .appendingPathComponent("share", isDirectory: true)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let groupUrl = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: "group.pvtbox.net")?
            .appendingPathComponent("share", isDirectory: true) {
            try? FileManager.default.createDirectory(
                at: groupUrl, withIntermediateDirectories: true, attributes: nil)
        }
        placeholder = "Tap 'Post' to share"
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.isEditable = false
        textView.isSelectable = false
        view.endEditing(true)
    }

    override func didSelectPost() {
        let extensionItem = extensionContext?.inputItems[0] as! NSExtensionItem
        
        let attachments = extensionItem.attachments ?? []
        
        for attachment in attachments {
            attachmentsCount += 1
            if attachment.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                processText(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                processScreenshot(attachment)
            } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeItem as String) {
                processItem(attachment)
            } else {
                attachmentsCount -= 1
            }
        }
    }
    
    @objc func openURL(_ url: URL) {
        return
    }
    
    func openContainerApp() {
        var responder: UIResponder? = self as UIResponder
        let selector = #selector(openURL(_:))
        while responder != nil {
            if responder!.responds(to: selector) && responder != self {
                responder!.perform(selector, with: URL(string: "pvtbox://share_extension")!)
                return
            }
            responder = responder?.next
        }
    }
    
    private func processText(_ attachment: NSItemProvider) {
        attachment.loadItem(
            forTypeIdentifier: kUTTypeText as String,
            options: nil) { secureCoding, error in
                if let text = secureCoding as? String {
                    var fileName = "note.txt"
                    let fileNameTemplate = "note %d.txt"
                    var i = 0
                    while FileManager.default.fileExists(
                        atPath: self.groupUrl.appendingPathComponent(
                            fileName, isDirectory: false).path) {
                                i += 1
                                fileName = String(format: fileNameTemplate, i)
                    }
                    FileManager.default.createFile(
                        atPath: self.groupUrl.appendingPathComponent(
                            fileName, isDirectory: false).path,
                        contents: text.data(using: .unicode, allowLossyConversion: true),
                        attributes: nil)
                }
                DispatchQueue.main.async { [weak self] in
                    self?.attachmentsCount -= 1
                    if self?.attachmentsCount == 0 {
                        self?.extensionContext?.completeRequest(
                            returningItems: [], completionHandler: { _ in
                                self?.openContainerApp()
                        })
                    }
                }
        }
    }
    
    private func processItem(_ attachment: NSItemProvider) {
        if #available(iOSApplicationExtension 11.0, *) {
            attachment.loadFileRepresentation(
            forTypeIdentifier: kUTTypeItem as String) { url, error in
                if let url = url {
                    let name = url.lastPathComponent
                    let copyUrl = self.groupUrl.appendingPathComponent(
                        name, isDirectory: false)
                    try? FileManager.default.copyItem(at: url, to: copyUrl)
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.attachmentsCount -= 1
                    if self?.attachmentsCount == 0 {
                        self?.openContainerApp()
                        self?.extensionContext?.completeRequest(
                            returningItems: [], completionHandler: nil)
                    }
                }
            }
        } else {
            attachment.loadItem(
                forTypeIdentifier: kUTTypeItem as String,
                options: nil) { url, error in
                if let url = url as? URL {
                    let name = url.lastPathComponent
                    let copyUrl = self.groupUrl.appendingPathComponent(
                        name, isDirectory: false)
                    try? FileManager.default.copyItem(at: url, to: copyUrl)
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.attachmentsCount -= 1
                    if self?.attachmentsCount == 0 {
                        self?.openContainerApp()
                        self?.extensionContext?.completeRequest(
                            returningItems: [], completionHandler: nil)
                    }
                }
            }
        }
    }
    
    private func processScreenshot(_ attachment: NSItemProvider) {
        attachment.loadItem(
        forTypeIdentifier: kUTTypeImage as String,
        options: nil) { secureCoding, error in
            guard let image = secureCoding as? UIImage else {
                self.processItem(attachment)
                return
            }
            
            let date = Date()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "YYYYMMdd_HHmm"
            let dateStr = dateFormatter.string(from: date)
            var name = String(
                format: "Screenshot_%@.jpg", dateStr)
            let nameTemplate = "Screenshot_%@ %d.jpg"
            var i = 0
            while FileManager.default.fileExists(
                atPath: self.groupUrl.appendingPathComponent(
                    name, isDirectory: false).path) {
                        i += 1
                        name = String(format: nameTemplate, dateStr, i)
            }
            
            let data = image.jpegData(compressionQuality: 0.5)
            try? data?.write(to: self.groupUrl.appendingPathComponent(
                name, isDirectory: false))
            
            DispatchQueue.main.async { [weak self] in
                self?.attachmentsCount -= 1
                if self?.attachmentsCount == 0 {
                    self?.openContainerApp()
                    self?.extensionContext?.completeRequest(
                        returningItems: [], completionHandler: nil)
                }
            }
        }
    }
}
