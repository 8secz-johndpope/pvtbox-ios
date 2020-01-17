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
import TTGSnackbar

class SnackBarManager {
    private static let instance = SnackBarManager()
    private var snack: TTGSnackbar?
    
    public static func dismiss() {
        DispatchQueue.main.async {
            instance.snack?.dismiss()
        }
    }
    
    public static func showSnack(
        _ text: String, showNew: Bool = true, showForever: Bool = false,
        actionText: String? = nil, actionBlock: (() -> ())? = nil) {
        BFLog("SnackBarManager::showSnack")
        DispatchQueue.main.async {
            instance.showSnack(
                text, showNew: showNew, showForever: showForever,
                actionText: actionText, actionBlock: actionBlock)
        }
    }
    
    private func showSnack(
        _ text: String, showNew: Bool, showForever: Bool,
        actionText: String?, actionBlock: (() -> ())?) {
        let duration: TTGSnackbarDuration = showForever ? .forever : .middle
        if showNew {
            self.snack?.dismiss()
            self.snack = nil
        }
        if self.snack == nil {
            createSnack(text, duration)
        }
        self.snack?.message = text
        self.snack?.duration = duration
        if actionText != nil {
            self.snack?.actionText = actionText!
            self.snack?.actionBlock = { snack  in
                if snack == self.snack {
                    actionBlock?()
                }
            }
        }
        self.snack?.show()
    }
    
    private func createSnack(_ text: String, _ duration: TTGSnackbarDuration) {
        let snack = TTGSnackbar(message: text, duration: duration)
        if #available(iOS 13.0, *) {
            snack.backgroundColor = .systemBackground
            snack.messageTextColor = .secondaryLabel
            snack.actionTextColor = .secondaryLabel
        } else {
            snack.backgroundColor = .white
            snack.messageTextColor = .darkGray
            snack.actionTextColor = .darkGray
        }
        snack.animationType = .slideFromBottomBackToBottom
        snack.animationDuration = 0.6
        snack.shouldDismissOnSwipe = true
        snack.messageTextAlign = .center
        snack.bottomMargin = 54
        snack.dismissBlock = { [weak self] snack in
            if snack == self?.snack {
                self?.snack = nil
            }
        }
        self.snack = snack
    }
}
