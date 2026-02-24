import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AppViewModel
    @State private var appeared = false
    @State private var showDemoSection = false
    @State private var showForgotPassword = false
    @State private var hapticTrigger = false
    @State private var glowPulse = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ZStack {
            AuroraNightSkyBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    logoSection

                    Spacer().frame(height: 12)

                    loginSection

                    Spacer().frame(height: 20)

                    #if DEBUG
                    dividerSection

                    Spacer().frame(height: 16)

                    demoSection
                    #endif

                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(duration: 0.7)) { appeared = true }
            withAnimation(.spring(duration: 0.6).delay(0.3)) { showDemoSection = true }
        }
    }

    private var logoSection: some View {
        VStack(spacing: 4) {
            ZStack {
                // Distant ambient glow — far behind the logo, doesn't overlap it
                Circle()
                    .fill(Theme.brandPurple.opacity(glowPulse ? 0.25 : 0.08))
                    .frame(width: 180, height: 180)
                    .blur(radius: 60)

                // Dark backing so the glass logo pops against lighter colors
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black)
                    .frame(width: 100, height: 100)

                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: Theme.brandPurple.opacity(glowPulse ? 0.6 : 0.25), radius: 20, y: 0)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
            }
            .frame(height: 130)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }

            Text("WOLFWHALE")
                .font(.system(size: 28, weight: .thin, design: .serif))
                .tracking(4)
                .foregroundStyle(.primary)

            Text("LEARNING MANAGEMENT SYSTEM")
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundStyle(.secondary)
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var loginSection: some View {
        VStack(spacing: 16) {
            Text("Sign In")
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    TextField("School Email", text: $viewModel.email)
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
                .padding(14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(focusedField == .email ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                )

                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 20)
                        .accessibilityHidden(true)
                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { focusedField = nil; viewModel.login() }
                        .accessibilityLabel("Password")
                        .accessibilityHint("Enter your password to sign in")
                }
                .padding(14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(focusedField == .password ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            if let error = viewModel.loginError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .symbolEffect(.wiggle, options: .repeat(2))
                    Text(error)
                        .font(.caption)
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
                        HStack(spacing: 8) {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Image(systemName: "arrow.right")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .symbolEffect(.wiggle.right, options: .repeat(.periodic(delay: 2)))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.plain)
            .background(
                LinearGradient(
                    colors: [Theme.brandBlue, Theme.brandPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: .rect(cornerRadius: 12)
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
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
            .retroSound(.tap, trigger: hapticTrigger)
            .accessibilityHint("Double tap to reset your password")

        }
        .padding(20)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    private var dividerSection: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(height: 1)
            Text("OR TRY A DEMO")
                .font(.system(size: 11, weight: .semibold, design: .serif))
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
}

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
                        .font(.system(size: 20))
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
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .retroSound(.coin, trigger: hapticTrigger)
        .accessibilityLabel("Demo \(role.rawValue)")
        .accessibilityHint("Double tap to sign in as a demo \(role.rawValue.lowercased())")
    }
}
