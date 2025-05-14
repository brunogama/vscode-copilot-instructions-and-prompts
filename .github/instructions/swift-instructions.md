---
applyTo: "**/*.swift"
---

# Swift Coding Standards for GitHub Copilot

## Core Principles

- Follow Swift API Design Guidelines (swift.org/documentation/api-design-guidelines)
- Write clean, readable code that follows Swift idioms and conventions
- Embrace Swift's strong type system and compile-time safety
- Use structured concurrency patterns with async/await and actors
- Prioritize memory safety and performance
- Follow security best practices for sensitive data and user input
- Create maintainable, testable code

## General Swift Coding Standards

### Naming Conventions

- Use camelCase for function, method, and variable names: `getUserProfile()`, `isEnabled`
- Use PascalCase for type names (classes, structs, enums, protocols): `UserProfile`, `NetworkManager`
- Use descriptive, clear names that convey purpose: prefer `userDidTapSubmitButton` over `buttonAction`
- Avoid abbreviations unless universally recognized: use `index` not `idx`
- Boolean properties and functions should read as assertions: `isValid`, `hasContent`
- Name functions according to their side effects: "noun phrases" for functions without side effects (e.g., `distance(to:)`) and "verb phrases" for functions with side effects
- Prioritize clarity at the point of use over brevity
- Use descriptive names that express the role rather than the type

### Code Formatting

- Use 4 spaces for indentation, not tabs
- Keep lines under 100 characters in length
- Use a single space after colons in declarations: `let name: String`
- Include one blank line between methods and up to one blank line between type declarations
- Group related properties and methods together
- Avoid trailing whitespace and ensure files end with a newline

### File Organization

- Place type declarations at the top of the file
- Organize code using MARK comments: `// MARK: - Properties`
- Group extensions by functionality
- Place private helpers at the bottom of the file
- Keep files focused on a single responsibility, typically under 400 lines

### Error Handling

- Use Swift's native error handling with `throws` and `do-catch` blocks
- Create specific error types using enums conforming to `Error`
- Provide meaningful error messages and context
- Avoid force unwrapping with `!` except in tests or when failure is impossible
- Use `guard` statements for early returns when validating preconditions

### Examples

**Good**:

```swift
enum NetworkError: Error {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingFailed
}

func fetchUser(id: String) async throws -> User {
    guard let url = URL(string: "https://api.example.com/users/\(id)") else {
        throw NetworkError.invalidURL
    }

    let (data, response) = try await URLSession.shared.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        throw NetworkError.serverError(statusCode: statusCode)
    }

    do {
        return try JSONDecoder().decode(User.self, from: data)
    } catch {
        throw NetworkError.decodingFailed
    }
}
```

**Bad**:

```swift
func getUsr(_ i: String) -> User? {
    let u = URL(string: "https://api.example.com/users/\(i)")!  // Force unwrap!

    // No error handling
    let d = try! Data(contentsOf: u)  // Synchronous and force try!

    return try? JSONDecoder().decode(User.self, from: d)  // Silently returns nil on failure
}
```

## Swift Concurrency Guidelines

### Async/Await

- Use `async`/`await` for asynchronous operations instead of completion handlers
- Mark functions that perform asynchronous work with `async`
- Use `async throws` for operations that can fail
- Add `await` when calling async functions
- Chain async calls sequentially when dependencies exist

### Tasks and Task Groups

- Use structured tasks to maintain proper parent-child relationships
- Create child tasks with `Task {}` within an async context
- For concurrent operations, use task groups with `withTaskGroup`
- Check for cancellation with `Task.isCancelled` or `try Task.checkCancellation()` in long-running tasks
- Add timeouts to long-running tasks when appropriate
- Remember that parent tasks cannot complete until all child tasks have completed
- Avoid creating unstructured tasks with `Task.init` or `Task.detached` unless specifically needed

### Actor Model

