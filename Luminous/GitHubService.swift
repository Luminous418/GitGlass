import Foundation
import Security

struct Repo: Decodable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let language: String?
    let htmlURL: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case description, language
        case htmlURL = "html_url"
        case updatedAt = "updated_at"
    }
}

struct CommitItem: Decodable, Identifiable {
    let sha: String
    let message: String
    let authorName: String
    let date: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case sha, commit
    }

    enum CommitKeys: String, CodingKey {
        case message, author, url
    }

    enum AuthorKeys: String, CodingKey {
        case name, date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sha = try container.decode(String.self, forKey: .sha)
        let commit = try container.nestedContainer(keyedBy: CommitKeys.self, forKey: .commit)
        message = try commit.decode(String.self, forKey: .message)
        htmlURL = try commit.decode(String.self, forKey: .url)
        let author = try commit.nestedContainer(keyedBy: AuthorKeys.self, forKey: .author)
        authorName = try author.decode(String.self, forKey: .name)
        date = try author.decode(String.self, forKey: .date)
    }

    var id: String { sha }
}

struct GitHubService {
    static let shared = GitHubService()

    private let base = URL(string: "https://api.github.com")!
    private var token: String { GitHubAuth.token }

    var hasToken: Bool { !token.isEmpty }

    private func request(_ path: String, query: [URLQueryItem] = []) -> URLRequest {
        var url = base.appending(path: path)
        if !query.isEmpty {
            url.append(queryItems: query)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        return request
    }

    func fetchRepos() async throws -> [Repo] {
        let request = request("/user/repos", query: [
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "per_page", value: "10")
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode([Repo].self, from: data)
    }

    func fetchCommits(for repo: Repo, perPage: Int = 5) async throws -> [CommitItem] {
        let request = request("/repos/\(repo.fullName)/commits", query: [
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try JSONDecoder().decode([CommitItem].self, from: data)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300:
            return
        case 401:
            throw GitHubError.unauthorized
        case 403:
            throw GitHubError.rateLimited
        default:
            throw GitHubError.other(http.statusCode)
        }
    }
}

enum GitHubError: LocalizedError {
    case unauthorized
    case rateLimited
    case other(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Token de GitHub no válido o sin permisos."
        case .rateLimited:
            return "Límite de peticiones de GitHub alcanzado."
        case .other(let code):
            return "Error de GitHub (código \(code))."
        }
    }
}

struct KeychainHelper {
    static let shared = KeychainHelper()

    private let service = "com.luminous.Luminous"

    func save(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let updateQuery: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, updateQuery as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum GitHubAuth {
    private static let key = "githubPat"

    static var token: String {
        get { KeychainHelper.shared.read(key) ?? "" }
        set {
            if newValue.isEmpty {
                KeychainHelper.shared.delete(key)
            } else {
                KeychainHelper.shared.save(newValue, for: key)
            }
        }
    }
}