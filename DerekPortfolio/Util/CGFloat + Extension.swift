//
//  CGFloat + Extension.swift
//  iotPlatform
//
//  Created by 구보성 on 3/28/24.
//

import Foundation

extension CGFloat {
    static public func random() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}
