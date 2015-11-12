//
//  TravelLocationsMapViewController.swift
//  Virtual Tourist
//
//  Created by Ahmed Onawale on 11/10/15.
//  Copyright © 2015 Ahmed Onawale. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class TravelLocationsMapViewController: UIViewController {
    
    // MARK: - Properties
    
    var pin: Pin?
    
    @IBOutlet weak var mapView: MKMapView!
    
    // MARK: - Core Data Convenience
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    // Mark: - Fetched Results Controller
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = []
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        return fetchedResultsController
    }()
    
    func handleLongPress(sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .Began:
            dropPinAtPoint(sender.locationInView(mapView))
        case .Changed:
            movePinToPoint(sender.locationInView(mapView))
        case .Ended:
            CoreDataStackManager.sharedInstance().saveContext()
            prefetchImagesForPin(pin!)
        default:
            break
        }
    }
    
    func movePinToPoint(point: CGPoint) {
        let coordinate = mapView.convertPoint(point, toCoordinateFromView: mapView)
        pin?.setCoordinate(coordinate)
    }
    
    func dropPinAtPoint(point: CGPoint) {
        let coordinate = mapView.convertPoint(point, toCoordinateFromView: mapView)
        pin = Pin(coordinate: coordinate, context: sharedContext)
        mapView.addAnnotation(pin!)
    }
    
    func prefetchImagesForPin(pin: Pin) {
        APIClient.sharedInstance().searchImageByLatitude(pin.latitude, longitude: pin.longitude) { result, error in
            guard error == nil, let result = result else {
                return
            }
            guard let dictionary = result["photos"] as? [String: AnyObject],
                photos = dictionary["photo"] as? [[String: AnyObject]] else {
                    return
            }
            _ = photos.map {
                let photo = Photo(dictionary: $0, context: self.sharedContext)
                photo.pin = pin
            }
        }
    }
    
    func saveMapViewState() {
        let latitude = mapView.centerCoordinate.latitude
        let longitude = mapView.centerCoordinate.longitude
        let altitude = mapView.camera.altitude
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setDouble(latitude, forKey: "latitude")
        defaults.setDouble(longitude, forKey: "longitude")
        defaults.setDouble(altitude, forKey: "altitude")
        defaults.synchronize()
    }
    
    func resumeMapViewState() {
        let defaults = NSUserDefaults.standardUserDefaults()
        let latitude = defaults.doubleForKey("latitude")
        let longitude = defaults.doubleForKey("longitude")
        let altitude = defaults.doubleForKey("altitude")
        let camera = MKMapCamera()
        camera.centerCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        camera.altitude = altitude
        mapView.setCamera(camera, animated: true)
    }
    
    func handleFirstTime() {
        let defaults = NSUserDefaults.standardUserDefaults()
        if !defaults.boolForKey("firstTime") {
            defaults.setBool(true, forKey: "firstTime")
            defaults.synchronize()
        } else {
            resumeMapViewState()
        }
    }
    
    func applicationDidEnterBackground() {
        saveMapViewState()
    }
    
    func applicationWillTerminate() {
        saveMapViewState()
    }
    
    private func subscribeToBackgroundNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "applicationDidEnterBackground",
            name: UIApplicationDidEnterBackgroundNotification,
            object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self,
            selector: "applicationWillTerminate",
            name: UIApplicationWillTerminateNotification,
            object: nil)
    }
    
    func fetchSavedPins() {
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print("Unhandled error \(error)")
        }
        guard let pins = fetchedResultsController.fetchedObjects as? [Pin] else {
            return
        }
        mapView.addAnnotations(pins)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        guard let identifier = segue.identifier else {
            return
        }
        switch identifier {
        case "Show Photo Album":
            guard let navigationController = segue.destinationViewController as? UINavigationController,
                controller = navigationController.topViewController as? PhotoAlbumViewController else {
                return
            }
            controller.pin = sender as! Pin
        default:
            break
        }
    }
    
    // MARK: - Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let gesture = UILongPressGestureRecognizer(target: self, action: "handleLongPress:")
        mapView.addGestureRecognizer(gesture)
        mapView.delegate = self
        subscribeToBackgroundNotifications()
        handleFirstTime()
        fetchSavedPins()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

}

// MARK: - MapView Delegate

extension TravelLocationsMapViewController: MKMapViewDelegate {

    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        mapView.deselectAnnotation(view.annotation, animated: true)
        performSegueWithIdentifier("Show Photo Album", sender: view.annotation)
    }
    
}
