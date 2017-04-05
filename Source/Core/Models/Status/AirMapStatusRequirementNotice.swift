//
//  AirMapStatusRequirementsNotice.swift
//  AirMapSDK
//
//  Created by Rocky Demoff on 6/13/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import ObjectMapper

open class AirMapStatusRequirementNotice : NSObject {
	
	open var digital = false
	open var phoneNumber: String?
	
	public required init?(map: Map) {}
}

extension AirMapStatusRequirementNotice: Mappable {
	
	public func mapping(map: Map) {
		digital     <- map["digital"]
		phoneNumber <- map["phone"]
	}
}
