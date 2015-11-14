//
//  PhotoAlbumViewController.swift
//  Virtual Tourist
//
//  Created by Ahmed Onawale on 11/10/15.
//  Copyright © 2015 Ahmed Onawale. All rights reserved.
//


import UIKit
import CoreData
import MapKit

class PhotoAlbumViewController: UIViewController {
    
    // MARK: - Properties
    
    var pin: Pin!
    
    let collectionViewHeaderReuseID = "identifier"
    
    var totalPages = 2
    
    var insertedIndexPaths: [NSIndexPath]!
    var deletedIndexPaths: [NSIndexPath]!
    var updatedIndexPaths: [NSIndexPath]!
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var layout: UICollectionViewFlowLayout!
    @IBOutlet weak var newCollectionButton: UIBarButtonItem!
    
    @IBAction func close(sender: UIBarButtonItem) {
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    @IBAction func newPhotosCollection(sender: UIBarButtonItem) {
        _ = pin.photos.map {
            sharedContext.deleteObject($0)
        }
        fetchImagesForPin()
    }
    
    func fetchImagesForPin() {
        newCollectionButton.enabled = false
        APIClient.sharedInstance.searchImageByLatitude(pin.latitude, longitude: pin.longitude, totalPages: totalPages) { result, error in
            guard error == nil, let result = result else {
                return
            }
            guard let dictionary = result["photos"] as? [String: AnyObject],
                photos = dictionary["photo"] as? [[String: AnyObject]],
                totalPages = dictionary["pages"] as? Int else {
                    return
            }
            self.totalPages = totalPages
            dispatch_async(dispatch_get_main_queue()) { Void in
                _ = photos.map {
                    let photo = Photo(dictionary: $0, context: self.sharedContext)
                    photo.pin = self.pin
                }
                self.newCollectionButton.enabled = true
            }
        }
    }
    
    // MARK: - Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // Mark: - Fetched Results Controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Photo")
        fetchRequest.sortDescriptors = []
        fetchRequest.predicate = NSPredicate(format: "pin == %@", self.pin)
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        return fetchedResultsController
    }()
    
    // MARK: - Life Cycle
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = floor(collectionView.frame.size.width - 2*3) / 3.0
        layout.itemSize = CGSize(width: width, height: width)
        layout.headerReferenceSize = CGSize(width: collectionView.frame.width, height: collectionView.frame.height/4)
        layout.sectionHeadersPinToVisibleBounds = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Unhandled error \(error)")
        }
        fetchedResultsController.delegate = self
        collectionView.registerClass(UICollectionReusableView.self, forSupplementaryViewOfKind: UICollectionElementKindSectionHeader, withReuseIdentifier: collectionViewHeaderReuseID)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        if pin.photos.isEmpty {
            fetchImagesForPin()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}

// MARK: - FetchedResultsController Delegate

extension PhotoAlbumViewController: NSFetchedResultsControllerDelegate {
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        insertedIndexPaths = [NSIndexPath]()
        deletedIndexPaths = [NSIndexPath]()
        updatedIndexPaths = [NSIndexPath]()
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type{
        case .Insert:
            insertedIndexPaths.append(newIndexPath!)
        case .Delete:
            deletedIndexPaths.append(indexPath!)
        case .Update:
            updatedIndexPaths.append(indexPath!)
        case .Move:
            break
        }
    }
    
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        collectionView.performBatchUpdates({ () -> Void in
            self.collectionView.insertItemsAtIndexPaths(self.insertedIndexPaths)
            self.collectionView.deleteItemsAtIndexPaths(self.deletedIndexPaths)
            self.collectionView.reloadItemsAtIndexPaths(self.updatedIndexPaths)
        }) { finished in
            CoreDataStackManager.sharedInstance().saveContext()
        }
    }
    
}

// MARK: - CollectionView Delegate and Datasource

extension PhotoAlbumViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func emptyImagesLabel() -> UILabel {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: collectionView.frame.size.width, height: collectionView.frame.size.height))
        label.font = UIFont(name: "Palatino-Italic", size: 20)
        label.textColor = UIColor.blackColor()
        label.textAlignment = .Center
        label.text = "No Images."
        label.sizeToFit()
        return label
    }
    
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Photo Cell", forIndexPath: indexPath) as! TaskCancelingCollectionViewCell
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        configureCell(cell, withPhoto: photo)
        return cell
    }
    
    func configureCell(cell: TaskCancelingCollectionViewCell, withPhoto photo: Photo) {
        var placeHolderImage = UIImage(named: "placeHolderImage")
        cell.backgroundView = nil
        if photo.imageURL.isEmpty {
            placeHolderImage = UIImage(named: "noImage")
        } else if photo.image != nil {
            placeHolderImage = photo.image
        } else {
            cell.taskToCancelifCellIsReused = APIClient.sharedInstance.fetchImageWithURL(photo.imageURL) { data, error in
                guard error == nil, let data = data else {
                    print("Poster download error: \(error!.localizedDescription)")
                    return
                }
                let image = UIImage(data: data)
                photo.image = image
                dispatch_async(dispatch_get_main_queue()) {
                    cell.backgroundView = UIImageView(image: image)
                }
            }
        }
        cell.backgroundView = UIImageView(image: placeHolderImage)
    }
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = fetchedResultsController.sections![section]
        if sectionInfo.numberOfObjects < 1 {
            collectionView.backgroundView = emptyImagesLabel()
        } else {
            collectionView.backgroundView = nil
        }
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photo
        sharedContext.deleteObject(photo)
    }
    
    func collectionView(collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, atIndexPath indexPath: NSIndexPath) -> UICollectionReusableView {
        let supplementaryView = collectionView.dequeueReusableSupplementaryViewOfKind(UICollectionElementKindSectionHeader, withReuseIdentifier: collectionViewHeaderReuseID, forIndexPath: indexPath)
        let frame = CGRect(origin: CGPoint(x: 0, y: 0), size: layout.headerReferenceSize)
        supplementaryView.frame = frame
        let mapView = MKMapView(frame: frame)
        supplementaryView.addSubview(mapView)
        mapView.addAnnotation(pin)
        mapView.showAnnotations([pin], animated: false)
        return supplementaryView
    }
    
}
