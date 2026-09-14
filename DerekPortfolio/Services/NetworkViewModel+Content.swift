//
//  NetworkViewModel+Content.swift
//
//
//  Created by 구보성 on 14/9/26.
//
//  포트폴리오 콘텐츠 읽기/쓰기. Flutter lib/services/content_repository.dart 자리.
//
//  Firestore 컬렉션 구조
//    site/profile          → ProfileData 문서 하나
//    projects/{autoId}     → ProjectData 문서, order 오름차순 정렬
//    admins/{uid}          → 편집 권한이 있는 계정. 문서가 있기만 하면 된다
//

import Foundation

extension NetworkViewModel {
    private static let profilePath = "site/profile"
    private static let projectsCollection = "projects"

    private var projectsQuery: StructuredQuery {
        StructuredQuery(collection: Self.projectsCollection, orderBy: "order")
    }

    // MARK: 읽기

    /// 프로필과 프로젝트를 한 번에 읽어온다.
    /// 어떤 이유로든 실패하면 SiteContent.fallback 을 돌려주며 예외를 던지지 않는다.
    func loadSiteContent() async -> SiteContent {
        await fetchSiteContent().content
    }

    /// loadSiteContent 와 같지만 읽기에 실패했는지도 함께 알려 준다.
    ///
    /// 폴백이 돌아오는 경우는 둘이다. 네트워크 · 권한 문제로 읽지 못했을 때(readFailed = true)와,
    /// 읽기는 됐는데 아직 시드 전이라 문서가 없을 때(readFailed = false). 새로고침 안내가 둘을 가른다.
    func fetchSiteContent() async -> (content: SiteContent, readFailed: Bool) {
        // Firebase 설정이 없으면 기다리지 않고 내장 데이터로 바로 그린다.
        guard FirebaseConfig.isConfigured else { return (.fallback, false) }
        do {
            async let profileRead = getDocument(Self.profilePath)
            async let projectsRead = runQuery(projectsQuery)
            let (profileDocument, projectDocuments) = try await (profileRead, projectsRead)

            let profile = profileDocument?.fields.map(ProfileData.init(fields:)) ?? DefaultContent.profile
            let projects = projectDocuments.map { ProjectData(id: $0.id, fields: $0.fields ?? [:]) }

            // 문서가 하나도 없으면 아직 시드 전이다. 빈 포트폴리오 대신 폴백을 보여준다.
            if profileDocument == nil && projects.isEmpty {
                return (.fallback, false)
            }
            let content = SiteContent(
                profile: profile,
                projects: projects.isEmpty ? DefaultContent.projects : projects,
                fromFirestore: true
            )
            return (content, false)
        } catch {
            Log("콘텐츠 읽기 실패, 내장 데이터로 표시합니다: \(error.localizedDescription)")
            return (.fallback, true)
        }
    }

    /// 관리자 화면 전용. 폴백으로 감추지 않고 실패를 그대로 던진다.
    func loadProfileStrict() async throws -> ProfileData {
        guard let document = try await getDocument(Self.profilePath), let fields = document.fields else {
            return DefaultContent.profile
        }
        return ProfileData(fields: fields)
    }

    /// 관리자 화면 전용. 실패를 그대로 던진다.
    func loadProjectsStrict() async throws -> [ProjectData] {
        try await runQuery(projectsQuery).map { ProjectData(id: $0.id, fields: $0.fields ?? [:]) }
    }

    /// 이 계정이 관리자인지. 문서가 없으면 false 이고, 그 밖의 실패(네트워크·권한)는 던진다.
    /// 실패를 false 로 뭉개면 '연결이 안 됐다' 가 '권한이 없다' 로 둔갑한다.
    func isAdmin(uid: String) async throws -> Bool {
        try await getDocument("admins/\(uid)") != nil
    }

    // MARK: 쓰기 (관리자 인증 필요 — firestore.rules 참고)

    func saveProfile(_ profile: ProfileData) async throws {
        try await setDocument(Self.profilePath, fields: profile.fields)
    }

    /// id 가 없으면 새 문서를 만들고, 있으면 덮어쓴다. 저장된 문서 ID 를 돌려준다.
    func saveProject(_ project: ProjectData) async throws -> String {
        guard let id = project.id else {
            return try await addDocument(collection: Self.projectsCollection, fields: project.fields)
        }
        try await setDocument("\(Self.projectsCollection)/\(id)", fields: project.fields)
        return id
    }

    func deleteProject(id: String) async throws {
        try await deleteDocument("\(Self.projectsCollection)/\(id)")
    }

    /// 목록 순서를 리스트 인덱스대로 다시 매긴다. 아직 저장 안 된 항목은 건너뛴다.
    func saveProjectOrder(_ projects: [ProjectData]) async throws {
        let writes = projects.enumerated().compactMap { index, project -> FirestoreWrite? in
            guard let id = project.id else { return nil }
            return .update("\(Self.projectsCollection)/\(id)", fields: ["order": .integer(Int64(index))])
        }
        try await commit(writes)
    }

    /// 하드코딩 상수를 Firestore 로 밀어 넣는 최초 시드.
    ///
    /// replaceExisting 이 true 면 기존 프로젝트 문서를 모두 지우고 새로 쓴다.
    /// false 면 이미 프로젝트가 있을 때 아무것도 하지 않는다.
    /// 실제로 썼으면 true, 이미 있어서 건너뛰었으면 false.
    @discardableResult
    func seedFromDefaults(replaceExisting: Bool) async throws -> Bool {
        let existing = try await runQuery(
            StructuredQuery(collection: Self.projectsCollection, select: ["__name__"])
        )
        if !existing.isEmpty && !replaceExisting { return false }

        var writes: [FirestoreWrite] = []
        if replaceExisting {
            writes += existing.compactMap { $0.name.map(FirestoreWrite.delete(name:)) }
        }
        writes.append(.set(Self.profilePath, fields: DefaultContent.profile.fields))
        for (index, project) in DefaultContent.projects.enumerated() {
            var ordered = project
            ordered.order = index
            writes.append(.set("\(Self.projectsCollection)/\(FirestoreAutoID.make())", fields: ordered.fields))
        }
        try await commit(writes)
        return true
    }
}
