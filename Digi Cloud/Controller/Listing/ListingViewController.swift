//
//  ListingViewController.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 19/09/16.
//  Copyright © 2016 Mihai Cristescu. All rights reserved.
//

import UIKit

class ListingViewController: UITableViewController {

    // MARK: - Internal Properties

    var onFinish: (() -> Void)?

    // MARK: - Internal Properties

    // Type of action made by controller
    private let action: ActionType

    // The current location in normal listing mode
    private var rootLocation: Location

    // The current node in normal listing mode
    private var rootNode: Node?

    // The content of the rootnode
    private var nodes: [Node] = []

    // When coping or moving files/folders, this property will hold the source location which is passed between
    // controllers on navigation stack.
    private var sourceLocations: [Location]?
    private var needRefresh: Bool = true
    private let searchResult: String?
    private var isUpdating: Bool = false
    private var isActionConfirmed: Bool = false
    private var searchController: UISearchController!
    private let dispatchGroup = DispatchGroup()
    private var didReceivedNetworkError = false
    private var didReceivedStatus400 = false
    private var didReceivedStatus404 = false
    private var didSucceedCopyOrMove = false
    private var errorMessage = ""
    private var searchResultWasHighlighted = false
    private let flexibleBarButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.YYY・HH:mm"
        return formatter
    }()

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowsNonnumericFormatting = false
        return formatter
    }()

    private let busyIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = .gray
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        return activityIndicator
    }()

    private let emptyFolderLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor.lightGray
        label.textAlignment = .center
        return label
    }()

    private lazy var messageStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.spacing = 10
        stackView.alignment = .center
        stackView.addArrangedSubview(self.busyIndicator)
        stackView.addArrangedSubview(self.emptyFolderLabel)
        return stackView
    }()

    private lazy var createFolderBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: NSLocalizedString("Create Folder", comment: ""), style: .done, target: self, action: #selector(handleShowCreateFolderViewController))
        return button
    }()

    private lazy var copyInEditModeButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: NSLocalizedString("Copy", comment: ""), style: .done, target: self, action: #selector(handleExecuteActionsInEditMode(_:)))
        button.tag = ActionType.copy.rawValue
        return button
    }()

    private lazy var moveInEditModeButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: NSLocalizedString("Move", comment: ""), style: .done, target: self, action: #selector(handleExecuteActionsInEditMode(_:)))
        button.tag = ActionType.move.rawValue
        return button
    }()

    private lazy var bookmarksBarButton: UIBarButtonItem = {
        let button = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(handleShowBookmarksViewController(_:)))
        button.tag = 3
        return button
    }()

    private lazy var deleteInEditModeButton: UIBarButtonItem = {
        let buttonView = UIButton(type: UIButtonType.system)
        buttonView.setTitle(NSLocalizedString("Delete", comment: ""), for: .normal)
        buttonView.addTarget(self, action: #selector(handleExecuteActionsInEditMode(_:)), for: .touchUpInside)
        buttonView.setTitleColor(UIColor(white: 0.8, alpha: 1), for: .disabled)
        buttonView.setTitleColor(.red, for: .normal)
        buttonView.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        buttonView.sizeToFit()
        buttonView.tag = ActionType.delete.rawValue
        let button = UIBarButtonItem(customView: buttonView)
        return button
    }()

    private lazy var cancelInEditModeButton: UIBarButtonItem = {
        let button = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: .done, target: self, action: #selector(handleCancelEditMode))
        return button
    }()

    // MARK: - Initializers and Deinitializers

    init(location: Location, action: ActionType, searchResult: String? = nil, sourceLocations: [Location]? = nil) {
        self.rootLocation = location
        self.action = action
        self.searchResult = searchResult
        self.sourceLocations = sourceLocations
        super.init(style: .plain)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - UIViewController Methods

extension ListingViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupSearchController()
        updateNavigationBarItems()
        setupToolBarButtonItems()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if [ActionType.noAction, ActionType.showSearchResult].contains(self.action) {
            updateNavigationBarRightButtonItems()
        }
        if needRefresh {
            nodes.removeAll()
            busyIndicator.startAnimating()
            emptyFolderLabel.text = NSLocalizedString("Loading ...", comment: "")
            tableView.reloadData()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if needRefresh {
            self.getContent()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        #if DEBUG
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        #endif

        if tableView.isEditing {
            handleCancelEditMode()
        }
    }
}

// MARK: - UITableView Delegate Conformance

extension ListingViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return nodes.isEmpty ? 2 : nodes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if nodes.isEmpty {
            let cell = UITableViewCell()
            cell.isUserInteractionEnabled = false
            if indexPath.row == 1 {
                cell.contentView.addSubview(messageStackView)

                NSLayoutConstraint.activate([
                    messageStackView.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
                    messageStackView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)])
            }
            return cell
        }

        let item = nodes[indexPath.row]

        let itemDate = Date(timeIntervalSince1970: item.modified / 1000)
        let modifiedDateString = itemDate.timeAgoSyle

        if item.type == "dir" {

            guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: FolderCell.self),
                                                           for: indexPath) as? FolderCell else {
                return UITableViewCell()
            }

            // In copy or move mode you cannot copy or move a folder into itself.
            if self.action == .copy || self.action == .move {
                if let sourceLocations = sourceLocations {
                    if sourceLocations.contains(item.location(in: self.rootLocation)) {
                        cell.isUserInteractionEnabled = false
                        cell.nodeNameLabel.isEnabled = false
                        cell.detailsLabel.isEnabled = false
                    } else {
                        cell.isUserInteractionEnabled = true
                        cell.nodeNameLabel.isEnabled = true
                        cell.detailsLabel.isEnabled = true
                    }
                }
            }

            cell.actionsButton.addTarget(self, action: #selector(handleShowNodeActionsController(_:)), for: .touchUpInside)
            cell.actionsButton.tag = indexPath.row

            cell.nodeNameLabel.text = item.name

            cell.hasButton = [ActionType.noAction, ActionType.showSearchResult].contains(self.action)

            // CHECK THIS!
            cell.isShared = item.mount != nil
            cell.hasLink = item.link != nil
            cell.hasReceiver = item.receiver != nil
            cell.isBookmarked = item.bookmark != nil

            let detailAttributtedString = NSMutableAttributedString(string: modifiedDateString)

            if cell.hasLink {
                // http://fontawesome.io/icon/cloud-upload/
                let attributedString = NSAttributedString(string: "  \u{f0aa}",
                                                          attributes: [NSAttributedStringKey.font: UIFont.fontAwesome(size: 12)])
                detailAttributtedString.append(attributedString)
            }

            if cell.hasReceiver {
                // http://fontawesome.io/icon/cloud-download/
                let attributedString = NSAttributedString(string: "  \u{f0ab}",
                                                          attributes: [NSAttributedStringKey.font: UIFont.fontAwesome(size: 12)])
                detailAttributtedString.append(attributedString)
            }

            cell.detailsLabel.attributedText = detailAttributtedString

            return cell

        } else {

            guard let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: FileCell.self),
                                                           for: indexPath) as? FileCell else {
                return UITableViewCell()
            }

            cell.actionsButton.addTarget(self, action: #selector(handleShowNodeActionsController(_:)), for: .touchUpInside)
            cell.actionsButton.tag = indexPath.row
            cell.hasButton = [ActionType.noAction, ActionType.showSearchResult].contains(self.action)

            // In copy or move mode you cannot copy or move into a file.
            if self.action == .copy || self.action == .move {
                cell.isUserInteractionEnabled = false
                cell.nodeNameLabel.isEnabled = false
                cell.detailsLabel.isEnabled = false
            }

            cell.hasLink = item.link != nil
            cell.nodeNameLabel.text = item.name

            let sizeString = byteFormatter.string(fromByteCount: item.size)

            let detailAttributtedString = NSMutableAttributedString(string: sizeString + "・" + modifiedDateString)

            if cell.hasLink {
                // http://fontawesome.io/icon/cloud-upload/
                let attributedString = NSAttributedString(string: "  \u{f0aa}",
                                                          attributes: [NSAttributedStringKey.font: UIFont.fontAwesome(size: 12)])
                detailAttributtedString.append(attributedString)
            }

            cell.detailsLabel.attributedText = detailAttributtedString

            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateToolBarButtonItemsToMatchTableState()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateToolBarButtonItemsToMatchTableState()
            return
        }

        tableView.deselectRow(at: indexPath, animated: false)
        refreshControl?.endRefreshing()

        let selectedNode = nodes[indexPath.row]

        let newLocation = self.rootLocation.appendingPathComponentFrom(node: selectedNode)
        if selectedNode.type == "dir" {

            // This is a Folder
            let controller = ListingViewController(location: newLocation, action: self.action, sourceLocations: self.sourceLocations)

            if self.action != .noAction {

                // It makes sens only if this is a copy or move controller
                controller.onFinish = { [weak self] in
                    self?.onFinish?()
                }
            }
            navigationController?.pushViewController(controller, animated: true)

        } else {

            // This is a file

            if [ActionType.noAction, ActionType.showSearchResult].contains(self.action) {
                let controller = ContentViewController(location: newLocation)
                controller.node = selectedNode
                navigationController?.pushViewController(controller, animated: true)
            }
        }
    }
}

