import Foundation

nonisolated enum HumanCellData {
    static let organelles: [CellOrganelle] = [
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            name: "Nucleus",
            description: "The control center of the cell. Contains DNA and directs all cellular activities including growth, metabolism, and reproduction.",
            funFact: "If you stretched out all the DNA in a single human cell, it would be about 6 feet long!",
            colorHex: 0x5C6BC0,
            relativePosition: SIMD3<Float>(0, 0, 0),
            size: SIMD3<Float>(0.035, 0.035, 0.035),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000002")!,
            name: "Mitochondria",
            description: "The powerhouse of the cell. Converts nutrients into ATP (adenosine triphosphate), the energy currency that fuels cellular processes.",
            funFact: "Mitochondria have their own DNA, separate from the cell's nucleus. Scientists believe they were once independent bacteria!",
            colorHex: 0xEF5350,
            relativePosition: SIMD3<Float>(-0.045, -0.015, 0.02),
            size: SIMD3<Float>(0.022, 0.012, 0.012),
            shape: .ellipsoid
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000003")!,
            name: "Endoplasmic Reticulum",
            description: "A network of membrane-enclosed tubes. Rough ER (with ribosomes) makes proteins; Smooth ER makes lipids and detoxifies chemicals.",
            funFact: "The ER makes up more than half of the total membrane in many cells!",
            colorHex: 0xFFB74D,
            relativePosition: SIMD3<Float>(0.04, -0.02, -0.015),
            size: SIMD3<Float>(0.03, 0.015, 0.02),
            shape: .ellipsoid
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000004")!,
            name: "Golgi Apparatus",
            description: "The cell's post office. Modifies, packages, and ships proteins and lipids to their destinations inside or outside the cell.",
            funFact: "The Golgi apparatus was one of the first organelles ever observed, discovered by Camillo Golgi in 1898!",
            colorHex: 0x66BB6A,
            relativePosition: SIMD3<Float>(-0.03, 0.03, -0.02),
            size: SIMD3<Float>(0.025, 0.008, 0.018),
            shape: .flatDisc
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000005")!,
            name: "Cell Membrane",
            description: "The outer boundary of the cell. A flexible lipid bilayer that controls what enters and leaves, protecting the cell's contents.",
            funFact: "The cell membrane is only about 7-8 nanometers thick — 10,000 times thinner than a sheet of paper!",
            colorHex: 0x81C784,
            relativePosition: SIMD3<Float>(0, 0, 0),
            size: SIMD3<Float>(0.1, 0.08, 0.1),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000006")!,
            name: "Ribosome",
            description: "Tiny protein factories found floating in cytoplasm or attached to the rough ER. They read mRNA instructions to build proteins.",
            funFact: "A single cell can contain up to 10 million ribosomes!",
            colorHex: 0x795548,
            relativePosition: SIMD3<Float>(0.055, 0.01, 0.01),
            size: SIMD3<Float>(0.005, 0.005, 0.005),
            shape: .tinyDots
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000007")!,
            name: "Lysosome",
            description: "The cell's recycling center. Contains digestive enzymes that break down waste materials, old cell parts, and foreign invaders.",
            funFact: "Lysosomes can have a pH as low as 4.5 — almost as acidic as vinegar!",
            colorHex: 0xAB47BC,
            relativePosition: SIMD3<Float>(-0.05, 0.01, 0.03),
            size: SIMD3<Float>(0.012, 0.012, 0.012),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000008")!,
            name: "Vacuole",
            description: "Storage compartments that hold water, nutrients, or waste. In animal cells they're small; in plant cells they can be enormous.",
            funFact: "In plant cells, the central vacuole can take up to 90% of the cell's volume!",
            colorHex: 0x29B6F6,
            relativePosition: SIMD3<Float>(0.02, 0.035, 0.025),
            size: SIMD3<Float>(0.015, 0.015, 0.015),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000009")!,
            name: "Centrosome",
            description: "Organizes the cell's microtubule network and plays a crucial role in cell division by forming the mitotic spindle.",
            funFact: "The centrosome duplicates itself before a cell divides, with each copy moving to opposite ends of the cell!",
            colorHex: 0x78909C,
            relativePosition: SIMD3<Float>(-0.015, -0.04, -0.01),
            size: SIMD3<Float>(0.01, 0.01, 0.01),
            shape: .cylinder
        )
    ]
}
