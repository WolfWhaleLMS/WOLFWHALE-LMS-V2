import Foundation

// MARK: - Learning Standard

nonisolated struct LearningStandard: Identifiable, Hashable, Sendable, Codable {
    let id: UUID
    var code: String          // e.g., "CCSS.MATH.6.RP.1"
    var title: String
    var description: String
    var subject: String
    var gradeLevel: String
    var category: String

    init(
        id: UUID = UUID(),
        code: String,
        title: String,
        description: String,
        subject: String,
        gradeLevel: String,
        category: String
    ) {
        self.id = id
        self.code = code
        self.title = title
        self.description = description
        self.subject = subject
        self.gradeLevel = gradeLevel
        self.category = category
    }
}

// MARK: - Standards Set

nonisolated struct StandardsSet: Sendable {
    let subject: String
    let standards: [LearningStandard]
}

// MARK: - Mock Standards Data

enum MockStandards {

    // MARK: - Common Core Math Standards

    static let mathStandards: [LearningStandard] = [
        LearningStandard(
            code: "CCSS.MATH.6.RP.1",
            title: "Understand Ratios",
            description: "Understand the concept of a ratio and use ratio language to describe a ratio relationship between two quantities.",
            subject: "Math", gradeLevel: "6", category: "Ratios & Proportional Relationships"
        ),
        LearningStandard(
            code: "CCSS.MATH.6.RP.3",
            title: "Ratio & Rate Reasoning",
            description: "Use ratio and rate reasoning to solve real-world and mathematical problems.",
            subject: "Math", gradeLevel: "6", category: "Ratios & Proportional Relationships"
        ),
        LearningStandard(
            code: "CCSS.MATH.6.NS.1",
            title: "Divide Fractions",
            description: "Interpret and compute quotients of fractions, and solve word problems involving division of fractions by fractions.",
            subject: "Math", gradeLevel: "6", category: "The Number System"
        ),
        LearningStandard(
            code: "CCSS.MATH.6.EE.1",
            title: "Exponents",
            description: "Write and evaluate numerical expressions involving whole-number exponents.",
            subject: "Math", gradeLevel: "6", category: "Expressions & Equations"
        ),
        LearningStandard(
            code: "CCSS.MATH.6.EE.2",
            title: "Write Expressions",
            description: "Write, read, and evaluate expressions in which letters stand for numbers.",
            subject: "Math", gradeLevel: "6", category: "Expressions & Equations"
        ),
        LearningStandard(
            code: "CCSS.MATH.7.RP.1",
            title: "Unit Rates",
            description: "Compute unit rates associated with ratios of fractions, including ratios of lengths, areas, and other quantities.",
            subject: "Math", gradeLevel: "7", category: "Ratios & Proportional Relationships"
        ),
        LearningStandard(
            code: "CCSS.MATH.7.G.4",
            title: "Area & Circumference",
            description: "Know the formulas for the area and circumference of a circle and use them to solve problems.",
            subject: "Math", gradeLevel: "7", category: "Geometry"
        ),
        LearningStandard(
            code: "CCSS.MATH.8.EE.1",
            title: "Integer Exponents",
            description: "Know and apply the properties of integer exponents to generate equivalent numerical expressions.",
            subject: "Math", gradeLevel: "8", category: "Expressions & Equations"
        ),
        LearningStandard(
            code: "CCSS.MATH.8.F.1",
            title: "Understand Functions",
            description: "Understand that a function is a rule that assigns to each input exactly one output.",
            subject: "Math", gradeLevel: "8", category: "Functions"
        ),
        LearningStandard(
            code: "CCSS.MATH.8.G.7",
            title: "Pythagorean Theorem",
            description: "Apply the Pythagorean Theorem to determine unknown side lengths in right triangles in real-world and mathematical problems.",
            subject: "Math", gradeLevel: "8", category: "Geometry"
        ),
    ]

    // MARK: - Common Core ELA Standards

    static let elaStandards: [LearningStandard] = [
        LearningStandard(
            code: "CCSS.ELA.RL.6.1",
            title: "Cite Textual Evidence",
            description: "Cite textual evidence to support analysis of what the text says explicitly as well as inferences drawn from the text.",
            subject: "ELA", gradeLevel: "6", category: "Reading: Literature"
        ),
        LearningStandard(
            code: "CCSS.ELA.RL.6.2",
            title: "Determine Theme",
            description: "Determine a theme or central idea of a text and how it is conveyed through particular details.",
            subject: "ELA", gradeLevel: "6", category: "Reading: Literature"
        ),
        LearningStandard(
            code: "CCSS.ELA.W.6.1",
            title: "Write Arguments",
            description: "Write arguments to support claims with clear reasons and relevant evidence.",
            subject: "ELA", gradeLevel: "6", category: "Writing"
        ),
        LearningStandard(
            code: "CCSS.ELA.W.6.2",
            title: "Informative Writing",
            description: "Write informative/explanatory texts to examine a topic and convey ideas, concepts, and information.",
            subject: "ELA", gradeLevel: "6", category: "Writing"
        ),
        LearningStandard(
            code: "CCSS.ELA.RI.7.1",
            title: "Cite Several Sources",
            description: "Cite several pieces of textual evidence to support analysis of what the text says explicitly as well as inferences drawn from the text.",
            subject: "ELA", gradeLevel: "7", category: "Reading: Informational Text"
        ),
        LearningStandard(
            code: "CCSS.ELA.W.7.3",
            title: "Narrative Writing",
            description: "Write narratives to develop real or imagined experiences or events using effective technique, relevant descriptive details, and well-structured event sequences.",
            subject: "ELA", gradeLevel: "7", category: "Writing"
        ),
        LearningStandard(
            code: "CCSS.ELA.L.7.1",
            title: "Grammar & Usage",
            description: "Demonstrate command of the conventions of standard English grammar and usage when writing or speaking.",
            subject: "ELA", gradeLevel: "7", category: "Language"
        ),
        LearningStandard(
            code: "CCSS.ELA.RL.8.4",
            title: "Word Meaning in Context",
            description: "Determine the meaning of words and phrases as they are used in a text, including figurative and connotative meanings.",
            subject: "ELA", gradeLevel: "8", category: "Reading: Literature"
        ),
        LearningStandard(
            code: "CCSS.ELA.W.8.1",
            title: "Write Arguments (8th)",
            description: "Write arguments to support claims with clear reasons and relevant evidence, acknowledging and distinguishing the claim(s) from alternate or opposing claims.",
            subject: "ELA", gradeLevel: "8", category: "Writing"
        ),
        LearningStandard(
            code: "CCSS.ELA.SL.8.1",
            title: "Collaborative Discussion",
            description: "Engage effectively in a range of collaborative discussions with diverse partners on grade 8 topics, texts, and issues.",
            subject: "ELA", gradeLevel: "8", category: "Speaking & Listening"
        ),
    ]

    // MARK: - All Standards

    static let allStandards: [LearningStandard] = mathStandards + elaStandards

    static let standardsSets: [StandardsSet] = [
        StandardsSet(subject: "Math", standards: mathStandards),
        StandardsSet(subject: "ELA", standards: elaStandards),
    ]
}
