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
import MobileCoreServices
import UIKit

class FileTool {
    static let supportDirectory = try! FileManager.default.url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true)
    static let dbDirectory = supportDirectory
        .appendingPathComponent("db", isDirectory: true)
    static let copiesDirectory = supportDirectory
        .appendingPathComponent("copies", isDirectory: true)
    static let syncDirectory = try! FileManager.default.url(
        for: FileManager.SearchPathDirectory.documentDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: true)
    static let groupDirectory = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: "group.pvtbox.net")!
    static let shareGroupDirectory = groupDirectory
        .appendingPathComponent("share", isDirectory: true)
    static let addGroudDirectory = groupDirectory
        .appendingPathComponent("add", isDirectory: true)
    static let tmpDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
    
    public static func createDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: true, attributes: nil)
    }
    
    public static func createFile(_ url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(
                atPath: url.path, contents: nil, attributes: nil)
        }
    }
    
    public static func copy(from: URL, to: URL) {
        if !FileManager.default.fileExists(atPath: to.path) {
            try? FileManager.default.copyItem(at: from, to: to)
        }
    }
    
    public static func move(from: URL, to: URL) {
        if !FileManager.default.fileExists(atPath: to.path) {
            try? FileManager.default.moveItem(at: from, to: to)
        }
    }
    
    public static func makeLink(from: URL, to: URL) {
        try? FileManager.default.removeItem(at: to)
        try? FileManager.default.linkItem(at: from, to: to)
    }
    
    public static func exists(_ url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    public static func delete(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    public static func size(ofDirectory url: URL) -> Double {
        var size = 0.0
        let resourceKeys : [URLResourceKey] = [.totalFileSizeKey, .isDirectoryKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: resourceKeys, options: [],
            errorHandler: { (url, error) -> Bool in
                BFLogErr("FileTool::size directoryEnumerator error at %@: %@",
                         url.path, error.localizedDescription)
                return true
        }) else { return size }
        
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(
                forKeys: Set(resourceKeys)),
                let isDirectory = resourceValues.isDirectory,
                let totalFileSize = resourceValues.totalFileSize,
                !isDirectory else { continue }
            size += Double(totalFileSize)
        }
        return size
    }
    
    public static func size(ofFile url: URL) -> Double {
        let resourceKeys : [URLResourceKey] = [.totalFileSizeKey]
        guard let resourceValues = try? url.resourceValues(
                forKeys: Set(resourceKeys)),
            let totalFileSize = resourceValues.totalFileSize else { return 0.0 }
            return Double(totalFileSize)
    }
    
    public static func getFileHashViaSignature(_ url: URL) -> String? {
        return try? autoreleasepool {
            let handle = try FileHandle(forReadingFrom: url)
            defer {
                handle.closeFile()
            }
            
            let digestLength = Int(CC_MD5_DIGEST_LENGTH)
            
            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)
            while autoreleasepool(invoking: {
                let data = handle.readData(ofLength: Const.fileChunkSize)
                if data.count > 0 {
                    var hash = [UInt8](repeating: 0, count: digestLength)
                    data.withUnsafeBytes { ptr in
                        if let ptrAddr = ptr.baseAddress, ptr.count > 0 {
                            _ = CC_MD5(ptrAddr, numericCast(ptr.count), &hash)
                        }
                    }
                    let blockHash = hash.map { String(format: "%02hhx", $0) }.joined()
                    
                    let blockHashData = blockHash.data(using: .utf8)!
                    blockHashData.withUnsafeBytes { ptr in
                        if let ptrAddr = ptr.baseAddress, ptr.count > 0 {
                            _ = CC_MD5_Update(&context, ptrAddr, numericCast(blockHashData.count))
                        }
                    }
                    return true
                } else {
                    return false
                }
            }) {}
            var digest = Data(count: digestLength)
            digest.withUnsafeMutableBytes { ptr in
                if let ptrAddr = ptr.bindMemory(to: UInt8.self).baseAddress {
                    _ = CC_MD5_Final(ptrAddr, &context)
                }
            }
            
            let hexDigest = digest.map { String(format: "%02hhx", $0) }.joined()
            return hexDigest
        }
    }
    
    public static func getFileHashViaSignature(_ data: Data) -> String? {
        return autoreleasepool {
            let digestLength = Int(CC_MD5_DIGEST_LENGTH)
            
            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)
            var offset = 0
            while autoreleasepool(invoking: {
                let subData = data.subdata(
                    in: offset..<min(
                        offset + Const.fileChunkSize, data.count))
                if subData.count > 0 {
                    var hash = [UInt8](repeating: 0, count: digestLength)
                    subData.withUnsafeBytes { ptr in
                        if let ptrAddr = ptr.baseAddress, ptr.count > 0 {
                            _ = CC_MD5(ptrAddr, numericCast(ptr.count), &hash)
                        }
                    }
                    let blockHash = hash.map { String(format: "%02hhx", $0) }.joined()
                    
                    let blockHashData = blockHash.data(using: .utf8)!
                    blockHashData.withUnsafeBytes { ptr in
                        if let ptrAddr = ptr.baseAddress, ptr.count > 0 {
                            _ = CC_MD5_Update(&context, ptrAddr, numericCast(ptr.count))
                        }
                    }
                    return true
                } else {
                    return false
                }
            }) {
                offset += Const.fileChunkSize
                if offset >= data.count { break }
            }
            var digest = Data(count: digestLength)
            digest.withUnsafeMutableBytes { ptr in
                if let ptrAddr = ptr.bindMemory(to: UInt8.self).baseAddress {
                    _ = CC_MD5_Final(ptrAddr, &context)
                }
            }
            
            let hexDigest = digest.map { String(format: "%02hhx", $0) }.joined()
            return hexDigest
        }
    }
    
    public static func getFileHash(_ url: URL) -> String? {
        return try? autoreleasepool {
            let handle = try FileHandle(forReadingFrom: url)
            defer {
                handle.closeFile()
            }
            
            var context = CC_MD5_CTX()
            CC_MD5_Init(&context)
            while autoreleasepool(invoking: {
                let data = handle.readData(ofLength: Const.fileChunkSize)
                if data.count > 0 {
                    data.withUnsafeBytes { ptr in
                        if let ptrAddr = ptr.baseAddress, ptr.count > 0 {
                            _ = CC_MD5_Update(&context, ptrAddr, numericCast(ptr.count))
                        }
                    }
                    return true
                } else {
                    return false
                }
            }) {}
            var digest = Data(count: Int(CC_MD5_DIGEST_LENGTH))
            digest.withUnsafeMutableBytes { ptr in
                if let ptrAddr = ptr.bindMemory(to: UInt8.self).baseAddress {
                    _ = CC_MD5_Final(ptrAddr, &context)
                }
            }
        
            let hexDigest = digest.map { String(format: "%02hhx", $0) }.joined()
            return hexDigest
        }
    }
    
    public static func getParentPath(_ path: String) -> String? {
        var pathComponents = path.split(separator: "/")
        if pathComponents.count < 2 {
            return nil
        } else {
            guard let _ = pathComponents.popLast() else { fatalError() }
            return pathComponents.joined(separator: "/")
        }
    }
    
    public static func buildPath(_ parentPath: String?, _ fileName: String) -> String {
        return (parentPath == nil ? "" : parentPath! + "/") + fileName
    }
    
    public static func getNameFromPath(_ path: String) -> String {
        let url: URL = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }
    
    public static func getType(forFile file: FileRealm) -> String {
        if file.isFolder {
            return Strings.dir
        }
        guard let name = file.name else { return Strings.file }
        return getExtensionFromName(name)
    }
    
    private static func getExtensionFromName(_ name: String) -> String {
        guard let index = name.lastIndex(of: ".") else { return Strings.file }
        let suffix = name.suffix(from: name.index(after: index))
        if suffix.isEmpty {
            return "file"
        }
        return String(suffix)
    }
    
    public static func isImageOrVideoFile(_ fileName: String) -> Bool {
        let mimeType = mimeTypeForFileName(fileName: fileName)
        return mimeType.starts(with: "image") || mimeType.starts(with: "video")
    }
    
    public static func isImageFile(_ fileName: String) -> Bool {
        let mimeType = mimeTypeForFileName(fileName: fileName)
        return mimeType.starts(with: "image")
    }
    
    public static func mimeTypeForFileName(fileName: String) -> String {
        let url = NSURL(fileURLWithPath: fileName)
        let pathExtension = url.pathExtension
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?
                .takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(
                uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }
    
    public static func getIcon(forFile file: FileRealm) -> UIImage? {
        if file.isFolder {
            if file.isCollaborated {
                return UIImage(named: "folder_collaborated")
            } else {
                return UIImage(named: "folder")
            }
        } else {
            let type = FileTool.mimeTypeForFileName(fileName: file.name!)
            if type.starts(with: "audio") {
                return UIImage(named: "audio")
            } else if type.starts(with: "video") {
                return UIImage(named: "video")
            } else if type.starts(with: "image") {
                return UIImage(named: "image")
            } else if type.hasSuffix("zip") || type.hasSuffix("x-gzip") {
                return UIImage(named: "archive")
            } else if type.hasSuffix("excel") {
                return UIImage(named: "excel")
            } else if type.contains("wordprocessingml") || type.hasSuffix("msword") {
                return UIImage(named: "word")
            } else {
                BFLog("file format not recognized: %@", type)
                return UIImage(named: "file")
            }
        }
    }
    
    public static func getFileNameAndExtension(fromName name: String) -> (String, String) {
        var nameParts = name.split(separator: ".")
        switch nameParts.count {
        case 1:
            return (name, "")
        case 2:
            return (String(nameParts[0]), "." + String(nameParts[1]))
        default:
            var ext = "." + String(nameParts.popLast()!)
            ext = "." + String(nameParts.popLast()!) + ext
            let name = nameParts.joined(separator: ".")
            return (name, ext)
        }
    }
    
    public static func contents(of directoryUrl: URL) -> [URL] {
        return (try? FileManager.default.contentsOfDirectory(
            at: directoryUrl, includingPropertiesForKeys: nil)) ?? []
    }
}
