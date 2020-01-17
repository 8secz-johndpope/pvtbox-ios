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
import Photos
import ImageScrollView

class PHAssetPhotoPreviewVC: UIViewController {
    @IBOutlet weak var imageScroll: ImageScrollView!
    
    var asset: PHAsset!
    var fileName: String!
    
    private var imageRequestId: PHImageRequestID?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let requestOptions = PHImageRequestOptions()
        requestOptions.deliveryMode = .opportunistic
        requestOptions.isNetworkAccessAllowed = true
        requestOptions.isSynchronous = false
        navigationItem.title = fileName
        
        imageRequestId = PHImageManager.default().requestImage(
            for: asset,
            targetSize: view.frame.size,
            contentMode: .aspectFit,
            options: requestOptions,
            resultHandler: { [weak self] image, _ in
                if image != nil {
                    self?.imageScroll.display(image: image!)
                }
        })
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if imageRequestId != nil {
            PHImageManager.default().cancelImageRequest(imageRequestId!)
        }
    }
}
