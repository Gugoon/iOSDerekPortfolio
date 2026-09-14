//
//  AuthSession.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  Firebase Auth 이메일/비밀번호 로그인을 REST 로 직접 다룬다.
//
//  - ID 토큰(1시간)은 CommonUserDefault.jwtToken 에 둔다. NetworkViewModel 이 이 값을
//    Authorization: Bearer 헤더로 붙이고, Firestore 는 그걸로 request.auth 를 채운다.
//  - refresh token 은 키체인에 둔다. 앱을 다시 켜도 로그인이 유지된다.
//  - Flutter 의 authStateChanges() 자리는 `$user` 퍼블리셔가 맡는다.
//

import Foundation
import Combine

@MainActor
final class AuthSession: NetworkViewModel {
    static let shared = AuthSession()

    /// 로그인한 계정. nil 이면 로그아웃 상태.
    @Published private(set) var user: AuthUser?

    private enum Keys {
        static let refreshToken = "auth.refreshToken"
        static let user = "auth.user"
        static let expiresAt = "auth.idTokenExpiresAt"
    }

    /// 만료 직전 토큰으로 요청했다가 떨어지는 일이 없도록 이만큼 일찍 갱신한다.
    private let refreshMargin: TimeInterval = 120

    private var refreshTask: Task<Void, Never>?

    /// 로그아웃할 때마다 올린다. 이미 나간 갱신 요청은 취소가 먹지 않으므로, 응답이 왔을 때
    /// 세대가 바뀌었으면 결과를 버린다. 그러지 않으면 로그아웃한 세션이 되살아난다.
    private var sessionGeneration = 0

    private override init() {
        super.init()
        restore()
    }

    // MARK: 상태 복원

    private func restore() {
        guard
            KeychainStore.string(for: Keys.refreshToken) != nil,
            let saved = try? UserDefaults.standard.getObject(forKey: Keys.user, castTo: AuthUser.self)
        else {
            clearSession()
            return
        }
        user = saved
    }

    private var idTokenExpiresAt: Date {
        get { UserDefaults.standard.object(forKey: Keys.expiresAt) as? Date ?? .distantPast }
        set { UserDefaults.standard.set(newValue, forKey: Keys.expiresAt) }
    }

    // MARK: 로그인 · 로그아웃

    func signIn(email: String, password: String) async throws {
        // 남아 있던 토큰이 헤더로 따라가지 않게 비운다.
        CommonUserDefault.jwtToken = ""
        let response: SignInResponse = try await request(
            APIEndpoint.signIn,
            method: .POST,
            body: SignInRequest(email: email, password: password)
        )
        store(
            user: AuthUser(uid: response.localId, email: response.email ?? email),
            idToken: response.idToken,
            refreshToken: response.refreshToken,
            expiresIn: response.expiresIn
        )
    }

    func sendPasswordReset(email: String) async throws {
        let savedToken = CommonUserDefault.jwtToken
        CommonUserDefault.jwtToken = ""
        defer { CommonUserDefault.jwtToken = savedToken }
        try await requestNoReply(
            APIEndpoint.sendOobCode,
            method: .POST,
            body: PasswordResetRequest(email: email)
        )
    }

    func signOut() {
        sessionGeneration += 1
        refreshTask?.cancel()
        refreshTask = nil
        clearSession()
    }

    // MARK: 토큰

    /// Firestore 요청 직전에 부른다. 토큰이 곧 만료되면 갱신해 둔다.
    ///
    /// 만료된 토큰을 그대로 실어 보내면 공개 읽기까지 401 로 떨어진다.
    /// 갱신에 실패하면 헤더를 비워, 적어도 공개 콘텐츠는 읽히게 한다.
    func prepareAuthorization() async {
        guard user != nil else {
            CommonUserDefault.jwtToken = ""
            return
        }
        guard idTokenExpiresAt.timeIntervalSinceNow < refreshMargin
                || CommonUserDefault.jwtToken.isEmpty
        else { return }

        // 여러 요청이 동시에 들어와도 갱신은 한 번만.
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task = Task { await self.refreshIDToken() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func refreshIDToken() async {
        guard let refreshToken = KeychainStore.string(for: Keys.refreshToken), let current = user else {
            clearSession()
            return
        }

        let generation = sessionGeneration

        // securetoken 은 Authorization 헤더의 Firebase 토큰을 OAuth 토큰으로 오인해 거절한다.
        CommonUserDefault.jwtToken = ""

        do {
            let response: RefreshTokenResponse = try await request(
                APIEndpoint.refreshToken,
                method: .POST,
                body: RefreshTokenRequest(refresh_token: refreshToken)
            )
            // 기다리는 사이 로그아웃했다면 결과를 버린다.
            guard generation == sessionGeneration else { return }
            store(
                user: AuthUser(uid: response.user_id, email: current.email),
                idToken: response.id_token,
                refreshToken: response.refresh_token,
                expiresIn: response.expires_in
            )
        } catch let failure as APIFailure where failure.httpCode == 400 || failure.httpCode == 401 {
            // TOKEN_EXPIRED, USER_DISABLED, INVALID_REFRESH_TOKEN — 다시 로그인해야 한다.
            guard generation == sessionGeneration else { return }
            Log("세션이 만료되었습니다: \(failure.message)")
            clearSession()
        } catch {
            // 네트워크 문제. 세션은 남겨 두고 다음 요청에서 다시 시도한다.
            Log("토큰 갱신 실패: \(error.localizedDescription)")
        }
    }

    private func store(user: AuthUser, idToken: String, refreshToken: String, expiresIn: String) {
        KeychainStore.set(refreshToken, for: Keys.refreshToken)
        try? UserDefaults.standard.setObject(user, forKey: Keys.user)
        CommonUserDefault.tokenGrantType = "Bearer"
        CommonUserDefault.jwtToken = idToken
        idTokenExpiresAt = Date().addingTimeInterval(TimeInterval(expiresIn) ?? 3600)
        if self.user != user { self.user = user }
    }

    private func clearSession() {
        KeychainStore.set(nil, for: Keys.refreshToken)
        UserDefaults.standard.removeObject(forKey: Keys.user)
        UserDefaults.standard.removeObject(forKey: Keys.expiresAt)
        CommonUserDefault.jwtToken = ""
        if user != nil { user = nil }
    }
}
