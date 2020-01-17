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
import RealmSwift
import Nuke
import Photos

class PropertiesVC: UIViewController {
    @IBOutlet weak var header: UILabel!
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var size: UILabel!
    @IBOutlet weak var type: UILabel!
    @IBOutlet weak var filesCount: UILabel!
    @IBOutlet weak var permission: UILabel!
    @IBOutlet weak var addedDate: UILabel!
    @IBOutlet weak var modifiedDate: UILabel!
    @IBOutlet weak var path: UILabel!
    
    var file: FileRealm!
    var subscriptionFile: FileRealm?
    var realm: Realm?
    var subscription: NotificationToken?
    
    private var imageRequestId: PHImageRequestID?
    private var nukeTask: ImageTask?
    
    private let dataBaseService = DataBaseService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.titleView = header
        header.text = file.name
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        enable()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        disable()
    }
    
    public func enable() {
        if realm != nil { return }
        BFLog("PropertiesVC::enable")
        realm = try? Realm()
        subscriptionFile = realm?.object(ofType: FileRealm.self, forPrimaryKey: file.uuid)
        subscription = subscriptionFile?.observe({ [weak self] change in
            guard let strongSelf = self,
                let subscriptionFile = strongSelf.subscriptionFile else { return }
            switch change {
            case .change:
                strongSelf.file = FileRealm(value: subscriptionFile)
                strongSelf.updateInfo()
            case .error(let error):
                BFLog("PropertiesVC::observe error occured: %@", error)
            case .deleted:
                break
            }
        })
        if subscriptionFile != nil {
            file = FileRealm(value: subscriptionFile!)
            updateInfo()
        }
    }
    
    public func disable() {
        BFLog("PropertiesVC::disable")
        if imageRequestId != nil {
            PHImageManager.default().cancelImageRequest(imageRequestId!)
            imageRequestId = nil
        }
        nukeTask?.cancel()
        nukeTask = nil
        subscription?.invalidate()
        subscriptionFile = nil
        realm = nil
    }
    
    private func updateInfo() {
        if !FileTool.isImageFile(file.name!) ||
            file.size > Const.maxSizeForPreview ||
            file.hashsum == nil && file.localIdentifier == nil  {
            image.image = FileTool.getIcon(forFile: file)
        } else {
            if file.hashsum == nil {
                BFLog("FileCard::setIcon load icon from camera")
                imageRequestId = image.loadWithLocalIdentifier(
                    file.localIdentifier!, completion: { [weak self] err in
                        guard let strongSelf = self else { return }
                        if err != nil {
                            strongSelf.image.image = FileTool.getIcon(
                                forFile: strongSelf.file)
                        }
                })
            } else {
                let url = FileTool.syncDirectory.appendingPathComponent(file.path!)
                let request = ImageRequest(
                    url: url)
                nukeTask = Nuke.loadImage(
                    with: request, into: image, completion: { [weak self] res, err in
                        guard let strongSelf = self else { return }
                        if err != nil {
                            strongSelf.image.image = FileTool.getIcon(
                                forFile: strongSelf.file)
                        }
                })
            }
        }
        size.text = String(
            format: "%@/%@",
            ByteFormatter.instance.string(fromByteCount: Int64(file.downloadedSize)),
            ByteFormatter.instance.string(fromByteCount: Int64(file.size))
        )
        type.text = FileTool.getType(forFile: file)
        filesCount.text = file.isFolder ?
            String(format: "%d (%d %@)",
                        file.filesCount, file.offlineFilesCount, Strings.offline)
            : "1"
        addedDate.text = FileDateFormatter.instance.string(from: file.dateCreated!)
        modifiedDate.text = FileDateFormatter.instance.string(from: file.dateModified!)
        path.text = file.path
        if !file.isCollaborated && file.parentUuid == nil {
            permission.text = Strings.owner;
            permission.font = .systemFont(ofSize: 16)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.loadPermissions()
            }
        }
    }

    private func loadPermissions() {
        guard let parent = dataBaseService.getRootParent(file),
            parent.isCollaborated else {
                permission.text = Strings.owner
                permission.font = .systemFont(ofSize: 16)
                return
        }
        HttpClient.shared.collaborationInfo(
            uuid: parent.uuid!,
            onSuccess: { [weak self] response in
                DispatchQueue.main.async { [weak self] in
                    let type = response["data"]["access_type"].string
                    switch type {
                    case "edit":
                        self?.permission.text = Strings.canEdit
                    case "view":
                        self?.permission.text = Strings.canView
                    default:
                        self?.permission.text = Strings.owner
                    }
                    self?.permission.font = .systemFont(ofSize: 16)
                }
            },
            onError: { [weak self] error in
                DispatchQueue.main.async { [weak self] in
                    self?.permission.text = Strings.owner;
                    self?.permission.font = .systemFont(ofSize: 16)
                }
            })
    }
}
