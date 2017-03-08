//
//  ListingViewController.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 19/09/16.
//  Copyright © 2016 Mihai Cristescu. All rights reserved.
//

import UIKit

#if DEBUGCONTROLLERS
    var taskStarted: Int = 0
    var taskFinished: Int = 0
#endif

final class ListingViewController: UITableViewController {

    // MARK: - Properties

    var onFinish: (() -> Void)?

    // Type of action made by controller
    fileprivate let action: ActionType

    // The root location in normal listing mode
    fileprivate var location: Location

    // When coping or moving files/directories, this property will hold the source location which is passed between
    // controllers on navigation stack.
    fileprivate var sourceLocations: [Location]?

    fileprivate var needRefresh: Bool = true
    fileprivate var content: [Node] = []
    fileprivate var selectedIndexPath: IndexPath!
    private     let searchResult: String?
    private     var isUpdating: Bool = false
    private     var isActionConfirmed: Bool = false
    private     var searchController: UISearchController!
    private     var fileCellID = String()
    private     var folderCellID = String()
    private     let dispatchGroup = DispatchGroup()
    private     var didReceivedNetworkError = false
    private     var didReceivedStatus400 = false
    private     var didReceivedStatus404 = false
    private     var didSucceedCopyOrMove = false
    private     var searchResultWasHighlighted = false

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "dd.MM.YYY・HH:mm"
        return f
    }()

    private let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        f.allowsNonnumericFormatting = false
        return f
    }()

    private let busyIndicator: UIActivityIndicatorView = {
        let i = UIActivityIndicatorView()
        i.hidesWhenStopped = true
        i.activityIndicatorViewStyle = .gray
        i.translatesAutoresizingMaskIntoConstraints = false
        return i
    }()

    private let emptyFolderLabel: UILabel = {
        let l = UILabel()
        l.textColor = UIColor.lightGray
        l.textAlignment = .center
        return l
    }()

    private lazy var messageStackView: UIStackView = {
        let sv = UIStackView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.spacing = 10
        sv.alignment = .center
        sv.addArrangedSubview(self.busyIndicator)
        sv.addArrangedSubview(self.emptyFolderLabel)
        return sv
    }()

    private let flexibleBarButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

    private lazy var createFolderBarButton: UIBarButtonItem = {
        let b = UIBarButtonItem(title: NSLocalizedString("Create Directory", comment: ""), style: .plain, target: self, action: #selector(handleShowCreateDirectoryViewController))
        return b
    }()

    private lazy var copyInEditModeButton: UIBarButtonItem = {
        let b = UIBarButtonItem(title: NSLocalizedString("Copy", comment: ""), style: .plain, target: self, action: #selector(handleExecuteMultipleItemsEditAction(_:)))
        b.tag = ActionType.copy.rawValue
        return b
    }()

    private lazy var moveInEditModeButton: UIBarButtonItem = {
        let b = UIBarButtonItem(title: NSLocalizedString("Move", comment: ""), style: .plain, target: self, action: #selector(handleExecuteMultipleItemsEditAction(_:)))
        b.tag = ActionType.move.rawValue
        return b
    }()

    private lazy var bookmarksBarButton: UIBarButtonItem = {
        let b = UIBarButtonItem(barButtonSystemItem: .bookmarks, target: self, action: #selector(handleShowBookmarksViewController(_:)))
        b.tag = 3
        return b
    }()

    private lazy var deleteInEditModeButton: UIBarButtonItem = {
        let v = UIButton(type: UIButtonType.system)
        v.setTitle(NSLocalizedString("Delete", comment: ""), for: .normal)
        v.addTarget(self, action: #selector(handleExecuteMultipleItemsEditAction(_:)), for: .touchUpInside)
        v.setTitleColor(UIColor(white: 0.8, alpha: 1), for: .disabled)
        v.setTitleColor(.red, for: .normal)
        v.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        v.sizeToFit()
        v.tag = ActionType.delete.rawValue
        let b = UIBarButtonItem(customView: v)
        return b
    }()

    private lazy var cancelInEditModeButton: UIBarButtonItem = {
        let b = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: .plain, target: self, action: #selector(cancelEditMode))
        return b
    }()

    // MARK: - Initializers and Deinitializers

    init(location: Location, action: ActionType, searchResult: String? = nil, sourceLocations: [Location]? = nil) {
        self.location = location
        self.action = action
        self.searchResult = searchResult
        self.sourceLocations = sourceLocations
        super.init(style: .plain)
        INITLog(self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit { DEINITLog(self) }

    // MARK: - Overridden Methods and Properties

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupSearchController()
        setupViews()
    }

    override func viewWillAppear(_ animated: Bool) {
        if [ActionType.noAction, ActionType.showSearchResult].contains(self.action) {
            updateNavigationBarRightButtonItems()
            tableView.tableHeaderView = nil
        }
        if needRefresh {
            content.removeAll()
            busyIndicator.startAnimating()
            emptyFolderLabel.text = NSLocalizedString("Loading ...", comment: "")
            tableView.reloadData()
        }
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if needRefresh {
            self.updateContent()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {

        #if DEBUG
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        #endif

        if tableView.isEditing {
            cancelEditMode()
        }
        DigiClient.shared.task?.cancel()
        super.viewWillDisappear(animated)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return content.isEmpty ? 2 : content.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if content.isEmpty {

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

        let item = content[indexPath.row]

        if item.type == "dir" {

            guard let cell = tableView.dequeueReusableCell(withIdentifier: folderCellID, for: indexPath) as? DirectoryCell else {
                return UITableViewCell()
            }

            cell.actionsButton.addTarget(self, action: #selector(handleShowActionController(_:)), for: .touchUpInside)
            cell.actionsButton.tag = indexPath.row


            cell.nameLabel.text = item.name

            cell.hasButton = [ActionType.noAction, ActionType.showSearchResult].contains(self.action)
            cell.isShared = item.share != nil
            cell.hasDownloadLink = item.downloadLink != nil
            cell.hasUploadLink = item.uploadLink != nil
            cell.isBookmarked = item.bookmark != nil

            let modifiedDateString = dateFormatter.string(from: Date(timeIntervalSince1970: item.modified / 1000))

            let detailAttributtedString = NSMutableAttributedString(string: modifiedDateString)

            if cell.hasDownloadLink {
                // http://fontawesome.io/icon/cloud-upload/
                let attributedString = NSAttributedString(string: "  \u{f0aa}", attributes: [NSFontAttributeName: UIFont.fontAwesome(size: 12)])
                detailAttributtedString.append(attributedString)
            }

            if cell.hasUploadLink {
                // http://fontawesome.io/icon/cloud-download/
                let attributedString = NSAttributedString(string: "  \u{f0ab}", attributes: [NSFontAttributeName: UIFont.fontAwesome(size: 12)])
                detailAttributtedString.append(attributedString)
            }

            cell.detailsLabel.attributedText = detailAttributtedString

            return cell

        } else {

            guard let cell = tableView.dequeueReusableCell(withIdentifier: fileCellID, for: indexPath) as? FileCell else {
                return UITableViewCell()
            }

            cell.actionsButton.addTarget(self, action: #selector(handleShowActionController(_:)), for: .touchUpInside)
            cell.actionsButton.tag = indexPath.row
            cell.hasButton = [ActionType.noAction, ActionType.showSearchResult].contains(self.action)
            cell.hasDownloadLink = item.downloadLink != nil

            cell.nameLabel.text = item.name

            let modifiedDateString = dateFormatter.string(from: Date(timeIntervalSince1970: item.modified / 1000))
            let sizeString = byteFormatter.string(fromByteCount: item.size)

            let detailAttributtedString = NSMutableAttributedString(string: sizeString + "・" + modifiedDateString)

            if cell.hasDownloadLink {
                // http://fontawesome.io/icon/cloud-upload/
                let attributedString = NSAttributedString(string: "  \u{f0aa}", attributes: [NSFontAttributeName: UIFont.fontAwesome(size: 12)])
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

        let selectedNode = content[indexPath.row]
        
        let newLocation = self.location.appendingPathComponentFrom(node: selectedNode)

        if selectedNode.type == "dir" {
            
            // This is a Folder
            let controller = ListingViewController(location: newLocation, action: self.action, sourceLocations: self.sourceLocations)

            if self.action != .noAction {

                // It makes sens only if this is a copy or move controller
                controller.onFinish = { [unowned self] in
                    self.onFinish?()
                }
            }
            navigationController?.pushViewController(controller, animated: true)

        } else {

            // This is a file

            if [ActionType.noAction, ActionType.showSearchResult].contains(self.action) {
                let controller = ContentViewController(location: newLocation)
                navigationController?.pushViewController(controller, animated: true)
            }
        }
    }

    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if refreshControl?.isRefreshing == true {
            if self.isUpdating {
                return
            }
            endRefreshAndReloadTable()
        }
    }

    // MARK: - Helper Methods

    private func setupTableView() {

        self.fileCellID = "FileCell"
        self.folderCellID = "DirectoryCell"
        definesPresentationContext = true
        tableView.allowsMultipleSelectionDuringEditing = true

        refreshControl = UIRefreshControl()
        refreshControl?.addTarget(self, action: #selector(handleUpdateContentOnPullToRefreshGesture), for: UIControlEvents.valueChanged)
        tableView.register(FileCell.self, forCellReuseIdentifier: fileCellID)
        tableView.register(DirectoryCell.self, forCellReuseIdentifier: folderCellID)
        tableView.cellLayoutMarginsFollowReadableWidth = false
        tableView.rowHeight = AppSettings.tableViewRowHeight
    }

    private func setupViews() {
        
        switch self.action {

        case .copy, .move:
            self.navigationItem.prompt = NSLocalizedString("Choose a destination", comment: "")

            let cancelButton = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: .plain, target: self, action: #selector(handleCancelCopyOrMoveAction))

            navigationItem.rightBarButtonItem = cancelButton

            navigationController?.isToolbarHidden = false

            let buttonTitle = self.action == .copy ?
                NSLocalizedString("Save copy", comment: "") :
                NSLocalizedString("Move", comment: "")

            let copyMoveButton = UIBarButtonItem(title: buttonTitle, style: .plain, target: self, action: #selector(handleExecuteCopyOrMoveAction))
            copyMoveButton.isEnabled = true

            self.toolbarItems = [createFolderBarButton, flexibleBarButton, copyMoveButton]

        default:
            self.toolbarItems = [deleteInEditModeButton, flexibleBarButton, copyInEditModeButton, flexibleBarButton, moveInEditModeButton]
        }

        if self.location.path == "/" {
            self.title = location.mount.name
        } else {
            self.title = (location.path as NSString).lastPathComponent
        }
    }
    
    @objc private func handleShowBookmarksViewController(_ sender: UIBarButtonItem) {

        guard let buttonView = sender.value(forKey: "view") as? UIView, sender.tag == 3 else {
            return
        }
        
        let controller = ManageBookmarksViewController()

        controller.onFinish = { [weak self] in
            self?.dismiss(animated: true) {
                self?.updateContent()
            }
        }
        
        controller.onUpdate = { [weak self] in
            self?.updateContent()
        }

        controller.onSelect = { [weak self] location in
            self?.dismiss(animated: true) {
                let controller = ListingViewController(location: location, action: .noAction)
                self?.navigationController?.pushViewController(controller, animated: true)
            }
        }

        let navController = UINavigationController(rootViewController: controller)
        navController.modalPresentationStyle = .popover
        navController.popoverPresentationController?.sourceView = buttonView
        navController.popoverPresentationController?.sourceRect = buttonView.bounds
        present(navController, animated: true, completion: nil)
    }

    private func setupSearchController() {

        // Pass the location of the current directory
        let src = SearchResultController(location: self.location)
        
        searchController = UISearchController(searchResultsController: src)
        searchController.delegate = self
        searchController.loadViewIfNeeded()
        searchController.searchResultsUpdater = src
        searchController.searchBar.delegate = src
        searchController.searchBar.autocorrectionType = .no
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.placeholder = NSLocalizedString("Search for files or directories", comment: "")
        searchController.searchBar.scopeButtonTitles = [NSLocalizedString("This directory", comment: ""),
                                                        NSLocalizedString("Everywhere", comment: "")]
        searchController.searchBar.setValue(NSLocalizedString("Cancel", comment: ""), forKey: "cancelButtonText")
    }

    private func presentError() {

        self.busyIndicator.stopAnimating()
        self.emptyFolderLabel.text = NSLocalizedString("The location is not available.", comment: "")

        let message = NSLocalizedString("There was an error refreshing the location.", comment: "")
        let title = NSLocalizedString("Error", comment: "")
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }

    fileprivate func updateContent() {

        needRefresh = false
        isUpdating = true
        didReceivedNetworkError = false

        DigiClient.shared.getBundle(for: self.location) { nodesResult, error in

            self.isUpdating = false

            guard error == nil else {

                self.didReceivedNetworkError = true

                switch error! {

                case NetworkingError.wrongStatus(let message):
                    self.emptyFolderLabel.text = message
                    self.content.removeAll()
                    self.tableView.reloadData()
                default:

                    if self.tableView.isDragging {
                        return
                    }
                    self.presentError()
                }
                return
            }

            var nodes = nodesResult ?? []
            
            switch self.action {
                
            case .copy, .move:

                // Only in move action, the moved node should not appear in the list.
                if self.action == .move {
                    
                    guard self.sourceLocations != nil else {
                        
                        #if DEBUG
                            print("sourceLocations is nill")
                            fatalError()
                        #endif
                        
                        break
                    }
                    
                    let sourceNames = self.sourceLocations!.map { return ($0.path as NSString).lastPathComponent }

                    nodes = nodes.filter { node in
                        return !sourceNames.contains { source in
                            return node.name == source
                        }
                    }
                }
                
                // While copy and move, we sort by name with folders shown first
                self.content = nodes.sorted {
                    return $0.type == $1.type ? ($0.name.lowercased() < $1.name.lowercased()) : ($0.type < $1.type)
                }
                
            default:
                // In normal case (.noAction) we just sort the content with the method saved by the user.
                self.content = nodes
                self.sortContent()
            }
            
            // In case the user pulled the table to refresh, reload table only if the user has finished dragging.
            if self.refreshControl?.isRefreshing == true {
                if self.tableView.isDragging {
                    return
                } else {
                    self.updateDirectoryMessage()
                    self.endRefreshAndReloadTable()
                }
            } else {
                self.updateDirectoryMessage()
                
                // The content update is made while normal navigating through folders, in this case simply reload the table.
                self.tableView.reloadData()
                self.highlightSearchResultIfNeeded()
                
            }
            
        }
    }
    
    private func highlightSearchResultIfNeeded() {
        
        if let nameToHighlight = self.searchResult?.lowercased() {
            
            if !searchResultWasHighlighted {
                
                var indexFound = -1
                
                for (index, node) in self.content.enumerated() {
                    if node.name.lowercased() == nameToHighlight {
                        indexFound = index
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

    fileprivate func updateDirectoryMessage() {
        busyIndicator.stopAnimating()
        emptyFolderLabel.text = NSLocalizedString("Directory is Empty", comment: "")
    }

    private func endRefreshAndReloadTable() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.refreshControl?.endRefreshing()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {

                if self.didReceivedNetworkError {
                   self.presentError()

                } else {
                    self.updateDirectoryMessage()
                    self.tableView.reloadData()
                }

            }
        }
    }

    private func sortContent() {
        switch AppSettings.sortMethod {
        case .byName:        sortByName()
        case .byDate:        sortByDate()
        case .bySize:        sortBySize()
        case .byContentType: sortByContentType()
        }
    }

    fileprivate func animateActionButton(active: Bool) {
        guard let actionsButton = (tableView.cellForRow(at: selectedIndexPath) as? BaseListCell)?.actionsButton else {
            return
        }
        let transform = active ? CGAffineTransform.init(rotationAngle: CGFloat(Double.pi)) : CGAffineTransform.identity
        UIView.animate(withDuration: 0.4,
                       delay: 0.0,
                       usingSpringWithDamping: 1,
                       initialSpringVelocity: 1,
                       options: UIViewAnimationOptions.curveEaseOut,
                       animations: {
                        actionsButton.transform = transform
        },
                       completion: nil)
    }

    private func updateNavigationBarRightButtonItems() {

        var rightBarButtonItems: [UIBarButtonItem] = []

        if tableView.isEditing {
            rightBarButtonItems.append(cancelInEditModeButton)
        } else {
            
            let moreActionsBarButton = UIBarButtonItem(image: #imageLiteral(resourceName: "more_icon"), style: .plain, target: self, action: #selector(handleShowMoreActionsViewController(_:)))
            moreActionsBarButton.tag = 0
            
            let sortBarButton = UIBarButtonItem(image: #imageLiteral(resourceName: "sort_icon"), style: .plain, target: self, action: #selector(handleShowSortingSelectionViewController(_:)))
            sortBarButton.tag = 1
            
            let searchBarButton = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(handleShowSearchViewController(_:)))
            searchBarButton.tag = 2
            
            if location.mount.permissions.write {
                rightBarButtonItems.append(moreActionsBarButton)
            }
            
            rightBarButtonItems.append(contentsOf: [sortBarButton, searchBarButton, bookmarksBarButton])
        }

        navigationItem.setRightBarButtonItems(rightBarButtonItems, animated: false)
    }

    private func updateToolBarButtonItemsToMatchTableState() {
        if tableView.indexPathsForSelectedRows != nil, toolbarItems != nil {
            self.toolbarItems!.forEach { $0.isEnabled = true }
        } else {
            self.toolbarItems!.forEach { $0.isEnabled = false }
        }
    }

    private func sortByName() {
        if AppSettings.showsFoldersFirst {
            if AppSettings.sortAscending {
                self.content.sort { return $0.type == $1.type ? ($0.name.lowercased() < $1.name.lowercased()) : ($0.type < $1.type) }
            } else {
                self.content.sort { return $0.type == $1.type ? ($0.name.lowercased() > $1.name.lowercased()) : ($0.type < $1.type) }
            }
        } else {
            if AppSettings.sortAscending {
                self.content.sort { return $0.name.lowercased() < $1.name.lowercased() }
            } else {
                self.content.sort { return $0.name.lowercased() > $1.name.lowercased() }
            }
        }
    }

    private func sortByDate() {
        if AppSettings.showsFoldersFirst {
            if AppSettings.sortAscending {
                self.content.sort { return $0.type == $1.type ? ($0.modified < $1.modified) : ($0.type < $1.type) }
            } else {
                self.content.sort { return $0.type == $1.type ? ($0.modified > $1.modified) : ($0.type < $1.type) }
            }
        } else {
            if AppSettings.sortAscending {
                self.content.sort { return $0.modified < $1.modified }
            } else {
                self.content.sort { return $0.modified > $1.modified }
            }
        }
    }

    private func sortBySize() {
        if AppSettings.sortAscending {
            self.content.sort { return $0.type == $1.type ? ($0.size < $1.size) : ($0.type < $1.type) }
        } else {
            self.content.sort { return $0.type == $1.type ? ($0.size > $1.size) : ($0.type < $1.type) }
        }
    }

    private func sortByContentType() {
        if AppSettings.sortAscending {
            self.content.sort { return $0.type == $1.type ? ($0.ext < $1.ext) : ($0.type < $1.type) }
        } else {
            self.content.sort { return $0.type == $1.type ? ($0.ext > $1.ext) : ($0.type < $1.type) }
        }
    }

    fileprivate func resetSearchViewControllerIndex() {
        if let nav = navigationController as? MainNavigationController {
            nav.searchResultsControllerIndex = nil
        }
    }

    private func setBusyIndicatorView(_ visible: Bool) {
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

    @objc private func handleShowSortingSelectionViewController(_ sender: UIBarButtonItem) {
        
        guard let buttonView = sender.value(forKey: "view") as? UIView, sender.tag == 1 else {
            return
        }
        
        let controller = SortFolderViewController()
        
        controller.onFinish = { [unowned self] in
            self.sortContent()
            self.tableView.reloadData()
        }
        controller.modalPresentationStyle = .popover
        controller.popoverPresentationController?.sourceView = buttonView
        controller.popoverPresentationController?.sourceRect = buttonView.bounds
        present(controller, animated: true, completion: nil)
    }

    @objc private func handleShowMoreActionsViewController(_ sender: UIBarButtonItem) {
        
        guard let buttonView = sender.value(forKey: "view") as? UIView, sender.tag == 0 else {
            return
        }
        
        let controller = MoreActionsViewController(location: self.location)

        controller.onFinish = { [unowned self] selection in
            self.dismiss(animated: true, completion: nil)
            
            switch selection {
            case .createDirectory:
                self.handleShowCreateDirectoryViewController()
            case .selectionMode:
                if self.content.isEmpty { return }
                self.activateEditMode()
            case .share:
                self.showShareViewController(linkLocation: self.location, isDirectory: true)
            }
        }
        
        controller.modalPresentationStyle = .popover
        controller.popoverPresentationController?.sourceView = buttonView
        controller.popoverPresentationController?.sourceRect = buttonView.bounds
        present(controller, animated: true, completion: nil)
    }

    @objc private func handleShowCreateDirectoryViewController() {

        let controller = CreateDirectoryViewController(parentLocation: self.location)
        
        controller.onFinish = { [unowned self] (folderName) in

            let completionBlock = {
                
                guard let folderName = folderName else {
                    // User cancelled the folder creation
                    return
                }

                // Set needRefresh in this list
                self.needRefresh = true

                // Set needRefresh in the main List
                if let nav = self.presentingViewController as? UINavigationController {
                    if let cont = nav.topViewController as? ListingViewController {
                        cont.needRefresh = true
                    }
                }

                let newLocation = self.location.appendingPathComponent(folderName, isDirectory: true)
                let controller = ListingViewController(location: newLocation, action: self.action, sourceLocations: self.sourceLocations)

                controller.onFinish = {[unowned self] in
                    self.onFinish?()
                }
                self.navigationController?.pushViewController(controller, animated: true)
            }

            // dismiss AddFolderViewController
            self.dismiss(animated: true, completion: completionBlock)

        }
        
        let navigationController = UINavigationController(rootViewController: controller)
        navigationController.modalPresentationStyle = .formSheet
        
        present(navigationController, animated: true, completion: nil)

    }

    @objc private func handleCancelCopyOrMoveAction() {
        self.onFinish?()
    }

    @objc private func handleUpdateContentOnPullToRefreshGesture() {
        if self.isUpdating {
            self.refreshControl?.endRefreshing()
            return
        }
        self.updateContent()
    }

    @objc private func handleShowSearchViewController(_ sender: UIBarButtonItem) {
        
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
            self.tableView.setContentOffset(CGPoint(x: 0, y: -64), animated: false)
        
            if self.tableView.tableHeaderView == nil {
                searchController.searchBar.sizeToFit()
                self.tableView.tableHeaderView = searchController.searchBar
            }
            searchController.searchBar.becomeFirstResponder()
        }
    }

    private func setNeedsRefreshInMain() {
        // Set needRefresh true in the main Listing controller
        if let nav = self.presentingViewController as? UINavigationController {
            for controller in nav.viewControllers {
                if let controller = controller as? ListingViewController {
                    controller.needRefresh = true
                }
            }
        }
    }

    private func doCopyOrMove(sourceLocation: Location) {

        let sourceName = (sourceLocation.path as NSString).lastPathComponent
        let isDirectory = sourceName.characters.last == "/"
        let index = sourceName.getIndexBeforeExtension()

        // Start with initial destination location.
        var destinationLocation = self.location.appendingPathComponent(sourceName, isDirectory: isDirectory)

        if self.action == .copy {
            var destinationName = sourceName
            var copyCount: Int = 0
            var wasRenamed = false
            var wasFound = false
            repeat {
                // reset before check of all nodes
                wasFound = false

                // check all nodes for the initial name or new name incremented
                for node in self.content {
                    if node.name == destinationName {
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
                            destinationName.insert(contentsOf: countString.characters, at: index!)
                        } else {
                            destinationName = sourceName + countString
                        }

                        wasRenamed = true
                    }
                }
            } while (wasRenamed && wasFound)

            // change the file/folder name with incremented one
            destinationLocation = self.location.appendingPathComponent(destinationName, isDirectory: isDirectory)
        }

        dispatchGroup.enter()

        DigiClient.shared.copyOrMove(from: sourceLocation, to: destinationLocation, action: self.action) { statusCode, error in

            #if DEBUGCONTROLLERS
                print("Task \(taskFinished) finished")
                taskFinished += 1
            #endif

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

    @objc private func handleExecuteCopyOrMoveAction() {

        setBusyIndicatorView(true)

        guard self.sourceLocations != nil else {
            print("Couldn't get the source locations to move/copy.")

            defer {
                #if DEBUG
                    fatalError()
                #endif
            }

            return
        }

        #if DEBUGCONTROLLERS
                taskStarted = 0
                taskFinished = 0
        #endif

        didSucceedCopyOrMove = false
        didReceivedNetworkError = false
        didReceivedStatus400 = false
        didReceivedStatus404 = false

        for sourceLocation in self.sourceLocations! {
            self.doCopyOrMove(sourceLocation: sourceLocation)
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
            self.onFinish?()
        }
    }

    private func activateEditMode() {
        tableView.setEditing(true, animated: true)
        navigationController?.setToolbarHidden(false, animated: true)
        updateNavigationBarRightButtonItems()
        updateToolBarButtonItemsToMatchTableState()
    }

    @objc private func cancelEditMode() {
        tableView.setEditing(false, animated: true)
        navigationController?.setToolbarHidden(true, animated: true)
        updateNavigationBarRightButtonItems()
    }

    @objc private func handleExecuteMultipleItemsEditAction(_ sender: UIBarButtonItem) {

        guard let chosenAction = ActionType(rawValue: sender.tag) else { return }
        guard let selectedItemsIndexPaths = tableView.indexPathsForSelectedRows else { return }

        let sourceLocations = selectedItemsIndexPaths.map { content[$0.row].location(in: self.location) }

        switch chosenAction {
        case .delete:
            self.showDeleteConfirmationDialog(locations: sourceLocations)
        case .copy, .move:
            self.showViewControllerForCopyOrMove(action: chosenAction, sourceLocations: sourceLocations)
        default:
            break
        }
    }

    private func showDeleteConfirmationDialog(locations: [Location]) {
        
        guard isActionConfirmed else {

            let string: String
            if locations.count == 1 {
                if locations.first!.path.characters.last == "/" {
                    string = NSLocalizedString("Are you sure you want to delete this directory?", comment: "")
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
                self.showDeleteConfirmationDialog(locations: locations)
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

        self.cancelEditMode()

        for location in locations {
            self.dispatchGroup.enter()
            
            DigiClient.shared.deleteNode(at: location) { statusCode, error in
                // TODO: Stop spinner
                guard error == nil, statusCode != nil else {
                    // TODO: Show message for error
                    print(error!.localizedDescription)
                    return
                }
                
                if statusCode! != 200 {
                    // TODO: Mark flag for fail to delete
                    print("Could not delete an item.")
                }
                self.dispatchGroup.leave()
            }
        }

        // After all deletions have finished...
        dispatchGroup.notify(queue: .main) {
            self.setBusyIndicatorView(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.updateContent()
            }
        }

    }

    private func updateTableState() {

        // Clear source locations
        self.sourceLocations = nil

        if self.needRefresh {

            if self.tableView.isEditing {
                self.cancelEditMode()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self.updateContent()
                }
            } else {
                self.updateContent()
            }
        }
    }
    
    @objc private func handleShowActionController(_ sender: UIButton) {
        
        self.selectedIndexPath = IndexPath(row: sender.tag, section: 0)
        self.animateActionButton(active: true)
        
        let controller = NodeActionsViewController(node: self.content[sender.tag])
        controller.delegate = self
        
        controller.modalPresentationStyle = .popover
        controller.popoverPresentationController?.sourceView = sender
        controller.popoverPresentationController?.sourceRect = sender.bounds
        controller.popoverPresentationController?.delegate = self
        present(controller, animated: true, completion: nil)
    }

    fileprivate func showViewControllerForCopyOrMove(action: ActionType, sourceLocations: [Location]) {

        guard let stackControllers = self.navigationController?.viewControllers else {
            print("Couldn't get the previous navigation controllers!")
            return
        }

        var controllers: [UIViewController] = []

        for controller in stackControllers {

            if controller is LocationsViewController {

                let c = LocationsViewController(action: action, sourceLocations: sourceLocations)
                c.title = NSLocalizedString("Locations", comment: "")

                c.onFinish = { [unowned self] in
                    self.dismiss(animated: true) {
                        self.updateTableState()
                    }
                }
                controllers.append(c)
                continue

            } else {

                let aLocation = (controller as! ListingViewController).location
                
                let c = ListingViewController(location: aLocation, action: action, sourceLocations: sourceLocations)
                c.title = controller.title

                c.onFinish = { [unowned self] in
                    self.dismiss(animated: true) {
                        self.updateTableState()
                    }
                }
                controllers.append(c)
            }
        }

        let navController = UINavigationController(navigationBarClass: CustomNavBar.self, toolbarClass: nil)
        navController.setViewControllers(controllers, animated: false)
        navController.modalPresentationStyle = .formSheet
        self.present(navController, animated: true, completion: nil)

    }

    fileprivate func showShareViewController(linkLocation: Location, isDirectory: Bool) {

        let onFinish: () -> Void = { [unowned self] in
            self.dismiss(animated: true) {
                self.updateContent()
                if let navController = self.navigationController as? MainNavigationController {
                    for controller in navController.viewControllers {
                        (controller as? ListingViewController)?.needRefresh = true
                    }
                }
            }
        }

        let controller: UIViewController
        
        if isDirectory {
            controller = ShareViewController(location: linkLocation, onFinish: onFinish)
        } else {
            controller = ShareLinkViewController(location: linkLocation, linkType: .download, onFinish: onFinish)
        }
    
        let navController = UINavigationController(rootViewController: controller)
        navController.modalPresentationStyle = .formSheet
        self.present(navController, animated: true, completion: nil)
    }
}

extension ListingViewController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerShouldDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) -> Bool {
        self.animateActionButton(active: false)
        return true
    }
}

extension ListingViewController: NodeActionsViewControllerDelegate {
    func didSelectOption(action: ActionType) {

        self.animateActionButton(active: false)

        let completionBlock = {

            let node = self.content[self.selectedIndexPath.row]
            let nodeLocation = node.location(in: self.location)

            switch action {

            case .share:

                self.showShareViewController(linkLocation: nodeLocation, isDirectory: node.type == "dir")

            case .bookmark:

                if let bookmark = node.bookmark {

                    // Bookmark is set, removing it:
                    DigiClient.shared.removeBookmark(bookmark: bookmark, completion: { error in

                        guard error == nil else {
                            print(error!.localizedDescription)
                            return
                        }
                        self.content[self.selectedIndexPath.row].bookmark = nil
                        self.tableView.reloadRows(at: [self.selectedIndexPath], with: .none)
                    })
                } else {

                    // Bookmark is not set, adding it:                    
                    let bookmark = Bookmark(name: node.name,
                                            mountId: self.location.mount.id,
                                            path: nodeLocation.path)

                    DigiClient.shared.addBookmark(bookmark: bookmark, completion: { error in
                        guard error == nil else {
                            print(error!.localizedDescription)
                            return
                        }

                        self.content[self.selectedIndexPath.row].bookmark = bookmark
                        self.tableView.reloadRows(at: [self.selectedIndexPath], with: .none)
                    })
                }

            case .rename:
            
                let controller = RenameViewController(nodeLocation: nodeLocation, node: node)
                controller.onFinish = { (newName, needRefresh) in
                    // dismiss RenameViewController
                    self.dismiss(animated: true) {
                        if newName != nil {
                            self.content[self.selectedIndexPath.row].name = newName!

                            self.tableView.reloadRows(at: [self.selectedIndexPath], with: .middle)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                self.updateContent()
                            }
                        } else {
                            if needRefresh {
                                self.updateContent()
                            }
                        }
                    }
                }
                let navController = UINavigationController(rootViewController: controller)
                navController.modalPresentationStyle = .formSheet
                self.present(navController, animated: true, completion: nil)

            case .copy, .move:

                self.showViewControllerForCopyOrMove(action: action, sourceLocations: [nodeLocation])

            case .delete:

                if node.type == "file" {
                    let controller = DeleteViewController(location: nodeLocation, isDirectory: false)
                    controller.delegate = self

                    // position alert on the same row with the file
                    var sourceView = self.tableView.cellForRow(at: self.selectedIndexPath)!.contentView
                    for view in sourceView.subviews {
                        if view.tag == 1 {
                            sourceView = view.subviews[0]
                        }
                    }
                    controller.modalPresentationStyle = .popover
                    controller.popoverPresentationController?.sourceView = sourceView
                    controller.popoverPresentationController?.sourceRect = sourceView.bounds
                    self.present(controller, animated: true, completion: nil)
                }

            case .folderInfo:
                
                let controller = DirectoryInfoViewController(location: nodeLocation)
                controller.onFinish = { success, needRefresh in

                    // dismiss FolderViewController
                    self.dismiss(animated: true) {
                        if success {
                            self.content.remove(at: self.selectedIndexPath.row)
                            if self.content.count == 0 {
                                self.updateDirectoryMessage()
                                self.tableView.reloadData()
                            } else {
                                self.tableView.deleteRows(at: [self.selectedIndexPath], with: .left)
                            }
                        } else {
                            if needRefresh {
                                self.updateContent()
                            }
                        }
                    }
                }
                let navController = UINavigationController(rootViewController: controller)
                navController.modalPresentationStyle = .formSheet
                self.present(navController, animated: true, completion: nil)

            default:
                return
            }
        }

        dismiss(animated: true, completion: completionBlock)
    }
}

extension ListingViewController: DeleteViewControllerDelegate {
    func onConfirmDeletion() {

        let completionBlock = {
            
            let nodeLocation = self.content[self.selectedIndexPath.row].location(in: self.location)
            
            DigiClient.shared.deleteNode(at: nodeLocation) { statusCode, error in
                // TODO: Stop spinner
                guard error == nil else {
                    // TODO: Show message for error
                    let message = NSLocalizedString("There was an error while deleting.", comment: "")
                    let title = NSLocalizedString("Error", comment: "")
                    let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
                    self.present(alertController, animated: true, completion: nil)
                    print(error!.localizedDescription)
                    return
                }
                if let code = statusCode {
                    switch code {
                    case 200:
                        self.content.remove(at: self.selectedIndexPath.row)
                        if self.content.isEmpty {
                            self.updateDirectoryMessage()
                            self.tableView.reloadData()
                        } else {
                            self.tableView.deleteRows(at: [self.selectedIndexPath], with: .left)
                        }
                    case 400:
                        self.updateContent()
                    case 404:
                        self.updateContent()
                    default :
                        break
                    }
                } else {
                    print("Error: could not obtain a status code")
                }
            }
        }

        // Dismiss DeleteAlertViewController
        dismiss(animated: true, completion: completionBlock)
    }
}

extension ListingViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        DispatchQueue.main.async {
            searchController.searchResultsController?.view.isHidden = false
        }
    }

    func didPresentSearchController(_ searchController: UISearchController) {
        searchController.searchResultsController?.view.isHidden = false
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        guard let src = searchController.searchResultsController as? SearchResultController else {
            return
        }
        self.resetSearchViewControllerIndex()
        src.filteredContent.removeAll()
        src.tableView.reloadData()
    }
}
