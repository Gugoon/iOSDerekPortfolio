//
//  AdminRootView.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  콘텐츠 관리 화면. Flutter lib/admin/admin_page.dart 자리.
//
//  Firebase Auth 이메일/비밀번호로 로그인한 뒤, Firestore admins/{uid} 문서가 있는
//  계정만 편집할 수 있다. 같은 조건이 firestore.rules 에도 걸려 있으므로 여기서의
//  검사는 안내용이고 실제 차단은 서버가 한다.
//

import SwiftUI
import Combine

// MARK: - 상태

@MainActor
final class AdminViewModel: NetworkViewModel {
    enum State {
        case loading
        case failed(String)
        case notAdmin
        case ready(ProfileData, [ProjectData])
    }

    @Published private(set) var user: AuthUser?
    @Published private(set) var state: State = .loading
    /// 기다림이 길어졌는지. 아무 변화 없는 동그라미만 돌면 멈춘 화면과 구분이 되지 않는다.
    @Published private(set) var isSlow = false
    /// 편집기를 새로 만들어야 할 때(시드 · 다시 읽기) 바뀐다.
    @Published private(set) var loadGeneration = 0

    private var slowTimer: AnyCancellable?
    private var loadTask: Task<Void, Never>?

    override init() {
        super.init()

        // 이미 로그인한 채로 열었다면 첫 프레임부터 권한 확인 화면을 띄운다. 아래 구독은
        // receive(on:) 때문에 한 박자 늦게 오므로, 거기에만 맡기면 로그인 화면이 잠깐 비친다.
        user = AuthSession.shared.user
        if user != nil { reload() }

        // authStateChanges 자리. 로그인 · 로그아웃 · 세션 만료가 모두 여기로 모인다.
        // 현재 값은 위에서 반영했으므로 이후의 변화만 받는다.
        AuthSession.shared.$user
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                guard let self, self.user != user else { return }
                self.user = user
                if user != nil { self.reload() } else { self.loadTask?.cancel() }
            }
            .store(in: &subscriptions)
    }

    /// 화면에 필요한 것을 한 번에 읽어온다.
    ///
    /// 셋을 한 줄로 세우면 왕복이 쌓여 연결이 느린 날에는 그대로 진행 표시 시간이 된다.
    /// site · projects 는 공개 읽기라 권한 확인 전에 읽어도 문제가 없으므로 동시에 던진다.
    func reload() {
        guard let user else { return }
        loadTask?.cancel()
        state = .loading
        isSlow = false
        slowTimer = Just(())
            .delay(for: .seconds(3), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.isSlow = true }

        loadTask = Task {
            do {
                async let admin = isAdmin(uid: user.uid)
                async let profile = loadProfileStrict()
                async let projects = loadProjectsStrict()
                let (isAdmin, loadedProfile, loadedProjects) = try await (admin, profile, projects)
                guard !Task.isCancelled else { return }
                state = isAdmin ? .ready(loadedProfile, loadedProjects) : .notAdmin
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(Self.message(for: error))
            }
            loadGeneration += 1
            slowTimer = nil
        }
    }

    func seed(replaceExisting: Bool) async {
        do {
            let wrote = try await seedFromDefaults(replaceExisting: replaceExisting)
            guard wrote else {
                await setToastMessage("이미 프로젝트가 있어 가져오지 않았습니다. 기본 데이터로 바꾸려면 '초기화'를 누르세요.")
                return
            }
            await setToastMessage("기본 데이터를 반영했습니다.")
            reload()
        } catch {
            await setToastMessage("시드에 실패했습니다: \(error.localizedDescription)", type: .error)
        }
    }

    func signOut() {
        AuthSession.shared.signOut()
    }

    /// 읽기 실패를 화면에 보여 줄 문장으로 바꾼다. 제한 시간에 걸린 경우가 가장 흔하다.
    private static func message(for error: Error) -> String {
        if let failure = error as? APIFailure, failure.isTimeout {
            return "콘텐츠를 불러오지 못했습니다.\n서버 응답이 제때 오지 않았습니다. 네트워크 상태를 확인하고 다시 시도해 주세요."
        }
        return "콘텐츠를 불러오지 못했습니다.\n\(error.localizedDescription)"
    }
}

// MARK: - 화면

