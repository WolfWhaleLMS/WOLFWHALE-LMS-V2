import Foundation

struct MockDataService {
    static let shared = MockDataService()

    func sampleUser(role: UserRole) -> User {
        switch role {
        case .student:
            User(id: UUID(), firstName: "Alex", lastName: "Rivera", email: "alex@wolfwhale.edu", role: .student, avatarSystemName: "person.crop.circle.fill", streak: 12, joinDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(), schoolId: "school_001", userSlotsTotal: 0, userSlotsUsed: 0)
        case .teacher:
            User(id: UUID(), firstName: "Dr. Sarah", lastName: "Chen", email: "chen@wolfwhale.edu", role: .teacher, avatarSystemName: "person.crop.circle.fill", streak: 0, joinDate: Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date(), schoolId: "school_001", userSlotsTotal: 0, userSlotsUsed: 0)
        case .parent:
            User(id: UUID(), firstName: "Maria", lastName: "Rivera", email: "maria@email.com", role: .parent, avatarSystemName: "person.crop.circle.fill", streak: 0, joinDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(), schoolId: "school_001", userSlotsTotal: 0, userSlotsUsed: 0)
        case .admin:
            User(id: UUID(), firstName: "James", lastName: "Wilson", email: "jwilson@wolfwhale.edu", role: .admin, avatarSystemName: "person.crop.circle.fill", streak: 0, joinDate: Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date(), schoolId: "school_001", userSlotsTotal: 50, userSlotsUsed: 9)
        case .superAdmin:
            User(id: UUID(), firstName: "System", lastName: "Admin", email: "superadmin@wolfwhale.io", role: .superAdmin, avatarSystemName: "person.crop.circle.fill", streak: 0, joinDate: Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? Date(), schoolId: nil, userSlotsTotal: 0, userSlotsUsed: 0)
        }
    }

    func sampleCourses() -> [Course] {
        let mathId = UUID()
        let scienceId = UUID()
        let historyId = UUID()
        let englishId = UUID()
        let csId = UUID()

        return [
            Course(id: mathId, title: "Algebra II", description: "Advanced algebraic concepts including polynomials, quadratics, and functions.", teacherName: "Dr. Sarah Chen", iconSystemName: "function", colorName: "blue", modules: makeMathModules(), enrolledStudentCount: 28, progress: 0.65, classCode: "MATH-2024"),
            Course(id: scienceId, title: "AP Biology", description: "College-level biology covering cellular processes, genetics, and ecology.", teacherName: "Mr. David Park", iconSystemName: "leaf.fill", colorName: "green", modules: makeScienceModules(), enrolledStudentCount: 24, progress: 0.42, classCode: "BIO-2024"),
            Course(id: historyId, title: "World History", description: "Comprehensive survey of world civilizations from ancient to modern times.", teacherName: "Ms. Emily Torres", iconSystemName: "globe.americas.fill", colorName: "orange", modules: makeHistoryModules(), enrolledStudentCount: 32, progress: 0.78, classCode: "HIST-2024"),
            Course(id: englishId, title: "English Literature", description: "Critical analysis of classic and contemporary literary works.", teacherName: "Mrs. Lisa Johnson", iconSystemName: "text.book.closed.fill", colorName: "purple", modules: makeEnglishModules(), enrolledStudentCount: 26, progress: 0.55, classCode: "ENG-2024"),
            Course(id: csId, title: "Intro to Computer Science", description: "Foundations of programming, algorithms, and computational thinking using Python.", teacherName: "Mr. Jason Lee", iconSystemName: "chevron.left.forwardslash.chevron.right", colorName: "teal", modules: makeCSModules(), enrolledStudentCount: 22, progress: 0.35, classCode: "CS-2024"),
        ]
    }

    // MARK: - Assignments

    func sampleAssignments() -> [Assignment] {
        let cal = Calendar.current
        return [
            // Submitted & graded
            Assignment(id: UUID(), title: "Renaissance Essay", courseId: UUID(), courseName: "World History", instructions: "Write a 1000-word essay on the impact of the Renaissance on European society. Discuss key figures, artistic movements, and the shift in intellectual thought from the Medieval period.", dueDate: cal.date(byAdding: .day, value: -8, to: Date()) ?? Date(), points: 100, isSubmitted: true, submission: "The Renaissance was a period of cultural rebirth that swept across Europe beginning in 14th-century Italy...", grade: 92, feedback: "Excellent analysis of the cultural shift. Strong thesis statement and well-organized arguments. Consider adding more primary source references next time.", xpReward: 0),
            Assignment(id: UUID(), title: "Linear Equations Worksheet", courseId: UUID(), courseName: "Algebra II", instructions: "Complete problems 1-25 from Chapter 3. Show all work for full credit. Use graph paper for problems requiring a plotted line.", dueDate: cal.date(byAdding: .day, value: -5, to: Date()) ?? Date(), points: 50, isSubmitted: true, submission: "See attached worksheet with all solutions.", grade: 88, feedback: "Good work overall. Review problems 14 and 19 — check your sign errors when moving terms across the equals sign.", xpReward: 0),
            Assignment(id: UUID(), title: "Cell Organelle Diagram", courseId: UUID(), courseName: "AP Biology", instructions: "Create a detailed labeled diagram of a eukaryotic cell. Include all major organelles with brief descriptions of their functions.", dueDate: cal.date(byAdding: .day, value: -3, to: Date()) ?? Date(), points: 75, isSubmitted: true, submission: "Submitted digital diagram via Canvas upload.", grade: 95, feedback: "Outstanding detail on the organelle descriptions. The comparison between plant and animal cells was a nice addition.", xpReward: 0),
            // Submitted, awaiting grade
            Assignment(id: UUID(), title: "Shakespeare Sonnet Analysis", courseId: UUID(), courseName: "English Literature", instructions: "Choose one of Shakespeare's sonnets (not Sonnet 18) and write a 500-word analysis examining its use of meter, rhyme scheme, imagery, and thematic content.", dueDate: cal.date(byAdding: .day, value: -1, to: Date()) ?? Date(), points: 80, isSubmitted: true, submission: "I chose Sonnet 130, 'My mistress' eyes are nothing like the sun,' for its subversive take on the Petrarchan tradition of idealizing the beloved...", grade: nil, feedback: nil, xpReward: 0),
            // Pending (upcoming)
            Assignment(id: UUID(), title: "Quadratic Functions Problem Set", courseId: UUID(), courseName: "Algebra II", instructions: "Solve problems 1-20 from Chapter 5. Show all work. For each quadratic, identify the vertex, axis of symmetry, and direction of opening.", dueDate: cal.date(byAdding: .day, value: 2, to: Date()) ?? Date(), points: 100, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 0),
            Assignment(id: UUID(), title: "Cell Division Lab Report", courseId: UUID(), courseName: "AP Biology", instructions: "Write a complete lab report on the mitosis experiment conducted in class. Include hypothesis, materials, methods, results with data tables, and conclusion.", dueDate: cal.date(byAdding: .day, value: 5, to: Date()) ?? Date(), points: 150, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 0),
            Assignment(id: UUID(), title: "Roman Empire Timeline Project", courseId: UUID(), courseName: "World History", instructions: "Create an illustrated timeline of the Roman Empire from the founding of Rome (753 BCE) to the fall of the Western Empire (476 CE). Include at least 15 key events with brief descriptions.", dueDate: cal.date(byAdding: .day, value: 7, to: Date()) ?? Date(), points: 120, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 0),
            Assignment(id: UUID(), title: "Poetry Portfolio", courseId: UUID(), courseName: "English Literature", instructions: "Compile a portfolio of 3 original poems using techniques studied in class: one sonnet, one free verse, and one villanelle. Include a reflective introduction explaining your creative choices.", dueDate: cal.date(byAdding: .day, value: 10, to: Date()) ?? Date(), points: 100, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 0),
            // Computer Science assignments
            Assignment(id: UUID(), title: "Python Calculator Project", courseId: UUID(), courseName: "Intro to Computer Science", instructions: "Build a command-line calculator in Python that supports addition, subtraction, multiplication, division, and exponentiation. Handle division by zero gracefully and include a menu-driven interface.", dueDate: cal.date(byAdding: .day, value: 4, to: Date()) ?? Date(), points: 100, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 0),
            Assignment(id: UUID(), title: "HTML Portfolio Page", courseId: UUID(), courseName: "Intro to Computer Science", instructions: "Create a personal portfolio web page using HTML and CSS. Include sections for About Me, Projects, and Contact. Use semantic HTML elements and responsive design principles.", dueDate: cal.date(byAdding: .day, value: -6, to: Date()) ?? Date(), points: 80, isSubmitted: true, submission: "Submitted via GitHub Pages link.", grade: 90, feedback: "Clean layout and good use of semantic HTML. Consider adding media queries for mobile responsiveness.", xpReward: 0),
            Assignment(id: UUID(), title: "Genetics Problem Set", courseId: UUID(), courseName: "AP Biology", instructions: "Complete Punnett square problems for monohybrid and dihybrid crosses. Include phenotype and genotype ratios for each cross. Show all work.", dueDate: cal.date(byAdding: .day, value: 6, to: Date()) ?? Date(), points: 60, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 0),
            Assignment(id: UUID(), title: "Industrial Revolution Essay", courseId: UUID(), courseName: "World History", instructions: "Write an 800-word essay analyzing how the Industrial Revolution changed social class structures in 19th-century England. Use at least 3 primary sources.", dueDate: cal.date(byAdding: .day, value: 12, to: Date()) ?? Date(), points: 100, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 0),
        ]
    }

    // MARK: - Quizzes

    func sampleQuizzes() -> [Quiz] {
        let cal = Calendar.current
        return [
            Quiz(id: UUID(), title: "Chapter 5: Quadratics", courseId: UUID(), courseName: "Algebra II", questions: makeQuizQuestions(), timeLimit: 30, dueDate: cal.date(byAdding: .day, value: 3, to: Date()) ?? Date(), isCompleted: false, score: nil, xpReward: 0),
            Quiz(id: UUID(), title: "Cellular Respiration", courseId: UUID(), courseName: "AP Biology", questions: makeQuizQuestions(), timeLimit: 25, dueDate: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date(), isCompleted: true, score: 88, xpReward: 0),
            Quiz(id: UUID(), title: "Ancient Civilizations", courseId: UUID(), courseName: "World History", questions: makeQuizQuestions(), timeLimit: 20, dueDate: cal.date(byAdding: .day, value: -3, to: Date()) ?? Date(), isCompleted: true, score: 95, xpReward: 0),
            Quiz(id: UUID(), title: "Literary Devices", courseId: UUID(), courseName: "English Literature", questions: makeQuizQuestions(), timeLimit: 20, dueDate: cal.date(byAdding: .day, value: 4, to: Date()) ?? Date(), isCompleted: false, score: nil, xpReward: 0),
            Quiz(id: UUID(), title: "Python Basics", courseId: UUID(), courseName: "Intro to Computer Science", questions: makeQuizQuestions(), timeLimit: 25, dueDate: cal.date(byAdding: .day, value: 6, to: Date()) ?? Date(), isCompleted: false, score: nil, xpReward: 0),
        ]
    }

    // MARK: - Grades

