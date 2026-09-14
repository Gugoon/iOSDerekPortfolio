//
//  Double + Extension.swift
//  iotPlatform
//
//  Created by 구보성 on 3/28/24.
//

import Foundation

extension Double{
    public func insertComma()->String?{
        let largeNumber = self
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let formattedNumber = numberFormatter.string(from: NSNumber(value:largeNumber))
        return formattedNumber ?? nil
    }
}
