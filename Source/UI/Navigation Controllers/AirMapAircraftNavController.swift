//
//  AirMapAircraftNavController.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 8/18/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import UIKit

public protocol AirMapAircraftNavControllerDelegate: class {
	func aircraftNavController(_ navController: AirMapAircraftNavController, didCreateOrModify aircraft: AirMapAircraft)
}

open class AirMapAircraftNavController: UINavigationController {

	weak var aircraftDelegate: AirMapAircraftNavControllerDelegate?
	
}
