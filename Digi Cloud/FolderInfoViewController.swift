//
//  FolderInfoViewController.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 02/11/16.
//  Copyright © 2016 Mihai Cristescu. All rights reserved.
//

import UIKit

class FolderInfoViewController: UITableViewController {
    var onFinish: (() -> Void)?

    fileprivate var element: File
    fileprivate var rightBarButton: UIBarButtonItem!
    fileprivate var messageLabel: UILabel!
    fileprivate var deleteButton: UIButton!

    init(element: File) {
        self.element = element
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        updateFolderSize()
    }

    fileprivate func updateFolderSize() {
        //build the path of element to be renamed
        let elementPath = DigiClient.shared.currentPath.last! + element.name

        DigiClient.shared.getFolderSize(path: elementPath, completionHandler: { (size, error) in
            print(size ?? "nil")
        })

    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 200 : 80
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none

        if indexPath.section == 0 {
            let folderIcon: UIImageView = {
                let imageName = element.type == "dir" ? "FolderIcon" : "FileIcon"
                let imageView = UIImageView(image: UIImage(named: imageName))
                imageView.contentMode = .scaleAspectFit
                return imageView
            }()

            let folderName: UILabel = {
                let label = UILabel()
                label.text = element.name
                return label
            }()

            cell.contentView.addSubview(folderIcon)
            cell.contentView.addSubview(folderName)
            cell.contentView.addConstraints(with: "H:|-20-[v0(26)]-12-[v1]-12-|", views: folderIcon, folderName)
            cell.contentView.addConstraints(with: "V:|-20-[v0(26)]", views: folderIcon)
            cell.contentView.addConstraints(with: "V:|-20-[v0]", views: folderName)

        } else {
            deleteButton = UIButton(type: UIButtonType.system)
            deleteButton.layer.borderColor = UIColor.red.cgColor
            deleteButton.layer.cornerRadius = 5
            deleteButton.layer.borderWidth = 1/UIScreen.main.scale
            deleteButton.setTitle(NSLocalizedString("  Delete Folder  ", comment: "Title for Button"), for: .normal)
            deleteButton.setTitleColor(.red, for: .normal)
            deleteButton.setTitleColor(.gray, for: .disabled)
            deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)

            //constraints
            deleteButton.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(deleteButton)
            deleteButton.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor).isActive = true
            deleteButton.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor).isActive = true
        }
        return cell
    }

//    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
//        if section == 1 {
//            let footerView = UIView(frame: CGRect(x: 0, y: 0, width: 300, height: 300))
//            footerView.backgroundColor = .magenta
//            return footerView
//        } else {
//            return nil
//        }
//    }

    fileprivate func setupViews() {

        messageLabel = {
            let label = UILabel()
            label.textAlignment = .center
            label.text = "Test"
            label.font = UIFont.systemFont(ofSize: 14)
            label.textColor = .darkGray
            label.alpha = 1
            return label
        }()

        tableView.isScrollEnabled = false

        rightBarButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(handleDone))
        self.navigationItem.setRightBarButton(rightBarButton, animated: false)

        self.title = NSLocalizedString("Folder information", comment: "Title")
    }

    @objc fileprivate func handleDone() {
        onFinish?()
    }

    @objc fileprivate func handleDelete() {
        deleteButton.isEnabled = false
    }

    #if DEBUG
    deinit {
        print("FolderInfoViewController deinit")
    }
    #endif
}