- Use actors to protect shared mutable state from data races
- Mark classes as `actor` when they contain mutable properties accessed from multiple tasks
- Access actor methods and properties with `await`
- Keep actor methods small and focused to avoid unnecessary serialization
- Use `@MainActor` for UI updates or code that must run on the main thread

### Structured Concurrency Patterns

- Ensure child tasks complete before their parent scope ends
- Use `withTaskCancellationHandler` for cleanup when tasks are cancelled
- Prefer `async let` for simple parallel operations with clear dependencies
- Implement proper error handling in concurrent code

### Examples

**Good (Using Modern Concurrency)**:

```swift
actor ImageCache {
    private var cache: [URL: UIImage] = [:]

    func image(for url: URL) -> UIImage? {
        return cache[url]
    }

    func setImage(_ image: UIImage, for url: URL) {
        cache[url] = image
    }
}

class ImageLoader {
    private let cache = ImageCache()

    func loadImage(from url: URL) async throws -> UIImage {
        // Check cache first
        if let cachedImage = await cache.image(for: url) {
            return cachedImage
        }

        // Fetch from network
        let (data, _) = try await URLSession.shared.data(from: url)

        guard let image = UIImage(data: data) else {
            throw ImageError.invalidData
        }

        // Update cache
        await cache.setImage(image, for: url)
        return image
    }

    func loadImages(from urls: [URL]) async throws -> [UIImage] {
        try await withThrowingTaskGroup(of: (URL, UIImage).self) { group in
            for url in urls {
                group.addTask {
                    let image = try await self.loadImage(from: url)
                    return (url, image)
                }
            }

            var images: [UIImage] = []
            for try await (_, image) in group {
                images.append(image)
            }
            return images
        }
    }
}

// Using the ImageLoader in a UI context
class GalleryViewController: UIViewController {
    private let imageLoader = ImageLoader()

    @MainActor
    func displayImages(from urls: [URL]) async {
        do {
            let images = try await imageLoader.loadImages(from: urls)
            // Update UI with images
            imageCollectionView.images = images
            imageCollectionView.reloadData()
        } catch {
            showError(error)
        }
    }
}
```

**Bad (Legacy Approach)**:

```swift
class ImageCache {
    private var cache: [URL: UIImage] = [:]
    private let lock = NSLock()

    func image(for url: URL) -> UIImage? {
        lock.lock()
        defer { lock.unlock() }
        return cache[url]
    }

    func setImage(_ image: UIImage, for url: URL) {
        lock.lock()
        cache[url] = image
        lock.unlock()
    }
}

class ImageLoader {
    private let cache = ImageCache()

    func loadImage(from url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        // Check cache first
        if let cachedImage = cache.image(for: url) {
            completion(.success(cachedImage))
            return
        }

        // Fetch from network
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data, let image = UIImage(data: data) else {
                completion(.failure(ImageError.invalidData))
                return
            }

            // Update cache
            self.cache.setImage(image, for: url)
            completion(.success(image))
        }.resume()
    }

    func loadImages(from urls: [URL], completion: @escaping (Result<[UIImage], Error>) -> Void) {
        let group = DispatchGroup()
        var images: [UIImage] = []
        var errors: [Error] = []

        for url in urls {
            group.enter()
            loadImage(from: url) { result in
                switch result {
                case .success(let image):
                    images.append(image)
                case .failure(let error):
                    errors.append(error)
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            if !errors.isEmpty {
                completion(.failure(errors[0]))
            } else {
                completion(.success(images))
            }
        }
    }
}
```

## Memory Management Best Practices

### Value vs. Reference Types

- Prefer value types (structs, enums) for data models when possible
- Use classes (reference types) when identity or inheritance is needed
- Be mindful that value types are copied when passed around
- Consider using Copy-on-Write for large value types that are frequently passed but rarely modified

### Avoiding Memory Leaks

