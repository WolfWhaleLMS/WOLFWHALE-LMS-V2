import SwiftUI

struct CoursesListView: View {
    let viewModel: AppViewModel
    @State private var searchText = ""
    @State private var showJoinSheet = false
    @State private var classCode = ""
    @State private var isEnrolling = false
    @State private var enrollmentSuccess: String?
    @State private var enrollmentError: String?

    private var filteredCourses: [Course] {
        if searchText.isEmpty { return viewModel.courses }
        return viewModel.courses.filter {
            $0.title.localizedStandardContains(searchText) ||
            $0.teacherName.localizedStandardContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("Loading courses")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(filteredCourses) { course in
                                NavigationLink(value: course) {
                                    courseRow(course)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .overlay {
                        if filteredCourses.isEmpty && !searchText.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        } else if viewModel.courses.isEmpty {
                            ContentUnavailableView("No Courses", systemImage: "book.closed", description: Text("Enroll in a course to get started"))
                        }
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Courses")
            .searchable(text: $searchText, prompt: "Search courses")
            .navigationDestination(for: Course.self) { course in
                CourseDetailView(course: course, viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Join Course", systemImage: "plus") {
                        classCode = ""
                        enrollmentSuccess = nil
                        enrollmentError = nil
                        showJoinSheet = true
                    }
                    .accessibilityLabel("Join a course")
                    .accessibilityHint("Double tap to enter a class code and enroll")
                }
            }
            .sheet(isPresented: $showJoinSheet) {
                joinCourseSheet
            }
        }
    }

    private var joinCourseSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.and.pencil.and.ellipsis")
                        .font(.largeTitle)
                        .foregroundStyle(.indigo)
                    Text("Join a Course")
                        .font(.title2.bold())
                    Text("Enter the class code provided by your teacher.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)

                TextField("Class Code", text: $classCode)
                    .textFieldStyle(.plain)
                    .font(.title3.monospaced())
                    .multilineTextAlignment(.center)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.characters)
                    .padding(16)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                if let success = enrollmentSuccess {
                    Label(success, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(.green.opacity(0.1), in: .rect(cornerRadius: 12))
                }

                if let error = enrollmentError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.red)
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(.red.opacity(0.1), in: .rect(cornerRadius: 12))
                }

                Button {
                    enrollWithClassCode()
                } label: {
                    Group {
                        if isEnrolling {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Join")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(classCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEnrolling)

                Spacer()
            }
            .padding(.horizontal)
            .navigationTitle("Join Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showJoinSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func enrollWithClassCode() {
        isEnrolling = true
        enrollmentError = nil
        enrollmentSuccess = nil

        Task {
            do {
                let courseName = try await viewModel.enrollByClassCode(classCode)
                enrollmentSuccess = "Enrolled in \(courseName)!"
                classCode = ""
            } catch let error as EnrollmentError {
                enrollmentError = error.errorDescription
            } catch {
                let message = error.localizedDescription.lowercased()
                if message.contains("network") || message.contains("connection") || message.contains("not connected") {
                    enrollmentError = "Network error. Please check your connection."
                } else {
                    enrollmentError = "Something went wrong. Please try again."
                }
            }
            isEnrolling = false
        }
    }

    private func courseRow(_ course: Course) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.courseColor(course.colorName).gradient)
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: course.iconSystemName)
                        .font(.title2)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(course.title)
                    .font(.headline)
                Text(course.teacherName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    ProgressView(value: course.progress)
                        .tint(Theme.courseColor(course.colorName))
                    Text("\(Int(course.progress * 100))%")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(course.title), taught by \(course.teacherName), \(Int(course.progress * 100)) percent complete")
        .accessibilityHint("Double tap to open course")
    }
}
