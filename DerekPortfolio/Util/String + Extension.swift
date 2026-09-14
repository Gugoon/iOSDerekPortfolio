//
//  String + Extension.swift
//  iotPlatform
//
//  Created by 구보성 on 3/28/24.
//

import Foundation
extension String {
    
    public var ns: NSString {
        return self as NSString
    }
    
    public var pathExtension: String? {
        return ns.pathExtension
    }
    
    public var lastPathComponent: String? {
        return ns.lastPathComponent
    }
    
    public var deletingLastPathComponent: String {
        return ns.deletingLastPathComponent
    }
    
    public var deletingPathExtension: String {
        return ns.deletingPathExtension
    }
    
    public func appendingPathComponent(path: String) -> String {
        return ns.appendingPathComponent(path)
    }
    
    public func appendingPathExtension(ext: String) -> String? {
        return ns.appendingPathExtension(ext)
    }
    
    public func changeNumberStr(_ num : Int) -> String{
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        
        
        if let pointStr = numberFormatter.string(from: NSNumber(value: num)){
            return "\(pointStr)"
        }
        return ""
    }
    
    
    public func formatPhoneNumber() -> String {
        let mask = "XXX-XXXX-XXXX"
        let cleanNumber = components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        var result = ""
        var startIndex = cleanNumber.startIndex
        let endIndex = cleanNumber.endIndex
        
        for char in mask where startIndex < endIndex {
            if char == "X" {
                result.append(cleanNumber[startIndex])
                startIndex = cleanNumber.index(after: startIndex)
            } else {
                result.append(char)
            }
        }
        return result
    }

    
    public func isValidEmail() -> String {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        return emailPredicate.evaluate(with: self) ?  "" : "올바른 형식의 이메일을 입력해주세요."
    }

    public func validatePassword() -> String {
        let passwordRegex = "((?=.*\\d)(?=.*[A-Za-z])(?=.*[\\W]).{8,})"
        let passwordPredicate = NSPredicate(format: "SELF MATCHES %@", passwordRegex)
        
        return passwordPredicate.evaluate(with: self) ?  "" : "8자 이상의 영문, 숫자, 특수문자를 사용해주세요."
    }
    
}

extension StringProtocol {
    public func index(of string: Self, options: String.CompareOptions = []) -> Index? {
        return range(of: string, options: options)?.lowerBound
    }
    
    public func endIndex(of string: Self, options: String.CompareOptions = []) -> Index? {
        return range(of: string, options: options)?.upperBound
    }
    
    public func indexes(of string: Self, options: String.CompareOptions = []) -> [Index] {
        var result: [Index] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
              let range = self[startIndex...].range(of: string, options: options) {
            result.append(range.lowerBound)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound :
            index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
    
    public func ranges(of string: Self, options: String.CompareOptions = []) -> [Range<Index>] {
        var result: [Range<Index>] = []
        var startIndex = self.startIndex
        while startIndex < endIndex,
              let range = self[startIndex...].range(of: string, options: options) {
            result.append(range)
            startIndex = range.lowerBound < range.upperBound ? range.upperBound :
            index(range.lowerBound, offsetBy: 1, limitedBy: endIndex) ?? endIndex
        }
        return result
    }
}


extension String {

    public func sliceString(from: Int, to: Int) -> String {
        guard from < count, to >= 0, to - from >= 0 else {
            return ""
        }
        // Index 값 획득
        let startIndex = index(self.startIndex, offsetBy: from)
        let endIndex = index(self.startIndex, offsetBy: to + 1) // '+1'이 있는 이유: endIndex는 문자열의 마지막 그 다음을 가리키기 때문
        
        return String(self[startIndex ..< endIndex])
    }
    
    public func masked(withAsterisksWithLength length: Int) -> String {
        return String(repeating: "*", count: length)
    }
    
    public func toDate(format: String = "yyyy-MM-dd HH:mm:ss") -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(abbreviation: "KST")
        return formatter.date(from: self) ?? Date()
    }
    
    public func toDateNullable(format: String = "yyyy-MM-dd HH:mm:ss") -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(abbreviation: "KST")
        return formatter.date(from: self)
    }
    
    public func toDateString(sourceFormat: String = "yyyy-MM-dd HH:mm:ss", resultFormat: String = "yyyy년 M월 d일") -> String? {
        toDateNullable(format: sourceFormat)?.toString(format: resultFormat)
    }
    
    public func toDateFromISO(format: String = "yyyy-MM-dd'T'HH:mm:ss.SSSz") -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(abbreviation: "KST")
        return formatter.date(from: self) ?? Date()
    }
}