- Use `weak` references to break retain cycles in delegates and callbacks
- Use `unowned` only when the reference will never be nil during its lifetime
- Be cautious with closures capturing `self` - use `[weak self]` when appropriate
- Check for memory leaks using Instruments during development

### Memory Optimization

- Reuse expensive objects like formatters and date components
- Lazily initialize properties that are expensive to create or not always needed
- Consider using `final` classes when inheritance isn't needed for performance
- For large collections, use lazy sequences and avoid eager operations when possible

### Examples

**Good**:

```swift
protocol ImageDownloaderDelegate: AnyObject {
    func downloader(_ downloader: ImageDownloader, didDownload image: UIImage)
}

class ImageDownloader {
    weak var delegate: ImageDownloaderDelegate?

    func downloadImage(from url: URL) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw ImageError.invalidData
        }
        delegate?.downloader(self, didDownload: image)
    }
}

class ImageViewController: UIViewController, ImageDownloaderDelegate {
    private let downloader = ImageDownloader()

    override func viewDidLoad() {
        super.viewDidLoad()
        downloader.delegate = self
    }

    func loadImage(from url: URL) async {
        do {
            try await downloader.downloadImage(from: url)
        } catch {
            handleError(error)
        }
    }

    func downloader(_ downloader: ImageDownloader, didDownload image: UIImage) {
        imageView.image = image
    }
}
```

**Bad**:

```swift
class ImageDownloader {
    var completionHandler: ((UIImage) -> Void)?

    func downloadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [self] data, _, _ in
            // Strong reference cycle! 'self' is captured strongly in the closure
            guard let data = data, let image = UIImage(data: data) else { return }
            self.completionHandler?(image)
        }.resume()
    }
}

class ImageViewController: UIViewController {
    let downloader = ImageDownloader()

    func loadImage(from url: URL) {
        // Creates a retain cycle since downloader has a strong reference to self
        downloader.completionHandler = { image in
            self.imageView.image = image
        }
        downloader.downloadImage(from: url)
    }
}
```

## Security Best Practices

Security is crucial for Swift applications, especially those handling user data. Following best practices helps protect sensitive information and prevent common vulnerabilities.

### Secure Data Storage

- Never store sensitive data in UserDefaults or plain text files
- Use Keychain Services for storing sensitive information (passwords, tokens)
- Encrypt sensitive data at rest using CryptoKit or Apple's CommonCrypto
- Clear sensitive data from memory after use
- Use FileProtection API to encrypt files on disk

### Input Validation and Sanitization

- Validate all user inputs and external data before processing
- Use bounds checking when accessing arrays and collections
- Sanitize data before using in SQL queries, web views, or URLs
- Use Swift's strong typing to prevent type-related vulnerabilities
- Implement appropriate data validation rules for user inputs

### Network Security

- Always use HTTPS for network communication
- Implement certificate pinning to prevent man-in-the-middle attacks
- Validate server responses before processing
- Don't trust data received from the network without validation
- Implement proper timeout and retry strategies

### Authentication and Authorization

- Use modern authentication methods (OAuth 2.0, Sign in with Apple)
- Support biometric authentication (Face ID/Touch ID) where appropriate
- Implement proper session management
- Use secure password storage with salting and appropriate hashing
- Consider implementing two-factor authentication

### Avoiding Sensitive Data Exposure

- Never log sensitive information, even in debug builds
- Don't include sensitive data in crash reports or analytics
- Use secure debugging practices
- Implement app transport security (ATS) restrictions
- Be careful with clipboard data that might contain sensitive information

### Examples

**Good (Secure Data Handling)**:

