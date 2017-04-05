//
//  AirMapStatusAdvisorySpecialUseAirspaceProperties.swift
//  AirMapSDK
//
//  Created by Rocky Demoff on 7/8/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import ObjectMapper

open class AirMapStatusAdvisoryWildfireProperties : NSObject {

	open var size: Int?
	open var dateEffective: Date?

	public required init?(map: Map) {}
}

extension AirMapStatusAdvisoryWildfireProperties: Mappable {

	public func mapping(map: Map) {		
		let dateTransform = CustomDateFormatTransform(formatString: Config.AirMapApi.dateFormat)
		size			<-  map["size"]
		dateEffective	<- (map["date_effective"], dateTransform)
	}
}
