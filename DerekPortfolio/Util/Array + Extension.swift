//
//  Array + Extension.swift
//  iotPlatform
//
//  Created by 구보성 on 3/28/24.
//

import Foundation

extension Array where Element: Hashable {
    public var uniques: Array {
        var buffer = Array()
        var added = Set<Element>()
        for elem in self {
            if !added.contains(elem) {
                buffer.append(elem)
                added.insert(elem)
            }
        }
        return buffer
    }
    
    public func wrapAround() -> [Element] {
      guard let first = self.first, let last = self.last else { return self }
      return [last] + self + [first]
    }
}