// MARK: - UIScrollView delegate Conformance

extension ListingViewController {

    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if refreshControl?.isRefreshing == true {
            if self.isUpdating {
                return
            }
            endRefreshAndReloadTable()
        }
    }
}

// MARK: - Target-Action Methods

private extension ListingViewController {

    @objc func handleShowNodeActionsController(_ sender: UIButton) {

        self.animateActionButton(sender)

        let nodeIndex = sender.tag
        let node = self.nodes[nodeIndex]
        let nodeLocation = node.location(in: self.rootLocation)

        let controller = NodeActionsViewController(location: nodeLocation, node: node)

        controller.onSelect = { [unowned self] action in

            switch action {

            case .bookmark:
                self.executeToogleBookmark(location: nodeLocation, node: node, index: nodeIndex)

            case .copy, .move:
                self.showCopyOrMoveViewController(action: action, sourceLocations: [nodeLocation])

            case .delete:
                self.showDeleteViewController(location: nodeLocation, sourceView: sender, index: nodeIndex)

            case .folderInfo:
                self.showFolderInfoViewController(location: nodeLocation, index: nodeIndex)

            case .rename:
                self.showRenameViewController(nodeLocation: nodeLocation, node: node, index: nodeIndex)

            case .sendDownloadLink:
                self.showLinkViewController(location: nodeLocation, sharedNode: node, linkType: .download)

            case .sendUploadLink:
                self.showLinkViewController(location: nodeLocation, sharedNode: node, linkType: .upload)

            case .makeShare, .manageShare:
                self.showShareMountViewController(location: nodeLocation, sharedNode: node)

            default:
                break
            }
        }

        presentController(controller, sender: sender)
    }

