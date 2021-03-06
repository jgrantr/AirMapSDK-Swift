//
//  AirMapFlight+MGL.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 8/5/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//

import Mapbox
import SwiftTurf

extension AirMapFlight: MGLAnnotation {
		
	public var title: String? {
		guard let startTime = startTime else { return nil }
		let dateFormatter = DateFormatter()
		dateFormatter.doesRelativeDateFormatting = true
		dateFormatter.dateStyle = .medium
		dateFormatter.timeStyle = .long
		return dateFormatter.string(from: startTime)
	}
	
	public func annotationRepresentations() -> [MGLAnnotation]? {
		
		guard let geometry = self.geometry else { return nil }
		
		switch geometry.type {

		case .point:
			
			guard let buffer = self.buffer
				else { return nil }
			
			guard let centerCoordinate = (geometry as? AirMapPoint)?.coordinate
				else { return nil }
			
			let point = Point(geometry: centerCoordinate)
			let bufferedPoint = SwiftTurf.buffer(point, distance: buffer, units: .Meters)
			var coordinates = bufferedPoint?.geometry.first ?? []
			let circlePolygon = MGLPolygon(coordinates: &coordinates, count: UInt(coordinates.count))
			let circleLine = MGLPolyline(coordinates: &coordinates, count: UInt(coordinates.count))

			return [circlePolygon, circleLine]
			
		case .path:

			guard let buffer = self.buffer
				else { return nil }
			
			guard var coordinates = (geometry as? AirMapPath)?.coordinates, coordinates.count >= 2
				else { return nil }

			let lineString = LineString(geometry: coordinates)

			guard let bufferedCoordinates = SwiftTurf.buffer(lineString, distance: buffer)?.geometry else {
				return nil
			}
			var outerCoordinates = bufferedCoordinates.first!
			
			var interiorPolygons: [MGLPolygon] = bufferedCoordinates.map {
				var coordinates = $0
				return MGLPolygon(coordinates: &coordinates, count: UInt(coordinates.count))
			}
			interiorPolygons.removeFirst()
			
			let bufferPolygon = Buffer(coordinates: &outerCoordinates, count: UInt(outerCoordinates.count), interiorPolygons: interiorPolygons)
			let pathPolyline = MGLPolyline(coordinates: &coordinates, count: UInt(coordinates.count))

			return [bufferPolygon, pathPolyline]

		case .polygon:
			
			guard
				var polygons = (geometry as? AirMapPolygon)?.coordinates,
				polygons.count > 0 &&
				polygons.first!.count >= 3
			else {
				return nil
			}
			
			var outer = polygons.first!
			outer.append(outer.first!)
			
			let fill: MGLAnnotation
			let strokes: [MGLAnnotation]
			
			if polygons.count == 1 {
				fill = MGLPolygon(coordinates: &outer, count: UInt(outer.count))
				strokes = [MGLPolyline(coordinates: &outer, count: UInt(outer.count))]
			} else {
				let interiorPolygons: [MGLPolygon] = polygons[1..<polygons.count].map {
					var coords = $0
					return MGLPolygon(coordinates: &coords, count: UInt(coords.count))
				}
				fill = MGLPolygon(coordinates: &outer, count: UInt(outer.count), interiorPolygons: interiorPolygons)
				strokes = interiorPolygons.map { polygon in
					MGLPolyline(coordinates: polygon.coordinates, count: UInt(interiorPolygons.count))
				}
			}
			
			return [fill] + strokes
		}
	
	}

}
