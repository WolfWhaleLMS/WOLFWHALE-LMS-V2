import Foundation

struct MockDataService {
    static let shared = MockDataService()

    func sampleUser(role: UserRole) -> User {
        switch role {
        case .student:
            User(id: UUID(), firstName: "Alex", lastName: "Rivera", email: "alex@wolfwhale.edu", role: .student, avatarSystemName: "person.crop.circle.fill", xp: 2350, level: 5, coins: 180, streak: 12, joinDate: Calendar.current.date(byAdding: .month, value: -3, to: Date())!, schoolId: "school_001", userSlotsTotal: 0, userSlotsUsed: 0)
        case .teacher:
            User(id: UUID(), firstName: "Dr. Sarah", lastName: "Chen", email: "chen@wolfwhale.edu", role: .teacher, avatarSystemName: "person.crop.circle.fill", xp: 0, level: 0, coins: 0, streak: 0, joinDate: Calendar.current.date(byAdding: .year, value: -2, to: Date())!, schoolId: "school_001", userSlotsTotal: 0, userSlotsUsed: 0)
        case .parent:
            User(id: UUID(), firstName: "Maria", lastName: "Rivera", email: "maria@email.com", role: .parent, avatarSystemName: "person.crop.circle.fill", xp: 0, level: 0, coins: 0, streak: 0, joinDate: Calendar.current.date(byAdding: .month, value: -3, to: Date())!, schoolId: "school_001", userSlotsTotal: 0, userSlotsUsed: 0)
        case .admin:
            User(id: UUID(), firstName: "James", lastName: "Wilson", email: "jwilson@wolfwhale.edu", role: .admin, avatarSystemName: "person.crop.circle.fill", xp: 0, level: 0, coins: 0, streak: 0, joinDate: Calendar.current.date(byAdding: .year, value: -5, to: Date())!, schoolId: "school_001", userSlotsTotal: 50, userSlotsUsed: 9)
        }
    }

    func sampleCourses() -> [Course] {
        let mathId = UUID()
        let scienceId = UUID()
        let historyId = UUID()
        let englishId = UUID()

        return [
            Course(id: mathId, title: "Algebra II", description: "Advanced algebraic concepts including polynomials, quadratics, and functions.", teacherName: "Dr. Sarah Chen", iconSystemName: "function", colorName: "blue", modules: makeMathModules(), enrolledStudentCount: 28, progress: 0.65, classCode: "MATH-2024"),
            Course(id: scienceId, title: "AP Biology", description: "College-level biology covering cellular processes, genetics, and ecology.", teacherName: "Mr. David Park", iconSystemName: "leaf.fill", colorName: "green", modules: makeScienceModules(), enrolledStudentCount: 24, progress: 0.42, classCode: "BIO-2024"),
            Course(id: historyId, title: "World History", description: "Comprehensive survey of world civilizations from ancient to modern times.", teacherName: "Ms. Emily Torres", iconSystemName: "globe.americas.fill", colorName: "orange", modules: makeHistoryModules(), enrolledStudentCount: 32, progress: 0.78, classCode: "HIST-2024"),
            Course(id: englishId, title: "English Literature", description: "Critical analysis of classic and contemporary literary works.", teacherName: "Mrs. Lisa Johnson", iconSystemName: "text.book.closed.fill", colorName: "purple", modules: makeEnglishModules(), enrolledStudentCount: 26, progress: 0.55, classCode: "ENG-2024"),
        ]
    }

    func sampleAssignments() -> [Assignment] {
        let cal = Calendar.current
        return [
            Assignment(id: UUID(), title: "Quadratic Functions Problem Set", courseId: UUID(), courseName: "Algebra II", instructions: "Solve problems 1-20 from Chapter 5. Show all work.", dueDate: cal.date(byAdding: .day, value: 2, to: Date())!, points: 100, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 50),
            Assignment(id: UUID(), title: "Cell Division Lab Report", courseId: UUID(), courseName: "AP Biology", instructions: "Write a complete lab report on the mitosis experiment. Include hypothesis, methods, results, and conclusion.", dueDate: cal.date(byAdding: .day, value: 5, to: Date())!, points: 150, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 75),
            Assignment(id: UUID(), title: "Renaissance Essay", courseId: UUID(), courseName: "World History", instructions: "Write a 1000-word essay on the impact of the Renaissance on European society.", dueDate: cal.date(byAdding: .day, value: -1, to: Date())!, points: 100, isSubmitted: true, submission: "The Renaissance was a period of cultural rebirth...", grade: 92, feedback: "Excellent analysis. Strong thesis.", xpReward: 50),
            Assignment(id: UUID(), title: "Poetry Analysis", courseId: UUID(), courseName: "English Literature", instructions: "Analyze the use of imagery in Robert Frost's 'The Road Not Taken'.", dueDate: cal.date(byAdding: .day, value: 7, to: Date())!, points: 75, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 40),
        ]
    }

