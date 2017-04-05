//
//  AirMapStatusRequirements.swift
//  AirMapSDK
//
//  Created by Rocky Demoff on 6/13/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import ObjectMapper

open class AirMapStatusRequirements : NSObject {
	
	open var id: String!
	open var notice: AirMapStatusRequirementNotice?

	public required init?(map: Map) {}
}

extension AirMapStatusRequirements: Mappable {
	
	public func mapping(map: Map) {
		notice   <-  map["notice"]
	}
}
