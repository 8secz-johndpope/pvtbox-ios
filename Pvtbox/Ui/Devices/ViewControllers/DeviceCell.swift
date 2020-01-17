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

class DeviceCell: UITableViewCell {
    @IBOutlet weak var onlineIcon: UIImageView!
    @IBOutlet weak var deviceIcon: UIImageView!
    @IBOutlet weak var name: UILabel!
    @IBOutlet weak var osIcon: UIImageView!
    @IBOutlet weak var os: UILabel!
    @IBOutlet weak var status: UILabel!
    @IBOutlet weak var diskSpace: UILabel!
    @IBOutlet weak var downloadSpeed: UILabel!
    @IBOutlet weak var uploadSpeed: UILabel!
    @IBOutlet weak var manage: UILabel!
    
    public func displayContent(
        _ device: DeviceRealm, _ index: IndexPath, isOwnOnline: Bool, isOwn: Bool) {
        if index.item % 2 == 0 {
            if #available(iOS 13.0, *) {
                backgroundColor = .systemBackground
            } else {
                backgroundColor = .white
            }
        } else {
            if #available(iOS 13.0, *) {
                backgroundColor = .secondarySystemBackground
            } else {
                backgroundColor = .graySelection
            }
        }
        
        let isOnline = isOwnOnline && device.online
        if #available(iOS 13.0, *) {
            onlineIcon.tintColor = isOnline ?
                UIColor.darkGreen : UIColor.quaternaryLabel
        } else {
            onlineIcon.tintColor = isOnline ?
                UIColor.darkGreen : UIColor.lightGray
        }
        
        manage.isHidden = !isOwnOnline && !isOwn

        switch device.deviceType {
        case "phone", "tablet":
            deviceIcon.image = UIImage(named: "mobile")
        default:
            deviceIcon.image = UIImage(named: "desktop")
        }
        
        name.text = device.name
        switch device.osType?.lowercased() {
        case "linux":
            osIcon.image = UIImage(named: "linux")
        case "windows":
            osIcon.image = UIImage(named: "windows")
        case "mac", "ios", "darwin":
            osIcon.image = UIImage(named: "apple")
        case "android":
            osIcon.image = UIImage(named: "android")
        default:
            break
        }
        os.text = device.os
        
        var deviceStatus = isOwn && device.paused ? 8 : device.status
        var deviceUploadSpeed = device.uploadSpeed
        var deviceDownloadSpeed = device.downloadSpeed
        if !isOnline {
            if ![5,6,7,10].contains(deviceStatus) {
                deviceStatus = 7
            }
            deviceUploadSpeed = 0
            deviceDownloadSpeed = 0
        }
        
        let (text, color) = DeviceStatusFormatter.stringAndColor(deviceStatus)
        status.text = text
        status.textColor = color
                
        diskSpace.text = ByteFormatter.instance.string(fromByteCount: Int64(device.diskUsage))
        uploadSpeed.text = String(
            format: "%@/%@",
            ByteFormatter.instance.string(fromByteCount: Int64(deviceUploadSpeed)),
            Strings.secondLetter)
        downloadSpeed.text = String(
            format: "%@/%@",
            ByteFormatter.instance.string(fromByteCount: Int64(deviceDownloadSpeed)),
            Strings.secondLetter)
    }
    
}
