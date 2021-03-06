//
//  Color+App.swift
//  AirMapSDK
//
//  Created by Adolfo Martinelli on 7/19/16.
//  Copyright © 2016 AirMap, Inc. All rights reserved.
//


#if os(OSX)
	import AppKit
	public typealias Color = NSColor
#else
	import UIKit
	public typealias Color = UIColor
#endif

public extension Color {

	public static var airMapLightBlue: Color {
		return Color(red: 136.0/255.0, green: 219.0/255.0, blue: 223.0/255.0, alpha: 1.0)
	}

	public static var airMapDarkBlue: Color {
		return Color(red: 51.0/255.0, green: 63.0/255.0, blue: 72.0/255.0, alpha: 1.0)
	}
	
	public static var airMapDarkGray: Color {
		return Color(red: 51.0/255.0, green: 63.0/255.0, blue: 72.0/255.0, alpha: 1.0)
	}
	
	public static var airMapGreen: Color {
		return Color(red: 108.0/255.0, green: 194.0/255.0, blue: 74.0/255.0, alpha: 1.0)
	}
	
	public static var airMapYellow: Color {
		return Color(red: 249.0/255.0, green: 229.0/255.0, blue: 71.0/255.0, alpha: 1.0)
	}
	
	public static var airMapRed: Color {
		return .red
	}
	
	public static var airMapBlack: Color {
		return .black
	}

}