    @objc func handleCancelEditMode() {
        tableView.setEditing(false, animated: true)
        navigationController?.setToolbarHidden(true, animated: true)
        updateNavigationBarRightButtonItems()
    }

    @objc func handleExecuteActionsInEditMode(_ sender: UIBarButtonItem) {

        guard let chosenAction = ActionType(rawValue: sender.tag) else { return }
        guard let selectedItemsIndexPaths = tableView.indexPathsForSelectedRows else { return }

        let sourceLocations = selectedItemsIndexPaths.map { nodes[$0.row].location(in: self.rootLocation) }

        switch chosenAction {
        case .delete:
            self.executeDeletionInSelectionMode(locations: sourceLocations)
        case .copy, .move:
            self.showCopyOrMoveViewController(action: chosenAction, sourceLocations: sourceLocations)
        default:
            break
        }
    }

    @objc func handleCopyOrMoveAction() {

        setBusyIndicatorView(true)

        guard self.sourceLocations != nil else {
            return
        }

        didSucceedCopyOrMove = false
        didReceivedNetworkError = false
        didReceivedStatus400 = false
        didReceivedStatus404 = false

        for sourceLocation in self.sourceLocations! {
            self.executeCopyOrMove(sourceLocation: sourceLocation)
        }

        dispatchGroup.notify(queue: .main) {

            self.setBusyIndicatorView(false)

            if self.didReceivedNetworkError {
                let title = NSLocalizedString("Error", comment: "")
                let message = NSLocalizedString("An error has occured while processing the request.", comment: "")
                let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
                return
            } else {
                if self.didReceivedStatus400 {
                    let message = NSLocalizedString("An error has occured. Some elements already exists at the destination or the destination location no longer exists.", comment: "")
                    let title = NSLocalizedString("Error", comment: "")
                    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                    return
                } else {
                    if self.didReceivedStatus404 {
                        let message = NSLocalizedString("An error has occured. Some elements no longer exists.", comment: "")
                        let title = NSLocalizedString("Error", comment: "")
                        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { _ in
                            self.onFinish?()
                        }))
                        self.present(alertController, animated: true, completion: nil)
                        return
                    }
                }
            }

