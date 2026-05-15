import Foundation

struct User: Identifiable, Equatable {
    let id: String
    var username: String
    var email: String
    var isActive: Bool = true
    var photoURL: String? = nil
}