```swift
import Security
import CryptoKit

struct SecureDataManager {
    // Keychain access for secure storage
    enum KeychainError: Error {
        case storeFailed(OSStatus)
        case loadFailed(OSStatus)
        case itemNotFound
    }

    static func savePassword(_ password: String, for account: String) throws {
        guard let passwordData = password.data(using: .utf8) else {
            throw KeychainError.storeFailed(errSecParam)
        }

        // Prepare query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Delete existing item if it exists
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    static func loadPassword(for account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let passwordData = item as? Data else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            } else {
                throw KeychainError.loadFailed(status)
            }
        }

        guard let password = String(data: passwordData, encoding: .utf8) else {
            throw KeychainError.loadFailed(errSecDecode)
        }

        return password
    }

    // Secure encryption of sensitive data
    static func encryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try ChaChaPoly.seal(data, using: key)
        return sealedBox.combined
    }

    static func decryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try ChaChaPoly.SealedBox(combined: data)
        return try ChaChaPoly.open(sealedBox, using: key)
    }
}

// Safe URL creation with validation
func createSecureURL(baseURLString: String, path: String, parameters: [String: String]) -> URL? {
    guard let baseURL = URL(string: baseURLString),
          var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
        return nil
    }

    components.path = path

    if !parameters.isEmpty {
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
    }

    return components.url
}
```

**Bad (Insecure Data Handling)**:

```swift
// NEVER DO THIS
class InsecureDataManager {
    // Storing sensitive data in UserDefaults
    static func savePassword(_ password: String, for username: String) {
        UserDefaults.standard.set(password, forKey: "password_\(username)")
    }

    // Loading password from UserDefaults
    static func loadPassword(for username: String) -> String? {
        return UserDefaults.standard.string(forKey: "password_\(username)")
    }

    // Hardcoded encryption key (extremely dangerous)
    static let encryptionKey = "MySecretKey12345"

    // Exposing sensitive data in logs
    static func logUserData(user: User) {
        print("User logged in - Username: \(user.username), Password: \(user.password), Token: \(user.token)")
    }

    // Unsafe URL creation with string concatenation
    static func createURL(for userId: String) -> URL? {
        let urlString = "https://api.example.com/users?id=\(userId)&token=MyAPIToken123"
        return URL(string: urlString)
    }
}
```

### Error Handling

- Use Swift's built-in error handling with `do`/`try`/`catch` rather than optional error parameters
- Design functions to throw errors rather than returning optional values when failures are expected
- Propagate errors naturally through the task hierarchy when using structured concurrency

### Documentation

- Include documentation comments for all public declarations
- Follow the standard documentation format: summary line, blank line, additional details
- Document parameters, return values, and thrown errors when applicable

## SwiftUI Guidelines

For modern Apple platform development, prefer SwiftUI when possible. Follow these guidelines to create maintainable, performant SwiftUI code.

### View Structure and Composition

- Keep views small and focused on a single responsibility
- Break complex views into smaller, reusable components
- Use ViewBuilder and custom container views for repeated patterns
- Follow a declarative programming style
- Use proper view hierarchy for better performance

### State Management

- Use appropriate property wrappers for state:
  - `@State` for local view state
  - `@Binding` for receiving state from a parent
  - `@ObservedObject` for external reference types
  - `@StateObject` for owned reference types
  - `@EnvironmentObject` for dependency injection
- Minimize the scope of state to the views that need it
- Use state management tools (Combine, Redux pattern) for complex apps

### Performance Optimization

- Avoid expensive computations directly in view body
- Use `@ViewBuilder` for conditional content
- Extract complex logic to methods outside the view body
- Apply `Equatable` conformance and use `==` operator where appropriate
- Use `id` parameter on `ForEach` for stable identifiers

### Concurrency in SwiftUI

- Use Swift Concurrency (`async`/`await`) with SwiftUI
- Use `Task` for asynchronous operations in `.onAppear` or button actions
- Properly handle view lifecycle with `.task` modifier
- Use `@MainActor` for properties and methods that update the UI

### Accessibility

- Include appropriate accessibility labels and hints
- Support dynamic type and provide readable font sizing
- Ensure sufficient color contrast
- Test with VoiceOver and other accessibility features
- Implement proper keyboard navigation

### Examples

**Good (Well-Structured SwiftUI)**:

