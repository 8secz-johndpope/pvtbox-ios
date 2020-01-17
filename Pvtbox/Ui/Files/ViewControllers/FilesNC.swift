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

class FilesNC: UINavigationController, UINavigationControllerDelegate {
    var presenter: FilesPresenter!
    var tag: String!
    var currentVC: FilesVC?
    var enabled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        BFLog("FilesNC::%@::viewDidLoad", self.tag)
        delegate = self
    }
    
    public func enable() {
        BFLog("FilesNC::%@::enable", tag)
        enabled = true
        (visibleViewController as? FilesVC)?.enabled = true
        (visibleViewController as? PropertiesVC)?.enable()
    }
    
    public func disable() {
        BFLog("FilesNC::%@::disable", tag)
        enabled = false
        (visibleViewController as? FilesVC)?.enabled = false
        (visibleViewController as? PropertiesVC)?.disable()
    }
    
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool) {
        BFLog("FilesNC::%@::navigationControllerWillShow", tag)
        currentVC?.enabled = false
        currentVC = viewController as? FilesVC
        currentVC?.enabled = enabled
    }
}
