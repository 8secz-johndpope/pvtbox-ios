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
import WebKit
import NVActivityIndicatorView

class WebVC: UIViewController, WKNavigationDelegate {
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var errorView: UIView!
    
    var header: String!
    var url: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = header
        webView.navigationDelegate = self
        load()
    }
    
    private func load() {
        let activityData = ActivityData(type: .lineSpinFadeLoader, color: .orange)
        errorView.isHidden = true
        NVActivityIndicatorPresenter.sharedInstance.startAnimating(activityData, nil)
        webView.load(URLRequest(url: url))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        BFLog("FaqVC::webView didFinish")
        NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
        errorView.isHidden = true
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        BFLog("FaqVC::webView didFail")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
            NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
            self?.errorView.isHidden = false
        })
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        BFLog("FaqVC::webView didFailProvisionalNavigation")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
            NVActivityIndicatorPresenter.sharedInstance.stopAnimating(nil)
            self?.errorView.isHidden = false
        })
    }
    
    @IBAction func retry(_ sender: Any) {
        load()
    }
}
