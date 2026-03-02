# ESNetwork

[![ESNetwork CI](https://github.com/YunusEmreSimseek/ESNetwork/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/YunusEmreSimseek/ESNetwork/actions/workflows/ci.yml)

ESNetwork is a modern, generic, and protocol-oriented network abstraction layer for Swift applications, designed with `async/await` for clean and efficient asynchronous operations. It provides a robust and flexible foundation for handling network requests, responses, authentication, and error management across various projects.

## Features

*   **`async/await` Support:** Built entirely on Swift's modern concurrency model for clear, readable asynchronous code.
*   **Protocol-Oriented Design:** Easily extensible and customizable through protocols like `Endpoint`, `NetworkService`, `AuthProvider`, and `NetworkInterceptor`.
*   **Generic Request Handling:** Supports decoding any `Decodable` type directly from network responses.
*   **Customizable Endpoint Definitions:** Define your API endpoints with precise control over base URL, path, HTTP method, and task (plain, with body, with query parameters).
*   **Pluggable Authentication:** Integrate token-based authentication (e.g., Bearer tokens) with automatic token refreshing via the `AuthProvider` protocol.
*   **Request/Response Interception:** Modify requests before they are sent and process responses before they are decoded using `NetworkInterceptor`s.
*   **Comprehensive Error Handling:** Utilizes a custom `NetworkError` enum to provide detailed and localized error descriptions, including transport errors, HTTP errors, decoding failures, and authentication issues.
*   **URLSession Integration:** Leverages Apple's native `URLSession` for reliable and efficient networking, with no third-party network client dependencies.

## Requirements

*   iOS 15.0+
*   macOS 12.0+
*   Swift 6.0+

## Installation

You can add ESNetwork to your project using Swift Package Manager.

1.  In Xcode, open your project.
2.  Navigate to `File` > `Add Packages...`.
3.  Enter the repository URL: `https://github.com/YunusEmreSimseek/ESNetwork.git` (Replace with your actual repository URL).
4.  Choose the desired version or branch.

Alternatively, you can add it to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/YunusEmreSimseek/ESNetwork.git", from: "1.0.0") // Replace with your actual repository URL
]
```

## Usage

### 1. Defining an Endpoint

Conform to the `Endpoint` protocol to define your API routes.

```swift
import Foundation
import ESNetwork

enum MyAPIEndpoint: Endpoint {
    var baseURL: String { "https://api.example.com" }

    case getUsers
    case createUser(name: String, email: String)
    case getUser(id: Int)
    case searchUsers(query: String, page: Int)

    var path: String {
        switch self {
        case .getUsers, .createUser:
            return "/users"
        case .getUser(let id):
            return "/users/\(id)"
        case .searchUsers:
            return "/users/search"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getUsers, .getUser, .searchUsers:
            return .get
        case .createUser:
            return .post
        }
    }

    var task: HTTPTask {
        switch self {
        case .getUsers, .getUser:
            return .requestPlain
        case .createUser(let name, let email):
            // Assuming User is an Encodable struct
            struct User: Encodable { let name: String; let email: String }
            return .requestWithBody(User(name: name, email: email))
        case .searchUsers(let query, let page):
            return .requestWithQueryParameters([
                "q": query,
                "page": String(page)
            ])
        }
    }

    // Optional: Customize timeout for specific endpoints
    var timeoutInterval: TimeInterval? {
        switch self {
        case .getUsers:
            return 30.0
        default:
            return nil
        }
    }
}
```

### 2. Defining a Decodable Model

```swift
struct User: Decodable, Equatable {
    let id: Int
    let name: String
    let email: String
}
```

### 3. Making a Request

Initialize `NetworkManager` and use its `request` methods.

```swift
import Foundation
import ESNetwork

// MARK: - Basic Request Example

func fetchUsers() async {
    let networkManager = NetworkManager() // Use default session and decoder

    do {
        let users = try await networkManager.request(MyAPIEndpoint.getUsers, responseType: [User].self)
        print("Fetched users: \(users)")
    } catch {
        print("Failed to fetch users: \(error.localizedDescription)")
    }
}

// MARK: - Request with Body Example

func createUser(name: String, email: String) async {
    let networkManager = NetworkManager()
    do {
        // For requests without an expected return type (e.g., 204 No Content)
        try await networkManager.request(MyAPIEndpoint.createUser(name: name, email: email))
        print("User created successfully!")
    } catch {
        print("Failed to create user: \(error.localizedDescription)")
    }
}

// MARK: - Request with Query Parameters Example

func searchUsers(query: String, page: Int) async {
    let networkManager = NetworkManager()
    do {
        let searchResults = try await networkManager.request(MyAPIEndpoint.searchUsers(query: query, page: page), responseType: [User].self)
        print("Search results for '\(query)': \(searchResults)")
    } catch {
        print("Failed to search users: \(error.localizedDescription)")
    }
}
```

### 4. Authentication (Using `AuthProvider`)

Implement the `AuthProvider` protocol to handle access token retrieval and refreshing.

```swift
import Foundation
import ESNetwork

class MyAuthProvider: AuthProvider {
    private var currentAccessToken: String? = "initial_valid_token" // Simulate a stored token
    private var isRefreshing = false

    func getAccessToken() async throws -> String? {
        // In a real app, you would retrieve this from Keychain or a secure store
        return currentAccessToken
    }

    func refreshToken() async throws -> String? {
        guard !isRefreshing else {
            // Wait for existing refresh to complete
            // (You might use a TaskGroup or continuation here for a more robust solution)
            try await Task.sleep(nanoseconds: 1 * 1_000_000_000) // Simulate delay
            return currentAccessToken // Return the newly refreshed token if available
        }

        isRefreshing = true
        print("Refreshing token...")
        // Simulate an API call to refresh the token
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // Simulate network call

        // On success
        let newToken = "new_token_\(UUID().uuidString)"
        self.currentAccessToken = newToken
        isRefreshing = false
        print("Token refreshed: \(newToken)")
        return newToken

        // On failure (e.g., refresh token expired)
        // self.currentAccessToken = nil
        // isRefreshing = false
        // throw NetworkError.unauthorized // Or a more specific AuthError
    }
}

// Using NetworkManager with AuthProvider
func performAuthenticatedRequest() async {
    let authProvider = MyAuthProvider()
    let networkManager = NetworkManager(authProvider: authProvider)

    do {
        let users = try await networkManager.request(MyAPIEndpoint.getUsers, responseType: [User].self)
        print("Authenticated users: \(users)")
    } catch {
        print("Authenticated request failed: \(error.localizedDescription)")
    }
}
```

### 5. Intercepting Requests and Responses (Using `NetworkInterceptor`)

Create custom interceptors to modify requests or process responses globally.

```swift
import Foundation
import ESNetwork

class LoggingInterceptor: NetworkInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        print("--> Request: \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "")")
        return request
    }

    func process(_ response: HTTPURLResponse, data: Data) async throws {
        print("<-- Response: \(response.statusCode) for \(response.url?.absoluteString ?? "")")
        if let json = String(data: data, encoding: .utf8) {
            print("Response Body: \(json)")
        }
    }
}

class HeaderInterceptor: NetworkInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        var mutableRequest = request
        mutableRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        mutableRequest.setValue("iOS_App/1.0", forHTTPHeaderField: "User-Agent")
        return mutableRequest
    }
}

// Using NetworkManager with Interceptors
func performInterceptedRequest() async {
    let networkManager = NetworkManager(interceptors: [LoggingInterceptor(), HeaderInterceptor()])

    do {
        let users = try await networkManager.request(MyAPIEndpoint.getUsers, responseType: [User].self)
        print("Intercepted request completed. Fetched users: \(users.count)")
    } catch {
        print("Intercepted request failed: \(error.localizedDescription)")
    }
}
```

### Error Handling

All network-related errors are encapsulated within the `NetworkError` enum. You can `catch` these errors to provide specific feedback to your users.

```swift
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case encodingFailed(Error?)
    case transportError(Error)
    case timeout
    case noInternetConnection
    case requestCancelled
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int, data: Data?)
    case decodingFailed(Error)
    case unknown(String)

    // errorDescription provides localized messages
    // isRetryable and isRecoverable properties help with UI/logic decisions
}
```

## Contributing

Contributions are welcome! Please feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License.
