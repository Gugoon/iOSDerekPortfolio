//
//  TimeInterval.swift
//  iotPlatform
//
//  Created by 구보성 on 3/28/24.
//

import Foundation

extension TimeInterval {
    public var hourMinuteSecondMS: String {
        String(format:"%d:%02d:%02d.%03d", hour, minute, second, millisecond)
    }
    
    public var hourMinuteSecond: String {
        String(format:"%d:%02d:%02d", hour, minute, second)
    }
    
    public var minuteSecondMS: String {
        String(format:"%d:%02d.%03d", minute, second, millisecond)
    }
    
    public var hour: Int {
        Int((self/3600).truncatingRemainder(dividingBy: 3600))
    }
    
    public var minute: Int {
        Int((self/60).truncatingRemainder(dividingBy: 60))
    }
    
    public var second: Int {
        Int(truncatingRemainder(dividingBy: 60))
    }
    
    public var millisecond: Int {
        Int((self*1000).truncatingRemainder(dividingBy: 1000))
    }
}
