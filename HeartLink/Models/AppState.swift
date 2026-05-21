import Foundation

enum AuthenticationState: Equatable {
    case checking
    case signedOut
    case signedIn(UserProfile)
}

enum Loadable<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