    func sampleGrades() -> [GradeEntry] {
        [
            GradeEntry(id: UUID(), courseId: UUID(), courseName: "Algebra II", courseIcon: "function", courseColor: "blue", letterGrade: "A-", numericGrade: 91.5, assignmentGrades: [
                AssignmentGrade(id: UUID(), title: "Homework 1: Slope Review", score: 95, maxScore: 100, date: Date().addingTimeInterval(-86400 * 28), type: "Homework"),
                AssignmentGrade(id: UUID(), title: "Quiz 1: Linear Equations", score: 88, maxScore: 100, date: Date().addingTimeInterval(-86400 * 21), type: "Quiz"),
                AssignmentGrade(id: UUID(), title: "Homework 2: Systems of Equations", score: 92, maxScore: 100, date: Date().addingTimeInterval(-86400 * 14), type: "Homework"),
                AssignmentGrade(id: UUID(), title: "Linear Equations Worksheet", score: 44, maxScore: 50, date: Date().addingTimeInterval(-86400 * 5), type: "Homework"),
                AssignmentGrade(id: UUID(), title: "Midterm Exam", score: 92, maxScore: 100, date: Date().addingTimeInterval(-86400 * 3), type: "Exam"),
                AssignmentGrade(id: UUID(), title: "Class Participation: Week 1-4", score: 90, maxScore: 100, date: Date().addingTimeInterval(-86400 * 7), type: "Participation"),
                AssignmentGrade(id: UUID(), title: "Attendance: January", score: 18, maxScore: 20, date: Date().addingTimeInterval(-86400 * 15), type: "Attendance"),
                AssignmentGrade(id: UUID(), title: "Attendance: February", score: 19, maxScore: 20, date: Date().addingTimeInterval(-86400 * 2), type: "Attendance"),
            ]),
            GradeEntry(id: UUID(), courseId: UUID(), courseName: "AP Biology", courseIcon: "leaf.fill", courseColor: "green", letterGrade: "B+", numericGrade: 87.2, assignmentGrades: [
                AssignmentGrade(id: UUID(), title: "Lab Report 1: Microscopy", score: 85, maxScore: 100, date: Date().addingTimeInterval(-86400 * 25), type: "Lab"),
                AssignmentGrade(id: UUID(), title: "Quiz: Cell Structures", score: 82, maxScore: 100, date: Date().addingTimeInterval(-86400 * 18), type: "Quiz"),
                AssignmentGrade(id: UUID(), title: "Cell Organelle Diagram", score: 71.25, maxScore: 75, date: Date().addingTimeInterval(-86400 * 3), type: "Homework"),
                AssignmentGrade(id: UUID(), title: "Chapter Test: Cells", score: 89, maxScore: 100, date: Date().addingTimeInterval(-86400 * 5), type: "Exam"),
                AssignmentGrade(id: UUID(), title: "Lab Participation", score: 85, maxScore: 100, date: Date().addingTimeInterval(-86400 * 10), type: "Participation"),
                AssignmentGrade(id: UUID(), title: "Attendance: January", score: 17, maxScore: 20, date: Date().addingTimeInterval(-86400 * 15), type: "Attendance"),
                AssignmentGrade(id: UUID(), title: "Attendance: February", score: 20, maxScore: 20, date: Date().addingTimeInterval(-86400 * 2), type: "Attendance"),
            ]),
            GradeEntry(id: UUID(), courseId: UUID(), courseName: "World History", courseIcon: "globe.americas.fill", courseColor: "orange", letterGrade: "A", numericGrade: 95.0, assignmentGrades: [
                AssignmentGrade(id: UUID(), title: "Essay 1: Mesopotamia", score: 94, maxScore: 100, date: Date().addingTimeInterval(-86400 * 24), type: "Essay"),
                AssignmentGrade(id: UUID(), title: "Quiz: Ancient Egypt", score: 98, maxScore: 100, date: Date().addingTimeInterval(-86400 * 17), type: "Quiz"),
                AssignmentGrade(id: UUID(), title: "Map Activity: Greek City-States", score: 90, maxScore: 100, date: Date().addingTimeInterval(-86400 * 10), type: "Homework"),
                AssignmentGrade(id: UUID(), title: "Renaissance Essay", score: 92, maxScore: 100, date: Date().addingTimeInterval(-86400 * 8), type: "Essay"),
                AssignmentGrade(id: UUID(), title: "Quiz: Roman Republic", score: 96, maxScore: 100, date: Date().addingTimeInterval(-86400 * 4), type: "Quiz"),
                AssignmentGrade(id: UUID(), title: "Discussion Participation", score: 95, maxScore: 100, date: Date().addingTimeInterval(-86400 * 6), type: "Participation"),
                AssignmentGrade(id: UUID(), title: "Attendance: January-February", score: 38, maxScore: 40, date: Date().addingTimeInterval(-86400 * 2), type: "Attendance"),
            ]),
            GradeEntry(id: UUID(), courseId: UUID(), courseName: "English Literature", courseIcon: "text.book.closed.fill", courseColor: "purple", letterGrade: "A-", numericGrade: 90.8, assignmentGrades: [
                AssignmentGrade(id: UUID(), title: "Poetry Analysis: Romantic Era", score: 91, maxScore: 100, date: Date().addingTimeInterval(-86400 * 20), type: "Essay"),
                AssignmentGrade(id: UUID(), title: "Quiz: Literary Devices", score: 87, maxScore: 100, date: Date().addingTimeInterval(-86400 * 13), type: "Quiz"),
                AssignmentGrade(id: UUID(), title: "Hamlet Discussion Response", score: 94, maxScore: 100, date: Date().addingTimeInterval(-86400 * 8), type: "Homework"),
                AssignmentGrade(id: UUID(), title: "Midterm: Poetry & Drama", score: 91, maxScore: 100, date: Date().addingTimeInterval(-86400 * 4), type: "Exam"),
                AssignmentGrade(id: UUID(), title: "Seminar Participation", score: 92, maxScore: 100, date: Date().addingTimeInterval(-86400 * 6), type: "Participation"),
                AssignmentGrade(id: UUID(), title: "Attendance: January-February", score: 36, maxScore: 40, date: Date().addingTimeInterval(-86400 * 2), type: "Attendance"),
            ]),
            GradeEntry(id: UUID(), courseId: UUID(), courseName: "Intro to Computer Science", courseIcon: "chevron.left.forwardslash.chevron.right", courseColor: "teal", letterGrade: "A", numericGrade: 93.5, assignmentGrades: [
                AssignmentGrade(id: UUID(), title: "Hello World Assignment", score: 100, maxScore: 100, date: Date().addingTimeInterval(-86400 * 30), type: "Homework"),
                AssignmentGrade(id: UUID(), title: "Variables & Data Types Quiz", score: 92, maxScore: 100, date: Date().addingTimeInterval(-86400 * 22), type: "Quiz"),
                AssignmentGrade(id: UUID(), title: "Control Flow Exercises", score: 88, maxScore: 100, date: Date().addingTimeInterval(-86400 * 15), type: "Homework"),
                AssignmentGrade(id: UUID(), title: "HTML Portfolio Page", score: 72, maxScore: 80, date: Date().addingTimeInterval(-86400 * 6), type: "Project"),
                AssignmentGrade(id: UUID(), title: "Functions & Modules Quiz", score: 95, maxScore: 100, date: Date().addingTimeInterval(-86400 * 8), type: "Quiz"),
                AssignmentGrade(id: UUID(), title: "Lab Participation", score: 94, maxScore: 100, date: Date().addingTimeInterval(-86400 * 4), type: "Participation"),
                AssignmentGrade(id: UUID(), title: "Attendance: January-February", score: 39, maxScore: 40, date: Date().addingTimeInterval(-86400 * 2), type: "Attendance"),
            ]),
        ]
    }

    // MARK: - Attendance

    func sampleAttendance() -> [AttendanceRecord] {
        let cal = Calendar.current
        var records: [AttendanceRecord] = []
        var dayOffset = 0
        var schoolDayCount = 0
        let statusPattern: [AttendanceStatus] = [
            .present, .present, .present, .present, .present,
            .present, .tardy, .present, .present, .present,
            .present, .present, .absent, .present, .present,
            .present, .present, .present, .excused, .present,
            .present, .present, .present, .present, .tardy,
        ]
        while schoolDayCount < 25 {
            let date = cal.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let weekday = cal.component(.weekday, from: date)
            if weekday != 1 && weekday != 7 {
                records.append(AttendanceRecord(
                    id: UUID(),
                    date: date,
                    status: statusPattern[schoolDayCount],
                    courseName: "All Classes",
                    studentName: nil
                ))
                schoolDayCount += 1
            }
            dayOffset += 1
        }
        return records
    }

    // MARK: - Achievements

    func sampleAchievements() -> [Achievement] {
        [
            Achievement(id: UUID(), title: "First Steps", description: "Complete your first lesson", iconSystemName: "star.fill", isUnlocked: true, unlockedDate: Date().addingTimeInterval(-86400 * 60), xpReward: 0, rarity: .common),
            Achievement(id: UUID(), title: "Bookworm", description: "Complete 10 reading lessons", iconSystemName: "book.fill", isUnlocked: true, unlockedDate: Date().addingTimeInterval(-86400 * 30), xpReward: 0, rarity: .rare),
            Achievement(id: UUID(), title: "Social Butterfly", description: "Join 3 study groups", iconSystemName: "person.3.fill", isUnlocked: true, unlockedDate: Date().addingTimeInterval(-86400 * 14), xpReward: 0, rarity: .common),
            Achievement(id: UUID(), title: "Hot Streak", description: "Maintain a 10-day login streak", iconSystemName: "flame.fill", isUnlocked: true, unlockedDate: Date().addingTimeInterval(-86400 * 2), xpReward: 0, rarity: .rare),
            Achievement(id: UUID(), title: "Quiz Master", description: "Score 100% on 5 quizzes", iconSystemName: "checkmark.seal.fill", isUnlocked: false, unlockedDate: nil, xpReward: 0, rarity: .epic),
            Achievement(id: UUID(), title: "Streak Legend", description: "Maintain a 30-day streak", iconSystemName: "bolt.fill", isUnlocked: false, unlockedDate: nil, xpReward: 0, rarity: .legendary),
            Achievement(id: UUID(), title: "Early Bird", description: "Submit 3 assignments before the deadline", iconSystemName: "sunrise.fill", isUnlocked: true, unlockedDate: Date().addingTimeInterval(-86400 * 10), xpReward: 0, rarity: .common),
            Achievement(id: UUID(), title: "Perfect Score", description: "Score 100% on any assignment", iconSystemName: "star.circle.fill", isUnlocked: true, unlockedDate: Date().addingTimeInterval(-86400 * 25), xpReward: 0, rarity: .rare),
            Achievement(id: UUID(), title: "Team Player", description: "Participate in 5 group discussions", iconSystemName: "hands.sparkles.fill", isUnlocked: false, unlockedDate: nil, xpReward: 0, rarity: .epic),
            Achievement(id: UUID(), title: "Code Ninja", description: "Complete all programming exercises", iconSystemName: "terminal.fill", isUnlocked: false, unlockedDate: nil, xpReward: 0, rarity: .legendary),
        ]
    }

    // MARK: - Leaderboard

    func sampleLeaderboard() -> [LeaderboardEntry] {
        [
            LeaderboardEntry(id: UUID(), userName: "Alex Rivera", xp: 0, level: 1, rank: 1, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Jordan Kim", xp: 0, level: 1, rank: 2, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Sam Patel", xp: 0, level: 1, rank: 3, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Taylor Brooks", xp: 0, level: 1, rank: 4, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Casey Nguyen", xp: 0, level: 1, rank: 5, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Morgan Lee", xp: 0, level: 1, rank: 6, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Avery Wilson", xp: 0, level: 1, rank: 7, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Riley Thompson", xp: 0, level: 1, rank: 8, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Jamie Garcia", xp: 0, level: 1, rank: 9, avatarSystemName: "person.crop.circle.fill"),
            LeaderboardEntry(id: UUID(), userName: "Drew Martinez", xp: 0, level: 1, rank: 10, avatarSystemName: "person.crop.circle.fill"),
        ]
    }

    // MARK: - Conversations

