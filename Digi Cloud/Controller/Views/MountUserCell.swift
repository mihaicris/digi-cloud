//
//  MountUserCell.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 10/03/2017.
//  Copyright © 2017 Mihai Cristescu. All rights reserved.
//

import UIKit

class MountUserCell: UITableViewCell {

    // MARK: - Properties

    var user: User? {
        didSet {
            if let user = user {
                nameLabel.text = "\(user.firstName) \(user.lastName)"
                emailLabel.text = user.email

                if isOwner {
                    permissionsLabel.text = NSLocalizedString("OWNER", comment: "")
                    permissionsLabel.textColor = .white
                    permissionsLabel.backgroundColor = UIColor.blue.withAlphaComponent(0.6)
                } else {
                    if user.permissions.isExtended {
                        permissionsLabel.text = NSLocalizedString("EXTENDED", comment: "")
                        permissionsLabel.textColor = .white
                        permissionsLabel.backgroundColor = UIColor(red: 202/255, green: 187/255, blue: 250/255, alpha: 1.0)
                    } else {
                        permissionsLabel.text = NSLocalizedString("READ", comment: "")
                        permissionsLabel.textColor = .darkGray
                        permissionsLabel.backgroundColor = UIColor(red: 240/255, green: 240/255, blue: 240/255, alpha: 1.0)
                    }
                }
            }
        }
    }

    var isOwner: Bool = false

    let profileImageView: UIImageView = {
        let imagView = UIImageView()
        imagView.translatesAutoresizingMaskIntoConstraints = false
        imagView.layer.cornerRadius = 7
        imagView.layer.masksToBounds = true
        imagView.contentMode = .scaleAspectFill
        return imagView
    }()

    let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.fontHelveticaNeue(size: 16)
        return label
    }()

    let emailLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.fontHelveticaNeue(size: 11)
        label.textColor = .darkGray
        return label
    }()

    let permissionsLabel: UILabelWithPadding = {
        let label = UILabelWithPadding(paddingTop: 2, paddingLeft: 4, paddingBottom: 2, paddingRight: 4)
        label.font = UIFont.systemFont(ofSize: 10)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Initializers and Deinitializers

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.setupViews()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Overridden Methods and Properties

    // MARK: - Helper Functions

    private func setupViews() {

        contentView.addSubview(profileImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(emailLabel)
        contentView.addSubview(permissionsLabel)

        NSLayoutConstraint.activate([
            profileImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            profileImageView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 15),
            profileImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.8),
            profileImageView.widthAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.8),

            nameLabel.topAnchor.constraint(equalTo: profileImageView.topAnchor),
            nameLabel.leftAnchor.constraint(equalTo: profileImageView.rightAnchor, constant: 10),
            nameLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -120),

            emailLabel.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor),
            emailLabel.leftAnchor.constraint(equalTo: nameLabel.leftAnchor),
            emailLabel.rightAnchor.constraint(equalTo: nameLabel.rightAnchor),

            permissionsLabel.rightAnchor.constraint(equalTo: contentView.layoutMarginsGuide.rightAnchor),
            permissionsLabel.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor)
        ])
    }

}
