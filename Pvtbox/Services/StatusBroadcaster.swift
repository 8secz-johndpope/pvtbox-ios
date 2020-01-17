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

class StatusBroadcaster {
    private let dispatchQueue = DispatchQueue(
        label: "net.pvtbox.service.status", qos: .background)
    
    private weak var dataBaseService: DataBaseService?
    private weak var signalServerService: SignalServerClient?
    
    private var sentStatus: Int = 0
    private var sentDiskUsage: Double = 0
    private var sentDownloadSpeed: Double = 0
    private var sentUploadSpeed: Double = 0
    
    private var workItem: DispatchWorkItem? = nil
    
    init(_ dataBaseService: DataBaseService?, _ signalServerService: SignalServerService?) {
        self.dataBaseService = dataBaseService
        self.signalServerService = signalServerService
        dispatchQueue.async { [weak self] in
            self?.checkAndBroadcastStatus()
        }
    }
    
    public func stop() {
        workItem?.cancel()
        dataBaseService = nil
        signalServerService = nil
    }

    public func checkAndBroadcastStatus(force: Bool = false) {
        workItem?.cancel()
        workItem = DispatchWorkItem { [weak self] in
            self?.checkAndBroadcastStatus()
        }
        dispatchQueue.asyncAfter(
            deadline: .now() + 10, execute: workItem!)
        guard let signalServerService = signalServerService,
            signalServerService.isConnected,
            let ownDevice = dataBaseService?.getOwnDevice() else { return }
        let status = ownDevice.paused ? 8 : ownDevice.status
        
        if force ||
            sentStatus != status ||
            sentDiskUsage != ownDevice.diskUsage ||
            sentDownloadSpeed != ownDevice.downloadSpeed ||
            sentUploadSpeed != ownDevice.uploadSpeed {
        
            sentStatus = status
            sentDiskUsage = ownDevice.diskUsage
            sentDownloadSpeed = ownDevice.downloadSpeed
            sentUploadSpeed = ownDevice.uploadSpeed
        
            let msg: [String: Any] = ["operation": "node_status", "data": [
                "disk_usage": UInt64(sentDiskUsage),
                "upload_speed": sentUploadSpeed,
                "download_speed": sentDownloadSpeed,
                "node_status": sentStatus,
                ]]
            let message = JSONCoder.encode(msg)!
            signalServerService.send(message)
        }
    }
}
