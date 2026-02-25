import SwiftUI

/// A ViewModifier that restricts access to views based on user role.
/// If the current user's role is not in the allowed set, shows an "Access Denied" view.
struct RoleGuard: ViewModifier {
    let allowedRoles: Set<UserRole>
    let currentUserRole: UserRole?

    func body(content: Content) -> some View {
        if let role = currentUserRole, allowedRoles.contains(role) {
            content
        } else {
            accessDeniedView
        }
    }

    private var accessDeniedView: some View {
        ContentUnavailableView(
            "Access Denied",
            systemImage: "lock.shield.fill",
            description: Text("You don't have permission to access this area.")
        )
    }
}

extension View {
    func requireRole(_ roles: UserRole..., currentRole: UserRole?) -> some View {
        modifier(RoleGuard(allowedRoles: Set(roles), currentUserRole: currentRole))
    }
}
