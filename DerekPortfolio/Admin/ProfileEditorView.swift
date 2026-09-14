//
//  ProfileEditorView.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  프로필 · 경력 · 스킬 편집. Flutter lib/admin/profile_editor.dart 자리.
//

import SwiftUI

/// 편집 중인 스킬 그룹. 리스트를 넣고 빼도 입력 칸이 제 자리를 지키도록 고정 id 를 들고 다닌다.
struct SkillGroupDraft: Identifiable {
    let id = UUID()
    var category: String
    var skillsText: String

    init(category: String = "", skillsText: String = "") {
        self.category = category
        self.skillsText = skillsText
    }

    init(_ group: SkillGroup) {
        self.init(category: group.category, skillsText: listToLines(group.skills))
    }

    var model: SkillGroup {
        SkillGroup(category: category.trimmed, skills: linesToList(skillsText))
    }
}

struct CareerDraft: Identifiable {
    let id = UUID()
    var company = ""
    var period = ""
    var duration = ""
    var role = ""

    init() {}

    init(_ career: CareerHistory) {
        company = career.company
        period = career.period
        duration = career.duration
        role = career.role
    }

    var model: CareerHistory {
        CareerHistory(company: company.trimmed, period: period.trimmed, duration: duration.trimmed, role: role.trimmed)
    }
}

@MainActor
final class ProfileEditorViewModel: NetworkViewModel {
    @Published var name: String
    @Published var title: String
    @Published var experience: String
    @Published var bio: String
    @Published var email: String
    @Published var phone: String
    @Published var github: String
    @Published var notion: String
    @Published var certificate: String
    @Published var skillsText: String
    @Published var direct: [SkillGroupDraft]
    @Published var ai: [SkillGroupDraft]
    @Published var careers: [CareerDraft]
    @Published private(set) var saving = false

    init(initial p: ProfileData) {
        name = p.name
        title = p.title
        experience = p.experience
        bio = p.bio
        email = p.email
        phone = p.phone
        github = p.github ?? ""
        notion = p.notion ?? ""
        certificate = p.certificate
        skillsText = listToLines(p.skills)
        direct = p.directSkillGroups.map(SkillGroupDraft.init)
        ai = p.aiSkillGroups.map(SkillGroupDraft.init)
        careers = p.careers.map(CareerDraft.init)
        super.init()
    }

    private var model: ProfileData {
        ProfileData(
            name: name.trimmed,
            title: title.trimmed,
            experience: experience.trimmed,
            bio: bio,
            email: email.trimmed,
            phone: phone.trimmed,
            github: github.trimmed.isEmpty ? nil : github.trimmed,
            notion: notion.trimmed.isEmpty ? nil : notion.trimmed,
            certificate: certificate.trimmed,
            directSkillGroups: direct.map(\.model),
            aiSkillGroups: ai.map(\.model),
            skills: linesToList(skillsText),
            careers: careers.map(\.model)
        )
    }

    func save() async {
        guard !name.trimmed.isEmpty else {
            await setToastMessage("이름은 비워 둘 수 없습니다.", type: .error)
            return
        }
        saving = true
        defer { saving = false }
        do {
            try await saveProfile(model)
            await setToastMessage("프로필을 저장했습니다.")
        } catch {
            await setToastMessage("저장에 실패했습니다: \(error.localizedDescription)", type: .error)
        }
    }
}

extension Array {
    /// index 항목을 delta 만큼 옮긴다. 범위를 벗어나면 그대로 둔다.
    mutating func move(at index: Int, by delta: Int) {
        let target = index + delta
        guard indices.contains(index), indices.contains(target) else { return }
        insert(remove(at: index), at: target)
    }
}

struct ProfileEditorView: View {
    @StateObject private var viewModel: ProfileEditorViewModel

