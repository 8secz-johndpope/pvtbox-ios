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

// MIT licence. Copyright © 2018 Simon Strandgaard. All rights reserved.
import Foundation

extension URL {
    /// SwiftyRelativePath: Creates a path between two paths
    ///
    ///     let u1 = URL(fileURLWithPath: "/Users/Mozart/Music/Nachtmusik.mp3")!
    ///     let u2 = URL(fileURLWithPath: "/Users/Mozart/Documents")!
    ///     u1.relativePath(from: u2)  // "../Music/Nachtmusik.mp3"
    ///
    /// Case (in)sensitivity is not handled.
    ///
    /// It is assumed that given URLs are absolute. Not relative.
    ///
    /// This method doesn't access the filesystem. It assumes no symlinks.
    ///
    /// `"."` and `".."` in the given URLs are removed.
    ///
    /// - Parameter base: The `base` url must be an absolute path to a directory.
    ///
    /// - Returns: The returned path is relative to the `base` path.
    ///
    public func relativePath(from base: URL) -> String? {
        // Original code written by Martin R. https://stackoverflow.com/a/48360631/78336
        
        // Ensure that both URLs represent files
        guard self.isFileURL && base.isFileURL else {
            return nil
        }
        
        // Ensure that it's absolute paths. Ignore relative paths.
        guard self.baseURL == nil && base.baseURL == nil else {
            return nil
        }
        
        let relPath = self.path.replacingOccurrences(of: base.path, with: "")
        if relPath.hasPrefix("/") {
            return String(relPath.dropFirst())
        } else {
            return nil
        }
    }
}
