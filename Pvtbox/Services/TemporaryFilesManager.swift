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

class TemporaryFilesManager {
    private static let fileLifetime = 60.0
    private let dq = DispatchQueue(
        label: "net.pvtbox.service.temporary_files", qos: .background)
    private var checkWorkItem: DispatchWorkItem? = nil
    private var temporaryFiles = [URL: Date]()
    
    public func touch(_ url: URL) {
        dq.sync {
            self.temporaryFiles[url] = Date()
            if self.checkWorkItem == nil {
                self.checkWorkItem = DispatchWorkItem() { [weak self] in
                    self?.check()
                }
               self.dq.asyncAfter(
                    deadline: .now() + TemporaryFilesManager.fileLifetime,
                    execute: self.checkWorkItem!)
            }
        }
    }
    
    public func stop() {
        checkWorkItem?.cancel()
        checkWorkItem = nil
    }
    
    private func check() {
        let outdatedFiles = temporaryFiles.filter { url, date in
            date.timeIntervalSinceNow * -1 > TemporaryFilesManager.fileLifetime
        }
        for (url, _) in outdatedFiles {
            FileTool.delete(url)
            temporaryFiles.removeValue(forKey: url)
        }
        if temporaryFiles.isEmpty {
            checkWorkItem = nil
        } else {
            checkWorkItem = DispatchWorkItem() { [weak self] in
                self?.check()
            }
            dq.asyncAfter(
                deadline: .now() + TemporaryFilesManager.fileLifetime,
                execute: checkWorkItem!)
        }
    }
}
