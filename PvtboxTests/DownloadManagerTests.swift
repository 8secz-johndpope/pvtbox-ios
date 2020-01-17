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

import XCTest
@testable import Pvtbox

class ConnectivityServiceMock : ConnectivityService {
}

class DownloadManagerTests: XCTestCase {

    var dataBaseService: DataBaseService!
    var connectivity: ConnectivityServiceMock!
    var tempFilesManager: TemporaryFilesManager!
    var task1: DownloadTask!
    var task2: DownloadTask!
    var task3: DownloadTask!
    var task4: DownloadTask!
    var task5: DownloadTask!
    
    var manager: DownloadManager!
    
    override func setUp() {
        task1 = DownloadTask(
            priority: 100, fileUuid: "fileUuid", objId: "objId",
            name: "test", size: 1024 * 10,
            hashsum: "hashsum", connectivityService: nil)
        task2 = DownloadTask(
            priority: 100, fileUuid: "fileUuid_2", objId: "objId_2",
            name: "test", size: 1024 * 10,
            hashsum: "hashsum", connectivityService: nil)
        task3 = DownloadTask(
            priority: 101, fileUuid: "fileUuid_3", objId: "objId_3",
            name: "test", size: 1024 * 10,
            hashsum: "hashsum", connectivityService: nil)
        task4 = DownloadTask(
            priority: 100, fileUuid: "fileUuid_4", objId: "objId_4",
            name: "test", size: 1024 * 100,
            hashsum: "hashsum", connectivityService: nil)
        task5 = DownloadTask(
            priority: 100, fileUuid: "fileUuid_5", objId: "objId_5",
            name: "test", size: 1024 * 50,
            hashsum: "hashsum", connectivityService: nil)
        manager = DownloadManager(
            dataBaseService, connectivity, tempFilesManager, shareMode: false, paused: false)
    }

    override func tearDown() {
    }

    func testOnDownloadTaskReady() {
        manager.currentTask = DownloadTask(
            priority: 100, fileUuid: "", objId: "",
            name: "", size: 1024 * 50,
            hashsum: "", connectivityService: nil)
        manager.onDownloadTaskReady(task1)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [])
        
