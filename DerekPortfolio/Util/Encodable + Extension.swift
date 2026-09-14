//
//  Encodable + Extension.swift
//  iotPlatform
//
//  Created by 구보성 on 3/28/24.
//

import Foundation

extension Encodable {
    public func toJSONData() -> Data? { try? JSONEncoder().encode(self) }
}