            // Finish multiple edits without issues
            self.dismiss(animated: true) {
                self.onFinish?()
            }
        }
    }

    @objc func handleCancelCopyOrMoveAction() {
        dismiss(animated: true, completion: nil)
    }

    @objc func handleUpdateContentOnPullToRefreshGesture() {
        if self.isUpdating {
            self.refreshControl?.endRefreshing()
            return
        }
        self.getContent()
    }

    @objc func handleShowBookmarksViewController(_ sender: UIBarButtonItem) {

        guard let buttonView = sender.value(forKey: "view") as? UIView, sender.tag == 3 else {
            return
        }

        let controller = ManageBookmarksViewController()
        let controllerAction = self.action
        let controllerSourceLocations = self.sourceLocations

        controller.onFinish = { [weak self] in
            self?.getContent()
        }

        controller.onUpdateNeeded = { [weak self] in
            self?.getContent()
        }

        controller.onSelect = { [weak self] location in
            let controller = ListingViewController(location: location, action: controllerAction, sourceLocations: controllerSourceLocations)

            if self?.action != .noAction {

                // It makes sens only if this is a copy or move controller
                controller.onFinish = { [weak self] in
                    self?.onFinish?()
                }
            }

            self?.navigationController?.pushViewController(controller, animated: true)
        }

        let navController = UINavigationController(rootViewController: controller)
        navController.modalPresentationStyle = .popover
        navController.popoverPresentationController?.sourceView = buttonView
        navController.popoverPresentationController?.sourceRect = buttonView.bounds
        present(navController, animated: true, completion: nil)
    }

    @objc func handleShowSortingSelectionViewController(_ sender: UIBarButtonItem) {

        guard let buttonView = sender.value(forKey: "view") as? UIView, sender.tag == 1 else {
            return
        }

        let controller = SortFolderViewController()

        controller.onSelection = { [weak self] in
            self?.sortContent()
            self?.tableView.reloadData()
        }

        presentController(controller, sender: buttonView)
    }

    @objc func handleShowMoreActionsViewController(_ sender: UIBarButtonItem) {

        guard let rootNode = self.rootNode else {
            print("No valid root node fetched in updateContent.")
            return
        }

        guard let buttonView = sender.value(forKey: "view") as? UIView, sender.tag == 0 else {
            return
        }

        let controller = MoreActionsViewController(rootNode: rootNode, childs: self.nodes.count)

        controller.onSelect = { [unowned self] selection in

            switch selection {

            case .bookmark:
                self.setNeedsRefreshInPrevious()
                self.executeToogleBookmark(location: self.rootLocation, node: rootNode)

            case .createFolder:
                self.handleShowCreateFolderViewController()

            case .selectionMode:
                if self.nodes.isEmpty { return }
                self.activateEditMode()

            case .manageShare, .makeShare, .shareInfo:
                self.showShareMountViewController(location: self.rootLocation, sharedNode: rootNode)

            case .sendDownloadLink:
                self.showLinkViewController(location: self.rootLocation, sharedNode: rootNode, linkType: .download)

            case .sendUploadLink:
                self.showLinkViewController(location: self.rootLocation, sharedNode: rootNode, linkType: .upload)

            default:
                break
            }
        }

        presentController(controller, sender: buttonView)
    }

    @objc func handleShowSearchViewController(_ sender: UIBarButtonItem) {

        guard let nav = self.navigationController as? MainNavigationController else {
            print("Could not get the MainNavigationController")
            return
        }

        // If index of the search controller is set, and it is different than the current index on
        // navigation stack, then we pop to the saved index, otherwise we show the search controller.
        if let index = nav.searchResultsControllerIndex, index != nav.viewControllers.count - 1 {
            let searchResultsController = nav.viewControllers[index]
            _ = self.navigationController?.popToViewController(searchResultsController, animated: true)
        } else {
            nav.searchResultsControllerIndex = nav.viewControllers.count - 1
        }
    }

    @objc func handleShowCreateFolderViewController() {

        let controller = CreateFolderViewController(parentLocation: self.rootLocation)

        controller.onFinish = { [unowned self] (folderName) in

            // Set needRefresh in this list
            self.needRefresh = true

            // Set needRefresh in the main List
            if let nav = self.presentingViewController as? UINavigationController {
                if let cont = nav.topViewController as? ListingViewController {
                    cont.needRefresh = true
                }
            }

            let newLocation = self.rootLocation.appendingPathComponent(folderName, isFolder: true)

            let controller = ListingViewController(location: newLocation, action: self.action, sourceLocations: self.sourceLocations)

            controller.onFinish = { [weak self] in
                self?.onFinish?()
            }

            self.navigationController?.pushViewController(controller, animated: true)

        }

        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .formSheet

        present(navigationController, animated: true, completion: nil)
    }
}

// MARK: - Private Methods

private extension ListingViewController {