```swift
struct UserProfileView: View {
    @StateObject private var viewModel = UserProfileViewModel()
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection

                if viewModel.isLoading {
                    loadingView
                } else if let user = viewModel.user {
                    userInfoSection(user: user)
                } else if let error = viewModel.error {
                    errorView(error: error)
                }
            }
            .padding()
        }
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                editButton
            }
        }
        .task {
            await viewModel.loadUserProfile()
        }
        .sheet(isPresented: $isEditing) {
            EditProfileView(user: viewModel.user)
        }
    }

    private var headerSection: some View {
        HStack {
            ProfileImageView(imageURL: viewModel.user?.avatarURL)
                .accessibilityLabel("Profile picture")

            VStack(alignment: .leading) {
                Text(viewModel.user?.name ?? "")
                    .font(.title)
                Text(viewModel.user?.email ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var loadingView: some View {
        ProgressView("Loading profile...")
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
    }

    private func userInfoSection(user: User) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            InfoRow(title: "Username", value: user.username)
            InfoRow(title: "Member since", value: user.formattedJoinDate)
            InfoRow(title: "Posts", value: "\(user.postCount)")
            InfoRow(title: "Following", value: "\(user.followingCount)")
        }
    }

    private func errorView(error: Error) -> some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            Text("Failed to load profile")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Try Again") {
                Task {
                    await viewModel.loadUserProfile()
                }
            }
            .buttonStyle(.bordered)
            .padding(.top)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var editButton: some View {
        Button {
            isEditing = true
        } label: {
            Text("Edit")
        }
        .disabled(viewModel.user == nil)
    }
}

// Reusable component
struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
            Spacer()
        }
    }
}

// ViewModel with modern concurrency
class UserProfileViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var error: Error?

    private let userService = UserService()

    @MainActor
    func loadUserProfile() async {
        isLoading = true
        error = nil

        do {
            user = try await userService.getCurrentUser()
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
```

**Bad (Poor SwiftUI Structure)**:

```swift
struct BadUserProfileView: View {
    @State private var user: User?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var isEditing = false

    var body: some View {
        ScrollView {
            // Everything in one massive view
            VStack {
                // No extracted subviews
                if isLoading {
                    ProgressView()
                } else if let user = user {
                    HStack {
                        if let url = user.avatarURL {
                            AsyncImage(url: url) { image in
                                image.resizable()
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray)
                                .frame(width: 50, height: 50)
                        }

                        VStack(alignment: .leading) {
                            Text(user.name)
                            Text(user.email)
                        }
                    }

                    // State directly mixed with presentation
                    HStack {
                        Text("Username")
                        Text(user.username)
                    }

                    HStack {
                        Text("Member since")
                        Text(user.formattedJoinDate)
                    }

                    HStack {
                        Text("Posts")
                        Text("\(user.postCount)")
                    }

                    HStack {
                        Text("Following")
                        Text("\(user.followingCount)")
                    }

                    Button("Edit") {
                        isEditing = true
                    }

                } else if let error = error {
                    Text("Error: \(error.localizedDescription)")
                    Button("Retry") {
                        loadData()
                    }
                }
            }
        }
        .onAppear {
            // Using old-style concurrency in onAppear
            loadData()
        }
    }

    func loadData() {
        isLoading = true
        // Not using async/await or Task
        URLSession.shared.dataTask(with: URL(string: "https://api.example.com/user")!) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    self.error = error
                    return
                }

                if let data = data {
                    do {
                        self.user = try JSONDecoder().decode(User.self, from: data)
                    } catch {
                        self.error = error
                    }
                }
            }
        }.resume()
    }
}
```

## Remember

- Prioritize clarity and readability
- Use structured concurrency with async/await and actors
- Protect shared mutable state
- Handle errors explicitly and gracefully
- Follow security best practices for sensitive data
- Organize code in a logical, maintainable structure
- Test thoroughly for correct behavior and memory management
