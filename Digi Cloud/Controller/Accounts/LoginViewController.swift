//
//  LoginViewController.swift
//  test
//
//  Created by Mihai Cristescu on 15/09/16.
//  Copyright © 2016 Mihai Cristescu. All rights reserved.
//

import UIKit

final class LoginViewController: UIViewController {

    // MARK: - Properties

    var onSuccess: ((User) -> Void)?

    private let spinner: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .white)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        return activityIndicator
    }()

    private lazy var usernameTextField: LoginField = {
        let loginField = LoginField()
        loginField.textFieldName = NSLocalizedString("EMAIL ADDRESS", comment: "").uppercased()

        #if DEBUG
            let dict = ProcessInfo.processInfo.environment
            loginField.text = dict["USERNAME"] ?? ""
        #endif

        loginField.accessibilityLabel = "Username"
        loginField.delegate = self
        return loginField
    }()

    private lazy var passwordTextField: LoginField = {
        let loginField = LoginField()
        loginField.textFieldName = NSLocalizedString("PASSWORD", comment: "").uppercased()

        #if DEBUG
            let dict = ProcessInfo.processInfo.environment
            loginField.text = dict["PASSWORD"] ?? ""
        #endif

        loginField.isSecureTextEntry = true
        loginField.accessibilityLabel = "Password"
        loginField.delegate = self
        return loginField
    }()

    private let loginButton: LoginButton = {
        let button = LoginButton()
        button.setTitle(NSLocalizedString("LOGIN", comment: ""), for: .normal)
        button.addTarget(self, action: #selector(handleLogin), for: .touchUpInside)
        return button
    }()

    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("✕", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.fontHelveticaNeue(size: 24)
        button.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        return button
    }()

    private let forgotPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(NSLocalizedString("Forgot password?", comment: ""), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.fontHelveticaNeue(size: 14)
        button.addTarget(self, action: #selector(handleForgotPassword), for: .touchUpInside)
        return button
    }()

    private var usernameTextFieldCenterYAnchorConstraint: NSLayoutConstraint!

    // MARK: - Initializers and Deinitializers

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Overridden Methods and Properties

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.view.endEditing(true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.registerForKeyboardNotifications()
        setupViews()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        usernameTextField.becomeFirstResponder()
    }

    override var shouldAutorotate: Bool {
        return traitCollection.horizontalSizeClass != .compact &&
               traitCollection.verticalSizeClass != .compact &&
               self.view.bounds.width > self.view.bounds.height
    }

    // MARK: - Helper Functions

    private func registerForKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(notification:)),
            name: .UIKeyboardWillShow,
            object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(notification:)),
            name: .UIKeyboardWillHide,
            object: nil)
    }

    private func setupViews() {

        view.backgroundColor = UIColor.iconColor

        let titleTextView: UITextView = {
            let textView = UITextView()
            textView.backgroundColor = .clear
            textView.textColor = .white
            textView.textAlignment = .center
            textView.isEditable = false
            textView.isSelectable = false
            textView.isScrollEnabled = false
            textView.translatesAutoresizingMaskIntoConstraints = false

            // TODO: Change fonts?
            let aText = NSMutableAttributedString(string: NSLocalizedString("Hello!", comment: ""),
                                                  attributes: [NSAttributedStringKey.font: UIFont(name: "PingFangSC-Semibold", size: 26)!,
                                                               NSAttributedStringKey.foregroundColor: UIColor.white])
            aText.append(NSAttributedString(string: "\n"))

            aText.append(NSAttributedString(string: NSLocalizedString("Please provide the credentials for your Digi Storage account.", comment: ""),
                                            attributes: [NSAttributedStringKey.font: UIFont.fontHelveticaNeue(size: 16),
                                                         NSAttributedStringKey.foregroundColor: UIColor.white]))

            let aPar = NSMutableParagraphStyle()
            aPar.alignment = .center

            let range = NSRange(location: 0, length: aText.string.count)
            aText.addAttributes([NSAttributedStringKey.paragraphStyle: aPar], range: range)

            textView.textContainerInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)

            textView.attributedText = aText
            return textView
        }()

        view.addSubview(cancelButton)
        view.addSubview(titleTextView)
        view.addSubview(usernameTextField)
        view.addSubview(passwordTextField)
        view.addSubview(loginButton)
        view.addSubview(spinner)
        view.addSubview(forgotPasswordButton)

        usernameTextFieldCenterYAnchorConstraint = usernameTextField.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -30)

        NSLayoutConstraint.activate([
            cancelButton.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -2),
            cancelButton.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor, constant: 5),

            titleTextView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleTextView.bottomAnchor.constraint(equalTo: usernameTextField.topAnchor, constant: -10),
            titleTextView.widthAnchor.constraint(equalTo: usernameTextField.widthAnchor),

            usernameTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            usernameTextField.leftAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leftAnchor),
            usernameTextField.rightAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.rightAnchor),
            usernameTextField.heightAnchor.constraint(equalToConstant: 50),
            usernameTextFieldCenterYAnchorConstraint,

            passwordTextField.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            passwordTextField.topAnchor.constraint(equalTo: usernameTextField.bottomAnchor, constant: 20),
            passwordTextField.widthAnchor.constraint(equalTo: usernameTextField.widthAnchor),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),

            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 20),
            loginButton.widthAnchor.constraint(equalToConstant: 150),
            loginButton.heightAnchor.constraint(equalToConstant: 40),

            forgotPasswordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            forgotPasswordButton.centerYAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 20),

            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 20)
        ])
    }

    @objc private func handleForgotPassword() {
        let alert = UIAlertController(title: NSLocalizedString("Information", comment: ""),
                                      message: NSLocalizedString("Please contact RCS RDS for password information.", comment: ""),
                                      preferredStyle: UIAlertControllerStyle.alert)

        let actionOK = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertActionStyle.default, handler: nil)

        alert.addAction(actionOK)
        self.present(alert, animated: false, completion: nil)
        return
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard let userinfo = notification.userInfo,
            let keyboardFrameEnd = userinfo[UIKeyboardFrameEndUserInfoKey] as? CGRect,
            let keyboardAnimationDuration = userinfo[UIKeyboardAnimationDurationUserInfoKey] as? Double,
            let keyboardAnimationCurveRawValue = userinfo[UIKeyboardAnimationCurveUserInfoKey] as? Int,
            let keyboardAnimationCurve = UIViewAnimationCurve(rawValue: keyboardAnimationCurveRawValue) else {
                return
        }
        self.view.layoutIfNeeded()
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(keyboardAnimationDuration)
        UIView.setAnimationCurve(keyboardAnimationCurve)
        UIView.setAnimationBeginsFromCurrentState(true)

        if let mainWindow = UIApplication.shared.delegate?.window,
            let mainView = mainWindow?.rootViewController?.view,
            let superview = forgotPasswordButton.superview {

            let forgotButtonFrame = superview.convert(forgotPasswordButton.frame, to: mainView)
            let forgotButtonBottomY = forgotButtonFrame.origin.y + forgotButtonFrame.height

            let difference = keyboardFrameEnd.origin.y - forgotButtonBottomY
            if difference < 0 {
                usernameTextFieldCenterYAnchorConstraint.constant = -40 + difference
            }
        }

        self.view.layoutIfNeeded()
        UIView.commitAnimations()
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        guard let userinfo = notification.userInfo,
            let keyboardAnimationDuration = userinfo[UIKeyboardAnimationDurationUserInfoKey] as? Double,
            let keyboardAnimationCurveRawValue = userinfo[UIKeyboardAnimationCurveUserInfoKey] as? Int,
            let keyboardAnimationCurve = UIViewAnimationCurve(rawValue: keyboardAnimationCurveRawValue) else {
                return
        }
        self.view.layoutIfNeeded()
        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(keyboardAnimationDuration)
        UIView.setAnimationCurve(keyboardAnimationCurve)
        UIView.setAnimationBeginsFromCurrentState(true)
        usernameTextFieldCenterYAnchorConstraint.constant = -30
        self.view.layoutIfNeeded()
        UIView.commitAnimations()
    }

    @objc private func handleCancel() {
        usernameTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()
        dismiss(animated: true, completion: nil)
    }

    @objc private func handleLogin() {

        usernameTextField.resignFirstResponder()
        passwordTextField.resignFirstResponder()

        guard let username = usernameTextField.text?.lowercased(),
            let password = passwordTextField.text,
            username.count > 0,
            password.count > 0
            else {
                let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""),
                                              message: NSLocalizedString("Please fill in the fields.", comment: ""),
                                              preferredStyle: UIAlertControllerStyle.alert)
                let actionOK = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: UIAlertActionStyle.default, handler: nil)
                alert.addAction(actionOK)
                self.present(alert, animated: false, completion: nil)
                return
        }

        spinner.startAnimating()

        DigiClient.shared.authenticate(username: username, password: password) { token, error in

            guard error == nil else {

                self.spinner.stopAnimating()

                var message: String

                switch error! {

                case NetworkingError.internetOffline(let errorMessage), NetworkingError.requestTimedOut(let errorMessage):

                    message = errorMessage

                    if !AppSettings.allowsCellularAccess {

                        let alert = UIAlertController(title: NSLocalizedString("Info", comment: ""),
                                                      message: NSLocalizedString("Would you like to use cellular data?", comment: ""),
                                                      preferredStyle: .alert)

                        let noAction = UIAlertAction(title: "No", style: .default) { _ in
                            self.showError(message: message)
                        }

                        let yesAction = UIAlertAction(title: "Yes", style: .default) { _ in
                            AppSettings.allowsCellularAccess = true
                            DigiClient.shared.renewSession()
                            self.handleLogin()
                        }

                        alert.addAction(noAction)
                        alert.addAction(yesAction)

                        self.present(alert, animated: true, completion: nil)
                        return
                    }

                default:
                    message = NSLocalizedString("An error has occurred.\nPlease try again later!", comment: "")
                }

                self.showError(message: message)

                return
            }

            AppSettings.saveUser(forToken: token!) { (user, error) in

                self.spinner.stopAnimating()

                guard error == nil else {
                    let message = NSLocalizedString("An error has occurred.\nPlease try again later!", comment: "")

                    self.showError(message: message)
                    return
                }

                if let user = user {
                    self.dismiss(animated: true) {
                        self.onSuccess?(user)
                    }
                } else {
                    let message = NSLocalizedString("An error has occurred.\nPlease try again later!", comment: "")

                    self.showError(message: message)
                }
            }
        }
    }

    private func showError(message: String) {

        let alert = UIAlertController(title: NSLocalizedString("Error", comment: ""),
                                      message: message,
                                      preferredStyle: .alert)

        let actionOK = UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil)

        alert.addAction(actionOK)
        self.present(alert, animated: false, completion: nil)
    }

}

extension LoginViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
