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

import UIKit
import JASON

class NotificationCell: UITableViewCell {

    @IBOutlet weak var message: UILabel!
    @IBOutlet weak var date: UILabel!
    
    public func displayContent(_ notification: JSON) {
        let d = Date(timeIntervalSince1970: notification["timestamp"].doubleValue)
        date.text = FileDateFormatter.instance.string(from: d)
        
        var text = notification["text"].stringValue
        let attributedText = NSMutableAttributedString(string: text)
        
        for (s, r) in zip(
                notification["search"].jsonArrayValue,
                notification["replace"].jsonArrayValue) {
            if let searchString = s.string,
                    let replaceString = r.string,
                    let range = text.range(of: searchString) {
                let location = range.lowerBound.utf16Offset(in: text)
                let length = range.upperBound.utf16Offset(in: text) - location
                attributedText.replaceCharacters(
                    in: NSRange(
                        location: location,
                        length: length),
                    with: NSAttributedString(
                        string: replaceString,
                        attributes: [.foregroundColor: UIColor.orange]))
                text = text.replacingCharacters(in: range, with: replaceString)
            }
        }
        
        if let range = text.range(of: "You ") {
            attributedText.addAttribute(
                .foregroundColor,
                value: UIColor.darkGreen,
                range: NSRange(
                    location: range.lowerBound.utf16Offset(in: text),
                    length: 3))
        }
        
        message.attributedText = attributedText
        if #available(iOS 13.0, *) {
            backgroundColor = notification["read"].boolValue ?
                .systemBackground : .secondarySystemBackground
        } else {
            backgroundColor = notification["read"].boolValue ?
                .white : .graySelection
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
