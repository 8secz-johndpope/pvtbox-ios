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

class DeviceStatusFormatter {
    public static func stringAndColor(_ deviceStatus: Int) -> (String, UIColor) {
        switch deviceStatus {
        case 4:
            return (Strings.synced, .darkGreen)
        case 5:
            if #available(iOS 13.0, *) {
                return (Strings.loggedOut, .tertiaryLabel)
            } else {
                return (Strings.loggedOut, .lightGray)
            }
        case 6:
            if #available(iOS 13.0, *) {
                return (Strings.wiped, .tertiaryLabel)
            } else {
                return (Strings.wiped, .lightGray)
            }
        case 7:
            if #available(iOS 13.0, *) {
                return (Strings.powerOff, .tertiaryLabel)
            } else {
                return (Strings.powerOff, .lightGray)
            }
        case 8:
            return (Strings.paused, .orange)
        case 9:
            return (Strings.indexing, .orange)
        case 10:
            if #available(iOS 13.0, *) {
                return (Strings.connecting, .tertiaryLabel)
            } else {
                return (Strings.connecting, .lightGray)
            }
        default:
            return (Strings.syncing, .orange)
        }
    }
}
