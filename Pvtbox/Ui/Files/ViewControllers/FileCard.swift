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
import NicoProgress
import Photos
import Nuke

class FileCard: UITableViewCell {
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    @IBOutlet weak var downloadIcon: UIImageView!
    @IBOutlet weak var shareIcon: UIImageView!
    @IBOutlet weak var menu: UIButton!
    @IBOutlet weak var checkbox: DLRadioButton!
    @IBOutlet weak var tapToDownload: UILabel!
    @IBOutlet weak var progress: UIProgressView!
    @IBOutlet weak var indeterminateProgress: NicoProgressBar!
    @IBOutlet weak var status: UILabel!
    
    private var imageRequestId: PHImageRequestID?
    private var nukeTask: ImageTask?
    
    weak var delegate: FileCardDelegate?
    var file: FileRealm!
    
    public func displayContent(
        _ file: FileRealm?, _ index: IndexPath, isSelected: Bool, isSelectionMode: Bool) {
        if imageRequestId != nil {
            PHImageManager.default().cancelImageRequest(imageRequestId!)
            imageRequestId = nil
        }
        nukeTask?.cancel()
        nukeTask = nil
        
        guard let file = file else {
            self.isHidden = true
            return
        }
        self.file = FileRealm(value: file)
        self.isHidden = false
        setIcon(file)
        name.text = file.name
        setTimeLabel(file)
        setSizeLabel(file)
        setOfflineOrDownloadIcon(file)
        shareIcon.isHidden = !file.isShared
        shareIcon.tintColor = .lightGray
        tapToDownload.isHidden = isSelectionMode || file.isFolder || file.isProcessing
            || file.isOffline || file.isDownloadActual || file.isDownload
            || file.localIdentifier != nil
        setupMenuAndCheckbox(isSelected, isSelectionMode)
        setupProgressAndStatus()
    }
    
    public func viewDidAppear() {
        if file == nil { return }
        setupProgressAndStatus()
    }
    
    deinit {
        if imageRequestId != nil {
            PHImageManager.default().cancelImageRequest(imageRequestId!)
            imageRequestId = nil
        }
        nukeTask?.cancel()
        nukeTask = nil
        BFLog("FileCard::deinit")
    }
    
    private func setupProgressAndStatus() {
        if file.isDownload || file.isProcessing {
            status.isHidden = false
            status.text = file.downloadStatus ?? Strings.processingStatus
            if file.downloadStatus == Strings.downloadingStatus {
                status.textColor = .darkGreen
                
                if !indeterminateProgress.isHidden {
                    indeterminateProgress.transition(to: .determinate(percentage: 0))
                    indeterminateProgress.isHidden = true
                }

                let progressValue = Float(file.downloadedSize) / Float(file.size)
                progress.isHidden = false
                progress.progress = progressValue
                progress.progressTintColor = UIColor.darkGreen
                progress.trackTintColor = UIColor.darkGreen.withAlphaComponent(0.2)
                
            } else if file.downloadStatus == Strings.finishingDownloadStatus {
                status.textColor = .darkGreen
                indeterminateProgress.primaryColor = .darkGreen
                indeterminateProgress.secondaryColor = UIColor.darkGreen.withAlphaComponent(0.2)
                
                if indeterminateProgress.isHidden {
                    indeterminateProgress.isHidden = false
                    indeterminateProgress.transition(to: .indeterminate)
                }
                progress.isHidden = true
            } else {
                status.textColor = .lightGray
                indeterminateProgress.primaryColor = .lightGray
                indeterminateProgress.secondaryColor = UIColor.lightGray.withAlphaComponent(0.2)
                
                if indeterminateProgress.isHidden {
                    indeterminateProgress.isHidden = false
                    indeterminateProgress.transition(to: .indeterminate)
                }
                progress.isHidden = true
            }
        } else {
            if !indeterminateProgress.isHidden {
                indeterminateProgress.transition(to: .determinate(percentage: 0))
                indeterminateProgress.isHidden = true
            }
            progress.isHidden = true
            status.isHidden = true
        }
    }
    
