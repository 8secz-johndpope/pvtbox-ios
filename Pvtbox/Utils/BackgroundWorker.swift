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

class BackgroundWorker: NSObject {
    private var thread: Thread!
    @objc private var block: (()->Void)!
    private weak var runLoop: RunLoop?
    
    @objc internal func runBlock() {
        BFLog("BackgroundWorker::runBlock")
        block()
    }
    
    internal func start(_ block: @escaping () -> Void) {
        BFLog("BackgroundWorker::start")
        self.block = block
        
        let threadName = String(describing: self)
            .components(separatedBy: .punctuationCharacters)[1]
        
        thread = Thread { [weak self] in
            BFLog("BackgroundWorker::start thread block")
            self?.runLoop = RunLoop.current
            while (self != nil && !(self?.thread.isCancelled ?? true) && self?.runLoop != nil) {
                self!.runLoop!.run()
                Thread.sleep(forTimeInterval: 0.1)
            }
            BFLog("BackgroundWorker::start runLoop exited")
        }
        thread.name = "\(threadName)-\(UUID().uuidString)"
        thread.start()
        
        self.asyncForce {
            BFLog("BackgroundWorker::start async block")
            self.runBlock()
        }
    }
    
    public func stop() {
        BFLog("BackgroundWorker::stop")
        async {
            self.thread.cancel()
            self.runLoop = nil
            Thread.exit()
            BFLog("BackgroundWorker::stop exited")
        }
    }

    public func async(_ f: @escaping () -> ()) {
        runLoop?.perform {
            f()
        }
    }
    
    private func asyncForce(_ f: @escaping () -> ()) {
        if let loop = runLoop {
            loop.perform {
                f()
            }
        } else {
            Thread.sleep(forTimeInterval: 0.1)
            asyncForce(f)
        }
    }
}
