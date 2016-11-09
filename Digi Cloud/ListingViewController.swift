//
//  FilesTableViewController.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 19/09/16.
//  Copyright © 2016 Mihai Cristescu. All rights reserved.
//

import UIKit

class ListingViewController: UITableViewController {

    enum Sorting {
        case ascending
        case descending
    }
    // MARK: - Properties

    var content: [File] = []
    let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale.current
        f.dateFormat = "dd.MM.YYY・HH:mm"
        return f
    }()
    let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        return f
    }()

    internal var currentIndex: IndexPath!

    // MARK: - View Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(FileCell.self, forCellReuseIdentifier: "FileCell")
        tableView.register(DirectoryCell.self, forCellReuseIdentifier: "DirectoryCell")
        tableView.cellLayoutMarginsFollowReadableWidth = false
        tableView.rowHeight = AppSettings.tableViewRowHeight
        setupViews()
        getFolderContent()
    }

    fileprivate func setupViews() {
        let sortButton      = UIBarButtonItem(title: "Sort", style: UIBarButtonItemStyle.plain, target: self, action: #selector(handleSortSelect))
        let addFolderButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.add, target: self, action: #selector(handleAddFolder))
        navigationItem.rightBarButtonItems = [addFolderButton, sortButton]
    }

    func toggleRightBarButtonsActive() {
        guard let buttons = navigationItem.rightBarButtonItems else {
            return
        }
        for button in buttons {
            button.isEnabled = !button.isEnabled
        }
    }

    @objc fileprivate func handleSortSelect() {
        print(123)
    }
    @objc fileprivate func handleAddFolder() {
        let controller = CreateFolderViewController()
        controller.onFinish = { [weak self] (folderName) in
            if let vc = self {
                DispatchQueue.main.async {
                    vc.dismiss(animated: true, completion: nil) // dismiss AddFolderViewController
                    if folderName != nil {
                        vc.getFolderContent()
                    } else {
                        return // Cancel
                    }
                }
            }
        }
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .formSheet
        navigationController.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(navigationController, animated: true, completion: nil)
    }

    // TODO: Implement sorting filters in the interface
    internal func sortContent() {

        // check settings and choose appropriate sorting function name/size/date
        sortByName(directoryFirst: true, direction: .ascending)
    }

    fileprivate func sortByName(directoryFirst: Bool, direction: Sorting) {
        self.content.sort {
            if directoryFirst {
                if direction == .ascending {
                    // Order items by name (ascending), directories are shown first
                    return $0.type == $1.type ? ($0.name.lowercased() < $1.name.lowercased()) : ($0.type < $1.type)
                } else {
                    return $0.type == $1.type ? ($0.name.lowercased() > $1.name.lowercased()) : ($0.type < $1.type)
                }
            } else {
                //  Order items by name (ascending)
                if direction == .ascending {
                    return $0.name.lowercased() < $1.name.lowercased()
                } else {
                    return $0.name.lowercased() > $1.name.lowercased()
                }
            }
        }
    }

    fileprivate func sortByDate(directoryFirst: Bool, direction: Sorting) {

        // TODO: Implement sort by date
        /* Order items by Date (descending), directories are shown first */
        // return $0.type == $1.type && $0.type != "dir" ? ($0.modified > $1.modified) : ($0.type < $1.type)
    }

    fileprivate func sortBySize(directoryFirst: Bool, direction: Sorting) {
        // TODO: Implement sort by size
    }

    func getFolderContent() {
        toggleRightBarButtonsActive()
        DigiClient.shared.getLocationContent(mount: DigiClient.shared.currentMount, queryPath: DigiClient.shared.currentPath.last!) {
            (content, error) in
            guard error == nil else {
                print("Error: \(error?.localizedDescription)")
                return
            }
            self.content = content ?? []
            self.sortContent()
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.toggleRightBarButtonsActive()
            }
        }
    }

    func animateActionButton(active: Bool) {
        let actionButton = (tableView.cellForRow(at: currentIndex) as! BaseListCell).actionButton
        let transform = active ? CGAffineTransform.init(rotationAngle: CGFloat(M_PI)) : CGAffineTransform.identity
        let color: UIColor = active ? .black : .darkGray
        actionButton.setTitleColor(color, for: .normal)
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: UIViewAnimationOptions.curveEaseOut, animations: {
            actionButton.transform = transform
        }, completion: nil)
    }

    // MARK: - Table View Data Source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let data = content[indexPath.row]

        if data.type == "dir" {
            let cell = tableView.dequeueReusableCell(withIdentifier: "DirectoryCell", for: indexPath) as! DirectoryCell
            cell.delegate = self

            cell.folderNameLabel.text = data.name

            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "FileCell", for: indexPath) as! FileCell
            cell.delegate = self

            let modifiedDate = dateFormatter.string(from: Date(timeIntervalSince1970: data.modified/1000))
            cell.fileNameLabel.text = data.name

            let fileSizeString = byteFormatter.string(fromByteCount: data.size) + "・" + modifiedDate
            cell.fileSizeLabel.text = fileSizeString

            return cell
        }
    }

    // MARK: - Table view delegate

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: false)

        let itemName = content[indexPath.row].name
        let previousPath = DigiClient.shared.currentPath.last!

        if content[indexPath.row].type == "dir" {
            // This is a Folder
            let controller = ListingViewController()
            controller.title = itemName

            let folderPath = previousPath + itemName + "/"
            DigiClient.shared.currentPath.append(folderPath)

            navigationController?.pushViewController(controller, animated: true)

        } else {
            // This is a file
            let controller = ContentViewController()
            controller.title = itemName

            let filePath = previousPath + itemName
            DigiClient.shared.currentPath.append(filePath)

            navigationController?.pushViewController(controller, animated: true)
        }
    }

    deinit {
        DigiClient.shared.currentPath.removeLast()
        #if DEBUG
            print("FilesTableViewController deinit")
        #endif
    }
}

extension ListingViewController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        self.animateActionButton(active: false)
        return true
    }
}

