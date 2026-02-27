import SwiftUI

// MARK: - Data Models

struct BodyOrgan: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
}

struct BodySystemStep: Identifiable {
    let id = UUID()
    let stepNumber: Int
    let title: String
    let description: String
}

struct BodyQuizQuestion: Identifiable {
    let id = UUID()
    let question: String
    let options: [String]
    let correctIndex: Int
}

struct BodySystem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let overview: String
    let organs: [BodyOrgan]
    let steps: [BodySystemStep]
    let funFacts: [String]
    let quiz: [BodyQuizQuestion]
}

// MARK: - Human Body View

struct HumanBodyView: View {
    @State private var selectedSystem: BodySystem?
    @State private var exploredSystems: Set<String> = []
    @State private var showQuiz = false
    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                progressSection
                systemsGrid
            }
            .padding()
        }
        .navigationTitle("Human Body Systems")
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color.teal.opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            )
        )
        .sheet(item: $selectedSystem) { system in
            BodySystemDetailSheet(
                system: system,
                exploredSystems: $exploredSystems,
                showQuiz: $showQuiz
            )
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { appeared = true } }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(colors: [.teal, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .compatBreatheRepeating()
                VStack(alignment: .leading) {
                    Text("Human Body Systems")
                        .font(.title2.bold())
                    Text("Explore how your body works")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
    }

    // MARK: - Progress

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.teal)
                Text("Exploration Progress")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(exploredSystems.count)/\(Self.systems.count)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(exploredSystems.count), total: Double(Self.systems.count))
                .tint(.teal)
            if exploredSystems.count == Self.systems.count {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("All systems explored! You are a body expert!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
    }

    // MARK: - Systems Grid

    private var systemsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(Self.systems) { system in
                SystemCard(
                    system: system,
                    isExplored: exploredSystems.contains(system.name)
                )
                .onTapGesture {
                    selectedSystem = system
                }
            }
        }
        .opacity(appeared ? 1 : 0)
    }

    // MARK: - All Systems Data

    static let systems: [BodySystem] = [
        BodySystem(
            name: "Circulatory",
            icon: "heart.fill",
            color: .red,
            overview: "The circulatory system is your body's delivery service. It transports oxygen, nutrients, hormones, and waste products throughout your body using blood, blood vessels, and the heart. An adult's blood vessels, laid end to end, would stretch about 100,000 kilometers -- enough to circle the Earth 2.5 times!",
            organs: [
                BodyOrgan(name: "Heart", icon: "heart.fill", description: "A muscular pump about the size of your fist that beats about 100,000 times per day, pushing blood through your entire body."),
                BodyOrgan(name: "Arteries", icon: "arrow.right.circle.fill", description: "Blood vessels that carry oxygen-rich blood away from the heart to all parts of the body."),
                BodyOrgan(name: "Veins", icon: "arrow.left.circle.fill", description: "Blood vessels that carry oxygen-poor blood back to the heart. They have valves to prevent backflow."),
                BodyOrgan(name: "Capillaries", icon: "circle.grid.3x3.fill", description: "Tiny blood vessels where oxygen and nutrients are exchanged with body tissues."),
                BodyOrgan(name: "Blood", icon: "drop.fill", description: "A liquid tissue made of red blood cells, white blood cells, platelets, and plasma.")
            ],
            steps: [
                BodySystemStep(stepNumber: 1, title: "Heart Pumps", description: "The right side of the heart pumps blood to the lungs to pick up oxygen."),
                BodySystemStep(stepNumber: 2, title: "Oxygenation", description: "Blood picks up oxygen in the lungs and releases carbon dioxide."),
                BodySystemStep(stepNumber: 3, title: "Delivery", description: "Oxygen-rich blood returns to the left side of the heart and is pumped to the body."),
                BodySystemStep(stepNumber: 4, title: "Exchange", description: "In the capillaries, oxygen and nutrients are delivered to cells, and waste is collected."),
                BodySystemStep(stepNumber: 5, title: "Return", description: "Oxygen-poor blood returns through veins to the right side of the heart to start again.")
            ],
            funFacts: [
                "Your heart beats about 100,000 times every day.",
                "Red blood cells live for about 120 days before being replaced.",
                "A red blood cell can travel around your entire body in about 20 seconds.",
                "Your body has about 5 liters of blood.",
                "The heart creates enough pressure to squirt blood 9 meters."
            ],
            quiz: [
                BodyQuizQuestion(question: "How many times does the heart beat per day?", options: ["10,000", "50,000", "100,000", "1,000,000"], correctIndex: 2),
                BodyQuizQuestion(question: "Which blood vessels carry blood away from the heart?", options: ["Veins", "Arteries", "Capillaries", "Lymph nodes"], correctIndex: 1),
                BodyQuizQuestion(question: "What gives blood its red color?", options: ["Platelets", "White blood cells", "Hemoglobin", "Plasma"], correctIndex: 2),
                BodyQuizQuestion(question: "Where does gas exchange happen?", options: ["Heart", "Arteries", "Veins", "Capillaries"], correctIndex: 3),
                BodyQuizQuestion(question: "How much blood does an adult have?", options: ["1 liter", "3 liters", "5 liters", "10 liters"], correctIndex: 2)
            ]
        ),
        BodySystem(
            name: "Respiratory",
            icon: "lungs.fill",
            color: .cyan,
            overview: "The respiratory system is responsible for breathing -- taking in oxygen that your cells need for energy and getting rid of carbon dioxide waste. You breathe about 20,000 times a day! The lungs contain about 300 million tiny air sacs called alveoli, which would cover an area the size of a tennis court if spread flat.",
            organs: [
                BodyOrgan(name: "Lungs", icon: "lungs.fill", description: "Two spongy organs that take in oxygen and release carbon dioxide. The right lung has 3 lobes, the left has 2."),
                BodyOrgan(name: "Trachea", icon: "arrow.down.circle.fill", description: "The windpipe that carries air from your throat to your lungs. It is about 10-12 cm long."),
                BodyOrgan(name: "Diaphragm", icon: "arrow.up.and.down.circle.fill", description: "A dome-shaped muscle below the lungs that contracts and relaxes to help you breathe."),
                BodyOrgan(name: "Bronchi", icon: "arrow.triangle.branch", description: "Two tubes that branch off the trachea and lead into each lung, dividing into smaller bronchioles."),
                BodyOrgan(name: "Alveoli", icon: "circle.grid.3x3.fill", description: "Tiny air sacs at the ends of bronchioles where oxygen and carbon dioxide are exchanged with blood.")
            ],
            steps: [
                BodySystemStep(stepNumber: 1, title: "Inhalation", description: "The diaphragm contracts and moves down, expanding the chest cavity and pulling air into the lungs."),
                BodySystemStep(stepNumber: 2, title: "Air Travel", description: "Air passes through the nose/mouth, down the trachea, through bronchi, and into bronchioles."),
                BodySystemStep(stepNumber: 3, title: "Gas Exchange", description: "In the alveoli, oxygen passes into the blood and carbon dioxide passes out of the blood."),
                BodySystemStep(stepNumber: 4, title: "Oxygen Delivery", description: "Oxygen-rich blood travels to the heart to be pumped throughout the body."),
                BodySystemStep(stepNumber: 5, title: "Exhalation", description: "The diaphragm relaxes, pushing air with carbon dioxide out of the lungs.")
            ],
            funFacts: [
                "You breathe about 20,000 times per day.",
                "The surface area of the lungs is roughly the size of a tennis court.",
                "The right lung is slightly larger than the left to make room for the heart.",
                "You can live with just one lung.",
                "Sneezes can travel over 160 km/h!"
            ],
            quiz: [
                BodyQuizQuestion(question: "What muscle helps you breathe?", options: ["Bicep", "Diaphragm", "Heart", "Abdominals"], correctIndex: 1),
                BodyQuizQuestion(question: "Where does gas exchange occur in the lungs?", options: ["Trachea", "Bronchi", "Alveoli", "Diaphragm"], correctIndex: 2),
                BodyQuizQuestion(question: "What gas do we exhale?", options: ["Oxygen", "Nitrogen", "Carbon dioxide", "Helium"], correctIndex: 2),
                BodyQuizQuestion(question: "How many lobes does the right lung have?", options: ["1", "2", "3", "4"], correctIndex: 2),
                BodyQuizQuestion(question: "About how many times do you breathe per day?", options: ["2,000", "5,000", "20,000", "100,000"], correctIndex: 2)
            ]
        ),
        BodySystem(
            name: "Digestive",
            icon: "fork.knife",
            color: .orange,
            overview: "The digestive system breaks down food into nutrients your body can use for energy, growth, and repair. The entire digestive tract is about 9 meters long from mouth to anus! It takes food between 24 and 72 hours to travel through your entire digestive system.",
            organs: [
                BodyOrgan(name: "Mouth", icon: "mouth.fill", description: "Where digestion begins. Teeth break food into smaller pieces while saliva starts chemical digestion."),
                BodyOrgan(name: "Esophagus", icon: "arrow.down.circle.fill", description: "A muscular tube that pushes food from the mouth to the stomach using wave-like contractions called peristalsis."),
                BodyOrgan(name: "Stomach", icon: "circle.fill", description: "A muscular sac that churns food and mixes it with acid and enzymes to break it down further."),
                BodyOrgan(name: "Small Intestine", icon: "circle.grid.cross.fill", description: "About 6 meters long, this is where most nutrient absorption occurs through tiny finger-like villi."),
                BodyOrgan(name: "Large Intestine", icon: "circle.bottomhalf.filled", description: "Absorbs water from remaining food matter and forms solid waste for elimination."),
                BodyOrgan(name: "Liver", icon: "liver.fill", description: "Produces bile to help digest fats, filters toxins, and processes nutrients from the small intestine.")
            ],
            steps: [
                BodySystemStep(stepNumber: 1, title: "Ingestion", description: "Food enters the mouth where teeth chew it and saliva begins breaking down starches."),
                BodySystemStep(stepNumber: 2, title: "Swallowing", description: "The tongue pushes food to the back of the throat and down the esophagus via peristalsis."),
                BodySystemStep(stepNumber: 3, title: "Stomach Digestion", description: "Stomach acid and enzymes break food into a soupy mixture called chyme over 2-6 hours."),
                BodySystemStep(stepNumber: 4, title: "Nutrient Absorption", description: "In the small intestine, nutrients are absorbed into the bloodstream through millions of villi."),
                BodySystemStep(stepNumber: 5, title: "Water Absorption", description: "The large intestine absorbs remaining water, and bacteria help break down remaining material."),
                BodySystemStep(stepNumber: 6, title: "Elimination", description: "Solid waste (feces) is stored in the rectum and expelled from the body.")
            ],
            funFacts: [
                "Your stomach acid is strong enough to dissolve metal.",
                "The small intestine is about 6 meters long.",
                "You produce about 1.5 liters of saliva every day.",
                "Your stomach gets a brand new lining every 3-4 days.",
                "The liver performs over 500 different functions."
            ],
            quiz: [
                BodyQuizQuestion(question: "Where does most nutrient absorption occur?", options: ["Stomach", "Large intestine", "Small intestine", "Mouth"], correctIndex: 2),
                BodyQuizQuestion(question: "What is the wave-like muscle movement in the esophagus called?", options: ["Digestion", "Peristalsis", "Osmosis", "Contraction"], correctIndex: 1),
                BodyQuizQuestion(question: "Which organ produces bile?", options: ["Stomach", "Pancreas", "Liver", "Gallbladder"], correctIndex: 2),
                BodyQuizQuestion(question: "What is food called after being mixed in the stomach?", options: ["Bolus", "Chyme", "Feces", "Nutrients"], correctIndex: 1),
                BodyQuizQuestion(question: "About how long is the digestive tract?", options: ["3 meters", "6 meters", "9 meters", "15 meters"], correctIndex: 2)
            ]
        ),
        BodySystem(
            name: "Nervous",
            icon: "brain.head.profile",
            color: .purple,
            overview: "The nervous system is your body's communication network. It uses electrical signals to control everything from your thoughts and emotions to your heartbeat and reflexes. Your brain contains about 86 billion neurons, and nerve signals can travel at speeds up to 430 km/h!",
            organs: [
                BodyOrgan(name: "Brain", icon: "brain.head.profile", description: "The control center of the body, weighing about 1.4 kg. It processes information, stores memories, and controls all body functions."),
                BodyOrgan(name: "Spinal Cord", icon: "line.3.horizontal", description: "A bundle of nerves running down the spine that relays messages between the brain and the rest of the body."),
                BodyOrgan(name: "Neurons", icon: "bolt.circle.fill", description: "Nerve cells that transmit electrical signals. There are about 86 billion in the brain alone."),
                BodyOrgan(name: "Sensory Nerves", icon: "hand.raised.fill", description: "Nerves that carry information from your senses (touch, sight, hearing, etc.) to the brain."),
                BodyOrgan(name: "Motor Nerves", icon: "figure.walk", description: "Nerves that carry signals from the brain to muscles, telling them when and how to move.")
            ],
            steps: [
                BodySystemStep(stepNumber: 1, title: "Stimulus", description: "A sensory receptor detects a change (like touching something hot)."),
                BodySystemStep(stepNumber: 2, title: "Signal Transmission", description: "Sensory neurons convert the stimulus into an electrical signal."),
                BodySystemStep(stepNumber: 3, title: "Processing", description: "The signal travels along neurons to the spinal cord and/or brain for processing."),
                BodySystemStep(stepNumber: 4, title: "Decision", description: "The brain or spinal cord processes the information and decides on a response."),
                BodySystemStep(stepNumber: 5, title: "Response", description: "Motor neurons carry the response signal to muscles or glands, causing a reaction.")
            ],
            funFacts: [
                "Your brain uses 20% of your body's oxygen and energy.",
                "Nerve impulses can travel up to 430 km/h.",
                "The brain cannot feel pain -- it has no pain receptors.",
                "You have more nerve cells than stars in the Milky Way.",
                "The brain generates enough electricity to power a small light bulb."
            ],
            quiz: [
                BodyQuizQuestion(question: "How many neurons are in the brain?", options: ["1 million", "1 billion", "86 billion", "1 trillion"], correctIndex: 2),
                BodyQuizQuestion(question: "What carries messages from the brain to muscles?", options: ["Sensory nerves", "Motor nerves", "Blood vessels", "Tendons"], correctIndex: 1),
                BodyQuizQuestion(question: "What percentage of oxygen does the brain use?", options: ["5%", "10%", "20%", "50%"], correctIndex: 2),
                BodyQuizQuestion(question: "What protects the spinal cord?", options: ["Skull", "Ribcage", "Vertebrae", "Skin"], correctIndex: 2),
                BodyQuizQuestion(question: "How fast can nerve signals travel?", options: ["10 km/h", "100 km/h", "430 km/h", "1000 km/h"], correctIndex: 2)
            ]
        ),
        BodySystem(
            name: "Skeletal",
            icon: "figure.stand",
            color: .gray,
            overview: "The skeletal system is your body's framework, made up of 206 bones in adults. It provides support, protects organs, allows movement, produces blood cells in bone marrow, and stores minerals like calcium. Babies are born with about 270 bones, but many fuse together as they grow.",
            organs: [
                BodyOrgan(name: "Skull", icon: "brain", description: "Made of 22 bones fused together, it protects the brain and supports the face."),
                BodyOrgan(name: "Spine", icon: "line.3.horizontal", description: "33 vertebrae stacked in a column that protects the spinal cord and supports the body."),
                BodyOrgan(name: "Ribcage", icon: "shield.fill", description: "12 pairs of ribs that form a protective cage around the heart and lungs."),
                BodyOrgan(name: "Joints", icon: "circle.and.line.horizontal.fill", description: "Places where two bones meet, allowing movement. Types include hinge, ball-and-socket, and pivot joints."),
                BodyOrgan(name: "Bone Marrow", icon: "drop.circle.fill", description: "Soft tissue inside bones that produces red blood cells, white blood cells, and platelets.")
            ],
            steps: [
                BodySystemStep(stepNumber: 1, title: "Support", description: "Bones form the rigid framework that holds up your body and gives it shape."),
                BodySystemStep(stepNumber: 2, title: "Protection", description: "The skull protects the brain, ribs protect the heart and lungs, and vertebrae protect the spinal cord."),
                BodySystemStep(stepNumber: 3, title: "Movement", description: "Muscles attach to bones via tendons. When muscles contract, they pull on bones to create movement at joints."),
                BodySystemStep(stepNumber: 4, title: "Blood Production", description: "Red bone marrow inside certain bones produces millions of new blood cells every day."),
                BodySystemStep(stepNumber: 5, title: "Mineral Storage", description: "Bones store calcium and phosphorus, releasing them into the blood when needed.")
            ],
            funFacts: [
                "Babies have about 270 bones; adults have 206.",
                "The smallest bone is the stapes in your ear (3mm).",
                "The femur (thigh bone) is the longest and strongest bone.",
                "Bones are 5 times stronger than steel of the same weight.",
                "Your skeleton is completely replaced about every 10 years."
            ],
            quiz: [
                BodyQuizQuestion(question: "How many bones does an adult have?", options: ["106", "206", "270", "350"], correctIndex: 1),
                BodyQuizQuestion(question: "What is the longest bone in the body?", options: ["Humerus", "Tibia", "Femur", "Spine"], correctIndex: 2),
                BodyQuizQuestion(question: "Where are blood cells produced?", options: ["Joints", "Cartilage", "Bone marrow", "Tendons"], correctIndex: 2),
                BodyQuizQuestion(question: "How many bones do babies have?", options: ["106", "206", "270", "350"], correctIndex: 2),
                BodyQuizQuestion(question: "What connects muscles to bones?", options: ["Ligaments", "Tendons", "Cartilage", "Nerves"], correctIndex: 1)
            ]
        ),
        BodySystem(
            name: "Muscular",
            icon: "figure.strengthtraining.traditional",
            color: .orange,
            overview: "The muscular system consists of over 600 muscles that allow you to move, maintain posture, and generate heat. There are three types: skeletal (voluntary), smooth (involuntary), and cardiac (heart). Muscles make up about 40% of your total body weight!",
            organs: [
                BodyOrgan(name: "Skeletal Muscles", icon: "figure.strengthtraining.traditional", description: "Voluntary muscles attached to bones that allow conscious movement. There are about 640 of them."),
                BodyOrgan(name: "Cardiac Muscle", icon: "heart.fill", description: "Involuntary muscle found only in the heart. It contracts rhythmically and never tires."),
                BodyOrgan(name: "Smooth Muscle", icon: "circle.fill", description: "Involuntary muscles found in organs like the stomach, intestines, and blood vessels."),
                BodyOrgan(name: "Tendons", icon: "line.diagonal", description: "Tough bands of tissue that connect skeletal muscles to bones."),
                BodyOrgan(name: "Fascia", icon: "square.grid.3x3.fill", description: "Connective tissue that wraps around muscles, holding them in place and separating groups.")
            ],
            steps: [
                BodySystemStep(stepNumber: 1, title: "Brain Signal", description: "The brain sends an electrical signal through motor neurons to a specific muscle."),
                BodySystemStep(stepNumber: 2, title: "Nerve Activation", description: "The signal reaches the neuromuscular junction where the nerve meets the muscle fiber."),
                BodySystemStep(stepNumber: 3, title: "Contraction", description: "Muscle fibers slide past each other, causing the muscle to shorten and generate force."),
                BodySystemStep(stepNumber: 4, title: "Movement", description: "The muscle pulls on the bone via the tendon, creating movement at the joint."),
                BodySystemStep(stepNumber: 5, title: "Relaxation", description: "When the signal stops, the muscle relaxes and returns to its resting length.")
            ],
            funFacts: [
                "The gluteus maximus is the largest muscle in the body.",
                "The stapedius in the ear is the smallest muscle.",
                "It takes 17 muscles to smile and 43 to frown.",
                "Muscles generate about 85% of your body heat.",
                "Your tongue is one of the strongest muscles for its size."
            ],
            quiz: [
                BodyQuizQuestion(question: "How many skeletal muscles are in the body?", options: ["About 200", "About 400", "About 640", "About 1000"], correctIndex: 2),
                BodyQuizQuestion(question: "Which type of muscle is voluntary?", options: ["Smooth", "Cardiac", "Skeletal", "All of them"], correctIndex: 2),
                BodyQuizQuestion(question: "What is the largest muscle?", options: ["Bicep", "Quadricep", "Gluteus maximus", "Latissimus dorsi"], correctIndex: 2),
                BodyQuizQuestion(question: "What connects muscles to bones?", options: ["Ligaments", "Tendons", "Cartilage", "Fascia"], correctIndex: 1),
                BodyQuizQuestion(question: "What percentage of body weight is muscle?", options: ["10%", "25%", "40%", "60%"], correctIndex: 2)
            ]
        ),
        BodySystem(
            name: "Immune",
            icon: "shield.checkered",
            color: .green,
            overview: "The immune system is your body's defense force against infections, viruses, bacteria, and other harmful invaders. It includes physical barriers like skin, chemical defenses, and specialized white blood cells that can recognize and destroy threats. Your immune system has a memory -- once it fights a pathogen, it remembers how to fight it faster next time!",
            organs: [
                BodyOrgan(name: "White Blood Cells", icon: "shield.fill", description: "The soldiers of the immune system. Different types (T-cells, B-cells, macrophages) fight invaders in different ways."),
                BodyOrgan(name: "Lymph Nodes", icon: "circle.grid.3x3.fill", description: "Small bean-shaped organs that filter harmful substances and contain immune cells. They swell when fighting infection."),
                BodyOrgan(name: "Bone Marrow", icon: "drop.circle.fill", description: "The factory where all blood cells, including immune cells, are produced."),
                BodyOrgan(name: "Thymus", icon: "t.circle.fill", description: "An organ behind the breastbone where T-cells mature and learn to recognize pathogens."),
                BodyOrgan(name: "Spleen", icon: "circle.lefthalf.filled", description: "Filters blood, removes old red blood cells, and stores white blood cells and platelets."),
                BodyOrgan(name: "Skin", icon: "hand.raised.fill", description: "The body's first line of defense -- a physical barrier that prevents most pathogens from entering.")
            ],
            steps: [
                BodySystemStep(stepNumber: 1, title: "Barrier Defense", description: "Skin, mucus membranes, and stomach acid form the first line of defense against invaders."),
                BodySystemStep(stepNumber: 2, title: "Detection", description: "If a pathogen gets past barriers, immune cells detect it by recognizing foreign proteins (antigens)."),
                BodySystemStep(stepNumber: 3, title: "Innate Response", description: "Macrophages and other white blood cells quickly attack and try to engulf the invader. Inflammation occurs."),
                BodySystemStep(stepNumber: 4, title: "Adaptive Response", description: "T-cells and B-cells mount a specific attack. B-cells produce antibodies that target the exact pathogen."),
                BodySystemStep(stepNumber: 5, title: "Memory", description: "Memory cells are created that remember the pathogen, allowing a faster response if it returns (immunity).")
            ],
            funFacts: [
                "A fever is actually your immune system fighting infection by raising body temperature.",
                "Your body produces about 3.8 million white blood cells every second.",
                "Vaccines work by training your immune system to recognize pathogens safely.",
                "Laughter boosts your immune system by reducing stress hormones.",
                "The immune system can distinguish between millions of different pathogens."
            ],
            quiz: [
                BodyQuizQuestion(question: "What is the body's first line of defense?", options: ["White blood cells", "Antibodies", "Skin", "Lymph nodes"], correctIndex: 2),
                BodyQuizQuestion(question: "Which cells produce antibodies?", options: ["T-cells", "B-cells", "Red blood cells", "Platelets"], correctIndex: 1),
                BodyQuizQuestion(question: "Where do T-cells mature?", options: ["Bone marrow", "Spleen", "Thymus", "Lymph nodes"], correctIndex: 2),
                BodyQuizQuestion(question: "What is a fever's purpose?", options: ["Cause pain", "Fight infection", "Produce mucus", "Increase blood flow"], correctIndex: 1),
                BodyQuizQuestion(question: "Where are immune cells produced?", options: ["Liver", "Bone marrow", "Brain", "Lungs"], correctIndex: 1)
            ]
        )
    ]
}

