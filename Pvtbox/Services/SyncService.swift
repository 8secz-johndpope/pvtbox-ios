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
import JASON

class SyncService {
    private let dispatchQueue = DispatchQueue(label: "net.pvtbox.service.sync", qos: .background)
    private weak var signalServerService: SignalServerService?
    private weak var dataBaseService: DataBaseService?
    
    private let lock = NSLock()
    private var processingEventsCount = 0
    private var processedEventsCount = 0
    
    private var shareInfo = [String: JSON]()
    private var collaboratedFolders = [String]()
    private var collaboratedFoldersReceived = false
    
    private var enabled = true
    
    private var initialSync = true {
        willSet {
            if initialSync && !newValue {
                dataBaseService?.cleanProcessing()
                onInitialSyncDone?()
            }
        }
    }
    
    public var onInitialSyncDone: (() -> ())?
    
    public var processingCount: Int {
        get {
            return processingEventsCount
        }
    }
    
    init(signalServerService: SignalServerService, dataBaseService: DataBaseService) {
        self.signalServerService = signalServerService
        self.dataBaseService = dataBaseService
        dispatchQueue.async { [weak self] in
            self?.dataBaseService?.updateOwnDeviceStatus(
                remoteCount: 0, fetchingChanges: true)
        }
    }
    
    public func stop() {
        BFLog("SyncService::stop")
        enabled = false
        dispatchQueue.sync {
            dataBaseService = nil
            signalServerService = nil
        }
    }
    
    public func onFileEvents(_ events: [JSON], nodeId: String?) {
        if !enabled { return }
        defer {
            lock.unlock()
        }
        lock.lock()
        processingEventsCount += events.count
        lock.unlock()
        BFLog("SyncService::onFileEvents, processingCount: %d", processingEventsCount)
        
        dispatchQueue.async { [weak self] in
            self?.handleFileEvents(events, nodeId)
        }
    }
    
    public func setShare(_ shareList: [JSON]) {
        BFLog("SyncService::setShare %d", shareList.count)
        dispatchQueue.async { [weak self] in
            for share in shareList {
                self?.shareInfo[share["uuid"].string!] = share
            }
            self?.dataBaseService?.setShare(self?.shareInfo ?? [String:JSON]())
        }
    }
    
    public func addShare(_ share: JSON) {
        BFLog("SyncService::addShare: %@", String(describing: share))
        dispatchQueue.async { [weak self] in
            self?.shareInfo[share["uuid"].string!] = share
            self?.dataBaseService?.addShare(share)
        }
    }
    
    public func removeShare(_ share: JSON) {
        BFLog("SyncService::removeShare: %@", String(describing: share))
        dispatchQueue.async { [weak self] in
            self?.shareInfo.removeValue(forKey: share["uuid"].string!)
            self?.dataBaseService?.removeShare(share)
        }
    }
    
    public func setCollaboratedFolders(_ collabs: [JSON]) {
        BFLog("SyncService::setCollaboratedFolders %@", collabs)
        dispatchQueue.async { [weak self] in
            self?.collaboratedFolders = collabs.map { $0.string! }
            self?.collaboratedFoldersReceived = true
            self?.dataBaseService?.setCollaboratedFolders(
                self?.collaboratedFolders ?? [String]())
        }
    }
    
    private func handleFileEvents(_ events: [JSON], _ nodeId: String?) {
        if events.isEmpty {
            initialSync = false
            dataBaseService?.updateOwnDeviceStatus(fetchingChanges: false)
            return
        } else {
            dataBaseService?.updateOwnDeviceStatus(remoteCount: 1)
        }
        while enabled {
            do {
                BFLog("SyncService::handleFileEvents, first event: %@, last event: %@",
                      String(describing: events.first?["event_id"].int),
                      String(describing: events.last?["event_id"].int))
                try dataBaseService!.saveFileEvents(
                    events, markChecked: nodeId == "__SERVER__", isInitialSync: initialSync,
                    onEventProcessed: { [weak self] in
                        defer { lock.unlock() }
                        lock.lock()
                        processingEventsCount -= 1
                        return self?.enabled ?? false
                })
                break
            } catch _ as DataBaseService.RealmError {
                BFLogErr("RealmError while saving file events")
            } catch let err {
                BFLogErr("Error while saving file events", String(describing: err))
                break
            }
        }
        if !enabled { return }
        processedEventsCount += events.count
        if processingEventsCount == 0 {
            defer {
                lock.unlock()
            }
            lock.lock()
            BFLog("SyncService::handleFileEvents, processingCount: %d, processed count: %d", processingEventsCount, processedEventsCount)
            
            if processedEventsCount >= Const.maxEventsTotal {
                dataBaseService?.updateOwnDeviceStatus(
                    remoteCount: processingEventsCount, fetchingChanges: true)
                processedEventsCount = 0
                sendEventsCheck()
            } else {
                dataBaseService?.setShare(shareInfo)
                if collaboratedFoldersReceived {
                    dataBaseService?.setCollaboratedFolders(collaboratedFolders)
                }
                dataBaseService?.updateOwnDeviceStatus(
                    remoteCount: processingEventsCount)
            }
        }
    }
    
    private func sendEventsCheck() {
        if !enabled { return }
        do {
            try signalServerService?.sendEventsCheck()
        } catch {
            dispatchQueue.async { [weak self] in
                self?.sendEventsCheck()
            }
        }
    }
}
