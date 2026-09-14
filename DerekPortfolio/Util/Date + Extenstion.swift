//
//  Date + Extenstion.swift
//  lx3
//
//  Created by 구보성 on 5/2/24.
//

import Foundation
extension Date {
    public var millisecondsSince1970:Double {
        return Double((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    public var millisecondsSince1970Int : Int{
        return Int((self.timeIntervalSince1970 * 1000).rounded())
    }
    
    public init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
    
    public static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
    
    public func getDateFor(days:Int) -> Date? {
        return Calendar.current.date(byAdding: .day, value: days, to: Date())
    }
    
    public func getYear()->String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        let yearString = dateFormatter.string(from: self)
        return yearString
    }
    
    public func getMonth()->String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M"
        let monthString = dateFormatter.string(from: self)
        return monthString
    }
    
    public func getDay()->String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd"
        let dayString = dateFormatter.string(from: self)
        return dayString
    }
    
    public func getMonthDay()->String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M. d"
        let monthDayString = dateFormatter.string(from: self)
        return monthDayString
    }
    
    public func getYearMonth()->String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy년 M월"
        let yearDayString = dateFormatter.string(from: self)
        return yearDayString
    }
    
    public func getMonthDayHourMin()->String{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M월 dd일 hh:mm"
        let yearDayString = dateFormatter.string(from: self)
        return yearDayString
    }
    
    
    public func startOfMonth() -> Date {
        return Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Calendar.current.startOfDay(for: self)))!
    }
    
    public func endOfMonth() -> Date {
        return Calendar.current.date(byAdding: DateComponents(month: 1, day: -1), to: self.startOfMonth())!
    }
    
    
    /// Returns the amount of years from another date
    public func years(from date: Date) -> Int {
        return Calendar.current.dateComponents([.year], from: date, to: self).year ?? 0
    }
    /// Returns the amount of months from another date
    public func months(from date: Date) -> Int {
        return Calendar.current.dateComponents([.month], from: date, to: self).month ?? 0
    }
    /// Returns the amount of weeks from another date
    public func weeks(from date: Date) -> Int {
        return Calendar.current.dateComponents([.weekOfMonth], from: date, to: self).weekOfMonth ?? 0
    }
    /// Returns the amount of days from another date
    public func days(from date: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }
    /// Returns the amount of hours from another date
    public func hours(from date: Date) -> Int {
        return Calendar.current.dateComponents([.hour], from: date, to: self).hour ?? 0
    }
    /// Returns the amount of minutes from another date
    public func minutes(from date: Date) -> Int {
        return Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0
    }
    /// Returns the amount of seconds from another date
    public func seconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
    
    
    public func toKor(formatStr : String = "yyyy-MM-dd'T'HH:mm:ss.SSSz") -> Date{
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = formatStr
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.timeZone = TimeZone(abbreviation: "KST")
        if let date = dateFormatter.date(from: self.toIsoString()){
            return date
        }else{
            return self
        }
    }
    
    public func toIsoString(format: String = "yyyy-MM-dd'T'HH:mm:ss.SSSz",
                       localeIdentifier: String = "ko_KR",
                       timeZoneAbbreviation: String = "KST") -> String {
           let dateFormatter = DateFormatter()
           dateFormatter.dateFormat = format
           dateFormatter.locale = Locale(identifier: localeIdentifier)
           dateFormatter.timeZone = TimeZone(abbreviation: timeZoneAbbreviation)
           return dateFormatter.string(from: self)
       }
    
    public func toString(format: String = "yyyy-MM-dd HH:mm:ss") -> String {
           let formatter = DateFormatter()
           formatter.dateFormat = format
           formatter.locale = Locale(identifier: "ko_KR")
           formatter.timeZone = TimeZone(abbreviation: "KST")
           return formatter.string(from: self)
       }
}
