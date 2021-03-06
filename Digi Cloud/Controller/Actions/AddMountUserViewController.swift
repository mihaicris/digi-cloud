//
//  AddMountUserViewController.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 12/03/2017.
//  Copyright © 2017 Mihai Cristescu. All rights reserved.
//

import UIKit

class AddMountUserViewController: UITableViewController, UITextFieldDelegate {

    var onUpdatedUser: (() -> Void)?
    var user: User

    let isUserEdited: Bool

    enum PermissionType: Int {
        case write
        case createLink
        case createReicever
        case mount
    }

    var permissions: [PermissionType] = []

    private let mount: Mount

    private lazy var saveMemberButton: UIButton = {
        let button = UIButton(type: UIButtonType.contactAdd)
        button.addTarget(self, action: #selector(handleSaveMember), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var usernameTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = NSLocalizedString("Email address", comment: "")
        textField.clearButtonMode = .whileEditing
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.keyboardType = .emailAddress
        textField.returnKeyType = .send
        textField.delegate = self
        textField.addTarget(self, action: #selector(handleTextFieldChange), for: .editingChanged)
        return textField
    }()

    let permissionWriteSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.translatesAutoresizingMaskIntoConstraints = false
        uiSwitch.tag = PermissionType.write.rawValue
        uiSwitch.addTarget(self, action: #selector(handleUpdateUserPermissions(_:)), for: .valueChanged)
        return uiSwitch
    }()

    let permissionCreateLinkSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.translatesAutoresizingMaskIntoConstraints = false
        uiSwitch.tag = PermissionType.createLink.rawValue
        uiSwitch.addTarget(self, action: #selector(handleUpdateUserPermissions(_:)), for: .valueChanged)
        return uiSwitch
    }()

    let permissionCreateReceiverSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.translatesAutoresizingMaskIntoConstraints = false
        uiSwitch.tag = PermissionType.createReicever.rawValue
        uiSwitch.addTarget(self, action: #selector(handleUpdateUserPermissions(_:)), for: .valueChanged)
        return uiSwitch
    }()

    let permissionManageShareSwitch: UISwitch = {
        let uiSwitch = UISwitch()
        uiSwitch.translatesAutoresizingMaskIntoConstraints = false
        uiSwitch.tag = PermissionType.mount.rawValue
        uiSwitch.addTarget(self, action: #selector(handleUpdateUserPermissions(_:)), for: .valueChanged)
        return uiSwitch
    }()

    init(mount: Mount, user: User? = nil) {
        self.mount = mount

        if let user = user {
            isUserEdited = true
            self.user = user
        } else {
            isUserEdited = false
            self.user = User(identifier: "", firstName: "", lastName: "", email: "", permissions: Permissions())
        }

        super.init(style: .grouped)

        self.permissions.append(contentsOf: mount.permissions.write ? [.write] : [])
        self.permissions.append(contentsOf: mount.permissions.createLink ? [.createLink] : [])
        self.permissions.append(contentsOf: mount.permissions.createReceiver ? [.createReicever] : [])
        self.permissions.append(contentsOf: mount.permissions.mount ? [.mount] : [])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Add member", comment: "")
        let saveMemberButton = UIBarButtonItem(title: NSLocalizedString("Save", comment: ""),
                                               style: .done, target: self, action: #selector(handleSaveMember))
        navigationItem.rightBarButtonItem = saveMemberButton
        navigationController?.isToolbarHidden = true
        tableView.rowHeight = AppSettings.tableViewRowHeight
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.usernameTextField.becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        navigationController?.isToolbarHidden = false
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : permissions.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? nil : NSLocalizedString("PERMISSIONS", comment: "")
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = UITableViewCell()
        cell.selectionStyle = .none

        if indexPath.section == 0 {

            cell.selectionStyle = .none
            cell.contentView.addSubview(usernameTextField)

            if isUserEdited {
                usernameTextField.text = user.email
                usernameTextField.isUserInteractionEnabled = false
            }

            NSLayoutConstraint.activate([
                usernameTextField.leftAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leftAnchor),
                usernameTextField.rightAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.rightAnchor),
                usernameTextField.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])

            return cell

        } else {

            let permissionType = permissions[indexPath.row]

            var aSwitch: UISwitch
            var permissionTitle: String

            switch permissionType {

            case .write:
                aSwitch = permissionWriteSwitch
                aSwitch.isOn = user.permissions.write
                permissionTitle = NSLocalizedString("Can modify", comment: "")

            case .createLink:
                aSwitch = permissionCreateLinkSwitch
                aSwitch.isOn = user.permissions.createLink
                permissionTitle = NSLocalizedString("Can create download links", comment: "")

            case .createReicever:
                aSwitch = permissionCreateReceiverSwitch
                aSwitch.isOn = user.permissions.createReceiver
                permissionTitle = NSLocalizedString("Can create receive links", comment: "")

            case .mount:
                aSwitch = permissionManageShareSwitch
                aSwitch.isOn = user.permissions.mount
                aSwitch.onTintColor = UIColor(red: 0.40, green: 0.43, blue: 0.98, alpha: 1.0)
                permissionTitle = NSLocalizedString("Can manage share", comment: "")
            }

            cell.textLabel?.text = permissionTitle
            cell.contentView.addSubview(aSwitch)

            NSLayoutConstraint.activate([
                aSwitch.rightAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.rightAnchor),
                aSwitch.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
            ])

        }

        return cell
    }

    @objc private func handleUpdateUserPermissions(_ sender: UISwitch) {

        guard let permissionType = PermissionType(rawValue: sender.tag) else {
            return
        }

        switch permissionType {
        case .write:
            user.permissions.write = sender.isOn
        case .mount:
            user.permissions.mount = sender.isOn
        case .createLink:
            user.permissions.createLink = sender.isOn
        case .createReicever:
            user.permissions.createReceiver = sender.isOn
        }
    }

    @objc private func handleSaveMember() {

        usernameTextField.resignFirstResponder()

        guard let username = usernameTextField.text, username.count > 3 else {

            self.showAlert(message: NSLocalizedString("Please provide the email address of the Digi Storage user.", comment: ""))

            return
        }

        if isUserEdited {

            DigiClient.shared.updateMount(mount: mount, operation: .updatePermissions, user: user, completion: { _, error in

                guard error == nil else {
                    self.showAlert(message: NSLocalizedString("Could not update member permissions.", comment: ""))

                    return
                }

                self.onUpdatedUser?()
            })

        } else {
            DigiClient.shared.updateMount(mount: mount, operation: .add, user: user) { newUser, error in

                guard error == nil else {

                    self.showAlert(message: NSLocalizedString("Could not add new member.", comment: ""))

                    return
                }
                if newUser != nil {
                    self.onUpdatedUser?()
                }
            }
        }

    }

    @objc private func handleTextFieldChange() {
        if let email = usernameTextField.text {
            self.user.email = email
        }
    }

    private func showAlert(message: String) {

        let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""),
                                      message: message,
                                      preferredStyle: UIAlertControllerStyle.alert)
        let actionOK = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertActionStyle.default, handler: nil)
        alert.addAction(actionOK)
        self.present(alert, animated: false) {
            self.usernameTextField.becomeFirstResponder()
        }
    }

}
