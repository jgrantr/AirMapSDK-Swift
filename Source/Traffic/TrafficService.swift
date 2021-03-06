//
//  TrafficService.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 6/29/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import SwiftMQTT
import CoreLocation
import ObjectMapper
import RxSwift
import RxSwiftExt

internal class TrafficService: MQTTSessionDelegate {

	enum ConnectionState {
		case connecting
		case connected
		case disconnected
	}

	enum TrafficServiceError: Error {
		case invalidCredentials
		case connectionFailed
		case subscriptionFailed
	}

	internal weak var delegate: AirMapTrafficObserver?

	internal var authToken: String? {
		set { client.password = authToken }
		get { return client.password }
	}

	fileprivate var activeTraffic = [AirMapTraffic]()
	fileprivate var expirationInterval = Config.AirMapTraffic.expirationInterval
	fileprivate var client = TrafficClient()
	fileprivate var connectionState  = Variable(ConnectionState.disconnected)
	fileprivate var currentFlight    = Variable(nil as AirMapFlight?)

	fileprivate let disposeBag = DisposeBag()

	// MARK: - Setup

	init() {

		client.delegate = self
		setupBindings()
		connect()
	}

	// MARK: - Instance Methods

	func setupBindings() {

		let state = connectionState.asObservable()

		let flight = currentFlight.asObservable()
			.distinctUntilChanged { flight in flight?.flightId ?? "" }

		let flightState = Observable.combineLatest(flight, state) { ($0, $1) }

		let whenConnected    = flightState.filter { $1 == .connected }
		let whenDisconnected = flightState.filter { $1 == .disconnected }

		func printError(_ error: Error) {
			AirMap.logger.error(error)
		}

		whenDisconnected
			.retry()
			.throttle(1, scheduler: MainScheduler.instance)
			.map { flight, state in flight }
			.unwrap()
			.filter {[unowned self] _ in AirMap.hasValidCredentials() && self.delegate != nil}
			.flatMap(unowned(self, TrafficService.connectWithFlight))
			.catchError({ _ in return Observable.just( .disconnected) })
			.bindTo(connectionState)
			.disposed(by: disposeBag)

		whenConnected
			.retry()
			.throttle(1, scheduler: MainScheduler.instance)
			.filter {[unowned self] _ in AirMap.hasValidCredentials() && self.delegate != nil}
			.map { flight, state in flight }
			.unwrap()
			.flatMap(unowned(self, TrafficService.subscribeToTraffic))
			.catchError({ _ in return Observable.empty() })
			.subscribe()
			.disposed(by: disposeBag)

		state
			.subscribe(onNext: { [unowned self] state in
				switch state {
				case .connecting:
					AirMap.logger.debug(TrafficService.self, "Connecting…")
				case .connected:
					AirMap.logger.debug(TrafficService.self, "Connected")
					self.delegate?.airMapTrafficServiceDidConnect?()
				case .disconnected:
					AirMap.logger.debug(TrafficService.self, "Disconnected")
					self.delegate?.airMapTrafficServiceDidDisconnect?()
				}
				AirMap.logger.debug(state)
			})
			.disposed(by: disposeBag)

		let refreshCurrentFlight = Observable<Int>.timer(0, period: 15, scheduler: MainScheduler.instance).mapToVoid()

		refreshCurrentFlight
			.skipWhile({[unowned self] _ in !AirMap.hasValidCredentials() || self.delegate == nil})
			.flatMap(AirMap.rx.getCurrentAuthenticatedPilotFlight)
			.bindTo(currentFlight)
			.disposed(by: disposeBag)

		let trafficProjectionTimer = Observable<Int>.interval(0.25, scheduler: MainScheduler.asyncInstance).mapToVoid()

		trafficProjectionTimer
			.subscribeNext(weak: self, TrafficService.updateTrafficProjections)
			.disposed(by: disposeBag)

		let purgeTrafficTimer = Observable<Int>.interval(5, scheduler: MainScheduler.asyncInstance).mapToVoid()

		purgeTrafficTimer
			.subscribeNext(weak: self, TrafficService.purgeExpiredTraffic)
			.disposed(by: disposeBag)
	}

	func connect() {

		if AirMap.hasValidCredentials() && delegate != nil {

			if connectionState.value != .disconnected {
				disconnect()
			}

			AirMap.rx.getCurrentAuthenticatedPilotFlight().bindTo(currentFlight).disposed(by: disposeBag)
		}
	}

	func disconnect() {
		
		unsubscribeFromAllChannels()
			.do(onDispose: { [unowned self] in
				self.client.disconnect()
				self.currentFlight.value = nil
				self.removeAllTraffic()
			})
			.subscribe()
			.disposed(by: disposeBag)
	}

	// MARK: - Observable Methods

