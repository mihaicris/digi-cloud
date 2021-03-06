//
//  SettingsViewControllerTableViewController.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 13/01/17.
//  Copyright © 2017 Mihai Cristescu. All rights reserved.
//

import UIKit

final class SettingsViewController: UITableViewController {

    // MARK: - Private Types

    enum SettingType {
        case user
        case data
    }

    // MARK: - Private Properties

    private var user: User
    private var profileImage: UIImage! = #imageLiteral(resourceName: "default_profile_image")
    private let settings: [SettingType] = [.user, .data]
    private var confirmButtonHorizontalConstraint: NSLayoutConstraint!

    private let confirmButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitleColor(.white, for: .normal)
        button.setTitle(NSLocalizedString("Confirm", comment: ""), for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.addTarget(self, action: #selector(handleConfirmButtonTouched), for: .touchUpInside)
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        button.backgroundColor = UIColor(red: 1.0, green: 0.0, blue: 0.25, alpha: 1.0)
        return button
    }()

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    // MARK: - Initializers and Deinitializers

    init(user: User) {
        self.user = user
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

}

// MARK: - UIViewController Methods

extension SettingsViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.registerForNotificationCenter()
        setupViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        fetchUserData()
        tableView.reloadData()
    }

}

// MARK: - Delegate Conformances

extension SettingsViewController {

