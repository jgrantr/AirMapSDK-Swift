//
//  RulesTests.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 1/11/17.
//  Copyright © 2017 AirMap, Inc. All rights reserved.
//

@testable import AirMap
import Nimble
import RxSwift

class RulesTests: TestCase {
	
	let disposeBag = DisposeBag()
	
	func testGetLocalRules() {
		
		let location = CLLocationCoordinate2D(latitude: 34.1, longitude: -118.1)
		
		stub(.GET, Config.AirMapApi.rulesUrl + "/locale", with: "rules_local_get_success.json") { request in
			let query = request.queryParams()
			expect(query["latitude"] as? String).to(equal(String(location.latitude)))
			expect(query["longitude"] as? String).to(equal(String(location.longitude)))
		}
		
		waitUntil { done in
			
			AirMap.rx_getLocalRules(location)
				.doOnNext { rules in
					guard rules.count == 5 else {
						return fail("Invalid number of rules")
					}
					let first = rules[0]
					expect(first.id).to(equal("abcd001"))
					expect(first.jurisdictionName).to(equal("United States of America"))
					expect(first.jurisdictionType).to(equal("country"))
					expect(first.text).to(equal("Sample Country Text"))
					expect(first.url).to(equal(NSURL(string: "http://www.faa.gov/beforeyoufly.pdf")))
					expect(first.summary).to(beNil())
					let third = rules[2]
					expect(third.summary).to(equal("A short city summary"))
				}
				.doOnError { error in
					expect(error).to(beNil()); done()
				}
				.doOnCompleted(done)
				.subscribe()
				.addDisposableTo(self.disposeBag)
		}
	}
}