    func sampleConversations() -> [Conversation] {
        let cal = Calendar.current
        let now = Date()
        return [
            Conversation(id: UUID(), participantNames: ["Dr. Sarah Chen"], title: "Dr. Sarah Chen", lastMessage: "Don't forget the homework is due Friday!", lastMessageDate: cal.date(byAdding: .hour, value: -2, to: now) ?? now, unreadCount: 1, messages: [
                ChatMessage(id: UUID(), senderName: "Dr. Sarah Chen", content: "Hi Alex, how's the quadratic functions problem set going? Let me know if you need help with any of the questions.", timestamp: cal.date(byAdding: .hour, value: -5, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "Going well! I finished most of them. I'm stuck on problem 17 though — it has a complex discriminant and I'm not sure how to handle it.", timestamp: cal.date(byAdding: .hour, value: -4, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Dr. Sarah Chen", content: "Great progress! For problem 17, remember that when the discriminant is negative, you'll get complex solutions. We covered that in Wednesday's lesson. Check your notes on imaginary numbers.", timestamp: cal.date(byAdding: .hour, value: -3, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "Oh right, I'll review that section. Thanks!", timestamp: cal.date(byAdding: .minute, value: -150, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Dr. Sarah Chen", content: "Don't forget the homework is due Friday!", timestamp: cal.date(byAdding: .hour, value: -2, to: now) ?? now, isFromCurrentUser: false),
            ], avatarSystemName: "person.crop.circle.fill"),

            Conversation(id: UUID(), participantNames: ["Study Group"], title: "Bio Study Group", lastMessage: "Thanks everyone, that really helps!", lastMessageDate: cal.date(byAdding: .hour, value: -3, to: now) ?? now, unreadCount: 0, messages: [
                ChatMessage(id: UUID(), senderName: "Jordan Kim", content: "Hey everyone, studying for the bio test tomorrow. Anyone want to review together?", timestamp: cal.date(byAdding: .hour, value: -8, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Sam Patel", content: "I'm in! Can someone explain the difference between mitosis and meiosis? I keep mixing them up.", timestamp: cal.date(byAdding: .hour, value: -7, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "Sure! Mitosis produces 2 identical daughter cells for growth and repair. Meiosis produces 4 genetically unique cells for reproduction. Mitosis = 1 division, Meiosis = 2 divisions.", timestamp: cal.date(byAdding: .hour, value: -6, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Jordan Kim", content: "That's a great summary. Also remember: meiosis has crossing over in prophase I, which is why the cells end up genetically different.", timestamp: cal.date(byAdding: .hour, value: -5, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Taylor Brooks", content: "Don't forget about the stages of mitosis for the test: Prophase, Metaphase, Anaphase, Telophase. I remember it with PMAT.", timestamp: cal.date(byAdding: .hour, value: -4, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Sam Patel", content: "Thanks everyone, that really helps!", timestamp: cal.date(byAdding: .hour, value: -3, to: now) ?? now, isFromCurrentUser: false),
            ], avatarSystemName: "person.3.fill"),

            Conversation(id: UUID(), participantNames: ["Ms. Emily Torres"], title: "Ms. Emily Torres", lastMessage: "Your essay was one of the best in the class.", lastMessageDate: cal.date(byAdding: .day, value: -1, to: now) ?? now, unreadCount: 1, messages: [
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "Hi Ms. Torres, I wanted to ask about the Roman Empire timeline project. Can we use digital tools like Canva or does it need to be hand-drawn?", timestamp: cal.date(byAdding: .hour, value: -50, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Ms. Emily Torres", content: "Great question, Alex! Either format is fine. If you go digital, just make sure it's detailed and includes images or illustrations for at least 5 of the key events.", timestamp: cal.date(byAdding: .hour, value: -47, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "Perfect, I'll use Canva then. Also, I really enjoyed the Renaissance unit.", timestamp: cal.date(byAdding: .hour, value: -30, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Ms. Emily Torres", content: "I'm glad to hear that! Your essay was one of the best in the class. You have a real knack for connecting historical events to broader themes. Keep it up!", timestamp: cal.date(byAdding: .day, value: -1, to: now) ?? now, isFromCurrentUser: false),
            ], avatarSystemName: "person.crop.circle.fill"),

            Conversation(id: UUID(), participantNames: ["Mrs. Lisa Johnson"], title: "Mrs. Lisa Johnson", lastMessage: "See you in class tomorrow!", lastMessageDate: cal.date(byAdding: .day, value: -2, to: now) ?? now, unreadCount: 0, messages: [
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "Mrs. Johnson, I chose Sonnet 130 for the Shakespeare assignment. Is that okay, or is it too commonly analyzed?", timestamp: cal.date(byAdding: .hour, value: -75, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Mrs. Lisa Johnson", content: "Sonnet 130 is a great choice! It's popular for a reason — there's a lot of depth to explore. Focus on how Shakespeare subverts Petrarchan conventions and you'll have a strong paper.", timestamp: cal.date(byAdding: .hour, value: -72, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "Thanks! I'm planning to discuss the irony in his comparisons and how the final couplet redefines beauty.", timestamp: cal.date(byAdding: .hour, value: -52, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Mrs. Lisa Johnson", content: "That sounds like a thoughtful approach. Make sure to include specific line references. See you in class tomorrow!", timestamp: cal.date(byAdding: .day, value: -2, to: now) ?? now, isFromCurrentUser: false),
            ], avatarSystemName: "person.crop.circle.fill"),

            Conversation(id: UUID(), participantNames: ["Mr. Jason Lee"], title: "Mr. Jason Lee", lastMessage: "Keep experimenting, that's how you learn!", lastMessageDate: cal.date(byAdding: .hour, value: -6, to: now) ?? now, unreadCount: 1, messages: [
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "Hi Mr. Lee, I'm working on the Python calculator but I'm getting an error when I try to handle division by zero. Can you help?", timestamp: cal.date(byAdding: .hour, value: -10, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Mr. Jason Lee", content: "Sure! You'll want to use a try-except block. Wrap your division operation in a try block and catch ZeroDivisionError in the except block.", timestamp: cal.date(byAdding: .hour, value: -9, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "That worked! I also added input validation to make sure the user enters a number.", timestamp: cal.date(byAdding: .hour, value: -7, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Mr. Jason Lee", content: "Excellent thinking! Input validation is a great habit. Keep experimenting, that's how you learn!", timestamp: cal.date(byAdding: .hour, value: -6, to: now) ?? now, isFromCurrentUser: false),
            ], avatarSystemName: "person.crop.circle.fill"),

            Conversation(id: UUID(), participantNames: ["School Counselor"], title: "Ms. Rachel Adams", lastMessage: "My door is always open if you need anything.", lastMessageDate: cal.date(byAdding: .day, value: -3, to: now) ?? now, unreadCount: 0, messages: [
                ChatMessage(id: UUID(), senderName: "Ms. Rachel Adams", content: "Hi Alex! Just checking in — how are you feeling about your course load this semester? Five courses can be a lot.", timestamp: cal.date(byAdding: .day, value: -5, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "It's busy but I'm managing! I really like the new CS class. History is my favorite though.", timestamp: cal.date(byAdding: .day, value: -4, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Ms. Rachel Adams", content: "That's great to hear! Your teachers say you're doing well. Remember, my door is always open if you need anything.", timestamp: cal.date(byAdding: .day, value: -3, to: now) ?? now, isFromCurrentUser: false),
            ], avatarSystemName: "person.crop.circle.fill"),

            Conversation(id: UUID(), participantNames: ["History Study Group"], title: "History Study Group", lastMessage: "See you all at the library tomorrow!", lastMessageDate: cal.date(byAdding: .hour, value: -12, to: now) ?? now, unreadCount: 0, messages: [
                ChatMessage(id: UUID(), senderName: "Casey Nguyen", content: "Anyone want to study for the Roman Empire test together?", timestamp: cal.date(byAdding: .hour, value: -20, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "I'm in! I made flashcards for all the key dates and figures.", timestamp: cal.date(byAdding: .hour, value: -18, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Taylor Brooks", content: "Can I join? I'm struggling with the Punic Wars section.", timestamp: cal.date(byAdding: .hour, value: -16, to: now) ?? now, isFromCurrentUser: false),
                ChatMessage(id: UUID(), senderName: "Alex Rivera", content: "Of course! I'll bring my notes on Hannibal's campaign.", timestamp: cal.date(byAdding: .hour, value: -14, to: now) ?? now, isFromCurrentUser: true),
                ChatMessage(id: UUID(), senderName: "Casey Nguyen", content: "See you all at the library tomorrow!", timestamp: cal.date(byAdding: .hour, value: -12, to: now) ?? now, isFromCurrentUser: false),
            ], avatarSystemName: "person.3.fill"),
        ]
    }

    // MARK: - Announcements

    func sampleAnnouncements() -> [Announcement] {
        [
            Announcement(id: UUID(), title: "Spring Break Schedule", content: "Spring break will be from March 15-22. No classes will be held during this period. All assignments due during break have been extended to March 24. Make sure to check your course pages for updated deadlines. Enjoy your well-deserved rest!", authorName: "James Wilson", date: Date().addingTimeInterval(-86400), isPinned: true),
            Announcement(id: UUID(), title: "Science Fair Registration Open", content: "Registration for the annual WolfWhale Academy Science Fair is now open! This year's theme is 'Innovation for Sustainability.' Submit your project proposals by March 10 through the student portal. Projects can be individual or in teams of up to 3. See Mr. Park in room 204 if you have questions.", authorName: "Mr. David Park", date: Date().addingTimeInterval(-86400 * 3), isPinned: true),
            Announcement(id: UUID(), title: "Parent-Teacher Conference Sign-Up", content: "Parent-teacher conferences will be held on March 5-6 from 4:00 PM to 8:00 PM. Parents can sign up for 15-minute slots through the school portal. If you need accommodations or language interpretation services, please contact the front office by February 28.", authorName: "James Wilson", date: Date().addingTimeInterval(-86400 * 5), isPinned: false),
            Announcement(id: UUID(), title: "Library Extended Hours for Midterms", content: "The school library will have extended hours during midterm week (February 24-28). The library will remain open until 7:00 PM Monday through Thursday. Quiet study rooms can be reserved through the library's online booking system. Snacks and water are now permitted in the study room area.", authorName: "Mrs. Patterson", date: Date().addingTimeInterval(-86400 * 7), isPinned: false),
            Announcement(id: UUID(), title: "New AR Learning Lab Now Open", content: "We are excited to announce that the new Augmented Reality Learning Lab in room 312 is now open for student use! The lab features AR stations for biology, chemistry, and history courses. Students can book 30-minute sessions during study hall or after school. Training sessions will be held this week during lunch periods.", authorName: "James Wilson", date: Date().addingTimeInterval(-86400 * 10), isPinned: false),
            Announcement(id: UUID(), title: "Varsity Basketball Championship", content: "Come support the WolfWhale Sharks at the regional championship game this Saturday at 3:00 PM in the main gymnasium! Student admission is free with valid school ID. Concessions will be available. Wear your school colors!", authorName: "Coach Martinez", date: Date().addingTimeInterval(-86400 * 2), isPinned: true),
            Announcement(id: UUID(), title: "Spring Club Fair", content: "The annual Spring Club Fair will be held next Wednesday during lunch in the student commons. Over 30 clubs will be represented, including Robotics, Debate, Art, Environmental Action, and more. It's a great opportunity to explore new interests and meet new people!", authorName: "Student Council", date: Date().addingTimeInterval(-86400 * 4), isPinned: false),
            Announcement(id: UUID(), title: "Coding Competition Sign-Up", content: "WolfWhale Academy is entering a team in the regional CodeJam competition on April 5th. Students interested in competitive programming should sign up with Mr. Lee in the CS lab (Room 218) by March 12. No prior competition experience needed — just enthusiasm for problem-solving!", authorName: "Mr. Jason Lee", date: Date().addingTimeInterval(-86400 * 6), isPinned: false),
            Announcement(id: UUID(), title: "Campus Wi-Fi Upgrade", content: "The IT department will be performing network upgrades this weekend to improve campus Wi-Fi speed and coverage. There may be brief connectivity interruptions on Saturday between 6:00 AM and 10:00 AM. All offline features of the WolfWhale LMS will remain fully functional during this time.", authorName: "IT Department", date: Date().addingTimeInterval(-86400 * 8), isPinned: false),
        ]
    }

    // MARK: - Parent Data

    func sampleChildren() -> [ChildInfo] {
        [
            ChildInfo(id: UUID(), name: "Alex Rivera", grade: "10th Grade", avatarSystemName: "person.crop.circle.fill", gpa: 3.7, attendanceRate: 0.96, courses: sampleGrades(), recentAssignments: Array(sampleAssignments().prefix(3))),
            ChildInfo(id: UUID(), name: "Sofia Rivera", grade: "7th Grade", avatarSystemName: "person.crop.circle.fill", gpa: 3.9, attendanceRate: 0.98, courses: [
                GradeEntry(id: UUID(), courseId: UUID(), courseName: "Pre-Algebra", courseIcon: "x.squareroot", courseColor: "blue", letterGrade: "A", numericGrade: 95.0, assignmentGrades: [
                    AssignmentGrade(id: UUID(), title: "Fractions Review", score: 96, maxScore: 100, date: Date().addingTimeInterval(-86400 * 14), type: "Homework"),
                    AssignmentGrade(id: UUID(), title: "Quiz: Decimals", score: 94, maxScore: 100, date: Date().addingTimeInterval(-86400 * 7), type: "Quiz"),
                ]),
                GradeEntry(id: UUID(), courseId: UUID(), courseName: "Life Science", courseIcon: "tortoise.fill", courseColor: "green", letterGrade: "A-", numericGrade: 92.0, assignmentGrades: [
                    AssignmentGrade(id: UUID(), title: "Ecosystems Poster", score: 90, maxScore: 100, date: Date().addingTimeInterval(-86400 * 10), type: "Project"),
                    AssignmentGrade(id: UUID(), title: "Quiz: Food Chains", score: 94, maxScore: 100, date: Date().addingTimeInterval(-86400 * 5), type: "Quiz"),
                ]),
                GradeEntry(id: UUID(), courseId: UUID(), courseName: "English 7", courseIcon: "text.book.closed.fill", courseColor: "purple", letterGrade: "A+", numericGrade: 97.5, assignmentGrades: [
                    AssignmentGrade(id: UUID(), title: "Book Report: The Giver", score: 98, maxScore: 100, date: Date().addingTimeInterval(-86400 * 8), type: "Essay"),
                    AssignmentGrade(id: UUID(), title: "Vocabulary Quiz 3", score: 97, maxScore: 100, date: Date().addingTimeInterval(-86400 * 3), type: "Quiz"),
                ]),
            ], recentAssignments: [
                Assignment(id: UUID(), title: "Fraction Word Problems", courseId: UUID(), courseName: "Pre-Algebra", instructions: "Complete worksheet problems 1-15.", dueDate: Date().addingTimeInterval(-86400 * 2), points: 50, isSubmitted: true, submission: "Completed.", grade: 48, feedback: "Excellent work!", xpReward: 0),
                Assignment(id: UUID(), title: "Habitat Diorama", courseId: UUID(), courseName: "Life Science", instructions: "Build a diorama of an assigned biome.", dueDate: Date().addingTimeInterval(86400 * 5), points: 100, isSubmitted: false, submission: nil, grade: nil, feedback: nil, xpReward: 0),
            ]),
        ]
    }

    func sampleSchoolMetrics() -> SchoolMetrics {
        SchoolMetrics(totalStudents: 1247, totalTeachers: 68, totalCourses: 142, averageAttendance: 0.94, averageGPA: 3.2, activeUsers: 1182)
    }

    // MARK: - Math Modules (Algebra II)

    private func makeMathModules() -> [Module] {
        [
            Module(id: UUID(), title: "Linear Equations Review", lessons: [
                Lesson(id: UUID(), title: "Slope-Intercept Form", content: """
The slope-intercept form of a linear equation is written as y = mx + b, where m represents the slope of the line and b represents the y-intercept — the point where the line crosses the y-axis. This form is one of the most useful representations of a linear equation because it immediately tells you two critical pieces of information: how steep the line is and where it starts on the y-axis.

To graph a line using slope-intercept form, begin by plotting the y-intercept (0, b) on the coordinate plane. From that point, use the slope m expressed as rise over run to find additional points. For example, if m = 2/3, move up 2 units and right 3 units from the y-intercept to plot the next point. Connect the points with a straight line extending in both directions.

Converting equations to slope-intercept form is a fundamental skill. If you are given an equation like 2x + 3y = 12, isolate y by subtracting 2x from both sides to get 3y = -2x + 12, then divide everything by 3 to get y = (-2/3)x + 4. Now you can see the slope is -2/3 and the y-intercept is 4. Practice this conversion with different standard form equations until it becomes second nature.
""", duration: 15, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Systems of Equations", content: """
A system of equations consists of two or more equations with the same set of variables. The solution to a system is the set of values that satisfies all equations simultaneously. In a system of two linear equations with two variables, the solution represents the point where the two lines intersect on a coordinate plane. There are three possible outcomes: one solution (the lines intersect at exactly one point), no solution (the lines are parallel), or infinitely many solutions (the lines are identical).

The substitution method works by solving one equation for one variable and substituting that expression into the other equation. For example, given the system y = 2x + 1 and 3x + y = 11, substitute the first equation into the second: 3x + (2x + 1) = 11. Simplify to get 5x + 1 = 11, so x = 2. Then substitute back to find y = 2(2) + 1 = 5. The solution is (2, 5).

The elimination method involves adding or subtracting equations to eliminate one variable. Consider the system 2x + 3y = 13 and 4x - 3y = 11. Adding both equations eliminates y: 6x = 24, giving x = 4. Substitute back into either equation to find y = 5/3. The elimination method is especially efficient when the coefficients of one variable are already opposites or can be made so by simple multiplication.
""", duration: 20, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Point-Slope Form", content: """
Point-slope form is another way to write the equation of a line, expressed as y - y1 = m(x - x1), where m is the slope and (x1, y1) is any known point on the line. This form is particularly useful when you know the slope and one specific point, or when you have two points and have calculated the slope between them.

To use point-slope form, first determine your slope m. If you are given two points, calculate the slope using the formula m = (y2 - y1) / (x2 - x1). For example, given the points (3, 7) and (5, 13), the slope is (13 - 7) / (5 - 3) = 6/2 = 3. Then plug the slope and either point into the formula: y - 7 = 3(x - 3), which simplifies to y - 7 = 3x - 9, or y = 3x - 2 in slope-intercept form.

Understanding when to use point-slope form versus slope-intercept form is an important strategic skill. Point-slope form is ideal when you are given a point and a slope directly, such as in problems involving parallel or perpendicular lines. Remember that parallel lines share the same slope, while perpendicular lines have slopes that are negative reciprocals of each other. If a line has slope 2/3, any line perpendicular to it has slope -3/2.
""", duration: 18, isCompleted: true, type: .reading, xpReward: 0),
            ], orderIndex: 0),

            Module(id: UUID(), title: "Quadratic Functions", lessons: [
                Lesson(id: UUID(), title: "Introduction to Parabolas", content: """
A quadratic function is any function that can be written in the form f(x) = ax² + bx + c, where a, b, and c are constants and a is not equal to zero. The graph of every quadratic function is a parabola — a symmetric U-shaped curve that opens upward when a is positive and downward when a is negative. The larger the absolute value of a, the narrower the parabola; the smaller the absolute value, the wider it stretches.

The vertex of a parabola is its highest or lowest point, depending on whether it opens downward or upward. You can find the x-coordinate of the vertex using the formula x = -b/(2a). Once you have the x-coordinate, substitute it back into the original equation to find the y-coordinate. For example, for f(x) = 2x² - 8x + 3, the vertex x-coordinate is -(-8)/(2·2) = 2. Substituting gives f(2) = 2(4) - 16 + 3 = -5, so the vertex is at (2, -5).

The axis of symmetry is the vertical line that passes through the vertex, given by the equation x = -b/(2a). Every parabola is perfectly symmetric about this line, meaning that for any point on the parabola, there is a mirror image point on the other side of the axis of symmetry at the same height. Understanding symmetry helps you graph parabolas efficiently: once you know the vertex and one or two points on one side, you can mirror them to complete the graph.
""", duration: 18, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Factoring Quadratics", content: """
Factoring is the process of breaking down a quadratic expression into the product of two binomials. For a quadratic of the form x² + bx + c, you need to find two numbers that multiply to give c and add to give b. For example, to factor x² + 7x + 12, find two numbers that multiply to 12 and add to 7. Those numbers are 3 and 4, so the factored form is (x + 3)(x + 4). You can verify by using FOIL: (x + 3)(x + 4) = x² + 4x + 3x + 12 = x² + 7x + 12.

When the leading coefficient a is not 1, factoring becomes more involved. For an expression like 2x² + 7x + 3, multiply a and c to get 6, then find two numbers that multiply to 6 and add to 7. Those are 6 and 1. Rewrite the middle term: 2x² + 6x + x + 3. Factor by grouping: 2x(x + 3) + 1(x + 3) = (2x + 1)(x + 3). This method, sometimes called the AC method, works reliably for any factorable quadratic.

Special factoring patterns can save significant time. The difference of squares pattern states that a² - b² = (a + b)(a - b). For example, x² - 49 = (x + 7)(x - 7). Perfect square trinomials follow the pattern a² + 2ab + b² = (a + b)² or a² - 2ab + b² = (a - b)². Recognizing these patterns quickly is a valuable skill that will help you throughout algebra and beyond. Not every quadratic can be factored over the integers, and that is where the quadratic formula becomes essential.
""", duration: 25, isCompleted: false, type: .activity, xpReward: 0),
                Lesson(id: UUID(), title: "The Quadratic Formula", content: """
The quadratic formula, x = (-b ± sqrt(b² - 4ac)) / (2a), provides a solution for any quadratic equation of the form ax² + bx + c = 0. Unlike factoring, which only works when the solutions are rational numbers, the quadratic formula works for all quadratic equations, making it one of the most powerful tools in algebra.

The discriminant, b² - 4ac, determines the nature of the solutions. When the discriminant is positive, there are two distinct real solutions. When it equals zero, there is exactly one real solution, meaning the parabola touches the x-axis at its vertex. When the discriminant is negative, there are no real solutions — the parabola does not cross the x-axis at all. In this case, the solutions are complex numbers involving the imaginary unit i.

To apply the quadratic formula, carefully identify a, b, and c from your equation, paying close attention to signs. For the equation 3x² - 5x - 2 = 0, we have a = 3, b = -5, and c = -2. The discriminant is (-5)² - 4(3)(-2) = 25 + 24 = 49. Since 49 is a perfect square, x = (5 ± 7)/6, giving x = 12/6 = 2 or x = -2/6 = -1/3. Always simplify your final answers and verify by substituting back into the original equation.
""", duration: 20, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Completing the Square", content: """
Completing the square is a technique for rewriting a quadratic expression in vertex form, f(x) = a(x - h)² + k, where (h, k) is the vertex of the parabola. This method reveals the vertex directly and is also the foundation for deriving the quadratic formula itself. Mastering this technique deepens your understanding of how quadratic functions behave.

To complete the square for x² + 6x + 2, focus on the x² and x terms first. Take half the coefficient of x (which is 6/2 = 3), then square it (3² = 9). Add and subtract 9 inside the expression: x² + 6x + 9 - 9 + 2 = (x + 3)² - 7. The vertex form is (x + 3)² - 7, revealing that the vertex is at (-3, -7). This means the parabola's minimum value is -7, occurring at x = -3.

When the leading coefficient is not 1, factor it out first. For 2x² + 12x + 5, factor out the 2 from the first two terms: 2(x² + 6x) + 5. Complete the square inside the parentheses: 2(x² + 6x + 9 - 9) + 5 = 2(x + 3)² - 18 + 5 = 2(x + 3)² - 13. The vertex is (-3, -13). Completing the square is especially valuable for optimization problems, where you need to find the maximum or minimum value of a quadratic function, such as maximizing area or minimizing cost.
""", duration: 22, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 1),

            Module(id: UUID(), title: "Polynomial Functions", lessons: [
                Lesson(id: UUID(), title: "Introduction to Polynomials", content: """
A polynomial is an expression consisting of variables and coefficients combined using addition, subtraction, and multiplication, where the exponents of the variables are non-negative integers. Polynomials are classified by their degree — the highest exponent present. A constant is degree 0, a linear expression is degree 1, a quadratic is degree 2, a cubic is degree 3, and so on. The leading coefficient is the coefficient of the highest-degree term.

The end behavior of a polynomial describes what happens to the function values as x approaches positive or negative infinity. For a polynomial with an even degree and positive leading coefficient, both ends rise toward positive infinity. For an odd degree with a positive leading coefficient, the left end falls while the right end rises. Understanding end behavior helps you sketch rough graphs and predict the general shape of polynomial functions.

Polynomials can be added, subtracted, and multiplied using familiar algebraic techniques. To add or subtract polynomials, combine like terms — terms with the same variable raised to the same power. To multiply polynomials, use the distributive property, multiplying each term in one polynomial by every term in the other. For example, (x² + 3x - 1)(2x + 5) = 2x³ + 5x² + 6x² + 15x - 2x - 5 = 2x³ + 11x² + 13x - 5.
""", duration: 20, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Polynomial Division", content: """
Polynomial long division works similarly to numerical long division. To divide one polynomial by another, arrange both in descending order of degree, then repeatedly divide the leading term of the dividend by the leading term of the divisor. For example, to divide x³ + 2x² - 5x + 3 by x - 1, divide x³ by x to get x², multiply (x - 1) by x² to get x³ - x², and subtract to bring down the next term. Continue this process until you reach a remainder.

Synthetic division is a shortcut method that works when dividing by a linear factor of the form (x - c). Write the coefficients of the dividend in a row and the value c to the left. Bring down the first coefficient, multiply by c, add to the next coefficient, and repeat. The bottom row gives you the coefficients of the quotient, with the last number being the remainder. For x³ + 2x² - 5x + 3 divided by x - 1, use c = 1 with coefficients [1, 2, -5, 3] to quickly find the quotient and remainder.

The Remainder Theorem states that when a polynomial f(x) is divided by (x - c), the remainder equals f(c). This means you can evaluate a polynomial at any value by performing synthetic division instead of substituting directly. The closely related Factor Theorem states that (x - c) is a factor of f(x) if and only if f(c) = 0. These theorems are essential tools for finding the roots of higher-degree polynomials.
""", duration: 25, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Zeros of Polynomials", content: """
The zeros (or roots) of a polynomial are the x-values where the function equals zero, corresponding to the points where the graph crosses or touches the x-axis. A polynomial of degree n has at most n real zeros. Finding these zeros is one of the central problems in algebra, and multiple strategies are available depending on the type of polynomial.

The Rational Root Theorem helps narrow down possible rational zeros. For a polynomial with integer coefficients, any rational zero p/q must have p as a factor of the constant term and q as a factor of the leading coefficient. For f(x) = 2x³ - 3x² - 8x + 12, the possible rational zeros are plus or minus 1, 2, 3, 4, 6, 12, 1/2, and 3/2. Test these candidates using synthetic division or direct substitution to identify actual zeros.

Once you find one zero using the Rational Root Theorem, use synthetic division to reduce the polynomial's degree by one, then continue finding zeros of the resulting polynomial. Multiplicity refers to how many times a particular zero is repeated. A zero with odd multiplicity means the graph crosses the x-axis at that point, while a zero with even multiplicity means the graph only touches the x-axis and turns back. Understanding multiplicity helps you produce accurate graphs of polynomial functions.
""", duration: 22, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 2),
        ]
    }

    // MARK: - Science Modules (AP Biology)

    private func makeScienceModules() -> [Module] {
        [
            Module(id: UUID(), title: "Cell Biology", lessons: [
                Lesson(id: UUID(), title: "Cell Structure and Organelles", content: """
All living organisms are composed of cells, the fundamental units of life. Cells come in two major types: prokaryotic and eukaryotic. Prokaryotic cells, found in bacteria and archaea, lack a membrane-bound nucleus and most organelles. Eukaryotic cells, found in plants, animals, fungi, and protists, contain a true nucleus enclosed by a double membrane and numerous specialized organelles that carry out specific functions.

The nucleus is the control center of the eukaryotic cell, housing the cell's DNA organized into chromosomes. It is surrounded by the nuclear envelope, a double membrane with nuclear pores that regulate the transport of molecules between the nucleus and cytoplasm. Inside the nucleus, the nucleolus is responsible for producing ribosomal RNA. The endoplasmic reticulum (ER) extends from the nuclear envelope throughout the cell. The rough ER, studded with ribosomes, synthesizes proteins, while the smooth ER is involved in lipid synthesis and detoxification.

Mitochondria are often called the powerhouses of the cell because they generate most of the cell's ATP through cellular respiration. They have their own double membrane — the inner membrane folds into structures called cristae that increase surface area for the electron transport chain. The Golgi apparatus modifies, packages, and ships proteins and lipids received from the ER. Lysosomes contain digestive enzymes that break down worn-out organelles, food particles, and engulfed bacteria. Plant cells have additional structures: a rigid cell wall for support, chloroplasts for photosynthesis, and a large central vacuole for storage and maintaining turgor pressure.
""", duration: 20, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Cell Membrane and Transport", content: """
The cell membrane, also known as the plasma membrane, is a selectively permeable barrier that controls what enters and exits the cell. Its structure is described by the fluid mosaic model: a dynamic bilayer of phospholipids with embedded proteins, cholesterol molecules, and carbohydrate chains. Each phospholipid has a hydrophilic (water-loving) head facing outward and two hydrophobic (water-fearing) fatty acid tails facing inward, creating a stable barrier in an aqueous environment.

Passive transport requires no energy input from the cell. Simple diffusion moves small, nonpolar molecules like oxygen and carbon dioxide directly through the lipid bilayer from areas of high concentration to low concentration. Facilitated diffusion uses channel proteins or carrier proteins to help polar molecules and ions cross the membrane down their concentration gradient. Osmosis is the diffusion of water across a selectively permeable membrane. In a hypertonic solution, a cell loses water and shrinks. In a hypotonic solution, water rushes in and the cell may swell or even burst.

Active transport requires energy, usually in the form of ATP, to move substances against their concentration gradient from low to high concentration. The sodium-potassium pump is a well-studied example: it pumps 3 sodium ions out and 2 potassium ions in with each cycle, maintaining the electrochemical gradient essential for nerve impulse transmission. Endocytosis brings large molecules into the cell by engulfing them in a vesicle, while exocytosis releases materials from the cell by fusing vesicles with the membrane. These processes are critical for cell communication and immune responses.
""", duration: 22, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Enzymes and Metabolism", content: """
Enzymes are biological catalysts — proteins that speed up chemical reactions in living organisms without being consumed in the process. Each enzyme has a specific three-dimensional shape with an active site that fits its particular substrate, much like a lock and key. When the substrate binds to the active site, it forms an enzyme-substrate complex, and the enzyme lowers the activation energy needed for the reaction to proceed, dramatically increasing the reaction rate.

The induced fit model refines the lock-and-key analogy by recognizing that the enzyme's active site slightly changes shape when the substrate binds, creating a tighter fit. Several factors affect enzyme activity. Temperature increases reaction rates up to a point — beyond the optimal temperature, the enzyme denatures as its protein structure unfolds. Similarly, each enzyme has an optimal pH. Pepsin in the stomach works best at pH 2, while trypsin in the small intestine prefers pH 8. Concentration of substrate and enzyme also influence the reaction rate.

Enzyme regulation is essential for maintaining homeostasis. Competitive inhibitors bind to the active site, blocking the substrate. Non-competitive inhibitors bind to an allosteric site elsewhere on the enzyme, changing its shape so the substrate can no longer fit. Feedback inhibition occurs when the end product of a metabolic pathway inhibits an enzyme earlier in the pathway, preventing overproduction. Understanding enzyme regulation is crucial for pharmacology — many drugs work by inhibiting specific enzymes involved in disease processes.
""", duration: 25, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 0),

            Module(id: UUID(), title: "Cell Division", lessons: [
                Lesson(id: UUID(), title: "The Cell Cycle and Mitosis", content: """
The cell cycle is the series of events that cells go through as they grow and divide. It consists of interphase (G1, S, and G2 phases) and the mitotic (M) phase. During G1, the cell grows and carries out normal functions. In the S phase, DNA replication occurs, creating identical copies of each chromosome. During G2, the cell continues growing and prepares for division by synthesizing proteins needed for mitosis. Interphase occupies about 90% of the cell cycle.

Mitosis is the division of the nucleus into two genetically identical daughter nuclei, consisting of four stages. In prophase, chromatin condenses into visible chromosomes, each consisting of two sister chromatids joined at the centromere. The mitotic spindle begins forming. In metaphase, chromosomes line up along the cell's equator (the metaphase plate), attached to spindle fibers at their centromeres. In anaphase, the centromeres split and sister chromatids are pulled to opposite poles of the cell. In telophase, chromosomes decondense, nuclear envelopes reform around each set, and the spindle disassembles.

Cytokinesis, the division of the cytoplasm, typically overlaps with telophase. In animal cells, a cleavage furrow forms as a ring of actin filaments contracts, pinching the cell in two. In plant cells, a cell plate forms down the middle from vesicles that fuse to create a new cell wall. Cell cycle checkpoints at G1, G2, and during metaphase ensure that the cell is ready to proceed. When these checkpoints fail, uncontrolled cell division can lead to cancer. Tumor suppressor genes like p53 play a critical role in stopping the cell cycle when DNA damage is detected.
""", duration: 25, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Meiosis and Genetic Variation", content: """
Meiosis is a specialized form of cell division that produces four genetically unique haploid cells from one diploid parent cell. While mitosis maintains the chromosome number for growth and repair, meiosis reduces the chromosome number by half, creating gametes (eggs and sperm) for sexual reproduction. In humans, meiosis reduces the chromosome number from 46 (diploid) to 23 (haploid) in each gamete.

Meiosis consists of two rounds of division. In meiosis I, homologous chromosomes pair up during prophase I in a process called synapsis. Crossing over occurs when homologous chromosomes exchange segments of DNA, creating new combinations of alleles. During metaphase I, homologous pairs line up at the metaphase plate, and the orientation of each pair is random — this is independent assortment. In anaphase I, homologous chromosomes (not sister chromatids) separate. The result of meiosis I is two haploid cells, each with one chromosome from each homologous pair.

Meiosis II resembles mitosis: sister chromatids separate in each of the two haploid cells, producing four haploid daughter cells total. Three mechanisms generate genetic variation during meiosis: crossing over shuffles alleles between homologous chromosomes, independent assortment randomly distributes maternal and paternal chromosomes, and random fertilization combines two unique gametes. With 23 chromosome pairs in humans, independent assortment alone can produce over 8 million different gamete combinations — and crossing over multiplies that number enormously.
""", duration: 28, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "DNA Replication", content: """
DNA replication is the process by which a cell copies its entire genome before division, ensuring that each daughter cell receives an identical set of genetic instructions. Replication is semiconservative, meaning each new DNA molecule contains one original (parent) strand and one newly synthesized strand. This was demonstrated by the famous Meselson-Stahl experiment in 1958 using nitrogen isotopes.

Replication begins at specific sequences called origins of replication, where the enzyme helicase unwinds the double helix by breaking the hydrogen bonds between complementary base pairs, creating a replication fork. Single-strand binding proteins prevent the separated strands from re-annealing. Topoisomerase relieves the tension ahead of the replication fork. DNA primase synthesizes a short RNA primer that provides a free 3' hydroxyl group for DNA polymerase III to begin adding nucleotides.

DNA polymerase III synthesizes new DNA in the 5' to 3' direction by adding complementary nucleotides — adenine pairs with thymine, cytosine pairs with guanine. The leading strand is synthesized continuously toward the replication fork. The lagging strand is synthesized in short fragments called Okazaki fragments, each requiring its own RNA primer. DNA polymerase I replaces the RNA primers with DNA, and DNA ligase seals the gaps between fragments. The proofreading ability of DNA polymerase gives replication remarkable accuracy, with only about one error per billion nucleotides.
""", duration: 25, isCompleted: false, type: .video, xpReward: 0),
            ], orderIndex: 1),

            Module(id: UUID(), title: "Genetics and Heredity", lessons: [
                Lesson(id: UUID(), title: "Mendelian Genetics", content: """
Gregor Mendel, an Austrian monk working with pea plants in the 1860s, discovered the fundamental laws of inheritance that bear his name. Through careful cross-breeding experiments tracking traits like flower color, seed shape, and plant height, Mendel determined that traits are controlled by discrete units (now called genes) that come in pairs and separate during gamete formation.

Mendel's Law of Segregation states that each organism carries two alleles for each trait, and these alleles separate during meiosis so that each gamete carries only one allele. His Law of Independent Assortment states that alleles for different traits are distributed independently of one another during gamete formation. A Punnett square is a visual tool for predicting the genotype and phenotype ratios of offspring. For a monohybrid cross between two heterozygous parents (Aa x Aa), the expected genotype ratio is 1 AA : 2 Aa : 1 aa, and the phenotype ratio is 3 dominant : 1 recessive.

Dominant alleles mask the expression of recessive alleles in heterozygous individuals. An organism's genotype is its genetic makeup (e.g., Bb), while its phenotype is the observable trait (e.g., brown eyes). Homozygous dominant (BB) and heterozygous (Bb) individuals display the same phenotype but have different genotypes. A test cross — crossing an organism with a dominant phenotype with a homozygous recessive individual — can determine whether the dominant organism is homozygous or heterozygous based on the offspring ratios.
""", duration: 22, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Beyond Mendel: Complex Inheritance", content: """
While Mendel's laws provide the foundation, many traits follow more complex inheritance patterns. Incomplete dominance occurs when the heterozygous phenotype is a blend of the two homozygous phenotypes. In snapdragons, crossing a red-flowered plant (RR) with a white-flowered plant (WW) produces pink-flowered offspring (RW). Codominance occurs when both alleles are fully expressed, as in human blood type: individuals with genotype IAIB express both A and B antigens on their red blood cells.

Polygenic traits are controlled by multiple genes, each contributing a small effect to the phenotype. Human height, skin color, and intelligence are polygenic traits that show continuous variation in a population, producing a bell-shaped distribution curve rather than distinct categories. Environmental factors also influence polygenic traits, making the relationship between genotype and phenotype more complex. Pleiotropy describes the situation where a single gene affects multiple, seemingly unrelated traits — the sickle cell gene, for example, affects red blood cell shape, oxygen transport, and malaria resistance.

Epistasis occurs when one gene affects the expression of another gene at a different locus. In Labrador retrievers, one gene controls pigment color (black vs. brown) and another controls whether pigment is deposited at all. A dog that is homozygous recessive at the deposition gene will be yellow regardless of its genotype at the color gene. Sex-linked traits, carried on the X chromosome, show different inheritance patterns in males and females. Males are more likely to express X-linked recessive conditions like red-green color blindness because they have only one X chromosome.
""", duration: 26, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Gene Expression: From DNA to Protein", content: """
The central dogma of molecular biology describes the flow of genetic information: DNA is transcribed into messenger RNA (mRNA), which is then translated into protein. This two-step process converts the genetic code stored in the nucleus into functional proteins that carry out virtually all cellular activities, from catalyzing metabolic reactions to providing structural support.

Transcription occurs in the nucleus when RNA polymerase binds to a promoter region upstream of a gene and synthesizes a complementary mRNA strand from the template DNA strand. In eukaryotes, the initial mRNA transcript (pre-mRNA) undergoes processing: a 5' cap and poly-A tail are added for stability, and introns (non-coding sequences) are removed by spliceosomes, leaving only exons (coding sequences) in the mature mRNA. Alternative splicing allows a single gene to code for multiple proteins by combining different sets of exons.

Translation takes place at ribosomes in the cytoplasm. The mRNA codons (three-nucleotide sequences) are read by transfer RNA (tRNA) molecules, each carrying a specific amino acid. The ribosome moves along the mRNA, matching codons to anticodons and linking amino acids together with peptide bonds. Translation begins at the start codon AUG (methionine) and continues until a stop codon (UAA, UAG, or UGA) is reached. The resulting polypeptide chain then folds into its functional three-dimensional shape, sometimes with the help of chaperone proteins.
""", duration: 28, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 2),
        ]
    }

    // MARK: - History Modules (World History)

    private func makeHistoryModules() -> [Module] {
        [
            Module(id: UUID(), title: "Ancient Civilizations", lessons: [
                Lesson(id: UUID(), title: "Mesopotamia: Cradle of Civilization", content: """
Mesopotamia, the land between the Tigris and Euphrates rivers in modern-day Iraq, is widely regarded as the birthplace of civilization. Around 3500 BCE, the Sumerians developed one of the world's first writing systems — cuneiform — pressing wedge-shaped marks into clay tablets to record everything from trade transactions to epic literature. The Sumerians also invented the wheel, the plow, and a number system based on 60 that still influences our measurement of time and angles today.

The city-states of Sumer, including Ur, Uruk, and Lagash, were governed by kings who claimed divine authority. Each city had a central ziggurat — a massive stepped temple that served as both a religious center and an administrative hub. Sumerian society was hierarchical, with priests and rulers at the top, followed by merchants, artisans, farmers, and enslaved people. Agriculture thrived thanks to sophisticated irrigation systems that channeled river water to fields, but the accumulation of salt in the soil eventually contributed to Sumer's decline.

The Babylonian Empire, under King Hammurabi around 1792 BCE, united much of Mesopotamia and produced one of the earliest written legal codes. The Code of Hammurabi contained 282 laws covering property rights, trade, family relations, and criminal justice, applying the principle of lex talionis — an eye for an eye. Later, the Assyrian Empire dominated the region through military innovation, including iron weapons and siege warfare. The Neo-Babylonian Empire under Nebuchadnezzar II built the legendary Hanging Gardens and conquered Jerusalem in 586 BCE.
""", duration: 18, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Ancient Egypt: Empire of the Nile", content: """
Ancient Egyptian civilization flourished along the Nile River for over 3,000 years, from roughly 3100 BCE to 30 BCE. The Nile's annual flooding deposited nutrient-rich silt on the riverbanks, creating extraordinarily fertile farmland in the midst of desert. This agricultural abundance supported a complex society governed by pharaohs — rulers who were considered living gods, serving as both political leaders and religious intermediaries between the people and the divine.

Egypt's history is divided into the Old Kingdom, Middle Kingdom, and New Kingdom, separated by intermediate periods of political fragmentation. The Old Kingdom (c. 2686-2181 BCE) was the age of the great pyramids. The Great Pyramid of Giza, built for Pharaoh Khufu, required an estimated 2.3 million limestone blocks and took roughly 20 years to construct. These monuments were not built by slaves, as commonly believed, but by paid laborers and skilled craftsmen organized into work crews.

The Egyptians developed hieroglyphic writing, a calendar of 365 days, advanced mathematics, and remarkable medical knowledge. They believed in an afterlife and developed elaborate mummification techniques to preserve the body. The Book of the Dead contained spells to guide the deceased through the underworld. During the New Kingdom (c. 1550-1070 BCE), Egypt reached its greatest territorial extent under pharaohs like Thutmose III and Ramesses II. Queen Hatshepsut, one of the few female pharaohs, expanded trade networks and commissioned ambitious building projects during her prosperous 22-year reign.
""", duration: 20, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Ancient Greece: Foundations of the West", content: """
Ancient Greece, spanning roughly from 800 BCE to 146 BCE, laid the intellectual and political foundations of Western civilization. Unlike Egypt or Mesopotamia, Greece was divided into independent city-states (poleis), each with its own government and culture. Athens developed the world's first direct democracy around 508 BCE under the reforms of Cleisthenes, where male citizens could vote on laws and policies in the Assembly. Sparta, in contrast, was a military state where citizens trained for warfare from age seven.

The classical period (5th-4th centuries BCE) produced an extraordinary explosion of achievement in philosophy, science, art, and literature. Socrates pioneered the method of systematic questioning, Plato wrote philosophical dialogues exploring justice and the ideal state, and Aristotle made foundational contributions to logic, biology, ethics, and political theory. Greek dramatists like Sophocles and Euripides created tragedies that explored the human condition, while Herodotus and Thucydides established the discipline of historical writing.

The Greco-Persian Wars (490-479 BCE) united the Greek city-states against the Persian Empire. Victories at Marathon, Thermopylae, and Salamis preserved Greek independence and ushered in the golden age of Athens under Pericles. However, rivalry between Athens and Sparta led to the devastating Peloponnesian War (431-404 BCE). The subsequent weakening of the city-states set the stage for Philip II of Macedon and his son Alexander the Great, whose conquests spread Greek language and culture from Egypt to India in the Hellenistic period.
""", duration: 22, isCompleted: true, type: .reading, xpReward: 0),
            ], orderIndex: 0),

            Module(id: UUID(), title: "The Roman Empire", lessons: [
                Lesson(id: UUID(), title: "The Roman Republic", content: """
Rome began as a small settlement on the Tiber River in central Italy, traditionally founded in 753 BCE. After overthrowing their Etruscan kings around 509 BCE, the Romans established a republic governed by elected officials and a complex system of checks and balances. Two consuls shared executive power and served one-year terms, while the Senate — composed of former magistrates — advised on policy and controlled finances. The Roman system of government profoundly influenced the framers of the United States Constitution.

The Conflict of the Orders, spanning nearly two centuries, shaped the republic's political development. Patricians (the hereditary aristocracy) initially held all political power, but the plebeians (common citizens) gradually won rights through organized protests. The creation of the Tribune of the Plebs gave commoners an official voice, and the Twelve Tables (c. 450 BCE) established written law that applied to all citizens. Roman law, with its emphasis on precedent, citizens' rights, and innocent-until-proven-guilty, remains a cornerstone of legal systems worldwide.

The republic expanded through a combination of military conquest and strategic alliances. The Punic Wars against Carthage (264-146 BCE) established Rome's dominance over the western Mediterranean. The brilliant Carthaginian general Hannibal famously crossed the Alps with war elephants, winning spectacular victories at Trebia, Lake Trasimene, and Cannae. But Rome's vast resources and resilience ultimately prevailed. By the 1st century BCE, internal conflicts between powerful generals like Marius, Sulla, Pompey, and Julius Caesar undermined republican institutions and paved the way for one-man rule.
""", duration: 22, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Rise and Height of the Empire", content: """
The Roman Republic gave way to the Roman Empire when Octavian, Julius Caesar's adopted heir, defeated his rivals and became Augustus — the first Roman Emperor — in 27 BCE. Augustus maintained the appearance of republican government while consolidating real power in his own hands. His reign inaugurated the Pax Romana, a roughly 200-year period of relative peace and stability across the Mediterranean world that allowed trade, culture, and infrastructure to flourish on an unprecedented scale.

At its height under Emperor Trajan (98-117 CE), the Roman Empire stretched from Britain to Mesopotamia, encompassing roughly 5 million square kilometers and 70 million people. Roman engineering achievements were extraordinary: a road network exceeding 80,000 kilometers connected the empire, aqueducts carried fresh water to cities, and concrete construction techniques produced buildings like the Pantheon that still stand today. The Colosseum, completed in 80 CE, could seat 50,000 spectators for gladiatorial contests and public spectacles.

Roman culture blended native traditions with Greek influences. Latin became the lingua franca of the western empire, eventually evolving into the Romance languages (French, Spanish, Italian, Portuguese, and Romanian). Roman literature produced masters like Virgil, Ovid, and Cicero. Roman law continued to develop, and Justinian's later codification preserved it for posterity. The empire also facilitated the spread of Christianity, which grew from a small Jewish sect into the official religion of the empire by the late 4th century under Emperor Theodosius.
""", duration: 25, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Fall of the Western Empire", content: """
The decline of the Western Roman Empire was a gradual process driven by a combination of internal weaknesses and external pressures. By the 3rd century, the empire faced a crisis: rapid turnover of emperors (over 25 in 50 years), devastating plagues, economic inflation, and increasing difficulty defending long borders against barbarian incursions. Emperor Diocletian attempted to stabilize the empire by dividing it into eastern and western halves, each with its own co-emperor.

Constantine the Great reunified the empire temporarily and established a new eastern capital at Constantinople (modern Istanbul) in 330 CE. His conversion to Christianity and the Edict of Milan (313 CE) transformed the religious landscape of the empire. However, the western half continued to weaken. The Roman army increasingly relied on Germanic mercenaries, blurring the line between Roman and barbarian. Wealth and population shifted eastward, leaving the west economically and militarily depleted.

The final decades of the Western Empire saw a succession of ineffective child emperors controlled by powerful generals, many of Germanic origin. The Visigoths sacked Rome in 410 CE, shocking the Mediterranean world. The Vandals sacked it again in 455 CE. In 476 CE, the Germanic chieftain Odoacer deposed the last Western Emperor, Romulus Augustulus, marking the traditional end of the Western Roman Empire. The Eastern Roman Empire (Byzantine Empire) continued for nearly another thousand years, preserving Roman law, Greek learning, and Orthodox Christianity until Constantinople fell to the Ottoman Turks in 1453.
""", duration: 24, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 1),

            Module(id: UUID(), title: "Medieval Europe", lessons: [
                Lesson(id: UUID(), title: "The Feudal System", content: """
After the fall of the Western Roman Empire, Europe entered a period of political fragmentation and economic contraction often called the Early Middle Ages (c. 500-1000 CE). Central authority collapsed, trade declined, and cities shrank as people retreated to the countryside for safety. In this vacuum, feudalism emerged as a decentralized system of governance based on mutual obligations between lords and vassals. A king granted land (fiefs) to powerful nobles in exchange for military service and loyalty.

The feudal hierarchy placed the king at the top, followed by great nobles (dukes, counts, and barons), lesser lords (knights), and peasants at the bottom. Most peasants were serfs — not enslaved, but bound to the land they worked. They owed their lord labor, a share of their harvest, and various fees, and could not leave without permission. In return, the lord provided protection and the use of farmland. The manor was the basic economic unit, largely self-sufficient with its own fields, pastures, workshops, and mill.

The medieval Church was the most powerful institution in Europe, providing spiritual guidance, education, and social services. Monasteries preserved classical texts, developed agricultural techniques, and operated schools. The Pope wielded enormous political as well as spiritual authority, sometimes clashing with kings over the appointment of bishops and other matters. The investiture controversy between Pope Gregory VII and Holy Roman Emperor Henry IV (1076-1122) exemplified the ongoing tension between religious and secular power that defined much of medieval political life.
""", duration: 22, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "The Crusades", content: """
The Crusades were a series of religious wars launched by Western European Christians between 1096 and 1291, primarily aimed at recapturing the Holy Land from Muslim control. Pope Urban II called the First Crusade in 1095, urging Christian knights to liberate Jerusalem. Motivated by religious zeal, promises of spiritual rewards, desire for land and wealth, and a spirit of adventure, tens of thousands of Europeans marched eastward. The First Crusade succeeded in capturing Jerusalem in 1099 and establishing several Crusader states.

The Second Crusade (1147-1149) was launched after Muslim forces recaptured the Crusader state of Edessa but ended in failure. The great Muslim leader Saladin unified Egypt and Syria and recaptured Jerusalem in 1187, prompting the Third Crusade (1189-1192). This crusade featured legendary figures like Richard the Lionheart of England and Saladin, who developed a mutual respect despite being adversaries. Richard won several battles but could not retake Jerusalem; the two leaders eventually negotiated a truce allowing Christian pilgrims access to holy sites.

The later Crusades were increasingly disastrous. The Fourth Crusade (1202-1204) never reached the Holy Land — the Crusaders instead sacked the Christian city of Constantinople, deepening the rift between Western and Eastern Christianity. Subsequent crusades achieved little, and the last Crusader stronghold at Acre fell in 1291. The Crusades had lasting consequences: they increased European contact with the Islamic world, stimulating trade and the exchange of knowledge in mathematics, medicine, and philosophy. They also strengthened royal authority, weakened feudal nobility, and fostered a spirit of intolerance that cast a long shadow over interfaith relations.
""", duration: 26, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "The Renaissance Begins", content: """
The Renaissance, meaning "rebirth," was a cultural and intellectual movement that began in Italy around 1350 and gradually spread across Europe over the next two centuries. It was characterized by a renewed interest in the classical civilizations of Greece and Rome, a shift toward secular thinking alongside continued religious devotion, and an emphasis on humanism — the belief in the potential and dignity of the individual. The Italian city-states of Florence, Venice, and Rome became centers of this cultural revolution.

Wealthy merchant families like the Medici of Florence patronized artists, scholars, and architects. Renaissance art broke from the flat, symbolic style of the Middle Ages, embracing realism, perspective, and the study of human anatomy. Leonardo da Vinci exemplified the "Renaissance man," excelling in painting (the Mona Lisa, The Last Supper), science, engineering, and anatomy. Michelangelo's sculpture of David and his ceiling frescoes in the Sistine Chapel demonstrated unprecedented technical mastery and emotional power. Raphael, Botticelli, and Titian further enriched the artistic landscape.

The Renaissance also transformed intellectual life. Humanist scholars like Petrarch and Erasmus studied classical texts, promoted education in the humanities (grammar, rhetoric, history, poetry, and philosophy), and applied critical thinking to both secular and religious questions. Niccolo Machiavelli's The Prince analyzed political power with unprecedented realism. Johannes Gutenberg's printing press (c. 1440) revolutionized the spread of knowledge by making books affordable and widely available for the first time. This technological breakthrough would later fuel the Protestant Reformation by enabling the rapid dissemination of new ideas.
""", duration: 24, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 2),
        ]
    }

    // MARK: - English Modules (English Literature)

    private func makeEnglishModules() -> [Module] {
        [
            Module(id: UUID(), title: "Poetry Analysis", lessons: [
                Lesson(id: UUID(), title: "Romantic Poetry", content: """
The Romantic movement in poetry, flourishing from the late 18th to mid-19th century, was a reaction against the rationalism of the Enlightenment and the mechanization of the Industrial Revolution. Romantic poets celebrated emotion, imagination, nature, and individual experience. They believed that deep feeling and personal intuition were just as valid as reason in understanding the world. William Wordsworth and Samuel Taylor Coleridge launched the movement with their joint publication Lyrical Ballads in 1798.

Wordsworth defined poetry as "the spontaneous overflow of powerful feelings recollected in tranquillity." His poems often drew on simple, everyday language and rural settings to explore profound themes. "Tintern Abbey" meditates on the relationship between nature and the human mind, tracing how the speaker's experience of landscape evolves over time from pure sensory delight to a deeper philosophical awareness. Coleridge's "The Rime of the Ancient Mariner" uses supernatural imagery and ballad form to explore guilt, redemption, and humanity's relationship with the natural world.

The second generation of Romantic poets — John Keats, Percy Bysshe Shelley, and Lord Byron — pushed the movement in new directions. Keats's odes, particularly "Ode to a Nightingale" and "Ode on a Grecian Urn," explore the tension between the permanence of art and the transience of human life. His concept of "negative capability" — the ability to remain comfortable with uncertainty and mystery — remains influential in literary criticism. Shelley's "Ozymandias" uses the image of a ruined statue in the desert to comment on the impermanence of political power, while Byron's Don Juan combined satire with lyric beauty.
""", duration: 15, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Modern Poetry", content: """
Modern poetry, emerging in the early 20th century, represented a radical break from traditional forms and conventions. Modernist poets rejected the ornate language and regular meter of their predecessors, experimenting with free verse, fragmentation, and allusion. T.S. Eliot's "The Waste Land" (1922) is considered a landmark of modernism — a dense, multilingual collage of literary references, mythology, and contemporary imagery that captures the spiritual crisis of post-World War I Europe.

Eliot's "The Love Song of J. Alfred Prufrock" introduced the dramatic monologue of a paralyzed, self-conscious modern man unable to connect meaningfully with others. Its famous opening — comparing the evening sky to "a patient etherised upon a table" — shocked readers with its unromantic imagery. William Butler Yeats bridged the Romantic and Modern periods, moving from Celtic mythology to a more symbolic, apocalyptic vision in poems like "The Second Coming," which famously declares that "the centre cannot hold."

Later in the 20th century, poets continued to expand the boundaries of the form. Langston Hughes brought the rhythms of jazz and blues into his poetry, giving voice to the African American experience during the Harlem Renaissance. Maya Angelou's "Still I Rise" is a powerful anthem of resilience against racial and gender oppression, using repetition and direct address to create a defiant, uplifting tone. Sylvia Plath's confessional poetry explored personal suffering with vivid, sometimes disturbing imagery. These diverse voices demonstrate that poetry remains a living art form, constantly reinventing itself to speak to new audiences and experiences.
""", duration: 18, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Poetic Devices and Analysis", content: """
Analyzing poetry requires close attention to the specific choices a poet makes with language, form, and sound. Literary devices are the tools poets use to create meaning beyond the literal content of their words. Metaphor compares two unlike things without using "like" or "as" — when Shakespeare writes "all the world's a stage," he invites us to see life itself as a performance. Simile makes the comparison explicit: Burns's "my love is like a red, red rose" draws a clear parallel between the beloved and the flower's beauty and fragrance.

Sound devices contribute to a poem's musicality and emotional impact. Alliteration (repeated consonant sounds at the beginning of words) creates rhythm and emphasis, as in Poe's "deep into that darkness peering." Assonance (repeated vowel sounds within words) produces a subtler musical effect. Onomatopoeia uses words that imitate sounds — "buzz," "hiss," "murmur." Rhyme and meter create patterns that can reinforce meaning: iambic pentameter (five pairs of unstressed-stressed syllables per line) has a heartbeat-like rhythm that sounds natural in English.

When analyzing a poem, consider both what is said and how it is said. Identify the speaker and their tone — is it wistful, angry, celebratory, ironic? Examine the poem's structure: Does the form (sonnet, villanelle, free verse) reinforce the theme? Look for imagery — vivid sensory details that create pictures in the reader's mind. Consider symbolism — objects or images that represent something beyond their literal meaning. Finally, pay attention to shifts in tone, subject, or perspective, which often occur at key structural points and signal the poem's deeper argument or emotional arc.
""", duration: 20, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 0),

            Module(id: UUID(), title: "Shakespeare", lessons: [
                Lesson(id: UUID(), title: "Introduction to Shakespeare", content: """
William Shakespeare (1564-1616) is widely regarded as the greatest writer in the English language. Born in Stratford-upon-Avon, he became an actor, playwright, and part-owner of the Globe Theatre in London. Over his career, he wrote 37 plays, 154 sonnets, and several longer poems, creating works of such psychological depth, linguistic richness, and universal appeal that they remain central to literature and theater more than 400 years later.

Shakespeare's plays fall into three main categories: comedies, tragedies, and histories, with a late group sometimes called romances. His comedies — including A Midsummer Night's Dream, Much Ado About Nothing, and Twelfth Night — feature mistaken identities, witty wordplay, romantic entanglements, and happy endings (usually marriages). His tragedies — Hamlet, Macbeth, Othello, and King Lear — explore the downfall of a noble protagonist through a fatal flaw, bad fortune, or both. His history plays dramatize the reigns of English kings, exploring themes of power, legitimacy, and national identity.

Shakespeare's language can seem daunting at first, but it rewards patient reading. He wrote primarily in blank verse (unrhymed iambic pentameter), which gives his dialogue a natural, elevated rhythm. He invented or popularized over 1,700 words, including "eyeball," "lonely," "generous," and "assassination." His metaphors have become so embedded in English that we use them without realizing their origin: "break the ice," "wild goose chase," "heart of gold." Understanding Shakespeare's language is not just an exercise in literary history — it is an exploration of the origins of modern English expression.
""", duration: 20, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Hamlet: Themes and Analysis", content: """
Hamlet, written around 1600, is Shakespeare's most famous and most analyzed play. The story follows Prince Hamlet of Denmark, who learns from his father's ghost that his uncle Claudius murdered the king and married Hamlet's mother, Gertrude. Hamlet vows revenge but is paralyzed by indecision, philosophical doubt, and moral complexity. His famous soliloquy "To be or not to be" explores the question of whether it is nobler to endure life's suffering or to take action against it — even if that action is death.

The theme of appearance versus reality runs throughout the play. Claudius appears to be a caring stepfather but is actually a murderer. Hamlet feigns madness to investigate his uncle's guilt, but the line between his performance and genuine psychological disturbance becomes increasingly blurred. The play-within-a-play, "The Mousetrap," is Hamlet's attempt to use theatrical illusion to expose real truth. Polonius, Rosencrantz, and Guildenstern all perform roles of loyalty while secretly serving Claudius, and Ophelia's descent into genuine madness contrasts with Hamlet's strategic performance.

Hamlet also explores the theme of moral corruption spreading outward. Claudius's initial crime contaminates everything it touches: Gertrude's marriage is tainted, the court becomes a place of surveillance and betrayal, and Hamlet's quest for justice leads to the deaths of innocent people, including Polonius and Ophelia. The famous line "Something is rotten in the state of Denmark" captures the sense of moral decay that pervades the play. By the final scene, nearly every major character is dead, suggesting that in a world where justice is delayed and compromised, the consequences are catastrophic for everyone.
""", duration: 25, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Shakespeare's Sonnets", content: """
Shakespeare's 154 sonnets, published in 1609, are among the most celebrated poems in the English language. They follow the English (Shakespearean) sonnet form: 14 lines of iambic pentameter organized into three quatrains and a concluding couplet, with the rhyme scheme ABAB CDCD EFEF GG. The three quatrains typically develop an idea or argument, and the couplet provides a surprising turn, resolution, or summary. This structure creates a natural rhythm of development and conclusion.

The first 126 sonnets are addressed to a young man, often called the "Fair Youth," and explore themes of beauty, time, love, and artistic immortality. In Sonnet 18 ("Shall I compare thee to a summer's day?"), Shakespeare argues that while summer is temporary and imperfect, the beloved's beauty will be preserved forever through the poem itself: "So long as men can breathe or eyes can see, / So long lives this, and this gives life to thee." This theme of poetry's power to defeat time recurs throughout the sequence.

Sonnets 127-152 are addressed to a mysterious "Dark Lady" and take a dramatically different tone. Where the Fair Youth sonnets idealize and elevate, the Dark Lady sonnets are passionate, conflicted, and sometimes brutally honest about physical desire. Sonnet 130 ("My mistress' eyes are nothing like the sun") deliberately rejects the conventions of Petrarchan love poetry by describing the beloved in unflattering realistic terms, yet the final couplet insists that this real woman is "as rare / As any she belied with false compare." Shakespeare thus argues that genuine love does not need the crutch of exaggerated comparisons.
""", duration: 22, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 1),

            Module(id: UUID(), title: "Essay Writing", lessons: [
                Lesson(id: UUID(), title: "Crafting a Thesis Statement", content: """
A thesis statement is the central argument or claim of an essay, typically expressed in one or two sentences at the end of the introduction. A strong thesis is specific, arguable, and provides a roadmap for the rest of the paper. It should not simply state a fact ("Shakespeare wrote Hamlet") but make a claim that requires evidence and analysis to support ("Hamlet's delay in avenging his father's murder stems not from cowardice but from a philosophical crisis about the nature of justice and action").

Developing a thesis begins with a question or problem. Start by asking yourself what interests you about the text, what patterns you notice, or what seems surprising or contradictory. Then move from observation to interpretation. If you notice that images of decay and disease appear throughout Hamlet, ask yourself why Shakespeare might use that pattern. Your thesis might argue that these images reflect the play's larger theme of moral corruption spreading through the Danish court.

A common mistake is writing a thesis that is too broad ("Shakespeare is a great writer") or too vague ("Hamlet is about many things"). A good thesis is precise enough to guide your argument but rich enough to sustain a full essay. Test your thesis by asking: Could a reasonable person disagree with this? If not, your claim may be too obvious. Can I support this with specific evidence from the text? If not, it may be too speculative. The thesis should evolve as you write — your best thesis often emerges after you have drafted and revised your argument, not before.
""", duration: 18, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Using Textual Evidence", content: """
Literary analysis essays must be grounded in specific evidence from the text. Textual evidence includes direct quotations, paraphrases, and references to specific scenes, images, or structural features. The key to using evidence effectively is not just inserting quotations but integrating them into your own argument and explaining how they support your point. Every quotation should be introduced, presented, and analyzed — a pattern sometimes called the "quote sandwich."

When introducing a quotation, provide context so the reader understands where it comes from and why it matters. Use a signal phrase that attributes the words and sets up the connection to your argument: "When Hamlet muses, 'To be or not to be, that is the question,' he frames his existential crisis in the starkest possible terms, reducing the complexity of his situation to a binary choice between existence and oblivion." After the quotation, always provide analysis — explain what the words mean, why the author chose them, and how they support your thesis.

Effective analysis goes beyond paraphrasing or summarizing what the quotation says. Instead, focus on how the language works. Examine word choice (diction), sentence structure (syntax), figurative language, and tone. Ask yourself: Why did the author choose this particular word? What associations does it carry? How does the rhythm or sound of the language contribute to the meaning? For example, noting that Hamlet uses the word "question" rather than "dilemma" or "problem" suggests an intellectual, philosophical approach to his suffering rather than a purely emotional response.
""", duration: 20, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Revision and Polishing", content: """
Revision is not merely proofreading for typos and grammatical errors — it is the process of re-seeing your essay at every level, from the overall argument to individual sentences. Professional writers understand that good writing is rewriting. Begin revision by stepping back from your draft for at least a few hours (ideally a day) so you can read it with fresh eyes. Then evaluate the big picture first: Is the thesis clear and arguable? Does each paragraph contribute to the central argument? Is the organization logical?

At the paragraph level, check that each body paragraph has a clear topic sentence that connects to the thesis, sufficient textual evidence, and thorough analysis. Ensure smooth transitions between paragraphs — each paragraph should logically follow from the previous one. Cut any material that does not directly support your argument, no matter how interesting it is. This is sometimes called "killing your darlings." A focused, streamlined essay is always more effective than one that tries to cover too much ground.

At the sentence level, aim for clarity and precision. Eliminate unnecessary words and phrases ("it is important to note that" can usually be cut entirely). Vary sentence length and structure to create a pleasing rhythm. Replace vague words with specific ones: instead of "Shakespeare uses a lot of imagery," write "Shakespeare saturates the opening scene with images of rot and decay." Read your essay aloud — your ear will catch awkward phrasing, repetition, and unclear passages that your eye might miss. Finally, proofread carefully for grammar, punctuation, and formatting according to the required style guide (MLA, APA, or Chicago).
""", duration: 18, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 2),
        ]
    }

    // MARK: - Computer Science Modules (Intro to CS)

    private func makeCSModules() -> [Module] {
        [
            Module(id: UUID(), title: "Introduction to Programming", lessons: [
                Lesson(id: UUID(), title: "What is Programming?", content: """
Programming is the process of creating instructions that a computer can follow to perform specific tasks. These instructions, written in a programming language, are called code. Just as humans communicate using natural languages like English or Spanish, programmers communicate with computers using languages like Python, Java, and JavaScript. Each language has its own syntax (rules for writing code) and semantics (meaning of the code).

At its core, programming is about problem-solving. Before writing any code, a programmer must understand the problem, break it down into smaller steps, and design a solution. This process is called computational thinking. It involves four key skills: decomposition (breaking a complex problem into smaller parts), pattern recognition (finding similarities among problems), abstraction (focusing on important details while ignoring irrelevant ones), and algorithm design (creating step-by-step instructions to solve each part).

Python is an excellent language for beginners because its syntax is clean and readable, closely resembling plain English. A simple Python program to display a greeting looks like this: print("Hello, World!"). This single line of code calls the print function and passes it a string of text. Python is used in web development, data science, artificial intelligence, and automation, making it one of the most versatile and in-demand programming languages in the world.
""", duration: 15, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Variables and Data Types", content: """
Variables are named containers that store data in a program. Think of a variable as a labeled box — the label is the variable name, and the contents are the value. In Python, you create a variable by assigning a value to a name using the equals sign: age = 16, name = "Alex", gpa = 3.7. Unlike some languages, Python does not require you to declare the type of a variable — it figures out the type automatically based on the value you assign.

Python has several built-in data types. Integers (int) are whole numbers like 42, -7, or 0. Floating-point numbers (float) have decimal points, like 3.14 or -0.5. Strings (str) are sequences of characters enclosed in quotes, like "Hello" or 'WolfWhale Academy'. Booleans (bool) represent truth values and can only be True or False. Lists are ordered collections that can hold multiple values: grades = [92, 88, 95, 91].

Type conversion lets you change a value from one type to another. The int() function converts to an integer, float() converts to a float, and str() converts to a string. This is important when combining different types — for example, you cannot directly concatenate a string and a number. Instead, you would write: "Your age is " + str(age). Understanding data types helps you avoid common errors and write more reliable code.
""", duration: 18, isCompleted: true, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Control Flow: Conditionals and Loops", content: """
Control flow determines the order in which statements are executed in a program. By default, Python executes code line by line from top to bottom. Conditional statements (if, elif, else) allow your program to make decisions based on conditions. For example: if grade >= 90: print("A") elif grade >= 80: print("B") else: print("Below B"). The condition is evaluated as True or False, and only the corresponding block of code runs.

Comparison operators are used in conditions: == (equal to), != (not equal to), > (greater than), < (less than), >= (greater than or equal to), and <= (less than or equal to). Logical operators combine multiple conditions: and (both must be true), or (at least one must be true), and not (reverses the truth value). For example: if age >= 13 and has_permission: print("Access granted").

Loops allow you to repeat code multiple times. A for loop iterates over a sequence: for student in students: print(student). A while loop repeats as long as a condition is true: while attempts < 3: get_password(). The break statement exits a loop early, and continue skips to the next iteration. Loops are essential for processing lists, reading files, and any task that involves repetition. Be careful with while loops — if the condition never becomes False, you create an infinite loop that will freeze your program.
""", duration: 20, isCompleted: true, type: .reading, xpReward: 0),
            ], orderIndex: 0),

            Module(id: UUID(), title: "Functions and Data Structures", lessons: [
                Lesson(id: UUID(), title: "Writing Functions", content: """
Functions are reusable blocks of code that perform a specific task. They help you organize your code, avoid repetition, and make your programs easier to read and debug. In Python, you define a function using the def keyword, followed by the function name and parentheses containing any parameters: def calculate_average(scores): total = sum(scores) return total / len(scores).

Parameters are the variables listed in the function definition — they act as placeholders for the actual values (arguments) that will be passed when the function is called. Functions can have default parameter values: def greet(name, greeting="Hello"): return f"{greeting}, {name}!". When you call greet("Alex"), it uses the default greeting. When you call greet("Alex", "Hey"), it uses the custom greeting.

The return statement sends a value back to the code that called the function. A function can return any type of value — a number, string, list, or even another function. If a function has no return statement, it returns None by default. Good functions follow the single responsibility principle: each function should do one thing and do it well. Breaking your code into small, focused functions makes it modular and testable. You can even write functions that call other functions, building complex behavior from simple pieces.
""", duration: 20, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Lists and Dictionaries", content: """
Lists and dictionaries are Python's most commonly used data structures. A list is an ordered, mutable collection of items: fruits = ["apple", "banana", "cherry"]. You access items by their index (starting at 0): fruits[0] returns "apple". Lists support operations like append() to add items, remove() to delete items, sort() to arrange items, and len() to count items. List slicing lets you extract portions: fruits[1:3] returns ["banana", "cherry"].

Dictionaries store data as key-value pairs, like a real dictionary maps words to definitions. Create a dictionary with curly braces: student = {"name": "Alex", "grade": 10, "gpa": 3.7}. Access values by their keys: student["name"] returns "Alex". Dictionaries are incredibly useful for organizing related data. You can add new entries (student["email"] = "alex@school.edu"), update existing ones, or remove them with del.

List comprehensions provide a concise way to create lists: squares = [x**2 for x in range(10)] creates a list of squares from 0 to 81. You can add conditions: passing = [s for s in scores if s >= 60]. Nested data structures — like lists of dictionaries — are common in real-world programming. For example, a classroom might be represented as: students = [{"name": "Alex", "grade": 95}, {"name": "Jordan", "grade": 88}]. Understanding when to use lists versus dictionaries is a key skill in writing clean, efficient Python code.
""", duration: 22, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "File I/O and Error Handling", content: """
File input and output (I/O) allows your program to read from and write to files on disk, enabling data persistence beyond a single program run. In Python, the open() function creates a file object. The recommended way to work with files is using the with statement, which automatically closes the file when done: with open("data.txt", "r") as file: content = file.read(). The mode parameter specifies the operation: "r" for reading, "w" for writing (overwrites), and "a" for appending.

Reading a file line by line is common for processing large datasets: with open("grades.csv") as file: for line in file: process(line). Writing to a file uses the write() method: with open("output.txt", "w") as file: file.write("Hello, World!"). For structured data, Python's csv module simplifies reading and writing CSV files, and the json module handles JSON data — a format widely used in web applications and APIs.

Error handling with try-except blocks prevents your program from crashing when something goes wrong. Common errors include FileNotFoundError (file does not exist), ValueError (wrong type of input), and ZeroDivisionError. Structure: try: result = 10 / number except ZeroDivisionError: print("Cannot divide by zero"). You can catch multiple exceptions, use else for code that runs only if no exception occurred, and finally for cleanup code that always runs. Good error handling makes your programs robust and user-friendly.
""", duration: 22, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 1),

            Module(id: UUID(), title: "Web Development Basics", lessons: [
                Lesson(id: UUID(), title: "HTML: Structure of the Web", content: """
HTML (HyperText Markup Language) is the standard language for creating web pages. It defines the structure and content of a page using elements represented by tags. An HTML document starts with <!DOCTYPE html> to declare the document type, followed by the <html> element containing <head> (metadata, title, linked stylesheets) and <body> (visible content). Every HTML page follows this basic skeleton.

HTML elements are defined by opening and closing tags: <p>This is a paragraph.</p>. Common elements include headings (<h1> through <h6>), paragraphs (<p>), links (<a href="url">), images (<img src="image.jpg" alt="description">), and lists (<ul> for unordered, <ol> for ordered, with <li> for items). Semantic elements like <header>, <nav>, <main>, <article>, <section>, and <footer> describe the meaning of their content, improving accessibility and SEO.

Attributes provide additional information about elements. The id attribute gives an element a unique identifier, class assigns one or more CSS classes, and aria attributes improve accessibility for screen readers. Forms collect user input using <form>, <input>, <textarea>, <select>, and <button> elements. Understanding HTML is the first step in web development — it provides the foundation upon which CSS adds visual styling and JavaScript adds interactivity.
""", duration: 18, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "CSS: Styling Your Pages", content: """
CSS (Cascading Style Sheets) controls the visual presentation of HTML elements. While HTML defines what content appears on a page, CSS determines how that content looks — colors, fonts, spacing, layout, and animations. CSS rules consist of a selector (which elements to style) and declarations (what styles to apply): h1 { color: navy; font-size: 24px; }.

Selectors target elements in different ways. Element selectors (p, h1, div) style all instances of a tag. Class selectors (.highlight) target elements with a specific class attribute. ID selectors (#header) target a single unique element. You can combine selectors and use pseudo-classes (:hover, :first-child) for interactive states. The cascade determines which styles take precedence when multiple rules apply — specificity and source order both play a role.

Modern CSS layout is powered by Flexbox and Grid. Flexbox excels at one-dimensional layouts (rows or columns): display: flex arranges child elements along a main axis, with properties like justify-content and align-items controlling alignment. CSS Grid handles two-dimensional layouts: display: grid lets you define rows and columns simultaneously. Responsive design uses media queries to adapt layouts for different screen sizes: @media (max-width: 768px) { ... } applies styles only on smaller screens. These tools let you create professional, responsive websites that look great on any device.
""", duration: 20, isCompleted: false, type: .reading, xpReward: 0),
                Lesson(id: UUID(), title: "Introduction to JavaScript", content: """
JavaScript is the programming language of the web, enabling interactive and dynamic behavior in web pages. While HTML provides structure and CSS provides styling, JavaScript brings pages to life — handling user clicks, validating forms, fetching data, creating animations, and much more. Every modern web browser includes a JavaScript engine that runs code directly in the browser.

JavaScript shares many concepts with Python — variables (declared with let or const), data types (numbers, strings, booleans, arrays, objects), conditionals (if/else), loops (for, while), and functions. However, the syntax differs: JavaScript uses curly braces for code blocks instead of indentation, semicolons to end statements, and === for strict equality comparison. Functions can be written as declarations: function add(a, b) { return a + b; } or as arrow functions: const add = (a, b) => a + b;

The Document Object Model (DOM) connects JavaScript to the web page. Using methods like document.getElementById() and document.querySelector(), you can select HTML elements and modify their content, attributes, and styles. Event listeners respond to user actions: button.addEventListener('click', function() { alert('Clicked!'); }). JavaScript can also fetch data from servers using the fetch API, enabling your pages to update without reloading. This is the foundation of modern single-page applications built with frameworks like React, Vue, and Angular.
""", duration: 22, isCompleted: false, type: .reading, xpReward: 0),
            ], orderIndex: 2),
        ]
    }

    // MARK: - Quiz Questions

    private func makeQuizQuestions() -> [QuizQuestion] {
        [
            // Multiple Choice
            QuizQuestion(
                id: UUID(),
                text: "What is the standard form of a quadratic equation?",
                questionType: .multipleChoice,
                options: ["y = mx + b", "ax\u{00B2} + bx + c = 0", "a\u{00B2} + b\u{00B2} = c\u{00B2}", "y = ab^x"],
                correctIndex: 1
            ),
            // True / False
            QuizQuestion(
                id: UUID(),
                text: "The discriminant of a quadratic equation determines the number of real solutions.",
                questionType: .trueFalse,
                options: ["True", "False"],
                correctIndex: 0
            ),
            // Fill in the Blank
            QuizQuestion(
                id: UUID(),
                text: "A quadratic function graphs a shape called a ___.",
                questionType: .fillInBlank,
                acceptedAnswers: ["parabola", "Parabola"]
            ),
            // Matching
            QuizQuestion(
                id: UUID(),
                text: "Match each formula with its name.",
                questionType: .matching,
                matchingPairs: [
                    MatchingPair(prompt: "ax\u{00B2} + bx + c = 0", answer: "Standard Form"),
                    MatchingPair(prompt: "b\u{00B2} - 4ac", answer: "Discriminant"),
                    MatchingPair(prompt: "(-b \u{00B1} \u{221A}(b\u{00B2}-4ac)) / 2a", answer: "Quadratic Formula"),
                ],
                needsManualReview: true
            ),
            // Essay
            QuizQuestion(
                id: UUID(),
                text: "Explain how the discriminant relates to the number of solutions of a quadratic equation.",
                questionType: .essay,
                essayPrompt: "Use specific examples with positive, zero, and negative discriminant values.",
                essayMinWords: 50,
                needsManualReview: true
            ),
        ]
    }
}
