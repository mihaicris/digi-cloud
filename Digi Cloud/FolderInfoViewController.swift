//
//  FolderInfoViewController.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 02/11/16.
//  Copyright © 2016 Mihai Cristescu. All rights reserved.
//

import UIKit

class FolderInfoViewController: UITableViewController {

    // MARK: - Properties

    var onFinish: ((_ success: Bool, _ needRefresh: Bool) -> Void)?
    var location: Location
    var node: Node
    let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowsNonnumericFormatting = false
        f.countStyle = .binary
        return f
    }()
    fileprivate var rightBarButton: UIBarButtonItem!
    fileprivate var deleteButton: UIButton!
    fileprivate var noElementsLabel = UILabel()
    fileprivate var folderSizeLabel = UILabel()
    fileprivate var noElements: (Int?, Int?) = (nil, nil) {
        didSet {
            guard let files = noElements.0,
                let folders = noElements.1 else {
                    return
            }
            self.noElementsLabel = {
                let label = UILabel()
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineHeightMultiple = 1.3
                label.numberOfLines = 2

                let filesString = NSLocalizedString("%d files\n", comment: "Information")
                let text1 = String.localizedStringWithFormat(filesString, files)
                let folderString = NSLocalizedString("%d folders", comment: "Information")
                let text2 = String.localizedStringWithFormat(folderString, folders)
                let attributedText = NSMutableAttributedString(string: text1 + text2,
                                                               attributes: [NSParagraphStyleAttributeName: paragraph])
                label.attributedText = attributedText

                return label
            }()
            self.tableView.reloadRows(at: [IndexPath(row: 0, section: 2)], with: .automatic)
        }
    }
    fileprivate var folderSize: Int64? {
        didSet {
            if let size = self.folderSize {
                self.folderSizeLabel.text = self.sizeFormatter.string(fromByteCount: size)
                self.tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .automatic)
            }
        }
    }

    // MARK: - Initializers and Deinitializers

    init(location: Location, node: Node) {
        self.location = location
        self.node = node
        super.init(style: .grouped)
    }

    #if DEBUG
    deinit {
        print("[DEINIT]: " + String(describing: type(of: self)))
    }
    #endif

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Overridden Methods and Properties

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        updateFolderInfo()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:     return NSLocalizedString("Name",               comment: "TableCell Header Title")
        case 1:     return NSLocalizedString("Size",               comment: "TableCell Header Title")
        case 2:     return NSLocalizedString("Folder content", comment: "TableCell Header Title")
        default:    return ""
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 2:     return NSLocalizedString("Note: Including subfolders",     comment: "TableCell Footer Title")
        case 3:     return NSLocalizedString("This action is not reversible!", comment: "TableCell Footer Title")
        default:    return ""
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 2:     return 70
        default:    return UITableViewAutomaticDimension
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        // for last section with the Button Delete
        if section == 3 {
            (view as? UITableViewHeaderFooterView)?.textLabel?.textAlignment = .center
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        switch indexPath.section {
        // Folder name
        case 0:
            let folderIcon: UIImageView = {
                let imageView = UIImageView(image: UIImage(named: "FolderIcon"))
                imageView.contentMode = .scaleAspectFit
                return imageView
            }()

            let folderName: UILabel = {
                let label = UILabel()
                label.text = node.name
                return label
            }()

            cell.contentView.addSubview(folderIcon)
            cell.contentView.addSubview(folderName)
            cell.contentView.addConstraints(with: "H:|-20-[v0(26)]-12-[v1]-12-|", views: folderIcon, folderName)
            cell.contentView.addConstraints(with: "V:[v0(26)]", views: folderIcon)
            folderIcon.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor).isActive = true
            folderName.centerYAnchor.constraint(equalTo: folderIcon.centerYAnchor).isActive = true
        // Size
        case 1:
            cell.contentView.addSubview(folderSizeLabel)
            cell.contentView.addConstraints(with: "H:|-20-[v0]-20-|", views: folderSizeLabel)
            folderSizeLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor).isActive = true
        case 2:
            cell.contentView.addSubview(noElementsLabel)
            cell.contentView.addConstraints(with: "H:|-20-[v0]-|", views: noElementsLabel)
            noElementsLabel.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor, constant: -2).isActive = true
        case 3:
            deleteButton = UIButton(type: UIButtonType.system)
            deleteButton.layer.borderColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5).cgColor
            deleteButton.layer.backgroundColor = UIColor(red: 1, green: 0, blue: 0, alpha: 0.05).cgColor
            deleteButton.layer.cornerRadius = 8
            deleteButton.layer.borderWidth = 1 / UIScreen.main.scale * 1.2
            deleteButton.setTitle(NSLocalizedString("Delete Folder", comment: "Button Title, keep the leading/trailing spaces!"), for: .normal)
            deleteButton.sizeToFit()
            deleteButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 14)
            deleteButton.setTitleColor(.red, for: .normal)
            deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)

            //  constraints
            deleteButton.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(deleteButton)
            deleteButton.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor).isActive = true
            deleteButton.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor).isActive = true
            deleteButton.widthAnchor.constraint(equalToConstant: deleteButton.bounds.width + 40).isActive = true
        default:
            break
        }
        return cell
    }

    // MARK: - Helper Functions

    fileprivate func setupViews() {
        tableView.isScrollEnabled = false
        rightBarButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: "Button title"),
                                         style: .plain,
                                         target: self,
                                         action: #selector(handleDone))
        self.navigationItem.setRightBarButton(rightBarButton, animated: false)
        self.title = NSLocalizedString("Folder information", comment: "Window Title")
    }

    fileprivate func updateFolderInfo() {

        let folderPath = self.location.path + node.name

        let folderLocation = Location(mount: self.location.mount, path: folderPath)

        DigiClient.shared.getFolderInfo(location: folderLocation, completion: { (info, error) in
            guard error == nil else {
                print(error!.localizedDescription)
                return
            }
            self.folderSize = info.0
            self.noElements = (info.1, info.2)
        })
    }

    @objc fileprivate func handleDone() {
        onFinish?(false, false)
    }

    @objc fileprivate func handleDelete() {
        let controller = DeleteViewController(node: node)
        controller.delegate = self
        controller.modalPresentationStyle = .popover
        controller.popoverPresentationController?.permittedArrowDirections = .up
        controller.popoverPresentationController?.sourceView = deleteButton
        controller.popoverPresentationController?.sourceRect = deleteButton.bounds
        present(controller, animated: true, completion: nil)
    }
}

extension FolderInfoViewController: DeleteViewControllerDelegate {
    func onConfirmDeletion() {

        // Dismiss DeleteAlertViewController
        dismiss(animated: true) {

            let nodePath = self.location.path + self.node.name

            // network request for delete

            let deleteLocation = Location(mount: self.location.mount, path: nodePath)
            DigiClient.shared.deleteNode(at: deleteLocation) { (statusCode, error) in

                // TODO: Stop spinner
                guard error == nil else {
                    // TODO: Show message for error
                    print(error!.localizedDescription)
                    return
                }
                if let code = statusCode {
                    switch code {
                    case 200:
                        // Delete successfully completed
                        self.onFinish?(true, true)
                    case 400:
                        // TODO: Alert Bad Request
                        self.onFinish?(false, true)
                    case 404:
                        // File not found, folder will be refreshed
                        self.onFinish?(false, true)
                    default :
                        // TODO: Alert Status Code server
                        self.onFinish?(false, false)
                        return
                    }
                }
            }
        }
    }
}