extension String {
//    public var hexToStr : String {
//        let regex = try! NSRegularExpression(pattern: "(0x)?([0-9A-Fa-f]{2})", options: .caseInsensitive)
//        let textNS = self as NSString
//        let matchesArray = regex.matches(in: textNS as String, options: [], range: NSMakeRange(0, textNS.length))
//        
//        let characters = matchesArray.map {
//            Character(UnicodeScalar(UInt32(textNS.substring(with: $0.range(at: 2)), radix: 16)!)!)
//        }
//        
//        return String(characters)
//    }

    public var hexToStr: String {
        let regex = try! NSRegularExpression(pattern: "(0x)?([0-9A-Fa-f]{2})", options: .caseInsensitive)
        let textNS = self as NSString
        let matchesArray = regex.matches(in: textNS as String, options: [], range: NSMakeRange(0, textNS.length))
        
        let bytes = matchesArray.map {
            UInt8(textNS.substring(with: $0.range(at: 2)), radix: 16)!
        }
        
        let data = Data(bytes)
        return String(data: data, encoding: .utf8) ?? "[인코딩 실패]"
    }
    
    public var toHexaDecimal: Data? {
        var data = Data(capacity: count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
    
    public func toHexString() -> String {
          if self.count % 2 != 0 {
              return "0" + self
          }
          return self
      }
    
    public func twoByteHexToNumbers() -> Int{
        let v1 = self.sliceString(from: 0, to: 1)
        let v2 = self.sliceString(from: 2, to: 3)
        return Int(UInt32("\(v2)\(v1)", radix: 16) ?? 0)
    }
    
    public func convertHexStringToUInt8Array() -> [UInt8] {
        let hexStringLength = self.count
        guard hexStringLength % 2 == 0 else {
            fatalError("Invalid hex string length: Must be even.")
        }
        
        var uint8Array: [UInt8] = []
        var currentByte: UInt8 = 0
        
        for (index, character) in self.enumerated() {
            let byteValue = UInt8(character.hexDigitValue ?? 0)
            
            if index % 2 == 0 {
                currentByte = byteValue << 4
            } else {
                currentByte |= byteValue
                uint8Array.append(currentByte)
            }
        }
        Log("### uint8Array : \(uint8Array)")
        return uint8Array
    }
    
    func hexStringToByteArray() -> [UInt8]? {
        let hexString = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hexString.count % 2 == 0 else { return nil }
        
        var byteArray: [UInt8] = []
        var index = hexString.startIndex
        
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            let byteString = hexString[index..<nextIndex]
            
            if let byte = UInt8(byteString, radix: 16) {
                byteArray.append(byte)
            } else {
                return nil // Invalid hex string
            }
            index = nextIndex
        }
        Log("byteArray : \(byteArray)")
        return byteArray
    }
    
    public var toHexa: Data? {
        var data = Data(capacity: count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
    
    func hexToDecimal() -> Int? {
        return Int(self, radix: 16)
    }
    
    func checkSumAT() -> String {
        // 1. Hex String -> [UInt8] 변환
        var bytes: [UInt8] = []
        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: 2, limitedBy: endIndex) ?? endIndex
            let hexStr = String(self[index..<nextIndex])
            if let byte = UInt8(hexStr, radix: 16) {
                bytes.append(byte)
            } 
            index = nextIndex
        }
        
        // 2. 바이트 합산
        let sum = bytes.reduce(0, { UInt16($0) + UInt16($1) }) & 0xFF // UInt16으로 변환 후 UInt8 범위 유지
        
        // 3. 2의 보수 계산 (모든 비트 반전 후 1 더하기)
        let checksum = (~sum & 0xFF) &+ 1
        
        // 4. Hex String으로 반환
        return String(format: "%02X", checksum)
    }
    
//    public func safeUInt8Sum() -> UInt8 {
//        var sum: Int16 = 0
//        for byte in self {
//            sum += Int16(byte)
//        }
//        return ~UInt8(sum & 0xFF)
//    }
    
    public func swappingHexBytes() -> String {
        guard self.count == 4 else { return self }
        return "\(self.suffix(2))\(self.prefix(2))"
    }
    
    public func splitStringByUnderscore(_ inputString: String) -> (String, String)? {
        let components = inputString.components(separatedBy: "_")
        
        guard components.count == 2 else {
            return nil
        }
        
        let part1 = components[0]
        let part2 = components[1]
        
        return (part1, part2)
    }
}

