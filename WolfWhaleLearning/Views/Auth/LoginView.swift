import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AppViewModel
    @State private var appeared = false
    @State private var showDemoSection = false
    @State private var showForgotPassword = false
    @State private var hapticTrigger = false
    @State private var glowPulse = false
    @State private var loginAudio = LoginAudioService()
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 56)

                logoSection

                Spacer().frame(height: 40)

                loginSection

                Spacer().frame(height: 32)

                dividerSection

                Spacer().frame(height: 28)

                demoSection

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .onAppear {
            withAnimation(.spring(duration: 0.7)) { appeared = true }
            withAnimation(.spring(duration: 0.6).delay(0.3)) { showDemoSection = true }
            loginAudio.startPlaying()
        }
        .onChange(of: viewModel.isAuthenticated) { _, authenticated in
            if authenticated {
                loginAudio.fadeOutAndStop()
            }
        }
        .onDisappear {
            loginAudio.stop()
        }
    }

    private var logoSection: some View {
        VStack(spacing: 14) {
            ZStack {
                // Outer glow layers (stacked for intensity)
                Circle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .blur(radius: 30)
                    .scaleEffect(glowPulse ? 1.15 : 0.95)

                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 130, height: 130)
                    .blur(radius: 20)
                    .scaleEffect(glowPulse ? 1.1 : 0.9)

                Circle()
                    .fill(Color.green.opacity(0.25))
                    .frame(width: 115, height: 115)
                    .blur(radius: 12)
                    .scaleEffect(glowPulse ? 1.05 : 0.95)

                // Logo
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(color: .green.opacity(0.6), radius: 16, y: 0)
                    .shadow(color: .green.opacity(0.3), radius: 30, y: 0)
            }
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }

            Text("WOLF WHALE")
                .font(.system(size: 36, weight: .black, design: .serif))
                .tracking(2)
                .foregroundStyle(.primary)

            Text("LEARNING MANAGEMENT SYSTEM")
                .font(.system(size: 10, weight: .medium, design: .serif))
                .foregroundStyle(.secondary)
                .tracking(3)
        }
    }

    private var loginSection: some View {
        VStack(spacing: 16) {
            Text("Sign In")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .foregroundStyle(.tertiary)
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
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(focusedField == .email ? Color.accentColor.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
                )

                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.tertiary)
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
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(focusedField == .password ? Color.accentColor.opacity(0.5) : Color(.separator).opacity(0.3), lineWidth: 1)
                )
            }

            if let error = viewModel.loginError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
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
                            Image(systemName: "arrow.right")
                                .font(.subheadline.bold())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .clipShape(.rect(cornerRadius: 12))
            .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
            .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isAuthenticated)
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
            .accessibilityHint("Double tap to reset your password")

        }
    }

    private var dividerSection: some View {
        HStack(spacing: 16) {
            Rectangle()
                .fill(Color(.separator).opacity(0.3))
                .frame(height: 1)
            Text("OR TRY A DEMO")
                .font(.system(size: 11, weight: .semibold, design: .serif))
                .foregroundStyle(.secondary)
                .tracking(1.5)
            Rectangle()
                .fill(Color(.separator).opacity(0.3))
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
        case .student: [.indigo, .purple]
        case .teacher: [.pink, .orange]
        case .parent: [.green, .teal]
        case .admin: [.blue, .cyan]
        case .superAdmin: [.indigo, .cyan]
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
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(.clear)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: hapticTrigger)
        .accessibilityLabel("Demo \(role.rawValue)")
        .accessibilityHint("Double tap to sign in as a demo \(role.rawValue.lowercased())")
    }
}
