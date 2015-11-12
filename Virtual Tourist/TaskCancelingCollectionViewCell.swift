//
//  TaskCancelingCollectionViewCell.swift
//  Virtual Tourist
//
//  Created by Ahmed Onawale on 11/11/15.
//  Copyright © 2015 Ahmed Onawale. All rights reserved.
//

import UIKit

class TaskCancelingCollectionViewCell: UICollectionViewCell {

    var taskToCancelifCellIsReused: NSURLSessionTask? {
        didSet {
            if let taskToCancel = oldValue {
                taskToCancel.cancel()
            }
        }
    }
    
}
