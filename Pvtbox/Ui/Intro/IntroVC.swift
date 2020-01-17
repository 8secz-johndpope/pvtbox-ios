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

class IntroVC: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var skipButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    var pagesVC: UIPageViewController!
    
    var pages = [UIViewController]()
    
    var currentIndex: Int = 0
    private var pendingIndex: Int?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "pvc" {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            pages.append(storyboard.instantiateViewController(withIdentifier: "intro_slide1"))
            pages.append(storyboard.instantiateViewController(withIdentifier: "intro_slide2"))
            pages.append(storyboard.instantiateViewController(withIdentifier: "intro_slide3"))
            
            guard let pvc = segue.destination as? UIPageViewController else { return }
            pagesVC = pvc
            pagesVC.dataSource = self
            pagesVC.delegate = self
            pagesVC.setViewControllers([pages[0]], direction: .forward, animated: true, completion: nil)
        }
        super.prepare(for: segue, sender: sender)
    }
    
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentIndex = pages.firstIndex(of: viewController) else {
            return nil
        }
        return currentIndex - 1 >= 0 ? pages[currentIndex - 1] : nil
    }
    
    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentIndex = pages.firstIndex(of: viewController) else {
            return nil
        }
        return currentIndex + 1 < pages.count ? pages[currentIndex + 1] : nil
    }
    
    func pageViewController(
        _ pageViewController: UIPageViewController,
        willTransitionTo pendingViewControllers: [UIViewController]) {
        pendingIndex = pages.firstIndex(of: pendingViewControllers.first!)
        if let index = pendingIndex {
            setupButtons(index)
        }
    }
    
    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool) {
        if completed {
            if let index = pendingIndex {
                currentIndex = index
                pageControl.currentPage = index
            }
        }
    }

    @IBAction func skip() {
        let loginVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "loginvc") as! LoginVC
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.window?.rootViewController = loginVC
    }
    
    @IBAction func next() {
        let index = currentIndex + 1
        if index < pages.count {
            pagesVC.setViewControllers(
                [pages[index]], direction: .forward, animated: true, completion: {
                    [weak self] _ in
                    self?.currentIndex = index
                    self?.pageControl.currentPage = index
            })
            setupButtons(index)
        } else {
            skip()
        }
    }
    
    private func setupButtons(_ index: Int) {
        if index < pages.count - 1 {
            skipButton.isHidden = false
            nextButton.setTitle(Strings.next, for: .normal)
        } else {
            skipButton.isHidden = true
            nextButton.setTitle(Strings.gotIt, for: .normal)
        }
    }
}
