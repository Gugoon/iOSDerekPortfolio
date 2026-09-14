//
//  UInt8 + Extension.swift
//  lx3
//
//  Created by 구보성 on 5/24/24.
//

import Foundation

extension UInt8{
    public func stringToHexStr() -> String{
        let hexString = String(self, radix: 16)
        
        if hexString.count == 1 {
                return "0\(hexString)"
            } else {
                return hexString
            }
    }
}

extension [UInt8]{
    public func safeUInt8Sum() -> UInt8 {
        var sum: Int16 = 0
        for byte in self {
            sum += Int16(byte)
        }
        return ~UInt8(sum & 0xFF)
    }
}
