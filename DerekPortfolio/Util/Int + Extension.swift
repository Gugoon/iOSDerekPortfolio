//
//  Int + Extension.swift
//  iotPlatform
//
//  Created by 구보성 on 3/28/24.
//

import Foundation

extension Int{
    public func insertComma()->String?{
        let largeNumber = self
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let formattedNumber = numberFormatter.string(from: NSNumber(value:largeNumber))
        return formattedNumber ?? nil
    }
    
//    func numbersTo2ByteHex() -> String{
//        let tempLight = String(self, radix: 16)
//        var returnValue = ""
//        if tempLight.count < 3 {
//            let lv1 = "0".toHexString()
//            let lv2 = tempLight.toHexString()
//            returnValue = "\(lv2)\(lv1)"
//        }else if tempLight.count == 3{
//            let lv1 = tempLight.cSubstring(from: 0, to: 0).toHexString()
//            let lv2 = tempLight.cSubstring(from: 1, to: 2).toHexString()
//            returnValue = "\(lv2)\(lv1)"
//        }else if tempLight.count == 4{
//            let lv1 = tempLight.cSubstring(from: 0, to: 1).toHexString()
//            let lv2 = tempLight.cSubstring(from: 2, to: 3).toHexString()
//            returnValue = "\(lv2)\(lv1)"
//        }
//        return returnValue
//    }
    
    public func numbersTo2ByteHex() -> String {
        return String(format: "%04X", self).swappingHexBytes()
    }
    
    public func numbersTo1ByteHex() -> String {
        return String(format: "%02X", self).swappingHexBytes()
    }
}
