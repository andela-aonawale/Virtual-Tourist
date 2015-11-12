//
//  APIClient.swift
//  Virtual Tourist
//
//  Created by Ahmed Onawale on 11/10/15.
//  Copyright © 2015 Ahmed Onawale. All rights reserved.
//

import Foundation

class APIClient {
    
    private struct Flickr {
        static let BASE_URL = "https://api.flickr.com"
        static let API_KEY = "f947e0c7616d988826e195d158caf794"
        static let METHOD_NAME = "flickr.photos.search"
        static let EXTRAS = "url_m"
        static let DATA_FORMAT = "json"
        static let SAFE_SEARCH = "1"
        static let NO_JSON_CALLBACK = "1"
        static let PATH = "/services/rest/"
    }
    
    // MARK: - Shared Instance
    
    class func sharedInstance() -> APIClient {
        struct Singleton {
            static var sharedInstance = APIClient()
        }
        return Singleton.sharedInstance
    }
    
    private func queryItemsFromDictionary(dictionary: [String: String]) -> [NSURLQueryItem] {
        return dictionary.map() {
            return NSURLQueryItem(name: $0.0, value: $0.1)
        }
    }
    
    typealias CompletionHandler = (result: AnyObject?, error: NSError?) -> Void
    
    private var session: NSURLSession
    
    init() {
        session = NSURLSession.sharedSession()
    }
    
    // MARK: - Shared Image Cache
    
    struct Caches {
        static let imageCache = ImageCache()
    }
    
    func fetchImageWithURL(urlString: String, completionHandler: (imageData: NSData?, error: NSError?) -> Void) -> NSURLSessionDataTask {
        let url = NSURL(string: urlString)!
        let task = session.dataTaskWithURL(url) { data, response, error in
            if let error = error {
                let newError = APIClient.errorForData(data, response: response, error: error)
                completionHandler(imageData: nil, error: newError)
            } else {
                completionHandler(imageData: data, error: nil)
            }
        }
        task.resume()
        return task
    }
    
    func searchImageByLatitude(latitude: Double, longitude: Double, completionHandler: CompletionHandler) -> NSURLSessionDataTask {
        let URLComponents = NSURLComponents(string: Flickr.BASE_URL)!
        URLComponents.path = Flickr.PATH
        let dictionary = [
            "method": Flickr.METHOD_NAME,
            "api_key": Flickr.API_KEY,
            "safe_search": Flickr.SAFE_SEARCH,
            "extras": Flickr.EXTRAS,
            "format": Flickr.DATA_FORMAT,
            "nojsoncallback": Flickr.NO_JSON_CALLBACK,
            "lat": "\(latitude)",
            "lon": "\(longitude)"
        ]
        URLComponents.queryItems = queryItemsFromDictionary(dictionary)
        let request = NSURLRequest(URL: URLComponents.URL!)
        let task = session.dataTaskWithRequest(request) { data, response, error in
            if let error = error {
                let newError = APIClient.errorForData(data, response: response, error: error)
                completionHandler(result: nil, error: newError)
            } else {
                APIClient.parseJSONWithCompletionHandler(data!, completionHandler: completionHandler)
            }
        }
        task.resume()
        return task
    }
    
    // MARK: - Helpers
    
    
    // Try to make a better error, based on the status_message from Flickr. If we cant then return the previous error
    
    class func errorForData(data: NSData?, response: NSURLResponse?, error: NSError) -> NSError {
        
        if data == nil {
            return error
        }
        
        do {
            let parsedResult = try NSJSONSerialization.JSONObjectWithData(data!, options: NSJSONReadingOptions.AllowFragments)
            
            if let parsedResult = parsedResult as? [String : AnyObject], errorMessage = parsedResult["stat"] as? String {
                let userInfo = [NSLocalizedDescriptionKey : errorMessage]
                return NSError(domain: "Flickr Error", code: 1, userInfo: userInfo)
            }
            
        } catch _ {}
        
        return error
    }
    
    // Parsing the JSON
    
    class func parseJSONWithCompletionHandler(data: NSData, completionHandler: CompletionHandler) {
        var parsingError: NSError? = nil
        
        let parsedResult: AnyObject?
        do {
            parsedResult = try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
        } catch let error as NSError {
            parsingError = error
            parsedResult = nil
        }
        
        if let error = parsingError {
            completionHandler(result: nil, error: error)
        } else {
            completionHandler(result: parsedResult, error: nil)
        }
    }
    
}
