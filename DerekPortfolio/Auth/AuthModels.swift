//
//  AuthModels.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  Firebase Auth REST(identitytoolkit / securetoken) 본문.
//

import Foundation

struct AuthUser: Codable, Equatable {
    let uid: String
    let email: String
}

struct SignInRequest: Codable {
    let email: String
    let password: String
    var returnSecureToken = true
}

struct SignInResponse: Codable {
    let localId: String
    let email: String?
    let idToken: String
    let refreshToken: String
    /// 초 단위 문자열. 보통 "3600".
    let expiresIn: String
}

struct PasswordResetRequest: Codable {
    var requestType = "PASSWORD_RESET"
    let email: String
}

struct RefreshTokenRequest: Codable {
    var grant_type = "refresh_token"
    let refresh_token: String
}

struct RefreshTokenResponse: Codable {
    let id_token: String
    let refresh_token: String
    let expires_in: String
    let user_id: String
}

/// Firebase Auth 가 message 로 돌려주는 오류 코드를 화면 문구로 바꾼다.
/// Flutter admin_page.dart 의 _messageFor 와 같은 분류다.
enum AuthErrorMessage {
    static func signIn(_ error: Error) -> String {
        guard let failure = error as? APIFailure, failure.httpCode != nil else {
            return "로그인에 실패했습니다: \(error.localizedDescription)"
        }
        // 'TOO_MANY_ATTEMPTS_TRY_LATER : Access to this account...' 처럼 뒤에 설명이 붙는다.
        let code = failure.message.split(separator: ":").first?
            .trimmingCharacters(in: .whitespaces) ?? failure.message

        switch code {
        case "INVALID_EMAIL", "MISSING_EMAIL":
            return "이메일 형식이 올바르지 않습니다."
        case "EMAIL_NOT_FOUND", "INVALID_PASSWORD", "INVALID_LOGIN_CREDENTIALS", "MISSING_PASSWORD":
            return "이메일 또는 비밀번호가 올바르지 않습니다."
        case "TOO_MANY_ATTEMPTS_TRY_LATER":
            return "시도가 너무 잦습니다. 잠시 후 다시 시도하세요."
        case "OPERATION_NOT_ALLOWED", "PASSWORD_LOGIN_DISABLED":
            return "Firebase 콘솔에서 이메일/비밀번호 로그인을 활성화해야 합니다."
        case "USER_DISABLED":
            return "사용이 중지된 계정입니다."
        default:
            return "로그인에 실패했습니다 (\(code))."
        }
    }
}
