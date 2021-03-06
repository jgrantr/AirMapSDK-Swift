//
//  AirMapTrafficProperties.swift
//  AirMapSDK
//
//  Created by Rocky Demoff on 6/7/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import ObjectMapper
import CoreLocation

@objc open class AirMapTrafficProperties: NSObject {
	
	open var aircraftId: String!
	open var aircraftType: String!
	
	public override init() {
		super.init()
	}
	
	public required init?(map: Map) {}
}

extension AirMapTrafficProperties: Mappable {
	
	public func mapping(map: Map) {
		aircraftId   <- map["aircraft_id"]
		aircraftType <- map["aircraft_type"]
	}
}