    fileprivate func setIcon(_ file: FileRealm) {
        if !FileTool.isImageFile(file.name!) ||
            file.size > Const.maxSizeForPreview ||
            file.localIdentifier == nil && file.hashsum == nil {
            var image = FileTool.getIcon(forFile: file)
            if file.isProcessing {
                image = image?.tint(tintColor: .processingTint)
            }
            icon.image = image
        } else {
            if file.hashsum == nil {
                BFLog("FileCard::setIcon load icon from camera")
                imageRequestId = icon.loadWithLocalIdentifier(
                    file.localIdentifier!, completion: { [weak self] err in
                        guard let strongSelf = self else { return }
                        if err != nil {
                            strongSelf.icon.image = FileTool.getIcon(
                                forFile: strongSelf.file)
                            if strongSelf.file.isProcessing {
                                strongSelf.icon.image = strongSelf.icon.image?.tint(
                                    tintColor: .processingTint)
                            }
                        } else if strongSelf.file.isProcessing {
                            strongSelf.icon.image = strongSelf.icon.image?.tint(
                                tintColor: .processingTint)
                        }
                })
            } else {
                let url = FileTool.syncDirectory.appendingPathComponent(file.path!)
                let request = ImageRequest(
                    url: url)
                nukeTask = Nuke.loadImage(
                    with: request, into: icon, completion: { [weak self] res, err in
                        guard let strongSelf = self else { return }
                        if err != nil {
                            strongSelf.icon.image = FileTool.getIcon(
                                forFile: strongSelf.file)
                            if strongSelf.file.isProcessing {
                                strongSelf.icon.image = strongSelf.icon.image?.tint(
                                    tintColor: .processingTint)
                            }
                        } else if strongSelf.file.isProcessing {
                            strongSelf.icon.image = strongSelf.icon.image?.tint(
                                tintColor: .processingTint)
                        }
                })
            }
        }
    }
    
    fileprivate func setTimeLabel(_ file: FileRealm) {
        let timeSinceModification = file.dateModified!.timeIntervalSinceNow * -1
        if timeSinceModification < 60 {
            timeLabel.text = file.isFolder || file.dateModified == file.dateCreated ?
                Strings.recentlyAdded : Strings.recentlyModified
        } else {
            timeLabel.text = String(
                format: "%@ %@",
                file.dateModified == file.dateCreated ? Strings.added : Strings.modified,
                String(
                    format: "%@ %@",
                    TimeIntervalFormatter.instance.string(from: timeSinceModification)!,
                    Strings.ago)
            )
        }
    }
    
    fileprivate func setSizeLabel(_ file: FileRealm) {
        sizeLabel.text = String(
            format: "%@/%@%@",
            ByteFormatter.instance.string(fromByteCount: Int64(file.downloadedSize)),
            ByteFormatter.instance.string(fromByteCount: Int64(file.size)),
            file.isFolder ?
                String(format: "; %d %@", file.filesCount, Strings.files)
                : ""
        )
    }
    
    fileprivate func setOfflineOrDownloadIcon(_ file: FileRealm) {
        let isDownloaded = file.isDownloadActual || file.isFolder && file.size == file.downloadedSize
        downloadIcon.isHidden = !file.isOffline && !isDownloaded
        if file.isOffline {
            downloadIcon.tintColor = .darkGreen
        } else if isDownloaded {
            downloadIcon.tintColor = .darkGray
        }
    }
    
    private func setupMenuAndCheckbox(_ isSelected: Bool, _ isSelectionMode: Bool) {
        checkbox.isUserInteractionEnabled = false
        if isSelected {
            checkbox.isSelected = true
            checkbox.iconColor = .orange
            if #available(iOS 13.0, *) {
                backgroundColor = .secondarySystemBackground
            } else {
                backgroundColor = UIColor.graySelection
            }
        } else {
            checkbox.isSelected = false
            checkbox.iconColor = .lightGray
            if #available(iOS 13.0, *) {
                backgroundColor = .systemBackground
            } else {
                backgroundColor = .white
            }
        }
        if isSelectionMode {
            menu.isHidden = true
            checkbox.isHidden = false
        } else {
            menu.setImage(UIImage(named: "more_menu_icon"), for: .normal)
            menu.isHidden = false
            checkbox.isHidden = true
        }
    }
    
    @IBAction func onMenuClicked(_ sender: UIButton) {
        if file.isProcessing { return }
        delegate?.fileCardDelegate(onMenuClicked: file!)
    }
}
