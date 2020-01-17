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
import BTree
@testable import Pvtbox

class DownloadTaskTest: XCTestCase {
    
    var task: DownloadTask!
    
    override func setUp() {
        task = DownloadTask(
            priority: 0, fileUuid: "fileUuid", objId: "objId", name: "test", size: 1024 * 10, hashsum: "hashsum",
            connectivityService: nil)
    }

    override func tearDown() {
        task = nil
    }

    func testEmptyAvailabilityInfo() {
        task.onAvailabilityInfoReceived([], from: "node_id")
        XCTAssertTrue(task.nodesAvailableChunks.isEmpty)
    }
    
    func testOnAvailabilityInfo() {
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=1000; $0.length=10 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [1000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=10000; $0.length=10 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [1000, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [10, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=800; $0.length=10 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [800, 1000, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [10, 10, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=700; $0.length=100 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [700, 1000, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [110, 10, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=810; $0.length=90 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [700, 1000, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [200, 10, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=1000; $0.length=100 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [700, 1000, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [200, 100, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=800; $0.length=100 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [700, 1000, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [200, 100, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=800; $0.length=250 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [700, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [400, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=600; $0.length=600 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [600, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [600, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=800; $0.length=600 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [600, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [800, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=100; $0.length=100 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [100, 600, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [100, 800, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=300; $0.length=100 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [100, 300, 600, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [100, 100, 800, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=1500; $0.length=100 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [100, 300, 600, 1500, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [100, 100, 800, 100, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=0; $0.length=2000 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [0, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [2000, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=0; $0.length=0 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [0, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [2000, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=10000; $0.length=0 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [0, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [2000, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=3000; $0.length=0 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [0, 10000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [2000, 10])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=2000; $0.length=8000 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [0])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [10010])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=0; $0.length=20000 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [0])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [20000])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=50000; $0.length=100 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [0, 50000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [20000, 100])
        
        task.onAvailabilityInfoReceived([
            Proto_Info.with { $0.offset=40000; $0.length=20000 }
            ], from: "node_id")
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.keys), [0, 40000])
        XCTAssertEqual(Array(task.nodesAvailableChunks["node_id"]!.values), [20000, 20000])
    }

    func testRemoveFromChunks() {
        var chunks = Map<UInt64, UInt64>()
        
        task.removeFromChunks(0, 100, &chunks)
        XCTAssertEqual(Array(chunks.keys), [])
        XCTAssertEqual(Array(chunks.values), [])
        
        
        chunks = Map<UInt64, UInt64>([(100, 100)])
        
        task.removeFromChunks(10, 90, &chunks)
        XCTAssertEqual(Array(chunks.keys), [100])
        XCTAssertEqual(Array(chunks.values), [100])
        
        task.removeFromChunks(200, 100, &chunks)
        XCTAssertEqual(Array(chunks.keys), [100])
        XCTAssertEqual(Array(chunks.values), [100])
        
        task.removeFromChunks(100, 10, &chunks)
        XCTAssertEqual(Array(chunks.keys), [110])
        XCTAssertEqual(Array(chunks.values), [90])
        
        task.removeFromChunks(190, 10, &chunks)
        XCTAssertEqual(Array(chunks.keys), [110])
        XCTAssertEqual(Array(chunks.values), [80])
        
        task.removeFromChunks(10, 110, &chunks)
        XCTAssertEqual(Array(chunks.keys), [120])
        XCTAssertEqual(Array(chunks.values), [70])
        
        task.removeFromChunks(180, 200, &chunks)
        XCTAssertEqual(Array(chunks.keys), [120])
        XCTAssertEqual(Array(chunks.values), [60])
        
        task.removeFromChunks(10, 500, &chunks)
        XCTAssertEqual(Array(chunks.keys), [])
        XCTAssertEqual(Array(chunks.values), [])
        
        
        chunks = Map<UInt64, UInt64>([(2, 1), (100, 100)])
        
        task.removeFromChunks(10, 90, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 100])
        XCTAssertEqual(Array(chunks.values), [1, 100])
        
        task.removeFromChunks(200, 100, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 100])
        XCTAssertEqual(Array(chunks.values), [1, 100])
        
        task.removeFromChunks(100, 10, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 110])
        XCTAssertEqual(Array(chunks.values), [1, 90])
        
        task.removeFromChunks(190, 10, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 110])
        XCTAssertEqual(Array(chunks.values), [1, 80])
        
        task.removeFromChunks(10, 110, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 120])
        XCTAssertEqual(Array(chunks.values), [1, 70])
        
        task.removeFromChunks(180, 200, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 120])
        XCTAssertEqual(Array(chunks.values), [1, 60])
        
        task.removeFromChunks(10, 500, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2])
        XCTAssertEqual(Array(chunks.values), [1])
        
        
        chunks = Map<UInt64, UInt64>([(100, 100), (1000, 100)])
        
        task.removeFromChunks(10, 90, &chunks)
        XCTAssertEqual(Array(chunks.keys), [100, 1000])
        XCTAssertEqual(Array(chunks.values), [100, 100])
        
        task.removeFromChunks(200, 100, &chunks)
        XCTAssertEqual(Array(chunks.keys), [100, 1000])
        XCTAssertEqual(Array(chunks.values), [100, 100])
        
        task.removeFromChunks(100, 10, &chunks)
        XCTAssertEqual(Array(chunks.keys), [110, 1000])
        XCTAssertEqual(Array(chunks.values), [90, 100])
        
        task.removeFromChunks(190, 10, &chunks)
        XCTAssertEqual(Array(chunks.keys), [110, 1000])
        XCTAssertEqual(Array(chunks.values), [80, 100])
        
        task.removeFromChunks(10, 110, &chunks)
        XCTAssertEqual(Array(chunks.keys), [120, 1000])
        XCTAssertEqual(Array(chunks.values), [70, 100])
        
        task.removeFromChunks(180, 200, &chunks)
        XCTAssertEqual(Array(chunks.keys), [120, 1000])
        XCTAssertEqual(Array(chunks.values), [60, 100])
        
        task.removeFromChunks(10, 500, &chunks)
        XCTAssertEqual(Array(chunks.keys), [1000])
        XCTAssertEqual(Array(chunks.values), [100])
        
        
        chunks = Map<UInt64, UInt64>([(2, 1), (100, 100), (1000, 100)])
        
        task.removeFromChunks(10, 90, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 100, 1000])
        XCTAssertEqual(Array(chunks.values), [1, 100, 100])
        
        task.removeFromChunks(200, 100, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 100, 1000])
        XCTAssertEqual(Array(chunks.values), [1, 100, 100])
        
        task.removeFromChunks(100, 10, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 110, 1000])
        XCTAssertEqual(Array(chunks.values), [1, 90, 100])
        
        task.removeFromChunks(190, 10, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 110, 1000])
        XCTAssertEqual(Array(chunks.values), [1, 80, 100])
        
        task.removeFromChunks(10, 110, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 120, 1000])
        XCTAssertEqual(Array(chunks.values), [1, 70, 100])
        
        task.removeFromChunks(180, 200, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 120, 1000])
        XCTAssertEqual(Array(chunks.values), [1, 60, 100])
        
        task.removeFromChunks(10, 500, &chunks)
        XCTAssertEqual(Array(chunks.keys), [2, 1000])
        XCTAssertEqual(Array(chunks.values), [1, 100])
        
        
        chunks = Map<UInt64, UInt64>([(2, 1), (100, 100), (1000, 100)])
        
        task.removeFromChunks(0, 110, &chunks)
        XCTAssertEqual(Array(chunks.keys), [110, 1000])
        XCTAssertEqual(Array(chunks.values), [90, 100])
        
        task.removeFromChunks(150, 900, &chunks)
        XCTAssertEqual(Array(chunks.keys), [110, 1050])
        XCTAssertEqual(Array(chunks.values), [40, 50])
        
        
        chunks = Map<UInt64, UInt64>([(2, 1), (100, 100), (1000, 100)])
        
        task.removeFromChunks(0, 2000, &chunks)
        task.removeFromChunks(0, 110, &chunks)
        XCTAssertEqual(Array(chunks.keys), [])
        XCTAssertEqual(Array(chunks.values), [])
        
        
        chunks = Map<UInt64, UInt64>([(100, 100), (300, 100), (500, 100), (700, 100)])
        
        task.removeFromChunks(0, 1000, &chunks)
        XCTAssertEqual(Array(chunks.keys), [])
        XCTAssertEqual(Array(chunks.values), [])
        
        
        chunks = Map<UInt64, UInt64>([(100, 100), (300, 100), (500, 100), (700, 100)])
        
        task.removeFromChunks(150, 600, &chunks)
        XCTAssertEqual(Array(chunks.keys), [100, 750])
        XCTAssertEqual(Array(chunks.values), [50, 50])
        
        
        chunks = Map<UInt64, UInt64>([(0, 100), (1000, 100), (2000, 100), (3000, 100)])
        
        task.removeFromChunks(150, 600, &chunks)
        XCTAssertEqual(Array(chunks.keys), [0, 1000, 2000, 3000])
        XCTAssertEqual(Array(chunks.values), [100, 100, 100, 100])
        
        task.removeFromChunks(5000, 600, &chunks)
        XCTAssertEqual(Array(chunks.keys), [0, 1000, 2000, 3000])
        XCTAssertEqual(Array(chunks.values), [100, 100, 100, 100])
        
        task.removeFromChunks(100, 1900, &chunks)
        XCTAssertEqual(Array(chunks.keys), [0, 2000, 3000])
        XCTAssertEqual(Array(chunks.values), [100, 100, 100])
        
        task.removeFromChunks(2040, 20, &chunks)
        XCTAssertEqual(Array(chunks.keys), [0, 2000, 2060, 3000])
        XCTAssertEqual(Array(chunks.values), [100, 40, 40, 100])
    }
    
    func testGetAvailableChunksToDownload() {
        var chunks = task.getAvailableChunksToDownload(from: "node_id")
        XCTAssertTrue(chunks.isEmpty)
        
        
        task.downloadedChunks = Map<UInt64, UInt64>([(0, 100), (200, 100), (500, 100), (1000, 1000), (5000, 100)])
        task.nodesRequestedChunks["node_id"] = Map<UInt64, UInt64>([(100, 100), (300, 200)])
        task.nodesRequestedChunks["node_id2"] = Map<UInt64, UInt64>([(300, 200), (3000, 1000)])
        task.nodesRequestedChunks["node_id3"] = Map<UInt64, UInt64>()
        task.nodesRequestedChunks["node_id4"] = Map<UInt64, UInt64>([(5100, 900)])
        task.nodesAvailableChunks["node_id"] = Map<UInt64, UInt64>([(0, 3000), (5000, 2000)])
        
        chunks = task.getAvailableChunksToDownload(from: "node_id")
        
        XCTAssertEqual(Array(chunks.keys), [600, 2000, 6000])
        XCTAssertEqual(Array(chunks.values), [400, 1000, 1000])
    }
    
    func testGetAvailableChunksToDownload2() {
        task.downloadedChunks = Map<UInt64, UInt64>([
            (65536, 65536), (262144, 196608), (524288, 131072), (851968, 65536), (1114112, 65536), (1310720, 131072),
            (1507328, 65536), (1703936, 131072), (1900544, 65536), (3145728, 65536), (3276800, 262144), (3604480, 65536),
            (3932160, 65536), (4063232, 196608), (4325376, 327680), (4718592, 327680), (5111808, 131072), (5308416, 65536),
            (5505024, 196608), (5767168, 262144), (6094848, 65536), (6291456, 1114112), (7602176, 196608), (7864320, 262144),
            (8192000, 65536), (8388608, 65536), (8519680, 262144), (8847360, 65536), (9043968, 196608), (9306112, 196608),
            (9568256, 65536), (9699328, 131072), (9895936, 393216), (10354688, 65536), (10485760, 1507328), (12058624, 262144),
            (12386304, 196608), (12648448, 393216), (13107200, 65536), (13238272, 131072), (13434880, 1310720), (14811136, 262144),
            (15138816, 65536), (15335424, 196608), (15597568, 196608), (15859712, 262144), (16187392, 65536), (16384000, 196608),
            (16646144, 131072), (16842752, 65536), (17039360, 196608), (17301504, 262144), (17629184, 65536), (18874368, 65536),
            (21037056, 65536), (21233664, 196608), (21495808, 196608), (21823488, 65536), (22020096, 65536), (22151168, 262144),
            (22478848, 65536), (22806528, 65536), (22937600, 131072), (28311552, 851968), (29229056, 131072), (29425664, 65536),
            (29622272, 65536), (29753344, 65536), (29949952, 65536), (30212096, 65536), (30408704, 65536), (30670848, 131072),
            (30867456, 327680), (31260672, 44906)
            ])
        task.nodesRequestedChunks["node_id"] = Map<UInt64, UInt64>([
            (0, 65536), (131072, 131072), (458752, 65536), (655360, 196608), (917504, 131072), (1048576, 65536), (1179648, 131072),
            (1441792, 65536), (1572864, 131072), (1835008, 65536), (1966080, 131072), (3211264, 65536), (3538944, 65536),
            (3670016, 262144), (3997696, 65536), (4259840, 65536), (4653056, 65536), (5046272, 65536), (5177344, 65536),
            (5242880, 65536), (5373952, 131072), (5701632, 65536), (6029312, 65536), (6160384, 131072), (7405568, 196608),
            (7798784, 65536), (8126464, 65536), (8257536, 131072), (8454144, 65536), (8781824, 65536), (8912896, 131072),
            (9240576, 65536), (9502720, 65536), (9633792, 65536), (9830400, 65536), (10289152, 65536), (10420224, 65536),
            (11468800, 65536), (11993088, 65536), (12320768, 65536), (12517376, 65536), (12582912, 65536), (13041664, 65536),
            (13172736, 65536), (13369344, 65536), (14745600, 65536), (15073280, 65536), (15204352, 131072), (15532032, 65536),
            (15794176, 65536), (16121856, 65536), (16252928, 131072), (16580608, 65536), (16711680, 65536), (16777216, 65536),
            (16908288, 131072), (17235968, 65536), (17563648, 65536), (17694720, 131072), (18939904, 983040), (20971520, 65536),
            (21102592, 131072), (21430272, 65536), (21692416, 131072), (21889024, 131072), (22085632, 65536), (22413312, 65536),
            (22544384, 262144), (22872064, 65536), (29163520, 65536), (29294592, 65536), (29360128, 65536), (29491200, 131072),
            (29687808, 65536), (29818880, 131072), (30015488, 196608), (30277632, 131072), (30474240, 196608), (30801920, 65536),
            (31195136, 65536)
            ])
        task.nodesAvailableChunks["node_id"] = Map<UInt64, UInt64>([(0, 31305578)])
        
        let chunks = task.getAvailableChunksToDownload(from: "node_id")
        XCTAssertNotNil(task.downloadedChunks[10485760])
        XCTAssertNil(chunks[10485760])
        XCTAssertEqual(Array(chunks.keys), [2097152, 17825792, 19922944, 23068672])
        XCTAssertEqual(Array(chunks.values), [1048576, 1048576, 1048576, 5242880])
    }
    
    func testOnNewChunkDownloaded() {
        let data = Data()
        _ = task.onNewChunkDownloaded(100, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [100])
        XCTAssertEqual(Array(task.downloadedChunks.values), [10])
        XCTAssertEqual(task.received, 10)
        
        _ = task.onNewChunkDownloaded(110, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [100])
        XCTAssertEqual(Array(task.downloadedChunks.values), [20])
        XCTAssertEqual(task.received, 20)
        
        _ = task.onNewChunkDownloaded(120, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [100])
        XCTAssertEqual(Array(task.downloadedChunks.values), [30])
        XCTAssertEqual(task.received, 30)
        
        _ = task.onNewChunkDownloaded(90, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [90])
        XCTAssertEqual(Array(task.downloadedChunks.values), [40])
        XCTAssertEqual(task.received, 40)
        
        _ = task.onNewChunkDownloaded(80, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [80])
        XCTAssertEqual(Array(task.downloadedChunks.values), [50])
        XCTAssertEqual(task.received, 50)
        
        _ = task.onNewChunkDownloaded(150, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [80, 150])
        XCTAssertEqual(Array(task.downloadedChunks.values), [50, 10])
        XCTAssertEqual(task.received, 60)
        
        _ = task.onNewChunkDownloaded(50, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [50, 80, 150])
        XCTAssertEqual(Array(task.downloadedChunks.values), [10, 50, 10])
        XCTAssertEqual(task.received, 70)

        _ = task.onNewChunkDownloaded(60, 20, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [50, 150])
        XCTAssertEqual(Array(task.downloadedChunks.values), [80, 10])
        XCTAssertEqual(task.received, 90)
        
        _ = task.onNewChunkDownloaded(130, 20, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [50])
        XCTAssertEqual(Array(task.downloadedChunks.values), [110])
        XCTAssertEqual(task.received, 110)
        
        _ = task.onNewChunkDownloaded(10, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [10, 50])
        XCTAssertEqual(Array(task.downloadedChunks.values), [10, 110])
        XCTAssertEqual(task.received, 120)
        
        _ = task.onNewChunkDownloaded(190, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [10, 50, 190])
        XCTAssertEqual(Array(task.downloadedChunks.values), [10, 110, 10])
        XCTAssertEqual(task.received, 130)
        
        _ = task.onNewChunkDownloaded(40, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [10, 40, 190])
        XCTAssertEqual(Array(task.downloadedChunks.values), [10, 120, 10])
        XCTAssertEqual(task.received, 140)
        
        _ = task.onNewChunkDownloaded(160, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [10, 40, 190])
        XCTAssertEqual(Array(task.downloadedChunks.values), [10, 130, 10])
        XCTAssertEqual(task.received, 150)
        
        _ = task.onNewChunkDownloaded(0, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [0, 40, 190])
        XCTAssertEqual(Array(task.downloadedChunks.values), [20, 130, 10])
        XCTAssertEqual(task.received, 160)
        
        _ = task.onNewChunkDownloaded(20, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [0, 40, 190])
        XCTAssertEqual(Array(task.downloadedChunks.values), [30, 130, 10])
        XCTAssertEqual(task.received, 170)
        
        _ = task.onNewChunkDownloaded(180, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [0, 40, 180])
        XCTAssertEqual(Array(task.downloadedChunks.values), [30, 130, 20])
        XCTAssertEqual(task.received, 180)
        
        _ = task.onNewChunkDownloaded(200, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [0, 40, 180])
        XCTAssertEqual(Array(task.downloadedChunks.values), [30, 130, 30])
        XCTAssertEqual(task.received, 190)
        
        _ = task.onNewChunkDownloaded(30, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [0, 180])
        XCTAssertEqual(Array(task.downloadedChunks.values), [170, 30])
        XCTAssertEqual(task.received, 200)
        
        _ = task.onNewChunkDownloaded(170, 10, data, from: "node_id")
        XCTAssertEqual(Array(task.downloadedChunks.keys), [0])
        XCTAssertEqual(Array(task.downloadedChunks.values), [210])
        XCTAssertEqual(task.received, 210)
    }
    
    func testCompare() {
        let task1 = DownloadTask(
            priority: 100, fileUuid: "fileUuid", objId: "objId",
            name: "test", size: 1024 * 10,
            hashsum: "hashsum", connectivityService: nil)
        XCTAssertTrue(task1 == task1)
        XCTAssertFalse(task1 != task1)
        XCTAssertFalse(task1 < task1)
        XCTAssertFalse(task1 > task1)
        XCTAssertTrue(task1 <= task1)
        XCTAssertTrue(task1 >= task1)
        
        let task1Copy = DownloadTask(
            priority: 100, fileUuid: "fileUuid", objId: "objId",
            name: "test", size: 1024 * 10,
            hashsum: "hashsum", connectivityService: nil)
        XCTAssertTrue(task1 == task1Copy)
        XCTAssertFalse(task1 != task1Copy)
        XCTAssertFalse(task1 < task1Copy)
        XCTAssertFalse(task1 > task1Copy)
        XCTAssertTrue(task1 <= task1Copy)
        XCTAssertTrue(task1 >= task1Copy)
        XCTAssertTrue(task1Copy == task1)
        XCTAssertFalse(task1Copy != task1)
        XCTAssertFalse(task1Copy < task1)
        XCTAssertFalse(task1Copy > task1)
        XCTAssertTrue(task1Copy <= task1)
        XCTAssertTrue(task1Copy >= task1)
        
        let task2 = DownloadTask(
            priority: 100, fileUuid: "fileUuid_2", objId: "objId_2",
            name: "test", size: 1024 * 10,
            hashsum: "hashsum", connectivityService: nil)
        XCTAssertTrue(task1 != task2)
        XCTAssertTrue(task2 != task1)
        XCTAssertFalse(task1 == task2)
        XCTAssertFalse(task2 == task1)
        XCTAssertFalse(task1 > task2)
        XCTAssertFalse(task1 >= task2)
        XCTAssertTrue(task2 > task1)
        XCTAssertTrue(task2 >= task1)
        XCTAssertTrue(task1 < task2)
        XCTAssertTrue(task1 <= task2)
        XCTAssertFalse(task2 < task1)
        XCTAssertFalse(task2 <= task1)
        let task3 = DownloadTask(
            priority: 100, fileUuid: "fileUuid_3", objId: "objId_3",
            name: "test", size: 1024 * 50,
            hashsum: "hashsum", connectivityService: nil)
        XCTAssertTrue(task1 != task3)
        XCTAssertTrue(task3 != task1)
        XCTAssertFalse(task1 == task3)
        XCTAssertFalse(task3 == task1)
        XCTAssertTrue(task1 < task3)
        XCTAssertTrue(task1 <= task3)
        XCTAssertFalse(task3 < task1)
        XCTAssertFalse(task3 <= task1)
        XCTAssertFalse(task1 > task3)
        XCTAssertFalse(task1 >= task3)
        XCTAssertTrue(task3 > task1)
        XCTAssertTrue(task3 >= task1)
        
        let task4 = DownloadTask(
            priority: 10, fileUuid: "fileUuid_4", objId: "objId_4",
            name: "test", size: 1024 * 10,
            hashsum: "hashsum", connectivityService: nil)
        XCTAssertTrue(task1 != task4)
        XCTAssertTrue(task4 != task1)
        XCTAssertFalse(task1 == task4)
        XCTAssertFalse(task4 == task1)
        XCTAssertTrue(task1 < task4)
        XCTAssertTrue(task1 <= task4)
        XCTAssertFalse(task4 < task1)
        XCTAssertFalse(task4 <= task1)
        XCTAssertFalse(task1 > task4)
        XCTAssertFalse(task1 >= task4)
        XCTAssertTrue(task4 > task1)
        XCTAssertTrue(task4 >= task1)
        
        let task5 = DownloadTask(
            priority: 100, fileUuid: "fileUuid_5", objId: "objId_5",
            name: "test", size: 1024 * 10,
            hashsum: "hashsum", connectivityService: nil)
        task5.received = 1024
        XCTAssertTrue(task1 != task5)
        XCTAssertTrue(task5 != task1)
        XCTAssertFalse(task1 == task5)
        XCTAssertFalse(task5 == task1)
        XCTAssertTrue(task1 > task5)
        XCTAssertTrue(task1 >= task5)
        XCTAssertFalse(task5 > task1)
        XCTAssertFalse(task5 >= task1)
        XCTAssertFalse(task1 < task5)
        XCTAssertFalse(task1 <= task5)
        XCTAssertTrue(task5 < task1)
        XCTAssertTrue(task5 <= task1)
    }
}
