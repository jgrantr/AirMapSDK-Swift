//
//  AirMapStatusAdvisoryAirportProperties.swift
//  AirMapSDK
//
//  Created by Rocky Demoff on 7/11/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import ObjectMapper

open class AirMapStatusAdvisoryAirportProperties : NSObject {

	open var identifier: String?
	open var phone: String?
	open var tower: Bool?
	open var paved: Bool?
	open var longestRunway: Int?
	open var elevation: Int?
	open var publicUse: Bool?

	public required init?(map: Map) {}
}

extension AirMapStatusAdvisoryAirportProperties: Mappable {

	public func mapping(map: Map) {
		identifier     <- map["identifier"]
		phone          <- map["phone"]
		tower          <- map["tower"]
		paved          <- map["paved"]
		longestRunway  <- map["longest_runway"]
		elevation      <- map["elevation"]
		publicUse      <- map["public_use"]
	}
}