struct AdminRootView: View {
    @StateObject private var viewModel = AdminViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if !FirebaseConfig.isConfigured {
                    AdminPlaceholder(
                        icon: "gearshape",
                        message: "Firebase 설정(FirebaseConfig.plist)이 없어 관리자 화면을 열 수 없습니다.\nREADME 의 설정 방법을 참고하세요."
                    )
                } else if viewModel.user == nil {
                    SignInView()
                } else {
                    gate
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background)
            .navigationTitle("포트폴리오 콘텐츠 관리")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.surfaceCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbar }
        }
        .toastOverlay()
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            // 닫으면 포트폴리오 화면이 여기서 고친 내용을 다시 읽어 반영한다.
            Button { dismiss() } label: {
                Label("사이트 보기", systemImage: "chevron.left")
                    .labelStyle(.titleAndIcon)
                    .font(AppFonts.sans(14, weight: .medium))
            }
            .tint(AppTheme.primary)
        }
        if let user = viewModel.user {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Text(user.email)
                    Button(role: .destructive) { viewModel.signOut() } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "person.crop.circle")
                        .foregroundStyle(AppTheme.textMuted)
                }
                .accessibilityLabel("계정")
            }
        }
    }

    @ViewBuilder
    private var gate: some View {
        switch viewModel.state {
        case .loading:
            AdminBusyView(message: "콘텐츠 불러오는 중", slow: viewModel.isSlow)
        case .failed(let message):
            AdminErrorView(icon: "icloud.slash", message: message, onRetry: viewModel.reload, onSignOut: viewModel.signOut)
        case .notAdmin:
            AdminErrorView(
                icon: "lock",
                message: "이 계정(\(viewModel.user?.email ?? ""))에는 편집 권한이 없습니다.\nFirestore 의 admins 컬렉션에 문서 ID \"\(viewModel.user?.uid ?? "")\" 를 추가하세요.",
                onRetry: viewModel.reload,
                onSignOut: viewModel.signOut
            )
        case .ready(let profile, let projects):
            AdminTabs(viewModel: viewModel, profile: profile, projects: projects)
                .id(viewModel.loadGeneration)
        }
    }
}

// MARK: - 탭

private struct AdminTabs: View {
    @ObservedObject var viewModel: AdminViewModel
    let profile: ProfileData
    let projects: [ProjectData]

    private enum Tab: String, CaseIterable {
        case profile = "프로필 · 경력 · 스킬"
        case projects = "프로젝트"
        case visits = "방문 기록"
    }

