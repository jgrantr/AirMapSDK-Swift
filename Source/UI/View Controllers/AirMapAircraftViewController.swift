//
//  AirMapAircraftViewController.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 7/18/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import RxSwift
import RxCocoa

class AirMapAircraftViewController: UITableViewController, AnalyticsTrackable {
	
	var screenName = "List Aircraft"
	
	let selectedAircraft = Variable(nil as AirMapAircraft?)
	
	fileprivate let activityIndicator = ActivityIndicator()
	fileprivate let aircraft = Variable([AirMapAircraft]())
	fileprivate let disposeBag = DisposeBag()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		setupBindings()
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		
		trackView()
		
		AirMap
			.rx.listAircraft()
			.trackActivity(activityIndicator)
			.bindTo(aircraft)
			.disposed(by: disposeBag)
	}
	
	@IBAction func dismiss() {
		self.dismiss(animated: true, completion: nil)
	}
	
	fileprivate func setupBindings() {
	
		tableView.dataSource = nil
		tableView.delegate = nil
		
		aircraft
			.asObservable()
			.bindTo(tableView.rx.items(cellIdentifier: "aircraftCell")) {
				(index, aircraft, cell) in
				cell.textLabel?.text = aircraft.nickname
				cell.detailTextLabel?.text = [aircraft.model.manufacturer.name, aircraft.model.name]
					.flatMap {$0}.joined(separator: " ")
			}
			.disposed(by: disposeBag)
		
		tableView.rx.modelSelected(AirMapAircraft.self)
			.do(onNext: { [weak self] _ in
				self?.dismiss(animated: true, completion: nil)
			})
			.asOptional()
			.bindTo(selectedAircraft)
			.disposed(by: disposeBag)
		
		tableView
			.rx.itemDeleted
			.do(
				onNext: { [unowned self] _ in
					self.trackEvent(.swipe, label: "Delete")
			})
			.map(tableView.rx.model)
			.flatMap { aircraft in
				AirMap.rx.deleteAircraft(aircraft)
					.do(
						onError: { [unowned self] error in
							self.trackEvent(.delete, label: "Error", value: (error as NSError).code as NSNumber?)
						},
						onCompleted: { [unowned self] _ in
							self.trackEvent(.delete, label: "Success")
					})
			}
			.flatMap(AirMap.rx.listAircraft)
			.do(onError: { AirMap.logger.error($0) })
			.ignoreErrors()
			.bindTo(aircraft)
			.disposed(by: disposeBag)
		
		activityIndicator.asObservable()
			.throttle(0.25, scheduler: MainScheduler.instance)
			.distinctUntilChanged()
			.bindTo(rx_loading)
			.disposed(by: disposeBag)
	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		guard let identifier = segue.identifier else { return }
		
		switch identifier {
			
		case "createAircraft":
			trackEvent(.tap, label: "New Aircraft Button")
			let nav = segue.destination as! AirMapAircraftNavController
			nav.aircraftDelegate = self
			
		case "editAircraft":
			trackEvent(.tap, label: "Edit Aircraft Button")
			let cell = sender as! UITableViewCell
			let indexPath = tableView.indexPath(for: cell)!
			let aircraft = try! tableView.rx.model(at: indexPath) as AirMapAircraft
			let nav = segue.destination as! AirMapAircraftNavController
			nav.aircraftDelegate = self
			let aircraftVC = nav.viewControllers.last as! AirMapCreateAircraftViewController
			aircraftVC.aircraft = aircraft
			
		default:
			break
		}
	}
	
	@IBAction func unwindToAircraft(_ segue: UIStoryboardSegue) { /* unwind hook; keep */ }
}

extension AirMapAircraftViewController: AirMapAircraftNavControllerDelegate {
	
	func aircraftNavController(_ navController: AirMapAircraftNavController, didCreateOrModify aircraft: AirMapAircraft) {
		selectedAircraft.value = aircraft
		navigationController?.dismiss(animated: true, completion: nil)
	}
}
