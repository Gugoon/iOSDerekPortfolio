//
//  Task + Extension.swift
//  iotPlatform
//
//  Created by 구보성 on 3/28/24.
//

import Foundation

extension Task where Success == Never, Failure == Never {
    public static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}
