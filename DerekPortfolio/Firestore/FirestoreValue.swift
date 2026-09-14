//
//  FirestoreValue.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  Firestore REST 의 타입 달린 값.
//  { "stringValue": "..." }, { "integerValue": "3" }, { "mapValue": { "fields": {...} } } ...
//

import Foundation

enum FirestoreValue: Codable, Equatable {
    case null
    case bool(Bool)
    case integer(Int64)
    case double(Double)
    case timestamp(Date)
    case string(String)
    case array([FirestoreValue])
    case map([String: FirestoreValue])
    /// 이 앱이 쓰지 않는 타입(참조, 좌표, 바이트). 읽을 때만 흡수한다.
    case unsupported

    private enum CodingKeys: String, CodingKey {
        case nullValue, booleanValue, integerValue, doubleValue, timestampValue
        case stringValue, arrayValue, mapValue
    }

    private struct ArrayBody: Codable { var values: [FirestoreValue]? }
    private struct MapBody: Codable { var fields: [String: FirestoreValue]? }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if c.contains(.nullValue) {
            self = .null
        } else if let v = try c.decodeIfPresent(Bool.self, forKey: .booleanValue) {
            self = .bool(v)
        } else if let v = try c.decodeIfPresent(String.self, forKey: .integerValue) {
            // int64 는 JSON 숫자 정밀도를 넘을 수 있어 문자열로 온다.
            self = .integer(Int64(v) ?? 0)
        } else if c.contains(.doubleValue) {
            // doubleValue 는 숫자지만 NaN/Infinity 는 문자열로 온다.
            if let v = try? c.decode(Double.self, forKey: .doubleValue) {
                self = .double(v)
            } else {
                self = .double(Double(try c.decode(String.self, forKey: .doubleValue)) ?? 0)
            }
        } else if let v = try c.decodeIfPresent(String.self, forKey: .timestampValue) {
            self = FirestoreTimestamp.parse(v).map { .timestamp($0) } ?? .unsupported
        } else if let v = try c.decodeIfPresent(String.self, forKey: .stringValue) {
            self = .string(v)
        } else if let v = try c.decodeIfPresent(ArrayBody.self, forKey: .arrayValue) {
            self = .array(v.values ?? [])
        } else if let v = try c.decodeIfPresent(MapBody.self, forKey: .mapValue) {
            self = .map(v.fields ?? [:])
        } else {
            self = .unsupported
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .null, .unsupported: try c.encodeNil(forKey: .nullValue)
        case .bool(let v): try c.encode(v, forKey: .booleanValue)
        case .integer(let v): try c.encode(String(v), forKey: .integerValue)
        case .double(let v): try c.encode(v, forKey: .doubleValue)
        case .timestamp(let v): try c.encode(FirestoreTimestamp.format(v), forKey: .timestampValue)
        case .string(let v): try c.encode(v, forKey: .stringValue)
        case .array(let v): try c.encode(ArrayBody(values: v), forKey: .arrayValue)
        case .map(let v): try c.encode(MapBody(fields: v), forKey: .mapValue)
        }
    }
}

// MARK: - 편의 생성

extension FirestoreValue {
    static func optionalString(_ value: String?) -> FirestoreValue {
        value.map { .string($0) } ?? .null
    }

    static func strings(_ values: [String]) -> FirestoreValue {
        .array(values.map { .string($0) })
    }
}

// MARK: - 너그러운 읽기
// 콘솔이나 관리자 화면에서 필드가 비거나 타입이 어긋나도 앱이 죽지 않도록,
// 모든 파싱은 기본값으로 흡수한다(Flutter project_data.dart 의 _str 등과 같다).

extension Optional where Wrapped == FirestoreValue {
    /// 문자열이 아니면 fallback.
    func str(_ fallback: String = "") -> String {
        if case .string(let v)? = self { return v }
        return fallback
    }

    /// 앞뒤 공백을 걷어 비어 있지 않은 문자열만.
    var strOrNil: String? {
        if case .string(let v)? = self {
            let trimmed = v.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return nil
    }

    /// 배열 항목을 문자열로 바꿔 빈 항목을 버린다.
    var strList: [String] {
        guard case .array(let items)? = self else { return [] }
        return items.compactMap { item -> String? in
            let text: String
            switch item {
            case .string(let v): text = v
            case .integer(let v): text = String(v)
            case .double(let v): text = String(v)
            case .bool(let v): text = String(v)
            default: return nil
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    var mapList: [[String: FirestoreValue]] {
        guard case .array(let items)? = self else { return [] }
        return items.compactMap { if case .map(let fields) = $0 { return fields } else { return nil } }
    }

    var intValue: Int? {
        switch self {
        case .integer(let v)?: return Int(v)
        case .double(let v)?: return Int(v)
        default: return nil
        }
    }

    var dateValue: Date? {
        if case .timestamp(let v)? = self { return v }
        return nil
    }
}

// MARK: - 시각

enum FirestoreTimestamp {
    /// '2026-09-10T05:22:11.123456Z' 처럼 소수점 자리가 들쭉날쭉하게 온다.
    /// ISO8601DateFormatter 는 밀리초까지만 믿을 수 있어 소수부를 따로 더한다.
    static func parse(_ text: String) -> Date? {
        var base = text
        var fraction: Double = 0

        if let dot = text.firstIndex(of: ".") {
            let afterDot = text[text.index(after: dot)...]
            let digits = afterDot.prefix { $0.isNumber }
            fraction = Double("0." + digits) ?? 0
            base = String(text[..<dot]) + String(afterDot.dropFirst(digits.count))
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: base).map { $0.addingTimeInterval(fraction) }
    }

    static func format(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