	func connectWithFlight(_ flight: AirMapFlight) -> Observable<ConnectionState> {

		return Observable.create { (observer: AnyObserver<ConnectionState>) -> Disposable in

			observer.onNext(.connecting)

			self.client.username = flight.flightId
			self.client.password = AirMap.authSession.authToken

			self.client.connect { succeeded, error in
				if succeeded {
					observer.onNext(.connected)
				} else {
					AirMap.logger.error(error)
					observer.onError(TrafficServiceError.connectionFailed)
					observer.onNext(.disconnected)
				}
			}

			return Disposables.create()
		}
	}

	func subscribeToTraffic(_ flight: AirMapFlight) -> Observable<Void> {
		
		let sa    = self.subscribe(flight, to: Config.AirMapTraffic.trafficSituationalAwarenessChannel + flight.flightId!)
		let alert = self.subscribe(flight, to: Config.AirMapTraffic.trafficAlertChannel + flight.flightId!)

		return unsubscribeFromAllChannels().concat(sa).concat(alert)
	}

	func subscribe(_ flight: AirMapFlight, to channel: String) -> Observable<Void> {
		return Observable.create { (observer: AnyObserver<Void>) -> Disposable in
			self.client.subscribe(to: channel, delivering: .atLeastOnce) { succeeded, error in
				if succeeded {
					self.client.currentChannels.append(channel)
					AirMap.logger.debug(TrafficService.self, "Subscribed to \(channel)")
					observer.onCompleted()
				} else {
					observer.onError(TrafficServiceError.subscriptionFailed)
				}
			}
			return Disposables.create()
		}
	}

	func unsubscribeFromAllChannels() -> Observable<Void> {
		return Observable.create { observer in
			let channels = self.client.currentChannels
			guard channels.count > 0 else {
				observer.onCompleted()
				return Disposables.create()
			}
			self.client.unSubscribe(from: channels) { succeeded, error in
				if succeeded {
					AirMap.logger.debug(TrafficService.self, "Unsubscribed from channels", channels)
				} else {
					AirMap.logger.debug(TrafficService.self, error)
					observer.onError(TrafficServiceError.subscriptionFailed)
				}
				self.client.currentChannels = []
				observer.onCompleted()
			}
			return Disposables.create()
		}
	}

	func startPurgingExpiredTraffic(_ flight: AirMapFlight) -> Observable<AirMapFlight> {
		return Observable.create { (observer: AnyObserver<AirMapFlight>) -> Disposable in
			observer.onCompleted()
			return Disposables.create()
		}
	}

	// MARK: - Private Instance Methods

	fileprivate func addTraffic(_ traffic: [AirMapTraffic]) {

		guard let currentFlight = currentFlight.value else {
			disconnect()
			return
		}

		var addedTraffic = traffic
		var updatedTraffic = [AirMapTraffic]()

		for added in addedTraffic {

			let existingTraffic = activeTraffic.filter(hasAircractIdMatching(added.properties.aircraftId))

			for existing in existingTraffic {

				// Update values using KVO-compliant mechanisms

				existing.setValuesForKeys([
					"id":              added.id,
					"direction":       added.direction,
					"altitude":        added.altitude,
					"groundSpeed":     added.groundSpeed,
					"trueHeading":     added.trueHeading,
					"timestamp":       added.timestamp,
					"recordedTime":    added.recordedTime,
					"properties":      added.properties,
					"createdAt":       added.createdAt
					])

				existing.willChangeValue(forKey: "coordinate")
				existing.coordinate = added.coordinate
				existing.didChangeValue(forKey: "coordinate")

				existing.willChangeValue(forKey: "initialCoordinate")
				existing.initialCoordinate = added.initialCoordinate
				existing.didChangeValue(forKey: "initialCoordinate")

				existing.willChangeValue(forKey: "trafficType")

				if existing.trafficType == .alert {
					existing.trafficTypeDidChangeToAlert = false
				} else {
					existing.trafficType = added.trafficType
				}

				let addedLocation = CLLocation(latitude: added.coordinate.latitude, longitude: added.coordinate.longitude)
				let trafficLocation = CLLocation(latitude: currentFlight.coordinate.latitude, longitude: currentFlight.coordinate.longitude)
				let distance = trafficLocation.distance(from: addedLocation)

				//FIXME: This is temporary
				if distance > 3000 {
					existing.trafficType = .situationalAwareness
				}

				existing.didChangeValue(forKey: "trafficType")

				updatedTraffic.append(existing)
				addedTraffic.removeObject(existing)
			}
		}

		if addedTraffic.count > 0 {
			delegate?.airMapTrafficServiceDidAdd(addedTraffic)
			activeTraffic += addedTraffic
		}

		if updatedTraffic.count > 0 {
			delegate?.airMapTrafficServiceDidUpdate(updatedTraffic)
		}
	}

