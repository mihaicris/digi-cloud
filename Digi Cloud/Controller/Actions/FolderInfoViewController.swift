//
//  FolderInfoViewController.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 02/11/16.
//  Copyright © 2016 Mihai Cristescu. All rights reserved.
//

import UIKit

final class FolderInfoViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    // MARK: - Properties

    var onFinish: (() -> Void)?

    private var location: Location

    private let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowsNonnumericFormatting = false
        formatter.countStyle = .binary
        return formatter
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: CGRect.zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    private var rightBarButton: UIBarButtonItem!
    private var deleteButton: UIButton!
    private var noElementsLabel = UILabel()
    private var folderSizeLabel = UILabel()

    private var folderInfo = FolderInfo() {
        didSet {
            self.noElementsLabel = {
                let label = UILabel()
                let paragraph = NSMutableParagraphStyle()
                paragraph.lineHeightMultiple = 1.3
                label.numberOfLines = 2

                let filesString: String
                if folderInfo.files == 1 {
                    filesString = NSLocalizedString("1 file\n", comment: "")
                } else {
                    filesString = NSLocalizedString("%d files\n", comment: "")
                }

                let foldersString: String
                if folderInfo.folders == 1 {
                    foldersString = NSLocalizedString("1 folder", comment: "")
                } else {
                    foldersString = NSLocalizedString("%d folders", comment: "")
                }

                let text1 = String.localizedStringWithFormat(filesString, folderInfo.files)
                let text2 = String.localizedStringWithFormat(foldersString, folderInfo.folders)
                let attributedText = NSMutableAttributedString(string: text1 + text2,
                                                               attributes: [NSAttributedStringKey.paragraphStyle: paragraph])
                label.attributedText = attributedText

                return label
            }()
            self.folderSizeLabel.text = self.sizeFormatter.string(fromByteCount: folderInfo.size)
            self.tableView.reloadData()
        }
    }

    private var errorMessageVerticalConstraint: NSLayoutConstraint?

    private lazy var waitingView: UIView = {

        let view = UIView()

        view.isHidden = false

        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false

        let spinner: UIActivityIndicatorView = {
            let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            activityIndicator.hidesWhenStopped = true
            activityIndicator.tag = 55
            activityIndicator.startAnimating()
            return activityIndicator
        }()

        let okButton: UIButton = {
            let button = UIButton(type: UIButtonType.system)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setTitle(NSLocalizedString("OK", comment: ""), for: UIControlState.normal)
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 10
            button.contentEdgeInsets = UIEdgeInsets(top: 2, left: 40, bottom: 2, right: 40)
            button.sizeToFit()
            button.backgroundColor = UIColor(red: 0.7, green: 0.7, blue: 0.9, alpha: 1)
            button.tag = 11
            button.isHidden = false
            button.addTarget(self, action: #selector(handleHideWaitingView), for: .touchUpInside)
            return button
        }()

        let label: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.textColor = .gray
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 14)
            label.tag = 99
            label.numberOfLines = 0
            return label
        }()

        view.addSubview(spinner)
        view.addSubview(label)
        view.addSubview(okButton)

        self.errorMessageVerticalConstraint = label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 40)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            self.errorMessageVerticalConstraint!,
            okButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            okButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 40)
            ])

        return view
    }()

    // MARK: - Initializers and Deinitializers

    init(location: Location) {
        self.location = location
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Overridden Methods and Properties

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        configureWaitingView(type: .started, message: NSLocalizedString("Please wait...", comment: ""))
        updateFolderInfo()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return location.mount.canWrite ? 4 : 3

    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:     return NSLocalizedString("Name", comment: "")
        case 1:     return NSLocalizedString("Size", comment: "")
        case 2:     return NSLocalizedString("Folder content", comment: "")
        default:    return ""
        }
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 2:     return NSLocalizedString("Note: Including subfolders", comment: "")
        case 3:     return NSLocalizedString("This action is not reversible.", comment: "")
        default:    return ""
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 2:     return 70
        case 3:     return AppSettings.tableViewRowHeight
        default:    return AppSettings.textFieldRowHeight
        }
    }

    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        // for last section with the Button Delete
        if section == 3 {
            (view as? UITableViewHeaderFooterView)?.textLabel?.textAlignment = .center
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        switch indexPath.section {
        // Folder name
        case 0:
            let folderIcon: UIImageView = {
                let imageView = UIImageView(image: #imageLiteral(resourceName: "folder_icon"))
                imageView.contentMode = .scaleAspectFit
                return imageView
            }()

            let folderName: UILabel = {
                let label = UILabel()
                label.text = (self.location.path as NSString).lastPathComponent
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
            deleteButton.layer.borderWidth = (1 / UIScreen.main.scale) * 1.2
            deleteButton.setTitle(NSLocalizedString("Delete Folder", comment: ""), for: .normal)
            deleteButton.contentEdgeInsets = UIEdgeInsets(top: 7, left: 15, bottom: 7, right: 15)
            deleteButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
            deleteButton.setTitleColor(.red, for: .normal)
            deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)

            //  constraints
            deleteButton.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(deleteButton)
            NSLayoutConstraint.activate([
                deleteButton.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                deleteButton.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])
        default:
            break
        }
        return cell
    }

    // MARK: - Helper Functions

    private func setupViews() {

        view.addSubview(tableView)
        view.addSubview(waitingView)

        NSLayoutConstraint.activate([

            waitingView.topAnchor.constraint(equalTo: view.topAnchor),
            waitingView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            waitingView.leftAnchor.constraint(equalTo: view.leftAnchor),
            waitingView.rightAnchor.constraint(equalTo: view.rightAnchor),

            tableView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leftAnchor.constraint(equalTo: view.leftAnchor),
            tableView.rightAnchor.constraint(equalTo: view.rightAnchor)
        ])

        rightBarButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""),
                                         style: .done,
                                         target: self,
                                         action: #selector(handleDone))
        self.navigationItem.setRightBarButton(rightBarButton, animated: false)
        self.title = NSLocalizedString("Folder information", comment: "")
    }

    private func updateFolderInfo() {

        DigiClient.shared.getFolderInfo(at: self.location, completion: { (info, error) in
            guard error == nil else {

                var errorMessage: String

                switch error! {
                case NetworkingError.internetOffline(let message), NetworkingError.requestTimedOut(let message):
                    errorMessage = message
                default:
                    errorMessage = NSLocalizedString("There was an error while calculating the folder size.", comment: "")
                }

                self.configureWaitingView(type: .stopped, message: errorMessage)

                return
            }
            if let info = info {
                self.folderInfo = info
                self.configureWaitingView(type: .hidden, message: "")
            } else {
                self.configureWaitingView(type: .stopped, message: NSLocalizedString("There was an error while calculating the folder size.", comment: ""))

            }
        })
    }

    private func configureWaitingView(type: WaitingType, message: String) {

        switch type {
        case .hidden:
            waitingView.isHidden = true

        case .started, .stopped:
            waitingView.isHidden = false

            navigationController?.isToolbarHidden = true

            if let waitView = waitingView.viewWithTag(55) as? UIActivityIndicatorView,
                let button = waitingView.viewWithTag(11) as? UIButton {
                if type == .started {
                    waitView.startAnimating()
                    errorMessageVerticalConstraint?.constant = 40
                    button.isHidden = true
                } else {
                    waitView.stopAnimating()
                    button.isHidden = false
                    errorMessageVerticalConstraint?.constant = 0
                }
            }

            if let waitView = waitingView.viewWithTag(99) as? UILabel {
                waitView.text = message
            }
        }
    }

    @objc func handleHideWaitingView(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }

    @objc private func handleDone() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc private func handleDelete() {
        let controller = DeleteViewController(isFolder: true)

        controller.onSelection = { [weak self] in
            self?.dismiss(animated: true) {
                self?.onFinish?()
            }
        }

        if let horizontalSizeClass = navigationController?.presentingViewController?.traitCollection.horizontalSizeClass,
            horizontalSizeClass == .regular {
            controller.modalPresentationStyle = .popover
            controller.popoverPresentationController?.permittedArrowDirections = .up
            controller.popoverPresentationController?.sourceView = deleteButton
            controller.popoverPresentationController?.sourceRect = deleteButton.bounds
            present(controller, animated: true, completion: nil)
        } else {
            let navController = UINavigationController(rootViewController: controller)
            present(navController, animated: true, completion: nil)
        }
    }
}
