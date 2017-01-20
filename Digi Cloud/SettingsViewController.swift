//
//  SettingsViewControllerTableViewController.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 13/01/17.
//  Copyright © 2017 Mihai Cristescu. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {

    private var isExecuting = false

    private let confirmButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.layer.cornerRadius = 8
        b.clipsToBounds = true
        b.setTitleColor(.white, for: .normal)
        b.setTitle(NSLocalizedString("Confirm", comment: "Button Title"), for: .normal)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 15)
        b.addTarget(self, action: #selector(handleLogoutConfirmed), for: .touchUpInside)
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        b.backgroundColor = UIColor(red: 1.0, green: 0.0, blue: 0.25, alpha: 1.0)
        return b
    }()

    private var confirmButtonHorizontalConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Settings", comment: "Window Title")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case  0: return 2 // ABOUT THE APP
        case  1: return 2 // DATA
        case  2: return 1 // USER
        default: return 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:  return NSLocalizedString("ABOUT DIGI CLOUD", comment: "Section title")
        case 1:  return NSLocalizedString("DATA", comment: "Section title")
        case 2:  return NSLocalizedString("USER", comment: "Section title")
        default: return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.selectionStyle = .none

        switch indexPath.section {
        case 0:
            // About the app
            switch indexPath.row {
            case 0:
                // App version
                cell.textLabel?.text = NSLocalizedString("App Version", comment: "Label Title")
                cell.detailTextLabel?.text = "\(UIApplication.Version)"
            case 1:
                // Rate the app
                cell.textLabel?.text = NSLocalizedString("Rate the App", comment: "Button Title")
                cell.textLabel?.textColor = .defaultColor
            default:
                break
            }

        case 1:
            // Data
            switch indexPath.row {
            case 0:
                // Allow celular
                cell.textLabel?.text = NSLocalizedString("Mobile Data", comment: "Button Title")
                let mobileDataUISwitch: UISwitch = {
                    let s = UISwitch()
                    s.isOn = AppSettings.allowsCellularAccess
                    s.translatesAutoresizingMaskIntoConstraints = false
                    s.addTarget(self, action: #selector(toggleAllowingCellularAccessSetting), for: .valueChanged)
                    return s
                }()

                cell.contentView.addSubview(mobileDataUISwitch)
                NSLayoutConstraint.activate([
                    mobileDataUISwitch.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    mobileDataUISwitch.rightAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.rightAnchor)
                ])
            case 1:
                // Clean cache
                cell.textLabel?.text = NSLocalizedString("Clear Cache", comment: "Button Title")
                cell.textLabel?.textColor = .defaultColor
                let str = NSLocalizedString("Currently:", comment: "")
                cell.detailTextLabel?.text = "\(str) 0 KB"
            default:
                break
            }

        case 2:
            // USER
            cell.textLabel?.text = NSLocalizedString("Logout", comment: "Button Title")
            cell.textLabel?.textColor = .defaultColor
            cell.contentView.addSubview(confirmButton)

            confirmButtonHorizontalConstraint = confirmButton.leftAnchor.constraint(equalTo: cell.contentView.rightAnchor)

            NSLayoutConstraint.activate([
                confirmButton.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                confirmButtonHorizontalConstraint
            ])

        default:
            return UITableViewCell()
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        switch indexPath.section {
        case 0:
            if indexPath.row == 1 {
                handleAppStoreReview()
            }
        case 1:
            if indexPath.row == 1 {
                handleClearCache()
            }
        case 2:
            handleLogout(cell)
        default:
            break
        }
    }

    @objc private func toggleAllowingCellularAccessSetting() {
        AppSettings.allowsCellularAccess = !AppSettings.allowsCellularAccess
    }

    @objc private func handleLogout(_ cell: UITableViewCell) {
        confirmButtonHorizontalConstraint.isActive = false
        if confirmButton.tag == 0 {
            confirmButton.tag = 1
            confirmButtonHorizontalConstraint = confirmButton.rightAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.rightAnchor)
        } else {
            confirmButton.tag = 0
            confirmButtonHorizontalConstraint = confirmButton.leftAnchor.constraint(equalTo: cell.contentView.rightAnchor)
        }
        confirmButtonHorizontalConstraint.isActive = true

        UIView.animate(withDuration: 0.4,
                              delay: 0,
             usingSpringWithDamping: 1,
              initialSpringVelocity: 1,
                            options: .curveEaseOut,
                         animations: { cell.layoutIfNeeded() },
                         completion: nil)
    }

    @objc private func handleLogoutConfirmed() {

        guard !isExecuting else { return }
        isExecuting = true

        if let navController = self.navigationController?.presentingViewController as? MainNavigationController {
            AppSettings.loggedAccount = nil
            dismiss(animated: true, completion: {
                if let controller = navController.visibleViewController as? LocationsViewController {
                    controller.activityIndicator.startAnimating()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    navController.onLogout?()
                }
            })
        }
    }

    @objc private func handleAppStoreReview() {
        let urlstring = "itms-apps://itunes.apple.com/app/viewContentsUserReviews?id=1173649518"
        guard let url = URL(string: urlstring) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func handleClearCache() {
        // TODO: Implement this
    }
}