    func setupTableView() {
        definesPresentationContext = true
        tableView.allowsMultipleSelectionDuringEditing = true
        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleUpdateContentOnPullToRefreshGesture), for: UIControlEvents.valueChanged)
        tableView.register(FileCell.self, forCellReuseIdentifier: String(describing: FileCell.self))
        tableView.register(FolderCell.self, forCellReuseIdentifier: String(describing: FolderCell.self))
        tableView.cellLayoutMarginsFollowReadableWidth = false
        tableView.rowHeight = AppSettings.tableViewRowHeight
    }

    func updateNavigationBarItems() {

        if self.rootLocation.path == "/" {
            self.title = rootLocation.mount.name
        } else {
            self.title = (rootLocation.path as NSString).lastPathComponent
        }

        switch self.action {

        case .copy, .move:
            self.navigationItem.prompt = NSLocalizedString("Choose a destination", comment: "")

            let cancelButton = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: .done, target: self, action: #selector(handleCancelCopyOrMoveAction))

            navigationItem.rightBarButtonItem = cancelButton

        default:
            break
        }
    }

    func setupToolBarButtonItems() {
        switch self.action {

        case .copy, .move:

            navigationController?.isToolbarHidden = false

            let buttonTitle = self.action == .copy ?
                NSLocalizedString("Save copy", comment: "") :
                NSLocalizedString("Move", comment: "")

            let copyMoveButton = UIBarButtonItem(title: buttonTitle, style: .done, target: self, action: #selector(handleCopyOrMoveAction))
            copyMoveButton.isEnabled = true

            self.toolbarItems = [createFolderBarButton, flexibleBarButton, bookmarksBarButton, flexibleBarButton, copyMoveButton]

        default:
            self.toolbarItems = [deleteInEditModeButton, flexibleBarButton, copyInEditModeButton, flexibleBarButton, moveInEditModeButton]
        }
    }

    func setupSearchController() {

        // Pass the location of the current folder
        let src = SearchResultController(location: self.rootLocation)

        searchController = UISearchController(searchResultsController: src)
        searchController.searchResultsUpdater = src
        searchController.searchBar.delegate = src
        searchController.searchBar.autocorrectionType = .no
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.placeholder = NSLocalizedString("Search for files or folders", comment: "")
        searchController.searchBar.scopeButtonTitles = [NSLocalizedString("This folder", comment: ""),
                                                        NSLocalizedString("Everywhere", comment: "")]
        searchController.searchBar.setValue(NSLocalizedString("Cancel", comment: ""), forKey: "cancelButtonText")
        switch self.action {
        case .copy, .move: break
        default:
            navigationItem.searchController = searchController
        }
    }

    func presentError(message: String) {

        let title = NSLocalizedString("Error", comment: "")
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }

    func getContent() {
        needRefresh = false
        isUpdating = true
        didReceivedNetworkError = false

        DigiClient.shared.getBundle(for: self.rootLocation) { nodesResult, rootNodeResult, error in
            self.isUpdating = false
            guard error == nil else {
                self.didReceivedNetworkError = true
                switch error! {
                case NetworkingError.internetOffline(let msg):
                    self.errorMessage = msg
                case NetworkingError.requestTimedOut(let msg):
                    self.errorMessage = msg
                default:
                    self.errorMessage = NSLocalizedString("There was an error while refreshing the locations.", comment: "")
                }

                if self.tableView.isDragging {
                    return
                }

                self.busyIndicator.stopAnimating()
                self.emptyFolderLabel.text = NSLocalizedString("The location is not available.", comment: "")

                self.nodes.removeAll()
                self.tableView.reloadData()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.presentError(message: self.errorMessage)
                }

                return
            }

            guard nodesResult != nil, rootNodeResult != nil else {
                print("Error at receiving content.")
                return
            }

            let nodes: [Node] = nodesResult!
            self.rootNode = rootNodeResult!

            if self.action == .copy || self.action == .move {

                // While copy and move, we sort by name with folders shown first
                self.nodes = nodes.sorted {
                    return $0.type == $1.type ? ($0.name.lowercased() < $1.name.lowercased()) : ($0.type < $1.type)
                }
            } else {

                // In normal case (.noAction) we just sort the content with the method saved by the user.

                self.nodes = nodes
                self.sortContent()

            }

            // In case the user pulled the table to refresh, reload table only if the user has finished dragging.
            if self.refreshControl?.isRefreshing == true {
                if self.tableView.isDragging {
                    return
                } else {
                    self.updateLocationContentMessage()
                    self.endRefreshAndReloadTable()
                }
            } else {
                self.updateLocationContentMessage()

                // The content update is made while normal navigating through folders, in this case simply reload the table.
                self.tableView.reloadData()
                self.highlightSearchResultIfNeeded()
            }
        }
    }

    func highlightSearchResultIfNeeded() {

        if let nameToHighlight = self.searchResult?.lowercased() {

            if !searchResultWasHighlighted {

                var indexFound = -1

                for nodeItem in self.nodes.enumerated() {
                    if nodeItem.element.name.lowercased() == nameToHighlight {
                        indexFound = nodeItem.offset
                        break
                    }
                }

                if indexFound != -1 {
                    let indexPath = IndexPath(row: indexFound, section: 0)
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
                }
            }
        }
    }

    func updateLocationContentMessage() {
        busyIndicator.stopAnimating()
        emptyFolderLabel.text = NSLocalizedString("Folder is Empty", comment: "")
    }

    func endRefreshAndReloadTable() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {

            self.refreshControl?.endRefreshing()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {

                if self.didReceivedNetworkError {
                    self.presentError(message: self.errorMessage)
                } else {
                    self.updateLocationContentMessage()
                    self.tableView.reloadData()
                }
            }
        }
    }

    func sortContent() {
        switch AppSettings.sortMethod {
        case .byName:        sortByName()
        case .byDate:        sortByDate()
        case .bySize:        sortBySize()
        case .byContentType: sortByContentType()
        }
    }

    func animateActionButton(_ button: UIButton) {

        var transform: CGAffineTransform

        if button.transform == .identity {
            transform = CGAffineTransform.init(rotationAngle: CGFloat(Double.pi))
        } else {
            transform = CGAffineTransform.identity
        }

        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1, initialSpringVelocity: 1,
                       options: UIViewAnimationOptions.curveEaseOut,
                       animations: { button.transform = transform },
                       completion: nil)
    }

    func updateNavigationBarRightButtonItems() {

        var rightBarButtonItems: [UIBarButtonItem] = []

        if tableView.isEditing {
            rightBarButtonItems.append(cancelInEditModeButton)
        } else {

            let moreActionsBarButton = UIBarButtonItem(image: #imageLiteral(resourceName: "more_icon"), style: .done, target: self, action: #selector(handleShowMoreActionsViewController(_:)))
            moreActionsBarButton.tag = 0

            let sortBarButton = UIBarButtonItem(image: #imageLiteral(resourceName: "sort_icon"), style: .done, target: self, action: #selector(handleShowSortingSelectionViewController(_:)))
            sortBarButton.tag = 1

            let searchBarButton = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(handleShowSearchViewController(_:)))
            searchBarButton.tag = 2

            rightBarButtonItems.append(moreActionsBarButton)
            rightBarButtonItems.append(contentsOf: [sortBarButton, bookmarksBarButton])

        }

        navigationItem.setRightBarButtonItems(rightBarButtonItems, animated: false)
    }

    func updateToolBarButtonItemsToMatchTableState() {
        if tableView.indexPathsForSelectedRows != nil, toolbarItems != nil {

            if rootLocation.mount.canWrite {
                moveInEditModeButton.isEnabled = true
                deleteInEditModeButton.isEnabled = true
            }
            copyInEditModeButton.isEnabled = true

        } else {
            self.toolbarItems!.forEach { $0.isEnabled = false }
        }
    }

    func updateTableState() {

        // Clear source locations
        self.sourceLocations = nil

        if self.needRefresh {

            if self.tableView.isEditing {
                self.handleCancelEditMode()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.getContent()
                }
            } else {
                self.getContent()
            }
        }
    }

    func activateEditMode() {
        tableView.setEditing(true, animated: true)
        navigationController?.setToolbarHidden(false, animated: true)
        updateNavigationBarRightButtonItems()
        updateToolBarButtonItemsToMatchTableState()
    }

    func sortByName() {
        if AppSettings.showsFoldersFirst {
            if AppSettings.sortAscending {
                self.nodes.sort { return $0.type == $1.type ? ($0.name.lowercased() < $1.name.lowercased()) : ($0.type < $1.type) }
            } else {
                self.nodes.sort { return $0.type == $1.type ? ($0.name.lowercased() > $1.name.lowercased()) : ($0.type < $1.type) }
            }
        } else {
            if AppSettings.sortAscending {
                self.nodes.sort { return $0.name.lowercased() < $1.name.lowercased() }
            } else {
                self.nodes.sort { return $0.name.lowercased() > $1.name.lowercased() }
            }
        }
    }

    func sortByDate() {
        if AppSettings.showsFoldersFirst {
            if AppSettings.sortAscending {
                self.nodes.sort { return $0.type == $1.type ? ($0.modified < $1.modified) : ($0.type < $1.type) }
            } else {
                self.nodes.sort { return $0.type == $1.type ? ($0.modified > $1.modified) : ($0.type < $1.type) }
            }
        } else {
            if AppSettings.sortAscending {
                self.nodes.sort { return $0.modified < $1.modified }
            } else {
                self.nodes.sort { return $0.modified > $1.modified }
            }
        }
    }

    func sortBySize() {
        if AppSettings.sortAscending {
            self.nodes.sort { return $0.type == $1.type ? ($0.size < $1.size) : ($0.type < $1.type) }
        } else {
            self.nodes.sort { return $0.type == $1.type ? ($0.size > $1.size) : ($0.type < $1.type) }
        }
    }

    func sortByContentType() {
        if AppSettings.sortAscending {
            self.nodes.sort { return $0.type == $1.type ? ($0.ext < $1.ext) : ($0.type < $1.type) }
        } else {
            self.nodes.sort { return $0.type == $1.type ? ($0.ext > $1.ext) : ($0.type < $1.type) }
        }
    }

    func setBusyIndicatorView(_ visible: Bool) {
        guard let navControllerView = navigationController?.view else {
            return
        }
        if visible {
            let screenSize = navControllerView.bounds.size
            let origin = CGPoint(x: (screenSize.width / 2) - 45, y: (screenSize.height / 2) - 45)
            let frame = CGRect(origin: origin, size: CGSize(width: 90, height: 90))
            let overlayView = UIView(frame: frame)
            overlayView.layer.cornerRadius = 8
            overlayView.backgroundColor = UIColor.init(white: 0.75, alpha: 1.0)
            overlayView.tag = 9999

            navControllerView.addSubview(overlayView)

            let activityIndicator = UIActivityIndicatorView()
            activityIndicator.startAnimating()
            activityIndicator.activityIndicatorViewStyle = .white
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            navControllerView.addSubview(activityIndicator)

            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: navControllerView.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: navControllerView.centerYAnchor)
                ])

        } else {
            if let overlayView = navControllerView.viewWithTag(9999) {
                UIView.animate(withDuration: 0.4, animations: {
                    overlayView.alpha = 0
                }, completion: { _ in
                    overlayView.removeFromSuperview()
                })
            }
        }
    }

    func setNeedsRefreshInMain() {
        // Set needRefresh true in the main Listing controller
        if let nav = self.presentingViewController as? UINavigationController {
            for controller in nav.viewControllers {
                if let controller = controller as? ListingViewController {
                    controller.needRefresh = true
                }
            }
        }
    }

    func setNeedsRefreshInPrevious() {
        if let viewControllers = self.navigationController?.viewControllers {
            if let previousVC = viewControllers[viewControllers.count-2] as? ListingViewController {
                previousVC.needRefresh = true
            }
        }
    }

    func presentController(_ controller: UIViewController, sender: UIView) {
        if traitCollection.horizontalSizeClass == .regular {
            controller.modalPresentationStyle = .popover
            controller.popoverPresentationController?.sourceView = sender
            controller.popoverPresentationController?.sourceRect = sender.bounds
            present(controller, animated: true, completion: nil)
        } else {
            let navigationController = UINavigationController(rootViewController: controller)
            present(navigationController, animated: true, completion: nil)
        }
    }

    func executeToogleBookmark(location: Location, node: Node, index: Int? = nil) {
        func updateBookmarkIcon(bookmark: Bookmark?) {
            if let index = index {
                let indexPath = IndexPath(row: index, section: 0)
                self.nodes[indexPath.row].bookmark = bookmark
                self.tableView.reloadRows(at: [indexPath], with: .none)
            } else {
                self.rootNode?.bookmark = bookmark
            }
        }
        if var bookmark = node.bookmark {
            bookmark.mountId = location.mount.identifier
            DigiClient.shared.removeBookmark(bookmark: bookmark) { error in
                guard error == nil else {
                    print(error!.localizedDescription)
                    return
                }
                updateBookmarkIcon(bookmark: nil)
            }
        } else {
            let bookmark = Bookmark(name: node.name, mountId: location.mount.identifier, path: location.path)
            DigiClient.shared.addBookmark(bookmark: bookmark) { error in
                guard error == nil else {
                    print(error!.localizedDescription)
                    return
                }
                updateBookmarkIcon(bookmark: bookmark)
            }
        }
    }

    func executeDeletion(at location: Location, index: Int) {
        DigiClient.shared.deleteNode(at: location) { (statusCode, error) in
            guard error == nil else {
                print(error!.localizedDescription)
                return
            }
            if let code = statusCode {
                switch code {

                case 200:
                    self.nodes.remove(at: index)
                    if self.nodes.isEmpty {
                        self.updateLocationContentMessage()
                    } else {
                        self.tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .left)
                    }

                    // MUST: for reordering the buttons tags!
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.tableView.reloadData()
                    }

                case 400:
                    // TODO: Alert Bad Request
                    break
                case 404:
                    // File not found, folder will be refreshed
                    break
                default :
                    // TODO: Alert Status Code server
                    break
                }
            }
        }
    }

    func executeCopyOrMove(sourceLocation: Location) {

        let sourceName = (sourceLocation.path as NSString).lastPathComponent
        let isFolder = sourceName.last == "/"
        let index = sourceName.getIndexBeforeExtension()

        // Start with initial destination location.
        var destinationLocation = self.rootLocation.appendingPathComponent(sourceName, isFolder: isFolder)

        if self.action == .copy {
            var destinationName = sourceName
            var copyCount: Int = 0
            var wasRenamed = false
            var wasFound = false
            repeat {
                // reset before check of all nodes
                wasFound = false

                // check all nodes for the initial name or new name incremented
                for node in self.nodes where node.name == destinationName {
                    // set the flags
                    wasFound = true

                    // increment counter in the new file name
                    copyCount += 1

                    // reset name to original
                    destinationName = sourceName

                    // Pad number (using Foundation Method)
                    let countString = String(format: " (%d)", copyCount)

                    // If name has an extension, we introduce the count number
                    if index != nil {
                        destinationName.insert(contentsOf: countString, at: index!)
                    } else {
                        destinationName = sourceName + countString
                    }

                    wasRenamed = true
                }
            } while (wasRenamed && wasFound)

            // change the file/folder name with incremented one
            destinationLocation = self.rootLocation.appendingPathComponent(destinationName, isFolder: isFolder)
        }

        dispatchGroup.enter()

        DigiClient.shared.copyOrMove(from: sourceLocation, to: destinationLocation, action: self.action) { statusCode, error in

            self.dispatchGroup.leave()

            guard error == nil else {
                self.didReceivedNetworkError = true
                DLog(object: error!.localizedDescription)
                return
            }

            if let code = statusCode {
                switch code {
                case 200:
                    // Operation successfully completed
                    self.setNeedsRefreshInMain()
                    self.didSucceedCopyOrMove = true
                case 400:
                    // Bad request ( Folder already exists, invalid file name?)
                    self.didReceivedStatus400 = true
                case 404:
                    // Not Found (Folder do not exists anymore), folder will refresh
                    self.setNeedsRefreshInMain()
                    self.didReceivedStatus404 = true
                default :
                    print("Server replied with Status Code: ", code)
                }
            }
        }
    }

    func executeDeletionInSelectionMode(locations: [Location]) {

        guard isActionConfirmed else {

            let string: String
            if locations.count == 1 {
                if locations.first!.path.last == "/" {
                    string = NSLocalizedString("Are you sure you want to delete this folder?", comment: "")
                } else {
                    string = NSLocalizedString("Are you sure you want to delete this file?", comment: "")
                }
            } else {
                string = NSLocalizedString("Are you sure you want to delete %d items?", comment: "")
            }

            let title = String.localizedStringWithFormat(string, locations.count)
            let message = NSLocalizedString("This action is not reversible.", comment: "")
            let confirmationController = UIAlertController(title: title, message: message, preferredStyle: .alert)

            let deleteAction = UIAlertAction(title: NSLocalizedString("Yes", comment: ""), style: .destructive, handler: { _ in
                self.isActionConfirmed = true
                self.executeDeletionInSelectionMode(locations: locations)
            })

            let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
            confirmationController.addAction(deleteAction)
            confirmationController.addAction(cancelAction)
            present(confirmationController, animated: true, completion: nil)
            return
        }

        self.isActionConfirmed = false
        self.setBusyIndicatorView(true)

        didSucceedCopyOrMove = false
        didReceivedNetworkError = false
        didReceivedStatus400 = false
        didReceivedStatus404 = false

        self.handleCancelEditMode()

        for location in locations {
            self.dispatchGroup.enter()

            DigiClient.shared.deleteNode(at: location) { statusCode, error in

                self.dispatchGroup.leave()

                guard error == nil, statusCode != nil else {
                    print(error!.localizedDescription)
                    return
                }

                if statusCode! != 200 {
                    print("Could not delete an item.")
                }

            }
        }

        // After all deletions have finished...
        dispatchGroup.notify(queue: .main) {
            self.setBusyIndicatorView(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.getContent()
            }
        }

    }

    func showRenameViewController(nodeLocation: Location, node: Node, index: Int) {

        let controller = RenameViewController(nodeLocation: nodeLocation, node: node)

        controller.onRename = { [weak self] name in
            self?.nodes[index].name = name

            self?.tableView.reloadRows(at: [IndexPath.init(row: index, section: 0)], with: .middle)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self?.getContent()
            }
        }

        let navController = UINavigationController(rootViewController: controller)

        navController.modalPresentationStyle = .formSheet
        self.present(navController, animated: true, completion: nil)

    }

    func showFolderInfoViewController(location: Location, index: Int) {

        let controller = FolderInfoViewController(location: location)

        controller.onFinish = { [weak self] in
            self?.executeDeletion(at: location, index: index)
        }

        let navController = UINavigationController(rootViewController: controller)
        navController.modalPresentationStyle = .formSheet
        self.present(navController, animated: true, completion: nil)
    }

    func showDeleteViewController(location: Location, sourceView: UIView, index: Int) {

        let controller = DeleteViewController(isFolder: false)

        controller.onSelection = { [weak self] in
            self?.executeDeletion(at: location, index: index)
        }

        presentController(controller, sender: sourceView)
    }

    func showCopyOrMoveViewController(action: ActionType, sourceLocations: [Location]) {

        guard let stackControllers = self.navigationController?.viewControllers else {
            print("Couldn't get the previous navigation controllers!")
            return
        }

        var controllers: [UIViewController] = []

        for controller in stackControllers {

            if controller is LocationsViewController {

                let locationController = LocationsViewController(action: action, sourceLocations: sourceLocations)

                locationController.title = NSLocalizedString("Locations", comment: "")

                locationController.onFinish = { [weak self] in
                    self?.updateTableState()
                }

                controllers.append(locationController)
                continue

            } else {

                guard let  rootLocation = (controller as? ListingViewController)?.rootLocation else {
                    continue
                }

                let listingViewController = ListingViewController(location: rootLocation, action: action, sourceLocations: sourceLocations)
                listingViewController.title = controller.title

                listingViewController.onFinish = { [weak self] in
                    self?.updateTableState()
                }
                controllers.append(listingViewController)
            }
        }

        let navController = UINavigationController(navigationBarClass: CustomNavBar.self, toolbarClass: nil)
        navController.setViewControllers(controllers, animated: false)
        navController.modalPresentationStyle = .formSheet
        self.present(navController, animated: true, completion: nil)

    }

    func showLinkViewController(location: Location, sharedNode: Node, linkType: LinkType) {

        let onFinish = { [weak self] (shouldExitMount: Bool) in

            if let navController = self?.navigationController as? MainNavigationController {
                self?.getContent()

                for controller in navController.viewControllers {
                    (controller as? ListingViewController)?.needRefresh = true
                }
            }
        }

        let controller = ShareLinkViewController(location: location, linkType: linkType, onFinish: onFinish)
        let navController = UINavigationController(rootViewController: controller)
        navController.modalPresentationStyle = .formSheet
        self.present(navController, animated: true, completion: nil)
    }

    func showShareMountViewController(location: Location, sharedNode: Node) {

        let onFinish = { [weak self] (shouldExitMount: Bool) in

            if let navController = self?.navigationController as? MainNavigationController {
                if shouldExitMount {
                    navController.popToRootViewController(animated: true)
                } else {

                    self?.getContent()

                    for controller in navController.viewControllers {
                        (controller as? ListingViewController)?.needRefresh = true
                    }
                }
            }
        }

        let controller = ShareMountViewController(location: location, sharedNode: sharedNode, onFinish: onFinish)
        let navController = UINavigationController(rootViewController: controller)
        navController.modalPresentationStyle = .formSheet
        self.present(navController, animated: true, completion: nil)
    }
}