    @State private var tab: Tab = .profile
    @State private var pendingSeed: Bool?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(Tab.allCases, id: \.self) { item in
                            Button { tab = item } label: {
                                VStack(spacing: 8) {
                                    Text(item.rawValue)
                                        .font(AppFonts.sans(14, weight: tab == item ? .semibold : .medium))
                                        .foregroundStyle(tab == item ? AppTheme.primary : AppTheme.textMuted)
                                    Rectangle()
                                        .fill(tab == item ? AppTheme.primary : .clear)
                                        .frame(height: 2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // 시드 버튼은 콘텐츠를 다루는 탭에서만 의미가 있다.
                if tab != .visits {
                    HStack(spacing: 8) {
                        AdminButton(label: "기본 데이터 가져오기", icon: "square.and.arrow.down", outlined: true) {
                            pendingSeed = false
                        }
                        AdminButton(label: "초기화", icon: "arrow.counterclockwise", outlined: true, color: AppTheme.accent) {
                            pendingSeed = true
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
            }
            .padding(.top, 10)
            .background(AppTheme.surfaceCard)
            .overlay(alignment: .bottom) { Rectangle().fill(AppTheme.border).frame(height: 1) }

            // 탭을 오가도 편집 중인 내용이 사라지지 않도록 셋 다 붙여 두고 보이는 것만 바꾼다.
            ZStack {
                ProfileEditorView(initial: profile).opacity(tab == .profile ? 1 : 0).allowsHitTesting(tab == .profile)
                ProjectsEditorView(initial: projects).opacity(tab == .projects ? 1 : 0).allowsHitTesting(tab == .projects)
                if tab == .visits { VisitsView() }
            }
        }
        .alert(
            pendingSeed == true ? "기본 데이터로 덮어쓰기" : "기본 데이터 가져오기",
            isPresented: Binding(get: { pendingSeed != nil }, set: { if !$0 { pendingSeed = nil } }),
            presenting: pendingSeed
        ) { replace in
            Button("취소", role: .cancel) {}
            Button(replace ? "덮어쓰기" : "가져오기", role: replace ? .destructive : nil) {
                Task { await viewModel.seed(replaceExisting: replace) }
            }
        } message: { replace in
            Text(replace
                ? "현재 Firestore 의 프로젝트 문서를 모두 지우고, 코드에 내장된 기본 데이터로 다시 채웁니다. 되돌릴 수 없습니다."
                : "코드에 내장된 기본 프로필과 프로젝트를 Firestore 에 넣습니다. 이미 프로젝트가 있으면 아무것도 하지 않습니다.")
        }
    }
}

// MARK: - 오류

private struct AdminErrorView: View {
    let icon: String
    let message: String
    let onRetry: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundStyle(AppTheme.textMuted)
            Text(message)
                .font(AppFonts.sans(13.5))
                .lineHeight(1.7, fontSize: 13.5)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .padding(.top, 14)
            HStack(spacing: 10) {
                AdminButton(label: "다시 시도", icon: "arrow.clockwise", outlined: true, action: onRetry)
                AdminButton(label: "로그아웃", icon: "rectangle.portrait.and.arrow.right", outlined: true, color: AppTheme.textMuted, action: onSignOut)
            }
            .padding(.top, AppTheme.spacingLg)
        }
        .frame(maxWidth: 460)
        .padding(AppTheme.spacingLg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 로그인

@MainActor
final class SignInViewModel: NetworkViewModel {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var busy = false
    @Published private(set) var error: String?

    func signIn() async {
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await AuthSession.shared.signIn(email: email.trimmed, password: password)
            // 로그인에 성공하면 AuthSession.$user 가 화면을 갈아끼운다.
        } catch {
            self.error = AuthErrorMessage.signIn(error)
        }
    }

    func resetPassword() async {
        let address = email.trimmed
        guard !address.isEmpty else {
            error = "먼저 이메일을 입력하세요."
            return
        }
        do {
            try await AuthSession.shared.sendPasswordReset(email: address)
            await setToastMessage("\(address) 로 비밀번호 재설정 메일을 보냈습니다.")
        } catch {
            self.error = "재설정 메일 발송에 실패했습니다: \(error.localizedDescription)"
        }
    }
}

private struct SignInView: View {
    @StateObject private var viewModel = SignInViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("관리자 로그인")
                    .font(AppFonts.serif(22, weight: .heavy))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("등록된 관리자 계정만 콘텐츠를 수정할 수 있습니다.")
                    .font(AppFonts.sans(12.5))
                    .foregroundStyle(AppTheme.textMuted)
                    .padding(.top, 6)
                    .padding(.bottom, AppTheme.spacingLg)

                AdminField(label: "이메일", text: $viewModel.email, keyboard: .emailAddress)
                    .textContentType(.username)
                VStack(alignment: .leading, spacing: 6) {
                    Text("비밀번호")
                        .font(AppFonts.sans(12.5, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                    SecureField("", text: $viewModel.password)
                        .textContentType(.password)
                        .font(AppFonts.sans(14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .paperCard(fill: AppTheme.surface, radius: AppTheme.radiusSm, stroke: AppTheme.border, lineWidth: 1)
                        .onSubmit { Task { await viewModel.signIn() } }
                }

                if let error = viewModel.error {
                    Text(error)
                        .font(AppFonts.sans(12.5))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.top, 12)
                }

                AdminButton(label: "로그인", icon: "arrow.right.circle", busy: viewModel.busy) {
                    Task { await viewModel.signIn() }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppTheme.spacingLg)

                Button("비밀번호 재설정 메일 보내기") {
                    Task { await viewModel.resetPassword() }
                }
                .font(AppFonts.sans(13))
                .foregroundStyle(AppTheme.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
            }
            .padding(AppTheme.spacingXl)
            .frame(maxWidth: 380)
            .paperCard()
            .cardShadow()
            .padding(AppTheme.spacingLg)
            .frame(maxWidth: .infinity)
        }
    }
}
