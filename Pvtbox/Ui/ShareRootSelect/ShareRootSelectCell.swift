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
import NicoProgress

class ShareRootSelectCell: UITableViewCell {

    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var downloadIcon: UIImageView!
    @IBOutlet weak var shareIcon: UIImageView!
    @IBOutlet weak var progress: NicoProgressBar!
    @IBOutlet weak var processingStatus: UILabel!
    
    private var file: FileRealm!
    
    public func displayContent(
        _ file: FileRealm?) {
        guard let file = file else {
            self.isHidden = true
            return
        }
        self.file = FileRealm(value: file)
        self.isHidden = false
        
        setIcon(file)
        name.text = file.name
        setOfflineOrDownloadIcon(file)
        shareIcon.isHidden = !file.isShared
        setupProgressAndStatus()
    }
    
    public func viewDidAppear() {
        if file == nil { return }
        setupProgressAndStatus()
    }
    
    deinit {
        BFLog("ShareRootSelectCell::deinit")
    }
    
    private func setupProgressAndStatus() {
        if file.isProcessing {
            processingStatus.isHidden = false
            progress.isHidden = false
        } else {
            progress.isHidden = true
            processingStatus.isHidden = true
        }
    }
    
    fileprivate func setIcon(_ file: FileRealm) {
        var image = FileTool.getIcon(forFile: file)
        if file.isProcessing {
            image = image?.tint(tintColor: .processingTint)
        }
        icon.image = image
    }
    
    fileprivate func setOfflineOrDownloadIcon(_ file: FileRealm) {
        let isDownloaded = file.isDownloadActual || file.isFolder && file.size == file.downloadedSize
        downloadIcon.isHidden = !file.isOffline && !isDownloaded
        if file.isOffline {
            downloadIcon.tintColor = .darkGreen
        } else if isDownloaded {
            downloadIcon.tintColor = .lightGray
        }
    }
}