    override func numberOfSections(in tableView: UITableView) -> Int {
        return settings.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch settings[section] {
        case .user:
            return 2
        case .data:
            return FileManager.sizeOfFilesCacheFolder() == 0 ? 1 : 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch settings[section] {
        case .user:
            return NSLocalizedString("User", comment: "")
        case .data:
            return NSLocalizedString("Data", comment: "")
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch settings[indexPath.section] {
        case .user:
            return indexPath.row == 0 ? 80 : AppSettings.textFieldRowHeight
        default:
            return AppSettings.textFieldRowHeight
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.selectionStyle = .none

        switch settings[indexPath.section] {
        case .user:

            if indexPath.row == 0 {

                let profileImageView: UIImageView = {
                    let imageView = UIImageView()
                    imageView.translatesAutoresizingMaskIntoConstraints = false
                    imageView.layer.cornerRadius = 10
                    imageView.layer.masksToBounds = true
                    imageView.contentMode = .scaleAspectFill
                    imageView.image = self.profileImage
                    return imageView
                }()

                let usernameLabel: UILabel = {
                    let label = UILabel()
                    label.translatesAutoresizingMaskIntoConstraints = false
                    label.text = "\(user.firstName) \(user.lastName)"
                    label.font = UIFont.fontHelveticaNeueMedium(size: 16)
                    return label
                }()

                let userloginLabel: UILabel = {
                    let label = UILabel()
                    label.translatesAutoresizingMaskIntoConstraints = false
                    label.text = self.user.email
                    label.textColor = UIColor.gray
                    label.font = UIFont.fontHelveticaNeue(size: 14)
                    return label
                }()

                cell.contentView.addSubview(profileImageView)
                cell.contentView.addSubview(usernameLabel)
                cell.contentView.addSubview(userloginLabel)

                NSLayoutConstraint.activate([
                    profileImageView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    profileImageView.leftAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leftAnchor),
                    profileImageView.heightAnchor.constraint(equalToConstant: 60),
                    profileImageView.widthAnchor.constraint(equalToConstant: 60),

                    userloginLabel.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor),
                    userloginLabel.leftAnchor.constraint(equalTo: profileImageView.rightAnchor, constant: 8),

                    usernameLabel.bottomAnchor.constraint(equalTo: userloginLabel.topAnchor),
                    usernameLabel.leftAnchor.constraint(equalTo: userloginLabel.leftAnchor)])

            } else {
                cell.textLabel?.text = NSLocalizedString("Switch Account", comment: "")
                cell.textLabel?.textColor = .defaultColor
                cell.contentView.addSubview(confirmButton)

                confirmButtonHorizontalConstraint = confirmButton.leftAnchor.constraint(equalTo: cell.contentView.rightAnchor)

                NSLayoutConstraint.activate([
                    confirmButton.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                    confirmButton.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                    confirmButtonHorizontalConstraint])
            }

        case .data:

            switch indexPath.row {

            case 0:
                cell.textLabel?.text = NSLocalizedString("Mobile Data", comment: "")
                let mobileDataUISwitch: UISwitch = {
                    let uiswitch = UISwitch()
                    uiswitch.isOn = AppSettings.allowsCellularAccess
                    uiswitch.translatesAutoresizingMaskIntoConstraints = false
                    uiswitch.addTarget(self, action: #selector(handleCellularDataSwitchValueChanged), for: .valueChanged)
                    return uiswitch
                }()

                cell.contentView.addSubview(mobileDataUISwitch)
                NSLayoutConstraint.activate([
                    mobileDataUISwitch.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    mobileDataUISwitch.rightAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.rightAnchor)
                    ])
            case 1:
                // Clean cache
                cell.textLabel?.text = NSLocalizedString("Clear Cache", comment: "")
                cell.textLabel?.textColor = .defaultColor

                cell.detailTextLabel?.font = UIFont.fontHelveticaNeue(size: 14)

                let str = NSLocalizedString("Total:", comment: "")

                var sizeString = NSLocalizedString("Error", comment: "")

                let size = FileManager.sizeOfFilesCacheFolder()
                sizeString = byteFormatter.string(fromByteCount: Int64(size))

                cell.detailTextLabel?.text = "\(str) \(sizeString)"

            default:
                break
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let cell = tableView.cellForRow(at: indexPath) else { return }

        switch settings[indexPath.section] {
        case .user:
            if indexPath.row == 1 {
                logout(cell)
            }
        case .data:
            if indexPath.row == 1 {
                handleClearCache()
            }
        }
    }
}

// MARK: - Target-Action Methods

private extension SettingsViewController {

    @objc func handleCellularDataSwitchValueChanged() {
        AppSettings.allowsCellularAccess = !AppSettings.allowsCellularAccess
        DigiClient.shared.renewSession()
    }

    @objc func handleConfirmButtonTouched() {

        UIApplication.shared.beginIgnoringInteractionEvents()
        defer { UIApplication.shared.endIgnoringInteractionEvents() }

        if let navController = self.navigationController?.presentingViewController as? MainNavigationController {
            AppSettings.loggedUserID = nil

            dismiss(animated: true) {

                if let controller = navController.visibleViewController as? LocationsViewController {
                    controller.activityIndicator.startAnimating()
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    navController.viewControllers = []
                    navController.onLogout?()
                }
            }
        }
    }

    @objc func handleCloseButtonTouched() {
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - Private Methods

private extension SettingsViewController {

    func setupViews() {
        title = NSLocalizedString("Settings", comment: "")
        if navigationController != nil {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Close", comment: ""),
                                                                     style: .done,
                                                                     target: self,
                                                                     action: #selector(handleCloseButtonTouched))
        }

        let tableFooterView: UIView = {
            let view = UIView()
            view.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 70)

            let versionLabel: UILabel = {
                let label = UILabel()
                label.numberOfLines = 0
                label.translatesAutoresizingMaskIntoConstraints = false
                label.textAlignment = .center
                label.text = Bundle.main.prettyVersionString
                label.textColor = UIColor.gray
                label.font = UIFont.fontHelveticaNeue(size: 12)
                return label
            }()

            view.addSubview(versionLabel)

            NSLayoutConstraint.activate([
                versionLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
                versionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
                ])

            return view
        }()

        tableView.tableFooterView = tableFooterView

    }

    func fetchUserData() {
        if let user = AppSettings.userLogged {
            self.user = user
            let cache = Cache()
            let key = self.user.identifier + ".png"
            if let data = cache.load(type: .profile, key: key) {
                self.profileImage = UIImage(data: data, scale: UIScreen.main.scale)
            }
        }
    }

    func handleClearCache() {
        FileManager.emptyFilesCache()
        tableView.reloadSections(IndexSet(integer: 1), with: .fade)
    }

    func registerForNotificationCenter() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCloseButtonTouched),
            name: .UIApplicationWillResignActive,
            object: nil)
    }

    func logout(_ cell: UITableViewCell) {
        confirmButtonHorizontalConstraint.isActive = false
        if confirmButton.tag == 0 {
            confirmButton.tag = 1
            confirmButtonHorizontalConstraint = confirmButton.rightAnchor.constraint(equalTo: cell.contentView.rightAnchor)
        } else {
            confirmButton.tag = 0
            confirmButtonHorizontalConstraint = confirmButton.leftAnchor.constraint(equalTo: cell.contentView.rightAnchor)
        }
        confirmButtonHorizontalConstraint.isActive = true

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 1,
            options: .curveEaseOut,
            animations: {
                cell.layoutIfNeeded()
        },
            completion: nil
        )
    }
}
