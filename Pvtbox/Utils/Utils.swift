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
import TTGSnackbar

class ByteFormatter : ByteCountFormatter {
    public static let instance = ByteFormatter()
    override init() {
        super.init()
        allowsNonnumericFormatting = false
        countStyle = .binary
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class FileDateFormatter: DateFormatter {
    public static let instance = FileDateFormatter()
    
    override init() {
        super.init()
        dateStyle = .long
        timeStyle = .short
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TimeIntervalFormatter : DateComponentsFormatter {
    public static let MINUTE = 60
    public static let HOUR = MINUTE * 60
    public static let DAY = HOUR * 24
    public static let MONTH = DAY * 30
    public static let YEAR = MONTH * 12
    
    public static let instance = TimeIntervalFormatter()
    override init() {
        super.init()
        unitsStyle = .full
        allowsFractionalUnits = false
        zeroFormattingBehavior = .dropAll
        includesApproximationPhrase = false
        includesTimeRemainingPhrase = false
        maximumUnitCount = 1
        allowedUnits = [.year, .month, .day, .hour, .minute]
    }
    
    override func string(from ti: TimeInterval) -> String? {
        let ti = Int(ti)
        if ti > TimeIntervalFormatter.HOUR {
            if ti > TimeIntervalFormatter.DAY {
                if ti > TimeIntervalFormatter.MONTH {
                    if ti > TimeIntervalFormatter.YEAR {
                        return super.string(from: Double(ti / TimeIntervalFormatter.YEAR * TimeIntervalFormatter.YEAR))
                    } else {
                        return super.string(from: Double(ti / TimeIntervalFormatter.MONTH * TimeIntervalFormatter.MONTH))
                    }
                } else {
                    return super.string(from: Double(ti / TimeIntervalFormatter.DAY * TimeIntervalFormatter.DAY))
                }
            } else {
                return super.string(from: Double(ti / TimeIntervalFormatter.HOUR * TimeIntervalFormatter.HOUR))
            }
        } else {
            return super.string(from: Double(ti / TimeIntervalFormatter.MINUTE * TimeIntervalFormatter.MINUTE))
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class EmailValidator: NSObject {
    static func isValid(_ email: String) -> Bool {
        let emailRegex = ".+@.+\\.[a-z]+"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
}

func md5(fromString str: String) -> String {
    let data = str.data(using: String.Encoding.utf8)
    return hexStringFromData(input: md5(input: data! as NSData))
}

private func md5(input: NSData) -> NSData {
    let digestLength = Int(CC_MD5_DIGEST_LENGTH)
    var hash = [UInt8](repeating: 0, count: digestLength)
    CC_MD5(input.bytes, UInt32(input.length), &hash)
    return NSData(bytes: hash, length: digestLength)
}

func sha512(fromString str: String) -> String {
    let data = str.data(using: String.Encoding.utf8)
    return hexStringFromData(input: digest(input: data! as NSData))
}

private func digest(input: NSData) -> NSData {
    let digestLength = Int(CC_SHA512_DIGEST_LENGTH)
    var hash = [UInt8](repeating: 0, count: digestLength)
    CC_SHA512(input.bytes, UInt32(input.length), &hash)
    return NSData(bytes: hash, length: digestLength)
}

private func hexStringFromData(input: NSData) -> String {
    var bytes = [UInt8](repeating: 0, count: input.length)
    input.getBytes(&bytes, length: input.length)
    
    var hexString = ""
    for byte in bytes {
        hexString += String(format:"%02x", UInt8(byte))
    }
    
    return hexString
}

public func base64(fromString: String) -> String {
    let data = fromString.data(using: String.Encoding.utf8)
    return data?.base64EncodedString() ?? ""
}

extension String: Error {}
