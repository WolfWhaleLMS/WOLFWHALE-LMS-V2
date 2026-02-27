import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false
    #if DEBUG
    @State private var showDemoSection = false
    #endif
    @State private var showForgotPassword = false
    @State private var hapticTrigger = false
    @State private var glowPulse = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                logoSection

                Spacer().frame(height: 16)

                loginSection

                #if DEBUG
                Spacer().frame(height: 24)

                dividerSection

                Spacer().frame(height: 20)

                demoSection
                #endif

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background { HolographicBackground() }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(duration: 0.7)) { appeared = true }
            #if DEBUG
            withAnimation(.spring(duration: 0.6).delay(0.3)) { showDemoSection = true }
            #endif
        }
    }

    private var logoSection: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Theme.brandPurple.opacity(glowPulse ? 0.45 : 0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 75)

                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(.systemBackground))
                    .frame(width: 160, height: 160)

                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 160, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 32))
                    .shadow(color: Theme.brandPurple.opacity(glowPulse ? 0.6 : 0.25), radius: 20, y: 0)
            }
            .frame(height: 180)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }

            Text("WOLFWHALE")
                .font(.largeTitle.weight(.thin))
                .tracking(4)
                .foregroundStyle(.primary)

            Text("LEARNING MANAGEMENT SYSTEM")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var loginSection: some View {
        VStack(spacing: 12) {
            Text("Sign In")
                .font(.footnote.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 16)
                        .accessibilityHidden(true)
                    TextField("School Email", text: $viewModel.email)
                        .font(.footnote)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .accessibilityLabel("Email address")
                        .accessibilityHint("Enter your school email to sign in")
                }
                .padding(10)
                .compatGlassEffect(in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(focusedField == .email ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                )

                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 16)
                        .accessibilityHidden(true)
                    SecureField("Password", text: $viewModel.password)
                        .font(.footnote)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { focusedField = nil; viewModel.login() }
                        .accessibilityLabel("Password")
                        .accessibilityHint("Enter your password to sign in")
                }
                .padding(10)
                .compatGlassEffect(in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(focusedField == .password ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            if let error = viewModel.loginError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .symbolEffect(.bounce, options: .repeat(2))
                    Text(error)
                        .font(.caption2)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                focusedField = nil
                viewModel.login()
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        HStack(spacing: 6) {
                            Text("Sign In")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Image(systemName: "arrow.right")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .compatBouncePeriodic(delay: 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
            .buttonStyle(.plain)
            .background(
                LinearGradient(
                    colors: [Theme.brandBlue, Theme.brandPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: .rect(cornerRadius: 10)
            )
            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty || viewModel.isLoginLockedOut)
            .opacity(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty || viewModel.isLoginLockedOut ? 0.75 : 1.0)
            .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isAuthenticated)
            .retroSound(.confirm, trigger: viewModel.isAuthenticated)
            .accessibilityLabel(viewModel.isLoading ? "Signing in" : "Sign In")
            .accessibilityHint("Double tap to sign in with your email and password")

            Button {
                hapticTrigger.toggle()
                showForgotPassword = true
            } label: {
                Text("Forgot Password?")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .retroSound(.tap, trigger: hapticTrigger)
            .accessibilityHint("Double tap to reset your password")

        }
        .padding(14)
        .compatGlassEffectIdentity(in: .rect(cornerRadius: 18))
    }

    #if DEBUG
    private var dividerSection: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
            Text("OR TRY A DEMO")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(1.5)
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
        }
    }

    private var demoSection: some View {
        VStack(spacing: 12) {
            Text("Explore the platform with a demo account")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(UserRole.allCases.filter { $0 != .superAdmin }) { role in
                    DemoRoleButton(role: role) {
                        viewModel.loginAsDemo(role: role)
                    }
                }
            }
        }
        .opacity(showDemoSection ? 1 : 0)
        .offset(y: showDemoSection ? 0 : 16)
    }
    #endif
}

#if DEBUG
struct DemoRoleButton: View {
    let role: UserRole
    let action: () -> Void
    @State private var hapticTrigger = false

    private var roleDescription: String {
        switch role {
        case .student: "View courses & grades"
        case .teacher: "Manage classes"
        case .parent: "Track progress"
        case .admin: "School dashboard"
        case .superAdmin: "System console"
        }
    }

    private var roleGradient: [Color] {
        switch role {
        case .student: [Theme.brandPurple, .purple]
        case .teacher: [.orange, .yellow]
        case .parent: [.green, .teal]
        case .admin: [Theme.brandBlue, .cyan]
        case .superAdmin: [Theme.brandPurple, Theme.brandBlue]
        }
    }

    var body: some View {
        Button {
            hapticTrigger.toggle()
            action()
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: roleGradient.map { $0.opacity(0.15) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: role.iconName)
                        .font(.headline)
                        .foregroundStyle(
                            LinearGradient(
                                colors: roleGradient,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 2) {
                    Text(role.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                    Text(roleDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .compatGlassEffect(in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .retroSound(.coin, trigger: hapticTrigger)
        .accessibilityLabel("Demo \(role.rawValue)")
        .accessibilityHint("Double tap to sign in as a demo \(role.rawValue.lowercased())")
    }
}
#endif