// MARK: - System Card

private struct SystemCard: View {
    let system: BodySystem
    let isExplored: Bool

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: system.icon)
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [system.color, system.color.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 50)

                if isExplored {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Text(system.name)
                .font(.subheadline.bold())
                .lineLimit(1)

            Text("Tap to explore")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isExplored ? system.color.opacity(0.4) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Body System Detail Sheet

private struct BodySystemDetailSheet: View {
    let system: BodySystem
    @Binding var exploredSystems: Set<String>
    @Binding var showQuiz: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var quizActive = false
    @State private var quizScore = 0
    @State private var quizIndex = 0
    @State private var quizAnswered = false
    @State private var quizSelectedOption: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // System header
                    VStack(spacing: 8) {
                        Image(systemName: system.icon)
                            .font(.system(size: 56))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [system.color, system.color.opacity(0.5)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .symbolEffect(.bounce, value: 1)
                        Text("\(system.name) System")
                            .font(.title.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))

                    // Tab picker
                    Picker("Section", selection: $selectedTab) {
                        Text("Overview").tag(0)
                        Text("Organs").tag(1)
                        Text("How It Works").tag(2)
                        Text("Facts").tag(3)
                        Text("Quiz").tag(4)
                    }
                    .pickerStyle(.segmented)

                    switch selectedTab {
                    case 0: overviewSection
                    case 1: organsSection
                    case 2: stepsSection
                    case 3: factsSection
                    case 4: quizSection
                    default: EmptyView()
                    }
                }
                .padding()
            }
            .navigationTitle(system.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                exploredSystems.insert(system.name)
            }
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Overview", systemImage: "doc.text.fill")
                .font(.headline)
                .foregroundStyle(system.color)
            Text(system.overview)
                .font(.body)
                .lineSpacing(4)
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var organsSection: some View {
        VStack(spacing: 12) {
            ForEach(system.organs) { organ in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: organ.icon)
                        .font(.title2)
                        .foregroundStyle(system.color)
                        .frame(width: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(organ.name)
                            .font(.subheadline.bold())
                        Text(organ.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            }
        }
    }

    private var stepsSection: some View {
        VStack(spacing: 0) {
            ForEach(system.steps) { step in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(system.color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("\(step.stepNumber)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            )
                        if step.stepNumber < system.steps.count {
                            Rectangle()
                                .fill(system.color.opacity(0.3))
                                .frame(width: 2, height: 40)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(.subheadline.bold())
                        Text(step.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, step.stepNumber < system.steps.count ? 12 : 0)
                    Spacer()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var factsSection: some View {
        VStack(spacing: 10) {
            ForEach(system.funFacts.indices, id: \.self) { i in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text(system.funFacts[i])
                        .font(.subheadline)
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
            }
        }
    }

    private var quizSection: some View {
        VStack(spacing: 16) {
            if quizIndex < system.quiz.count {
                let q = system.quiz[quizIndex]

                HStack {
                    Text("Question \(quizIndex + 1) of \(system.quiz.count)")
                        .font(.subheadline.bold())
                    Spacer()
                    Text("Score: \(quizScore)")
                        .foregroundStyle(system.color)
                }

                ProgressView(value: Double(quizIndex), total: Double(system.quiz.count))
                    .tint(system.color)

                Text(q.question)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))

                ForEach(q.options.indices, id: \.self) { i in
                    Button {
                        guard !quizAnswered else { return }
                        quizSelectedOption = i
                        quizAnswered = true
                        if i == q.correctIndex { quizScore += 1 }
                    } label: {
                        HStack {
                            Text(q.options[i])
                                .font(.subheadline.bold())
                            Spacer()
                            if quizAnswered {
                                if i == q.correctIndex {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else if i == quizSelectedOption {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                        .padding()
                        .background(
                            quizAnswered ?
                            (i == q.correctIndex ? Color.green.opacity(0.15) :
                                i == quizSelectedOption ? Color.red.opacity(0.15) : Color.clear) :
                                Color.clear,
                            in: .rect(cornerRadius: 12)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(quizAnswered && i == q.correctIndex ? .green : .secondary.opacity(0.3))
                        )
                    }
                    .foregroundStyle(.primary)
                }

                if quizAnswered {
                    Button {
                        quizIndex += 1
                        quizAnswered = false
                        quizSelectedOption = nil
                    } label: {
                        Text(quizIndex + 1 < system.quiz.count ? "Next Question" : "See Results")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.white)
                            .background(
                                LinearGradient(colors: [system.color, system.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                                in: .rect(cornerRadius: 14)
                            )
                    }
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: quizIndex)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: quizScore >= 4 ? "star.fill" : "book.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(system.color)
                    Text("Quiz Complete!")
                        .font(.title2.bold())
                    Text("\(quizScore) out of \(system.quiz.count)")
                        .font(.title3)
                    Text(quizScore >= 4 ? "Excellent knowledge!" : "Keep studying this system!")
                        .foregroundStyle(.secondary)

                    Button {
                        quizIndex = 0
                        quizScore = 0
                        quizAnswered = false
                        quizSelectedOption = nil
                    } label: {
                        Text("Retry Quiz")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundStyle(.white)
                            .background(
                                LinearGradient(colors: [system.color, system.color.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                                in: .rect(cornerRadius: 14)
                            )
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HumanBodyView()
    }
}