    func sampleQuizzes() -> [Quiz] {
        let cal = Calendar.current
        return [
            Quiz(id: UUID(), title: "Chapter 5: Quadratics", courseId: UUID(), courseName: "Algebra II", questions: makeQuizQuestions(), timeLimit: 30, dueDate: cal.date(byAdding: .day, value: 3, to: Date())!, isCompleted: false, score: nil, xpReward: 100),
            Quiz(id: UUID(), title: "Cellular Respiration", courseId: UUID(), courseName: "AP Biology", questions: makeQuizQuestions(), timeLimit: 25, dueDate: cal.date(byAdding: .day, value: 1, to: Date())!, isCompleted: true, score: 88, xpReward: 100),
            Quiz(id: UUID(), title: "Ancient Civilizations", courseId: UUID(), courseName: "World History", questions: makeQuizQuestions(), timeLimit: 20, dueDate: cal.date(byAdding: .day, value: -3, to: Date())!, isCompleted: true, score: 95, xpReward: 100),
        ]
    }

    func sampleGrades() -> [GradeEntry] {
        [
            GradeEntry(id: UUID(), courseId: UUID(), courseName: "Algebra II", courseIcon: "function", courseColor: "blue", letterGrade: "A-", numericGrade: 91.5, assignmentGrades: [
                AssignmentGrade(id: UUID(), title: "Homework 1", score: 95, maxScore: 100, date: Date().addingTimeInterval(-86400 * 14), type: "Homework"),
                AssignmentGrade(id: UUID(), title: "Quiz 1", score: 88, maxScore: 100, date: Date().addingTimeInterval(-86400 * 7), type: "Quiz"),
                AssignmentGrade(id: UUID(), title: "Midterm", score: 92, maxScore: 100, date: Date().addingTimeInterval(-86400 * 3), type: "Exam"),
            ]),
            GradeEntry(id: UUID(), courseId: UUID(), courseName: "AP Biology", courseIcon: "leaf.fill", courseColor: "green", letterGrade: "B+", numericGrade: 87.2, assignmentGrades: [
                AssignmentGrade(id: UUID(), title: "Lab Report 1", score: 85, maxScore: 100, date: Date().addingTimeInterval(-86400 * 10), type: "Lab"),
                AssignmentGrade(id: UUID(), title: "Chapter Test", score: 89, maxScore: 100, date: Date().addingTimeInterval(-86400 * 5), type: "Exam"),
            ]),
            GradeEntry(id: UUID(), courseId: UUID(), courseName: "World History", courseIcon: "globe.americas.fill", courseColor: "orange", letterGrade: "A", numericGrade: 95.0, assignmentGrades: [
                AssignmentGrade(id: UUID(), title: "Essay 1", score: 92, maxScore: 100, date: Date().addingTimeInterval(-86400 * 12), type: "Essay"),
                AssignmentGrade(id: UUID(), title: "Quiz 2", score: 98, maxScore: 100, date: Date().addingTimeInterval(-86400 * 4), type: "Quiz"),
            ]),
            GradeEntry(id: UUID(), courseId: UUID(), courseName: "English Literature", courseIcon: "text.book.closed.fill", courseColor: "purple", letterGrade: "A-", numericGrade: 90.8, assignmentGrades: [
                AssignmentGrade(id: UUID(), title: "Poetry Analysis", score: 91, maxScore: 100, date: Date().addingTimeInterval(-86400 * 8), type: "Essay"),
            ]),
        ]
    }

    func sampleAttendance() -> [AttendanceRecord] {
        let cal = Calendar.current
        return (0..<14).map { dayOffset in
            let date = cal.date(byAdding: .day, value: -dayOffset, to: Date())!
            let statuses: [AttendanceStatus] = [.present, .present, .present, .present, .tardy, .present, .present, .absent, .present, .present, .present, .present, .excused, .present]
            return AttendanceRecord(id: UUID(), date: date, status: statuses[dayOffset], courseName: "All Classes", studentName: nil)
        }
    }