    init(initial: ProfileData) {
        _viewModel = StateObject(wrappedValue: ProfileEditorViewModel(initial: initial))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.spacingLg) {
                AdminCard(title: "기본 정보", subtitle: "히어로 영역 상단에 노출되는 이름 · 직함 · 소개 문구입니다.") {
                    saveButton
                } content: {
                    AdminField(label: "이름", text: $viewModel.name, required: true)
                    AdminField(label: "직함", text: $viewModel.title)
                    AdminField(label: "경력", text: $viewModel.experience, hint: "예: 10년 이상")
                    AdminField(label: "소개", text: $viewModel.bio, hint: "줄바꿈이 그대로 반영됩니다", lines: 8)
                }

                AdminCard(title: "연락처 & 링크", subtitle: "비워 두면 해당 버튼이 사이트에서 사라집니다.") {
                    AdminField(label: "이메일", text: $viewModel.email, keyboard: .emailAddress)
                    AdminField(label: "연락처", text: $viewModel.phone, keyboard: .phonePad)
                    AdminField(label: "GitHub URL", text: $viewModel.github, keyboard: .URL)
                    AdminField(label: "Notion 경력서 URL", text: $viewModel.notion, keyboard: .URL)
                    AdminField(label: "자격증", text: $viewModel.certificate)
                }

                AdminCard(title: "대표 기술 태그", subtitle: "한 줄에 하나씩 입력합니다. 히어로 하단 요약 태그로 쓰입니다.") {
                    AdminField(label: "기술 태그", text: $viewModel.skillsText, lines: 10)
                }

                groupCard(title: "직접 개발 기술 스택", subtitle: "스킬 섹션의 \"직접 개발\" 탭에 노출됩니다.", list: $viewModel.direct)
                groupCard(title: "AI 활용 기술 스택", subtitle: "스킬 섹션의 \"AI 활용\" 탭에 노출됩니다.", list: $viewModel.ai)
                careerCard

                HStack {
                    Spacer()
                    saveButton
                }
            }
            .padding(AppTheme.spacingLg)
            .padding(.bottom, AppTheme.spacing2xl)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var saveButton: some View {
        AdminButton(label: "프로필 저장", icon: "square.and.arrow.down.fill", busy: viewModel.saving) {
            Task { await viewModel.save() }
        }
    }

    private func groupCard(title: String, subtitle: String, list: Binding<[SkillGroupDraft]>) -> some View {
        AdminCard(title: title, subtitle: subtitle) {
            AdminButton(label: "그룹 추가", icon: "plus", outlined: true) {
                list.wrappedValue.append(SkillGroupDraft())
            }
        } content: {
            if list.wrappedValue.isEmpty {
                Text("아직 그룹이 없습니다.").font(AppFonts.sans(13)).foregroundStyle(AppTheme.textMuted)
            }
            ForEach(Array(list.wrappedValue.enumerated()), id: \.element.id) { index, item in
                AdminListItem(heading: "GROUP \(index + 1)") {
                    moveButtons(index: index, count: list.wrappedValue.count) { list.wrappedValue.move(at: index, by: $0) }
                    AdminIconButton(icon: "trash", label: "삭제", color: AppTheme.accent) {
                        list.wrappedValue.removeAll { $0.id == item.id }
                    }
                } content: {
                    if let binding = binding(for: item.id, in: list) {
                        AdminField(label: "그룹 이름", text: binding.category)
                        AdminField(label: "기술 목록", text: binding.skillsText, hint: "한 줄에 하나씩", lines: 8)
                    }
                }
            }
        }
    }

    private var careerCard: some View {
        AdminCard(title: "경력 사항", subtitle: "위에서부터 최신 순으로 노출됩니다.") {
            AdminButton(label: "경력 추가", icon: "plus", outlined: true) {
                viewModel.careers.insert(CareerDraft(), at: 0)
            }
        } content: {
            if viewModel.careers.isEmpty {
                Text("아직 경력이 없습니다.").font(AppFonts.sans(13)).foregroundStyle(AppTheme.textMuted)
            }
            ForEach(Array(viewModel.careers.enumerated()), id: \.element.id) { index, item in
                AdminListItem(heading: "CAREER \(index + 1)") {
                    moveButtons(index: index, count: viewModel.careers.count) { viewModel.careers.move(at: index, by: $0) }
                    AdminIconButton(icon: "trash", label: "삭제", color: AppTheme.accent) {
                        viewModel.careers.removeAll { $0.id == item.id }
                    }
                } content: {
                    if let binding = binding(for: item.id, in: $viewModel.careers) {
                        AdminField(label: "회사", text: binding.company)
                        AdminField(label: "기간", text: binding.period, hint: "예: 2024.03 - 2026.08")
                        AdminField(label: "재직 기간", text: binding.duration, hint: "예: 2년 6개월")
                        AdminField(label: "역할", text: binding.role)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func moveButtons(index: Int, count: Int, move: @escaping (Int) -> Void) -> some View {
        AdminIconButton(icon: "arrow.up", label: "위로", enabled: index > 0) { move(-1) }
        AdminIconButton(icon: "arrow.down", label: "아래로", enabled: index < count - 1) { move(1) }
    }

    /// id 로 항목을 찾아 바인딩을 만든다.
    ///
    /// 만들 때의 위치를 붙잡지 않고 매번 id 로만 찾는다. 줄을 지우거나 옮긴 직후 남아 있던 입력 칸이
    /// 옛 바인딩을 읽어도 다른 항목의 값을 보이거나 죽지 않고, 마지막으로 알던 값을 돌려준다.
    private func binding<Item: Identifiable>(for id: Item.ID, in list: Binding<[Item]>) -> Binding<Item>? {
        guard let snapshot = list.wrappedValue.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { list.wrappedValue.first(where: { $0.id == id }) ?? snapshot },
            set: { newValue in
                if let current = list.wrappedValue.firstIndex(where: { $0.id == id }) {
                    list.wrappedValue[current] = newValue
                }
            }
        )
    }
}
