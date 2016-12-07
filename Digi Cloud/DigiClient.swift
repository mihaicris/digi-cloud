//
//  DigiClient.swift
//  Digi Cloud
//
//  Created by Mihai Cristescu on 26/09/16.
//  Copyright © 2016 Mihai Cristescu. All rights reserved.
//

import UIKit

// Singleton class for DIGI Client

enum NetworkingError: Error {
    case get(String)
    case post(String)
    case del(String)
    case wrongStatus(String)
    case data(String)
}
enum JSONError: Error {
    case parce(String)
}
enum Authentication: Error {
    case login(String)
}

final class DigiClient {

    // MARK: - Properties

    static let shared: DigiClient = DigiClient()
    var task: URLSessionDataTask?
    var token: String!

    // MARK: - Initializers and Deinitializers

    private init() {}

    // MARK: - Helper Functions

    func networkTask(requestType:       String,
                     method:            String,
                     headers:           [String: String]?,
                     json:              [String: String]?,
                     parameters:        [String: Any]?,
                     completion: @escaping(_ data: Any?, _ response: Int?, _ error: Error?) -> Void) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true

        /* 1. Build the URL, Configure the request */
        let url = self.getURL(method: method, parameters: parameters)

        var request = self.getURLRequest(url: url, requestType: requestType, headers: headers)

