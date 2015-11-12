//
//  Photo
//  Virtual Tourist
//
//  Created by Ahmed Onawale on 11/10/15.
//  Copyright © 2015 Ahmed Onawale. All rights reserved.
//

import Foundation
import CoreData
import UIKit

class Photo: NSManagedObject {
    
    // MARK: Properties
    
    @NSManaged var pin: Pin?
    @NSManaged var imageURL: String
    @NSManaged var imagePath: String
    
    // MARK: Initializers
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        imageURL = dictionary["url_m"] as? String ?? ""
        imagePath = imageURL.componentsSeparatedByString("/").last ?? ""
    }
    
    var image: UIImage? {
        get {
            return APIClient.Caches.imageCache.imageWithIdentifier(imagePath)
        }
        set {
            APIClient.Caches.imageCache.storeImage(newValue, withIdentifier: imagePath)
        }
    }
    
    override func prepareForDeletion() {
        super.prepareForDeletion()
        APIClient.Caches.imageCache.deleteImageWithIdentifier(imagePath)
    }
    
}