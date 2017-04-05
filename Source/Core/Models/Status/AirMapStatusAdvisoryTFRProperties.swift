//
//  AirMapStatusAdvisoryTFRProperties.swift
//  AirMapSDK
//
//  Created by Rocky Demoff on 7/8/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import ObjectMapper

open class AirMapStatusAdvisoryTFRProperties : NSObject {

	open var url: String = ""
	open var startTime: Date?
	open var endTime: Date?

	public required init?(map: Map) {}
}

extension AirMapStatusAdvisoryTFRProperties: Mappable {

	public func mapping(map: Map) {

		let dateTransform = CustomDateFormatTransform(formatString: Config.AirMapApi.dateFormat)

		url			<-  map["url"]
		startTime	<- (map["effective_start"], dateTransform)
		endTime		<- (map["effective_end"], dateTransform)
	}
}
