//
//  AirMapStatusAdvisoryPowerPlantProperties.swift
//  AirMapSDK
//
//  Created by Rocky Demoff on 7/11/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import ObjectMapper

open class AirMapStatusAdvisorySchoolProperties : NSObject {

	open var students: Int? // number of students

	public required init?(map: Map) {}
}

extension AirMapStatusAdvisorySchoolProperties: Mappable {

	public func mapping(map: Map) {
		students			<- map["students"]
	}
}
