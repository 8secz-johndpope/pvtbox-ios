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
import RealmSwift

class ShareRootSelectVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var emptyFolder: UILabel!
    @IBOutlet weak var foldersTV: UITableView!
    
    var root: FileRealm?
    private var realm: Realm?
    private var files: Results<FileRealm>!
    private var subscription: NotificationToken?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = root?.name ?? Strings.allFiles
        subscribe()
    }
    
    deinit {
        BFLog("ShareRootSelectVC::deinit")
        subscription?.invalidate()
        realm = nil
    }

    private func subscribe() {
        do {
            realm = try Realm()
        } catch {
            DispatchQueue.main.async(execute: subscribe)
            return
        }
        files = realm!.objects(FileRealm.self)
            .filter("isFolder = true")
        if self.root == nil {
            files = files.filter("parentUuid = nil")
        } else {
            files = files.filter("parentUuid = %@", self.root!.uuid!)
        }
        
        if PreferenceService.sortingByName {
            files = files.sorted(by: [SortDescriptor(keyPath: "name", ascending: true)])
        } else {
            files = files.sorted(by: [SortDescriptor(keyPath: "dateModified", ascending: false)])
        }
        
        subscription?.invalidate()
        subscription = files.observe { [weak self] (changes: RealmCollectionChange) in
            guard let tableView = self?.foldersTV else { return }
            switch changes {
            case .initial:
                break
            case .update(_, let deletions, let insertions, let modifications):
                tableView.beginUpdates()
                if !deletions.isEmpty {
                    tableView.deleteRows(
                        at: deletions.map({IndexPath(row: $0, section: 0)}), with: .none)
                }
                if !insertions.isEmpty {
                    tableView.insertRows(
                        at: insertions.map({IndexPath(row: $0, section: 0)}), with: .none)
                }
                if !modifications.isEmpty {
                    tableView.reloadRows(
                        at: modifications.map({IndexPath(row: $0, section: 0)}), with: .none)
                }
                tableView.endUpdates()
                self?.onFilesChanged()
            case .error(let error):
                BFLogErr("realm error: %@", String(describing: error))
            }
        }
        foldersTV.reloadData()
        onFilesChanged()
    }
    
    private func onFilesChanged() {
        if files.isEmpty {
            foldersTV.isHidden = true
            emptyFolder.isHidden = false
        } else {
            foldersTV.isHidden = false
            emptyFolder.isHidden = true
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let card = tableView.dequeueReusableCell(
            withIdentifier: "shareRootSelectCell", for: indexPath) as! ShareRootSelectCell
        card.displayContent(files[indexPath.item])
        return card
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let file = files?[indexPath.item],
            !file.isProcessing else { return }
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "shareRootSelectVC") as! ShareRootSelectVC
        vc.root = file
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @IBAction func addClicked(_ sender: Any) {
        let dialog = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(
            withIdentifier: "inputDialog") as! InputDialog
        dialog.setup(
            type: .createFolder,
            text: nil,
            realm: realm, root: root,
            onConfirmedInput: onCreateFolder,
            onCancelled: nil)
        present(dialog, animated: true, completion: nil)
    }
    
    private func onCreateFolder(_ name: String) {
        BFLog("ShareRootSelectVC::onCreateFolder, newName: %@", name)
        PvtboxService.addOperation(
            OperationService.OperationType.createFolder,
            root: root == nil ? nil : FileRealm(value: root!),
            newName: name)
    }
}
