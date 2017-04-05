//
//  AirMapStatusAdvisoryControlledAirspaceProperties.swift
//  AirMapSDK
//
//  Created by Rocky Demoff on 7/8/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import ObjectMapper

open class AirMapStatusAdvisoryControlledAirspaceProperties : NSObject {

	open var classAirspace: String = ""
	open var airportIdentifier: Date?

	public required init?(map: Map) {}
}

extension AirMapStatusAdvisoryControlledAirspaceProperties: Mappable {

	public func mapping(map: Map) {
		classAirspace		<- map["class"]
		airportIdentifier	<- map["airport_identifier"]
	}
}
