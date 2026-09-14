//
//  CommonUserDefault.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  NetworkViewModel 이 헤더를 만들 때 읽는 값들.
//

import Foundation

@propertyWrapper
struct UserDefault<Value> {
    let key: String
    let defaultValue: Value

    var wrappedValue: Value {
        get { UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

enum CommonUserDefault {
    @UserDefault(key: "localeStr", defaultValue: "system")
    static var localeStr: String

    /// 기기를 구분하는 UUID. 처음 읽을 때 만든다.
    static var DeviceID: String {
        if let saved = UserDefaults.standard.string(forKey: "DeviceID") { return saved }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "DeviceID")
        return id
    }

    // 이 앱에서는 쓰지 않지만 NetworkViewModel 의 공통 헤더가 읽는다.
    @UserDefault(key: "shopByToken", defaultValue: "")
    static var shopByToken: String

    @UserDefault(key: "fcmToken", defaultValue: "")
    static var fcmToken: String

    @UserDefault(key: "googleAnalyticsId", defaultValue: "")
    static var googleAnalyticsId: String

    /// Firebase ID 토큰(1시간짜리). 비어 있지 않으면 Authorization 헤더로 나간다.
    /// 오래 사는 refresh token 은 여기가 아니라 키체인에 둔다(AuthSession).
    @UserDefault(key: "jwtToken", defaultValue: "")
    static var jwtToken: String

    @UserDefault(key: "tokenGrantType", defaultValue: "Bearer")
    static var tokenGrantType: String

    /// 방문 기록 문서 ID 앞부분에 쓰는 16자리 16진수. Flutter 의 localStorage 'visitor-id' 자리.
    @UserDefault(key: "visitorId", defaultValue: "")
    static var visitorId: String
}