    func sampleAchievements() -> [Achievement] {
        [
            Achievement(id: UUID(), title: "First Steps", description: "Complete your first lesson", iconSystemName: "star.fill", isUnlocked: true, unlockedDate: Date().addingTimeInterval(-86400 * 30), xpReward: 50, rarity: .common),
            Achievement(id: UUID(), title: "Bookworm", description: "Complete 10 reading lessons", iconSystemName: "book.fill", isUnlocked: true, unlockedDate: Date().addingTimeInterval(-86400 * 14), xpReward: 100, rarity: .rare),
            Achievement(id: UUID(), title: "Quiz Master", description: "Score 100% on 5 quizzes", iconSystemName: "checkmark.seal.fill", isUnlocked: false, unlockedDate: nil, xpReward: 200, rarity: .epic),
            Achievement(id: UUID(), title: "Streak Legend", description: "Maintain a 30-day streak", iconSystemName: "flame.fill", isUnlocked: false, unlockedDate: nil, xpReward: 500, rarity: .legendary),
            Achievement(id: UUID(), title: "Social Butterfly", description: "Join 3 study groups", iconSystemName: "person.3.fill", isUnlocked: true, unlockedDate: Date().addingTimeInterval(-86400 * 7), xpReward: 75, rarity: .common),
            Achievement(id: UUID(), title: "Night Owl", description: "Study after 10 PM for 5 days", iconSystemName: "moon.stars.fill", isUnlocked: false, unlockedDate: nil, xpReward: 150, rarity: .rare),
        ]
    }

    func sampleLeaderboard() -> [LeaderboardEntry] {
        [
            LeaderboardEntry(id: UUID(), userName: "Alex Rivera", xp: 2350, level: 5, rank: 1, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Jordan Kim", xp: 2180, level: 5, rank: 2, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Sam Patel", xp: 1950, level: 4, rank: 3, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Taylor Brooks", xp: 1820, level: 4, rank: 4, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Casey Nguyen", xp: 1650, level: 4, rank: 5, avatarSystemName: "person.crop.circle.fill"),
        ]
    }

