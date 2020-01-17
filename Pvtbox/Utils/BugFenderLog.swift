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

public func BFLogWarn(_ format: String, _ args: CVarArg..., tag: String? = nil, level: BFLogLevel = .warning, filename: String = #file, line: Int = #line, funcname: String = #function)
{
    let message = String(format: format, arguments: args)
    Bugfender.log(lineNumber: line, method: funcname, file: filename, level: level, tag: tag, message: message)
}

public func BFLogErr(_ format: String, _ args: CVarArg..., tag: String? = nil, level: BFLogLevel = .error, filename: String = #file, line: Int = #line, funcname: String = #function)
{
    let message = String(format: format, arguments: args)
    Bugfender.log(lineNumber: line, method: funcname, file: filename, level: level, tag: tag, message: message)
}