        // add json object to request
        if let json = json {
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: json, options: [])
            } catch {
                completion(nil, nil, JSONError.parce("Could not convert json into data!"))
            }
        }

        /* 2. Make the request */
        task = URLSession.shared.dataTask(with: request) {
            (data, response, error) in
            // stop network indication
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false


                /* GUARD: Was there an error? */
                guard error == nil else {
                    completion(nil, nil, NetworkingError.get("There was an error with your request: \(error!.localizedDescription)"))
                    return
                }

                /* GUARD: Did we get a statusCode? */
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
                    completion(nil, nil, NetworkingError.get("There was an error with your request: \(error!.localizedDescription)"))
                    return
                }

                // Did we get a successful status code?
                if statusCode < 200 || statusCode > 299 {
                    completion(nil, statusCode, nil)
                    return
                }

                /* GUARD: Was there any data returned? */
                guard let data = data else {
                    completion(nil, statusCode, NetworkingError.data("No data was returned by the request!"))
                    return
                }

                guard data.count > 0 else {
                    completion(data, statusCode, nil)
                    return
                }

                /* 3. Parse the data and use the data (happens in completion handler) */
                do {
                    let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
                    completion(json, statusCode, nil)
                } catch {
                    completion(nil, statusCode, JSONError.parce("Could not parse the data as JSON"))
                }
            } // End of dispatched block
        }
        /* 4. Start the request */
        task?.resume()
    }

    func getURL(method: String, parameters: [String: Any]?) -> URL {
        var components = URLComponents()
        components.scheme = API.Scheme
        components.host = API.Host
        components.path = method

        if let parameters = parameters {
            components.queryItems = [URLQueryItem]()
            for (key, value) in parameters {
                let queryItem = URLQueryItem(name: key, value: "\(value)")
                components.queryItems!.append(queryItem)
            }
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
                .replacingOccurrences(of: ";", with: "%3B")
        }
        return components.url!
    }

    func getURLRequest(url: URL, requestType: String, headers: [String: String]?) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = requestType
        request.allHTTPHeaderFields = headers
        return request
    }

    func authenticate(email: String, password: String, completion: @escaping(_ success: Bool, _ error: Error?) -> Void) {
        let method = Methods.Token
        let headers = DefaultHeaders.Headers
        let jsonBody = ["password": password, "email": email]

        networkTask(requestType: "POST", method: method, headers: headers, json: jsonBody, parameters: nil) {
            (json, statusCode, error) in
            if let error = error {
                completion(false, error)
                return
            }
            if statusCode == 200 {
                if let json = json as? [String: String] {
                    self.token = json["token"]
                    completion(true, nil)
                }
            } else {
                completion(false, nil)
            }
        }
    }

    func getUserInfo(completion: @escaping(_ json: Any? , _ statusCode: Int?, _ error: Error?) -> Void) {
        let method = Methods.User

        let headers: [String: String] = [HeadersKeys.Accept: "application/json",
                                         "Authorization": "Token \(DigiClient.shared.token!)"]

        networkTask(requestType: "GET", method: method, headers: headers, json: nil, parameters: nil) {
            (data, statusCode, error) in

            guard error == nil else {
                completion(nil, nil, error)
                return
            }

            guard statusCode == 200 else {
                completion(nil, statusCode, nil)
                return
            }
            completion(data, statusCode, nil)
        }
    }

    func getDIGIStorageLocations(completion: @escaping(_ result: [Location]?, _ error: Error?) -> Void) {
        let method = Methods.Mounts
        var headers = DefaultHeaders.Headers
        headers[HeadersKeys.Authorization] = "Token \(DigiClient.shared.token!)"

        networkTask(requestType: "GET", method: method, headers: headers, json: nil, parameters: nil) {
            (data, statusCode, error) in
            if let error = error {
                completion(nil, error)
            } else {
                if let dict = data as? [String: Any] {
                    guard let mountsList = dict["mounts"] as? [Any] else {
                        completion(nil, JSONError.parce("Could not parce mount "))
                        return
                    }
                    var locations: [Location] = []
                    for mountJSON in mountsList {
                        if let mount = Mount(JSON: mountJSON) {
                            locations.append(Location(mount: mount, path: "/"))
                        }
                    }
                    completion(locations, nil)

                } else {
                    completion(nil, JSONError.parce("Could not parce data (getLocations)"))
                }
            }
        }
    }

    func getContent(at location: Location,
                    completion: @escaping(_ result: [Node]?, _ error: Error?) -> Void) {
        let method = Methods.ListFiles.replacingOccurrences(of: "{id}", with: location.mount.id)
        var headers = DefaultHeaders.Headers
        headers[HeadersKeys.Authorization] = "Token \(DigiClient.shared.token!)"
        let parameters = [ParametersKeys.Path: location.path]

        networkTask(requestType: "GET", method: method, headers: headers, json: nil, parameters: parameters) {
            (data, responseCode, error) in
            if let error = error {
                completion(nil, error)
                return
            } else {
                if let dict = data as? [String: Any] {
                    guard let fileList = dict["files"] as? [[String: Any]] else {
                        completion(nil, JSONError.parce("Could not parce filelist"))
                        return
                    }
                    let content = fileList.flatMap { Node(JSON: $0, parentLocation: location) }
                    completion(content, nil)
                } else {
                    completion(nil, JSONError.parce("Could not parce data (getFiles)"))
                }
            }
        }
    }

    func startDownloadFile(at location: Location, delegate: AnyObject) -> URLSession {

        // create the special session with custom delegate for download task
        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: delegate as? ContentViewController, delegateQueue: nil)

        // prepare the method string for download file by inserting the current mount
        let method =  Methods.GetFile.replacingOccurrences(of: "{id}", with: location.mount.id)

        // prepare the query parameter path with the current File path
        let parameters = [ParametersKeys.Path: location.path]

        // create url from method and parameters
        let url = DigiClient.shared.getURL(method: method, parameters: parameters)

        // create url request with the current token in the HTTP headers
        var request = URLRequest(url: url)
        request.addValue("Token " + DigiClient.shared.token, forHTTPHeaderField: "Authorization")

        // create and start download task
        let downloadTask = session.downloadTask(with: request)
        downloadTask.resume()

        return session
    }

    func renameNode(at location: Location, with name: String,
                    completion: @escaping(_ statusCode: Int?, _ error: Error?) -> Void) {
        // prepare the method string for rename the node by inserting the current mount
        let method = Methods.Rename.replacingOccurrences(of: "{id}", with: location.mount.id)

        // prepare headers
        var headers = DefaultHeaders.Headers
        headers[HeadersKeys.Authorization] = "Token \(DigiClient.shared.token!)"

        // prepare parameters (path of the node to be renamed
        let parameters = [ParametersKeys.Path: location.path]

        // prepare new name in request body
        let jsonBody = ["name": name]

        networkTask(requestType: "PUT", method: method, headers: headers, json: jsonBody, parameters: parameters) { (_, statusCode, error) in
            completion(statusCode, error)
        }
    }

    func deleteNode(at location: Location,
                    completion: @escaping(_ statusCode: Int?, _ error: Error?) -> Void) {
        // prepare the method string for rename the node by inserting the current mount
        let method = Methods.Remove.replacingOccurrences(of: "{id}", with: location.mount.id)

        // prepare headers
        var headers: [String: String] = [:]
        headers[HeadersKeys.Authorization] = "Token \(DigiClient.shared.token!)"

        // prepare parameters (node path to be renamed
        let parameters = [ParametersKeys.Path: location.path]

        networkTask(requestType: "DELETE", method: method, headers: headers, json: nil, parameters: parameters) { (_, statusCode, error) in
            completion(statusCode, error)
        }
    }

    func createFolderNode(in location: Location, name: String,
                          completion: @escaping(_ statusCode: Int?, _ error: Error?) -> Void) {
        // prepare the method string for create new folder
        let method = Methods.CreateFolder.replacingOccurrences(of: "{id}", with: location.mount.id)

        // prepare headers
        var headers = DefaultHeaders.Headers
        headers[HeadersKeys.Authorization] = "Token \(DigiClient.shared.token!)"

        // prepare parameters
        let parameters = [ParametersKeys.Path: location.path]

        // prepare new folder name in request body
        let jsonBody = [DataJSONKeys.folderName: name]

        networkTask(requestType: "POST", method: method, headers: headers, json: jsonBody, parameters: parameters) { (_, statusCode, error) in
            completion(statusCode, error)
        }
    }

    /// Search for files or folders
    ///
    /// - Parameters:
    ///   - query: String to search
    ///   - location: Location to search (mount and path). If nil, search is made in all locations
    ///   - completion: The block called after the server has responded
    ///   - json: The dictionary [String: Any] containing the search hits.
    ///   - error: The error occurred in the network request, nil for no error.
    func searchNodes(for query: String, at location: Location?,
                     completion: @escaping (_ json: [String: Any]?, _ error: Error?) -> Void) {
        let method = Methods.Search

        var headers: [String: String] = [HeadersKeys.Accept: "application/json"]
        headers[HeadersKeys.Authorization] = "Token \(DigiClient.shared.token!)"

        var parameters: [String: String] = [
                ParametersKeys.QueryString: query
        ]
        if let location = location {
            parameters[ParametersKeys.MountID] = location.mount.id
            parameters[ParametersKeys.Path] = location.path
        }

        networkTask(requestType: "GET", method: method, headers: headers, json: nil, parameters: parameters) { json, _ , error in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let json = json as? [String: Any] else {
                completion(nil, nil)
                return
            }
            completion(json, nil)
        }
    }

    /// Get the complete tree structure of a location
    /// - Parameters:
    ///   - location: The location of which the tree is returned
    ///   - completion:
    func getTree(at location: Location,
                 completion: @escaping (_ json: [String: Any]?, _ error: Error?) -> Void ) {
        let method = Methods.Tree.replacingOccurrences(of: "{id}", with: location.mount.id)

        var headers: [String: String] = [HeadersKeys.Accept: "application/json"]
        headers[HeadersKeys.Authorization] = "Token \(DigiClient.shared.token!)"

        let parameters = [ParametersKeys.Path: location.path]

        networkTask(requestType: "GET", method: method, headers: headers, json: nil, parameters: parameters) { (json, statusCode, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            guard let json = json as? [String: Any] else {
                completion(nil, nil)
                return
            }
            completion(json, nil)
        }
    }

    /// Get information about a folder
    ///
    /// - Parameters:
    ///   - path: path of the folder
    ///   - completion: completion handler with info about folder and error
    ///   -
    func getFolderInfo(location: Location,
                       completion: @escaping(_ size: (Int64?, Int?, Int?), _ error: Error?) -> Void) {
        // prepare the method string for create new folder
        let method = Methods.Tree.replacingOccurrences(of: "{id}", with: location.mount.id)

        // prepare headers
        var headers: [String: String] = [HeadersKeys.Accept: "application/json"]
        headers[HeadersKeys.Authorization] = "Token \(DigiClient.shared.token!)"

        // prepare parameters (node path to be renamed
        let parameters = [ParametersKeys.Path: location.path]

        /// Get information from Dictionary content (JSON folder tree)
        ///
        /// - Parameter parent: parent folder
        /// - Returns: return tuple with (size of child, number of files, number of folders)
        func getChildInfo(_ parent: [String: Any]) -> (Int64, Int, Int) {
            var size: Int64 = 0
            var files: Int = 0
            var folders: Int = 0
            if let childType = parent["type"] as? String, childType == "file" {
                files += 1
                if let childSize = parent["size"] as? Int64 {
                    return (childSize, files, folders)
                }
            }
            if let children = parent["children"] as? [[String: Any]] {
                folders += 1
                for child in children {
                    let info = getChildInfo(child)
                    size += info.0
                    files += info.1
                    folders += info.2
                }
            }
            return (size, files, folders)
        }

        getTree(at: location) { json, error in
            if let error = error {
                completion((nil, nil, nil), error)
                return
            }
            guard let json = json else {
                completion((nil, nil, nil), nil)
                return
            }
            let info = getChildInfo(json)

            // Subtracting 1 because the root folder is also counted
            completion((info.0, info.1, info.2 - 1), nil)
        }
    }

    /// Send a request to DIGI API to copy or move a node
    ///
    /// - Parameters:
    ///   - action:            Action Type, expected ActionType.move or ActionType.copy
    ///   - from:              Source location
    ///   - to:                Destination location
    ///   - completion:        Function to handle the status code and error response
    ///   - statusCode:        Returned HTTP request Status Code
    ///   - error:             Networking error (nil if no error)
    func copyOrMoveNode(action:     ActionType, from: Location, to: Location,
                        completion: @escaping (_ statusCode: Int?, _ error: Error?) -> Void) {

        var method : String

        switch action {
        case .copy:
            method = Methods.Copy.replacingOccurrences(of: "{id}", with: from.mount.id)
        case .move:
            method = Methods.Move.replacingOccurrences(of: "{id}", with: from.mount.id)
        default:
            return
        }

        var headers = DefaultHeaders.Headers
        headers[HeadersKeys.Authorization] = "Token \(DigiClient.shared.token!)"

        let parameters = [ParametersKeys.Path: from.path]

        let json: [String: String] = ["toMountId": to.mount.id, "toPath": to.path]

        networkTask(requestType: "PUT", method: method, headers: headers, json: json, parameters: parameters) { (dataResponse, statusCode, error) in
            completion(statusCode, error)
        }
    }
}