	@objc fileprivate func purgeExpiredTraffic() {

		let expiredTraffic = activeTraffic.filter(isExpired)

		if expiredTraffic.count > 0 {
			activeTraffic.removeObjectsInArray(expiredTraffic)
			delegate?.airMapTrafficServiceDidRemove(expiredTraffic)
		}

		updateTrafficProjections()
	}

	fileprivate func removeAllTraffic() {
		if activeTraffic.count > 0 {
			delegate?.airMapTrafficServiceDidRemove(activeTraffic)
			activeTraffic.removeAll()
		}
	}

	fileprivate func updateTrafficProjections() {

		let updatedTraffic = activeTraffic
			.filter(isMoving)
			.map (projectedTraffic)

		if updatedTraffic.count > 0 {
			addTraffic(updatedTraffic)
		}
	}

	func currentFlightLocation() -> CLLocation? {

		if let location = currentFlight.value?.coordinate {
			return CLLocation(latitude: location.latitude, longitude: location.longitude)
		}
		return nil
	}

	// MARK: - Filter/Map helper functions

	fileprivate func isMoving(_ traffic: AirMapTraffic) -> Bool {
		return traffic.groundSpeed > -1 && traffic.trueHeading > -1
	}

	fileprivate func hasAircractId(_ traffic: AirMapTraffic) -> Bool {
		return !traffic.properties.aircraftId.isEmpty
	}

	fileprivate func isExpired(_ traffic: AirMapTraffic) -> Bool {
		return traffic.createdAt.addingTimeInterval(expirationInterval).lessThanDate(Date())
	}

	fileprivate func hasAircractIdMatching(_ aircraftId: String) -> (AirMapTraffic) -> Bool {
		return { $0.properties.aircraftId == aircraftId }
	}

	/**
	Mapping function that projects the traffic's position
	*/
	fileprivate func projectedTraffic(_ traffic: AirMapTraffic) -> AirMapTraffic {
		let newPosition = projectedCoordinate(traffic)
		traffic.coordinate.latitude = newPosition.latitude
		traffic.coordinate.longitude = newPosition.longitude
		return traffic
	}

	/**
	Calculates the projected coordinate for the Manned Aircraft Traffic based upon distance and direction traveled.
	- returns: CLLocation
	*/
	fileprivate func projectedCoordinate(_ traffic: AirMapTraffic) -> CLLocationCoordinate2D {

		guard isMoving(traffic) else {
			return traffic.initialCoordinate
		}

		let elapsedTime = Double(Date().timeIntervalSince(traffic.recordedTime))
		let metersPerSecond = traffic.groundSpeed.metersPerSecond
		let distanceTraveledInMeters = metersPerSecond*elapsedTime
		let trafficLocation = CLLocation(latitude: traffic.initialCoordinate.latitude, longitude: traffic.initialCoordinate.longitude)

		return trafficLocation.destinationLocation(withInitialBearing: Double(traffic.trueHeading), distance: distanceTraveledInMeters).coordinate
	}

	/**
	Returns a TrafficType based upon a subscribed topic
	- parameter topic: String
	- returns: AirMapTraffic.TrafficType
	*/
	fileprivate func trafficTypeForTopic(_ topic: String) -> AirMapTraffic.TrafficType {

		if topic.hasPrefix(Config.AirMapTraffic.trafficAlertChannel) {
			return .alert
		} else {
			return .situationalAwareness
		}
	}

	// MARK: - MQTTSessionDelegate {
	
	func mqttDidReceive(message data: Data, in topic: String, from session: MQTTSession) {

		AirMap.logger.trace(TrafficService.self, "Did receive data")

		guard
			connectionState.value == .connected,
			let jsonString = String(data: data, encoding: String.Encoding.utf8),
			let jsonDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
			let trafficArray = jsonDict?["traffic"] as? [[String: Any]],
			let traffic = Mapper<AirMapTraffic>().mapArray(JSONArray: trafficArray)
		else {
			AirMap.logger.error(TrafficService.self, "Failed to parse JSON message")
			return
		}

		delegate?.airMapTrafficServiceDidReceive?(jsonString)

		let receivedTraffic = traffic.map { t -> AirMapTraffic in
			t.trafficType = self.trafficTypeForTopic(topic)
			t.coordinate = self.projectedCoordinate(t)
			return t
		}

		addTraffic(receivedTraffic)
	}
	
	func mqttDidDisconnect(session: MQTTSession) {
		AirMap.logger.debug(TrafficService.self, "Disconnected from MQTT")
		connectionState.value = .disconnected
	}
	
	func mqttSocketErrorOccurred(session: MQTTSession) {
		AirMap.logger.error(TrafficService.self, "MQTTSession socket error")
	}

	deinit {
		delegate = nil
	}

}