        manager.downloadTasks[task1.objId] = task1
        manager.onDownloadTaskReady(task1)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1])
        
        manager.onDownloadTaskReady(task1)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1])
        
        manager.onDownloadTaskReady(task2)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1])
        
        manager.downloadTasks[task2.objId] = task2
        manager.onDownloadTaskReady(task2)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1, task2])
        
        manager.onDownloadTaskReady(task3)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1, task2])
        
        manager.downloadTasks[task3.objId] = task3
        manager.onDownloadTaskReady(task3)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task3, task1, task2])
        
        manager.onDownloadTaskReady(task4)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task3, task1, task2])
        
        manager.downloadTasks[task4.objId] = task4
        manager.onDownloadTaskReady(task4)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task3, task1, task2, task4])
        
        manager.onDownloadTaskReady(task5)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task3, task1, task2, task4])
        
        manager.downloadTasks[task5.objId] = task5
        manager.onDownloadTaskReady(task5)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task3, task1, task2, task5, task4])
        manager.onDownloadTaskReady(task5)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task3, task1, task2, task5, task4])
    }
    
    func testOnDownloadTaskNotReady() {
        manager.currentTask = DownloadTask(
            priority: 100, fileUuid: "", objId: "",
            name: "", size: 1024 * 50,
            hashsum: "", connectivityService: nil)
        manager.onDownloadTaskNotReady(task1)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [])
    
        manager.downloadTasks[task1.objId] = task1
        manager.onDownloadTaskReady(task1)
        manager.onDownloadTaskNotReady(task1)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [])
        manager.onDownloadTaskReady(task1)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1])
        manager.onDownloadTaskNotReady(task1)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [])
        
        manager.onDownloadTaskReady(task1)
        manager.downloadTasks[task2.objId] = task2
        manager.onDownloadTaskReady(task2)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1, task2])
        manager.onDownloadTaskNotReady(task1)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task2])
        manager.onDownloadTaskNotReady(task2)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [])
    }
    
    func testStartNextTask() {
        manager.downloadTasks[task1.objId] = task1
        manager.downloadTasks[task2.objId] = task2
        manager.downloadTasks[task3.objId] = task3
        manager.onDownloadTaskReady(task1)
        manager.onDownloadTaskReady(task2)
        
        manager.startNextTask()
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task2])
        XCTAssertEqual(task1, manager.currentTask)
        
        manager.startNextTask()
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task2])
        XCTAssertEqual(task1, manager.currentTask)
        
        manager.onDownloadTaskReady(task3)
        manager.startNextTask()
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task3, task2])
        XCTAssertEqual(task1, manager.currentTask)
        
        manager.onDownloadTaskReady(task4)
        manager.startNextTask()
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task3, task2])
        XCTAssertEqual(task1, manager.currentTask)
        
        manager.onDownloadTaskNotReady(task2)
        manager.startNextTask()
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task3])
        XCTAssertEqual(task1, manager.currentTask)
        
        manager.onDownloadTaskNotReady(task1)
        XCTAssertEqual(nil, manager.currentTask)
        manager.startNextTask()
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [])
        XCTAssertEqual(task3, manager.currentTask)
        
        manager.onDownloadTaskReady(task1)
        manager.onDownloadTaskReady(task2)
        manager.onDownloadTaskNotReady(task3)
        manager.startNextTask()
        XCTAssertEqual(task1, manager.currentTask)
        manager.onDownloadTaskNotReady(task1)
        manager.onDownloadTaskReady(task3)
        manager.onDownloadTaskReady(task1)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task3, task1, task2])
        manager.startNextTask()
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1, task2])
        XCTAssertEqual(task3, manager.currentTask)
    }
    
    func testOnDownloadTaskCompleted() {
        manager.downloadTasks[task1.objId] = task1
        
        manager.onDownloadTaskReady(task1)
        manager.startNextTask()
        manager.onDownloadTaskCompleted(task1)
        XCTAssertEqual(manager.currentTask, nil)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [])
        XCTAssertEqual(Array(manager.downloadTasks.values), [])
        
        manager.downloadTasks[task2.objId] = task2
        manager.downloadTasks[task3.objId] = task3
        manager.onDownloadTaskReady(task2)
        manager.onDownloadTaskReady(task3)
        manager.startNextTask()
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, task3)
        manager.onDownloadTaskCompleted(task3)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, task2)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [])
        XCTAssertEqual(Array(manager.downloadTasks.values), [task2])
        
        manager.downloadTasks[task4.objId] = task4
        manager.onDownloadTaskReady(task4)
        manager.onDownloadTaskCompleted(task2)
        manager.onDownloadTaskCompleted(task4)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, nil)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [])
        XCTAssertEqual(Array(manager.downloadTasks.values), [])
    }
    
    func testPauseResume() {
        manager.downloadTasks[task1.objId] = task1
        manager.downloadTasks[task2.objId] = task2
        manager.downloadTasks[task3.objId] = task3
        
        manager.onDownloadTaskReady(task1)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, task1)
        manager.pause()
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, nil)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1])
        manager.onDownloadTaskReady(task2)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, nil)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1, task2])
        
        manager.onDownloadTaskReady(task3)
        manager.onDownloadTaskNotReady(task3)
        manager.onDownloadTaskCompleted(task2)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, nil)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1])
        
        manager.onDownloadTaskReady(task3)
        manager.resume()
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, task3)
        XCTAssertEqual(Array(manager.readyDownloadsQueue), [task1])
        
        manager.pause()
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, nil)
        
        manager.onDownloadTaskCompleted(task3)
        manager.onDownloadTaskNotReady(task1)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, nil)
        
        manager.resume()
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, nil)
        
        manager.onDownloadTaskReady(task1)
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(manager.currentTask, task1)
    }
}
