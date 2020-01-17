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

class SpeedCalculator {
    private static let notificationPeriod = 1.0
    private static let valuesPeriod = 10.0
    
    private let dispatchQueue = DispatchQueue(
        label: "net.pvtbox.service.network.speed", qos: .background)
    
    private weak var dataBaseService: DataBaseService?
    
    var updateWorkItem: DispatchWorkItem? = nil
    
    var totalDownloaded: Double = 0
    var totalUploaded: Double = 0
    
    var downloaded: Double = 0
    var uploaded: Double = 0
    
    var downloadValues: [Double] = []
    var uploadValues: [Double] = []
    
    var lastDownloadSpeed: Double = 0
    var lastUploadSpeed: Double = 0
    
    var enabled = true
    
    init(_ dataBaseService: DataBaseService) {
        self.dataBaseService = dataBaseService
    }
    
    public func stop() {
        enabled = false
        updateWorkItem?.cancel()
        updateWorkItem = nil
        dataBaseService = nil
    }
    
    public func onDataDownloaded(_ value: Double) {
        if !enabled { return }
        downloaded += value
        scheduleUpdate()
    }
    
    public func onDataUploaded(_ value: Double) {
        if !enabled { return }
        uploaded += value
        scheduleUpdate()
    }
    
    private func scheduleUpdate() {
        if updateWorkItem == nil {
            updateWorkItem = DispatchWorkItem { [weak self] in
                self?.updateWorkItem = nil
                self?.update()
            }
            dispatchQueue.asyncAfter(
                deadline: .now() + SpeedCalculator.notificationPeriod,
                execute: updateWorkItem!)
        }
    }
    
    private func update() {
        downloadValues.append(downloaded)
        totalDownloaded += downloaded
        downloaded = 0
        if downloadValues.count >
            Int(SpeedCalculator.valuesPeriod / SpeedCalculator.notificationPeriod) {
            downloadValues.removeFirst()
        }
        let downloadSpeed = calculateSpeed(downloadValues)
        
        uploadValues.append(uploaded)
        totalUploaded += uploaded
        uploaded = 0
        if uploadValues.count >
            Int(SpeedCalculator.valuesPeriod / SpeedCalculator.notificationPeriod) {
            uploadValues.removeFirst()
        }
        let uploadSpeed = calculateSpeed(uploadValues)
        
        dataBaseService?.updateOwnDeviceStatus(
            uploadSpeed: uploadSpeed, downloadSpeed: downloadSpeed,
            uploadedSize: totalUploaded, downloadedSize: totalDownloaded)
        lastDownloadSpeed = downloadSpeed
        lastUploadSpeed = uploadSpeed
        
        if lastUploadSpeed != 0.0 || lastDownloadSpeed != 0.0 {
            scheduleUpdate()
        }
    }
    
    private func calculateSpeed(_ values: [Double]) -> Double {
        guard let firstNonZero = values.firstIndex(
            where: { value in return value > 0 }) else { return 0.0 }
        let sum = values.reduce(0, +)
        let speed = sum / Double(values.distance(
            from: firstNonZero, to: values.endIndex))
        return speed
    }
}
