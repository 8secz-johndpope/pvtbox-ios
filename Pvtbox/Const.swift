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
import UIKit

struct Const {
    static let serverAddress = "https://pvtbox.net"
    static let api = "/api/"
    static let rulesLink = serverAddress + "/terms?header-free=1"
    static let privacyPolicyLink = serverAddress + "/privacy?header-free=1"
    static let faqLink = serverAddress + "/faq?header-free=1"

    static let nodeName = String(UIDevice.current.name.prefix(30))
    static let nodeOsType = "iOS"
    static let nodeOsName = String(format: "iOS %@", UIDevice.current.systemVersion)
    static let nodeType = UIDevice.current.userInterfaceIdiom == .pad ? "tablet" : "phone"
    
    static let maxSizeForPreview = 10 * 1024 * 1024
    
    static let fileChunkSize = 1024 * 1024
    
    static let eventsPackSize = 100
    static let maxEventsTotal = eventsPackSize * 50
    
    static let unknownLicense = "UNKNOWN"
    static let freeLicense = "FREE_DEFAULT"
    static let trialLicense = "FREE_TRIAL"
    static let proLicense = "PAYED_PROFESSIONAL"
    static let businessLicense = "PAYED_BUSINESS_USER"
    static let businessAdminLicense = "PAYED_BUSINESS_ADMIN"
}
