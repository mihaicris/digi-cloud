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
                nameLabel.text = user.name
                emailLabel.text = user.email

                if isOwner {
                    permissionsLabel.text = NSLocalizedString("OWNER", comment: "")
                    permissionsLabel.backgroundColor = UIColor.blue.withAlphaComponent(0.6)
                } else {
                    if user.permissions.isExtended {
                        permissionsLabel.text = NSLocalizedString("EXTENDED", comment: "")
                        permissionsLabel.backgroundColor = UIColor.magenta.withAlphaComponent(0.4)
                    } else {
                        permissionsLabel.text = NSLocalizedString("READ", comment: "")
                        permissionsLabel.backgroundColor = UIColor.darkGray.withAlphaComponent(0.4)
                    }
                }
            }
        }
    }

    var isOwner: Bool = false

    let profileImageView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.layer.cornerRadius = 7
        iv.layer.masksToBounds = true
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    let nameLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "HelveticaNeue", size: 16)
        return l
    }()

    let emailLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.font = UIFont(name: "HelveticaNeue", size: 11)
        l.textColor = .darkGray
        return l
    }()

    let permissionsLabel: UILabelWithPadding = {
        let l = UILabelWithPadding(paddingTop: 2, paddingLeft: 4, paddingBottom: 2, paddingRight: 4)
        l.font = UIFont.systemFont(ofSize: 10)
        l.textColor = .white
        l.layer.cornerRadius = 4
        l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
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
            profileImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            profileImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.8),
            profileImageView.widthAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.8),

            nameLabel.topAnchor.constraint(equalTo: profileImageView.topAnchor),
            nameLabel.leftAnchor.constraint(equalTo: profileImageView.rightAnchor, constant: 10),
            nameLabel.rightAnchor.constraint(equalTo: self.rightAnchor, constant: -120),

            emailLabel.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor),
            emailLabel.leftAnchor.constraint(equalTo: nameLabel.leftAnchor),
            emailLabel.rightAnchor.constraint(equalTo: nameLabel.rightAnchor),

            permissionsLabel.leftAnchor.constraint(equalTo: self.rightAnchor, constant: -100),
            permissionsLabel.centerYAnchor.constraint(equalTo: profileImageView.centerYAnchor),
        ])
    }

}
