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
//
// JASON+Alamofire.swift
//
// Copyright (c) 2015-2016 Damien (http://delba.io)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import JASON
import Alamofire

extension DataRequest {
    /**
     Creates a response serializer that returns a JASON.JSON object constructed from the response data.
     
     - returns: A JASON.JSON object response serializer.
     */
    static public func JASONReponseSerializer() -> DataResponseSerializer<JASON.JSON> {
        return DataResponseSerializer { _, _, data, error in
            guard error == nil else { return .failure(error!) }
            
            return .success(JASON.JSON(data))
        }
    }
    
    /**
     Adds a handler to be called once the request has finished.
     
     - parameter completionHandler: A closure to be executed once the request has finished.
     
     - returns: The request.
     */
    @discardableResult
    public func responseJASON(completionHandler: @escaping (DataResponse<JASON.JSON>) -> Void) -> Self {
        return response(responseSerializer: DataRequest.JASONReponseSerializer(), completionHandler: completionHandler)
    }
    
}