    func sampleConversations() -> [Conversation] {
        let cal = Calendar.current
        let now = Date()
        return [
            Conversation(id: UUID(), participantNames: ["Dr. Sarah Chen"], title: "Dr. Sarah Chen", lastMessage: "Don't forget the homework is due Friday!", lastMessageDate: cal.date(byAdding: .hour, value: -2, to: now) ?? now, unreadCount: 1, messages: [
                ChatMessage(id: UUID(), senderName: "Dr. Sarah Chen", content: "Hi Alex, how's the assignment going?", timestamp: cal.date(byAdding: .hour, value: -5, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "Going well! Almost done with the problem set.", timestamp: cal.date(byAdding: .hour, value: -4, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Dr. Sarah Chen", content: "Don't forget the homework is due Friday!", timestamp: cal.date(byAdding: .hour, value: -2, to: now) ?? now, isFromCurrentUser: false),
            ], avatarSystemName: "person.crop.circle.fill"),
            Conversation(id: UUID(), participantNames: ["Study Group"], title: "Bio Study Group", lastMessage: "Can someone explain mitosis?", lastMessageDate: cal.date(byAdding: .hour, value: -6, to: now) ?? now, unreadCount: 3, messages: [
                ChatMessage(id: UUID(), senderName: "Jordan Kim", content: "Hey everyone, studying for the bio test tomorrow", timestamp: cal.date(byAdding: .hour, value: -8, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Sam Patel", content: "Can someone explain mitosis?", timestamp: cal.date(byAdding: .hour, value: -6, to: now) ?? now, isFromCurrentUser: false),
            ], avatarSystemName: "person.3.fill"),
        ]
    }

    func sampleAnnouncements() -> [Announcement] {
        [
            Announcement(id: UUID(), title: "Spring Break Schedule", content: "Spring break will be from March 15-22. No classes during this period. Enjoy your break!", authorName: "James Wilson", date: Date().addingTimeInterval(-86400), isPinned: true),
            Announcement(id: UUID(), title: "Science Fair Registration", content: "Registration for the annual science fair is now open. Submit your project proposals by March 10.", authorName: "Mr. David Park", date: Date().addingTimeInterval(-86400 * 3), isPinned: false),
            Announcement(id: UUID(), title: "Parent-Teacher Conference", content: "Parent-teacher conferences will be held on March 5-6. Sign up through the school portal.", authorName: "James Wilson", date: Date().addingTimeInterval(-86400 * 5), isPinned: false),
        ]
    }

    func sampleChildren() -> [ChildInfo] {
        [
            ChildInfo(id: UUID(), name: "Alex Rivera", grade: "10th Grade", avatarSystemName: "person.crop.circle.fill", gpa: 3.7, attendanceRate: 0.96, courses: sampleGrades(), recentAssignments: Array(sampleAssignments().prefix(2))),
        ]
    }

    func sampleSchoolMetrics() -> SchoolMetrics {
        SchoolMetrics(totalStudents: 1247, totalTeachers: 68, totalCourses: 142, averageAttendance: 0.94, averageGPA: 3.2, activeUsers: 1089)
    }

    private func makeMathModules() -> [Module] {
        [
            Module(id: UUID(), title: "Linear Equations Review", lessons: [
                Lesson(id: UUID(), title: "Slope-Intercept Form", content: "Review of y = mx + b and graphing linear equations. The slope-intercept form is one of the most common ways to express a linear equation...", duration: 15, isCompleted: true, type: .reading, xpReward: 25),
                Lesson(id: UUID(), title: "Systems of Equations", content: "Methods for solving systems: substitution, elimination, and graphing.", duration: 20, isCompleted: true, type: .reading, xpReward: 25),
            ], orderIndex: 0),
            Module(id: UUID(), title: "Quadratic Functions", lessons: [
                Lesson(id: UUID(), title: "Introduction to Parabolas", content: "Understanding the shape and properties of quadratic functions.", duration: 18, isCompleted: true, type: .reading, xpReward: 30),
                Lesson(id: UUID(), title: "Factoring Quadratics", content: "Techniques for factoring quadratic expressions.", duration: 25, isCompleted: false, type: .activity, xpReward: 35),
                Lesson(id: UUID(), title: "Quadratic Formula", content: "Deriving and applying the quadratic formula.", duration: 20, isCompleted: false, type: .reading, xpReward: 30),
            ], orderIndex: 1),
        ]
    }

    private func makeScienceModules() -> [Module] {
        [
            Module(id: UUID(), title: "Cell Biology", lessons: [
                Lesson(id: UUID(), title: "Cell Structure", content: "Overview of prokaryotic and eukaryotic cell structures and their functions.", duration: 20, isCompleted: true, type: .reading, xpReward: 25),
                Lesson(id: UUID(), title: "Cell Membrane", content: "The fluid mosaic model and membrane transport mechanisms.", duration: 22, isCompleted: false, type: .video, xpReward: 30),
            ], orderIndex: 0),
        ]
    }

    private func makeHistoryModules() -> [Module] {
        [
            Module(id: UUID(), title: "Ancient Civilizations", lessons: [
                Lesson(id: UUID(), title: "Mesopotamia", content: "The cradle of civilization: Sumer, Babylon, and Assyria.", duration: 18, isCompleted: true, type: .reading, xpReward: 25),
                Lesson(id: UUID(), title: "Ancient Egypt", content: "Pharaohs, pyramids, and the Nile River civilization.", duration: 20, isCompleted: true, type: .reading, xpReward: 25),
                Lesson(id: UUID(), title: "Ancient Greece", content: "Democracy, philosophy, and the foundations of Western civilization.", duration: 22, isCompleted: true, type: .video, xpReward: 30),
            ], orderIndex: 0),
        ]
    }

    private func makeEnglishModules() -> [Module] {
        [
            Module(id: UUID(), title: "Poetry", lessons: [
                Lesson(id: UUID(), title: "Romantic Poetry", content: "Exploring the works of Wordsworth, Keats, and Shelley.", duration: 15, isCompleted: true, type: .reading, xpReward: 25),
                Lesson(id: UUID(), title: "Modern Poetry", content: "From T.S. Eliot to Maya Angelou: voices of the modern era.", duration: 18, isCompleted: false, type: .reading, xpReward: 25),
            ], orderIndex: 0),
        ]
    }

    private func makeQuizQuestions() -> [QuizQuestion] {
        [
            QuizQuestion(id: UUID(), text: "What is the standard form of a quadratic equation?", options: ["y = mx + b", "ax² + bx + c = 0", "a² + b² = c²", "y = ab^x"], correctIndex: 1),
            QuizQuestion(id: UUID(), text: "What is the discriminant of a quadratic equation?", options: ["b² - 4ac", "b² + 4ac", "-b ± √(b²-4ac)", "2a"], correctIndex: 0),
            QuizQuestion(id: UUID(), text: "How many solutions does a quadratic have when the discriminant is negative?", options: ["Two real solutions", "One real solution", "No real solutions", "Infinite solutions"], correctIndex: 2),
            QuizQuestion(id: UUID(), text: "What shape does a quadratic function graph?", options: ["Line", "Circle", "Parabola", "Hyperbola"], correctIndex: 2),
            QuizQuestion(id: UUID(), text: "What is the vertex of y = (x-3)² + 2?", options: ["(3, 2)", "(-3, 2)", "(3, -2)", "(2, 3)"], correctIndex: 0),
        ]
    }
}
