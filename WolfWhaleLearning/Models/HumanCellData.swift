import Foundation

nonisolated enum HumanCellData {
    static let organelles: [CellOrganelle] = [
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000001")!,
            name: "Nucleus",
            description: "The control center of the cell. Contains DNA organized into chromosomes and directs all cellular activities including growth, metabolism, and reproduction through gene expression.",
            funFact: "If you stretched out all the DNA in a single human cell, it would be about 6 feet long!",
            colorHex: 0x3949AB,
            relativePosition: SIMD3<Float>(0, 0, 0),
            size: SIMD3<Float>(0.045, 0.045, 0.045),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000010")!,
            name: "Nucleolus",
            description: "A dense region inside the nucleus responsible for producing ribosomal RNA (rRNA) and assembling ribosome subunits before they are exported to the cytoplasm.",
            funFact: "The nucleolus is the largest structure in the nucleus and can make up to 25% of its volume!",
            colorHex: 0x6A1B9A,
            relativePosition: SIMD3<Float>(0.008, 0.005, 0),
            size: SIMD3<Float>(0.012, 0.012, 0.012),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000011")!,
            name: "Nuclear Envelope",
            description: "A double-membrane structure that surrounds the nucleus, separating nuclear contents from the cytoplasm. Contains nuclear pores that regulate transport of molecules.",
            funFact: "The nuclear envelope has about 3,000-4,000 nuclear pores, each made of over 30 different proteins!",
            colorHex: 0x5C6BC0,
            relativePosition: SIMD3<Float>(0, 0, 0),
            size: SIMD3<Float>(0.048, 0.048, 0.048),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000002")!,
            name: "Mitochondria",
            description: "The powerhouse of the cell. Converts nutrients into ATP (adenosine triphosphate) through cellular respiration. Has a double membrane with inner folds called cristae.",
            funFact: "Mitochondria have their own DNA, separate from the cell's nucleus. Scientists believe they were once independent bacteria!",
            colorHex: 0xE65100,
            relativePosition: SIMD3<Float>(-0.065, -0.02, 0.03),
            size: SIMD3<Float>(0.03, 0.015, 0.015),
            shape: .ellipsoid
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000003")!,
            name: "Rough Endoplasmic Reticulum",
            description: "A network of flattened membrane sacs (cisternae) studded with ribosomes. Synthesizes and processes proteins destined for secretion, the cell membrane, or lysosomes.",
            funFact: "The rough ER makes up more than half of the total membrane in many cells and is continuous with the nuclear envelope!",
            colorHex: 0x00897B,
            relativePosition: SIMD3<Float>(0.05, -0.01, -0.02),
            size: SIMD3<Float>(0.04, 0.02, 0.03),
            shape: .flatDisc
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000012")!,
            name: "Smooth Endoplasmic Reticulum",
            description: "A tubular membrane network without ribosomes. Synthesizes lipids, metabolizes carbohydrates, detoxifies drugs and poisons, and stores calcium ions.",
            funFact: "Liver cells have extensive smooth ER because they detoxify many harmful substances in the blood!",
            colorHex: 0x9E9D24,
            relativePosition: SIMD3<Float>(-0.055, 0.02, -0.04),
            size: SIMD3<Float>(0.03, 0.015, 0.02),
            shape: .ellipsoid
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000004")!,
            name: "Golgi Apparatus",
            description: "A stack of flattened membrane sacs that modifies, sorts, and packages proteins and lipids for transport to their final destinations inside or outside the cell.",
            funFact: "The Golgi apparatus was one of the first organelles ever observed, discovered by Camillo Golgi in 1898!",
            colorHex: 0xFFA000,
            relativePosition: SIMD3<Float>(-0.05, 0.04, 0.01),
            size: SIMD3<Float>(0.03, 0.012, 0.025),
            shape: .flatDisc
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000005")!,
            name: "Cell Membrane",
            description: "The outer phospholipid bilayer boundary of the cell. A selectively permeable barrier that controls what enters and leaves, protecting the cell's contents.",
            funFact: "The cell membrane is only about 7-8 nanometers thick — 10,000 times thinner than a sheet of paper!",
            colorHex: 0xFFE082,
            relativePosition: SIMD3<Float>(0, 0, 0),
            size: SIMD3<Float>(0.15, 0.15, 0.15),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000006")!,
            name: "Ribosomes",
            description: "Tiny molecular machines made of rRNA and protein. They read mRNA instructions to synthesize proteins. Found free in cytoplasm or attached to rough ER.",
            funFact: "A single cell can contain up to 10 million ribosomes, and each one can add about 20 amino acids per second!",
            colorHex: 0x4A148C,
            relativePosition: SIMD3<Float>(0.05, 0.01, 0.01),
            size: SIMD3<Float>(0.002, 0.002, 0.002),
            shape: .tinyDots
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000007")!,
            name: "Lysosomes",
            description: "Membrane-bound organelles containing hydrolytic enzymes that digest worn-out organelles, food particles, viruses, and bacteria. Essential for cellular cleanup.",
            funFact: "Lysosomes maintain an internal pH of about 4.5-5.0, almost as acidic as vinegar, to activate their enzymes!",
            colorHex: 0x8D6E63,
            relativePosition: SIMD3<Float>(-0.06, 0.01, 0.04),
            size: SIMD3<Float>(0.01, 0.01, 0.01),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000008")!,
            name: "Vacuoles",
            description: "Membrane-enclosed storage compartments that hold water, nutrients, waste products, or other materials. Animal cell vacuoles are small and numerous.",
            funFact: "In plant cells, the central vacuole can take up to 90% of the cell's volume and helps maintain turgor pressure!",
            colorHex: 0x81C784,
            relativePosition: SIMD3<Float>(0.04, 0.05, 0.03),
            size: SIMD3<Float>(0.015, 0.015, 0.015),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000009")!,
            name: "Centrioles",
            description: "A pair of cylindrical structures composed of microtubule triplets arranged at right angles. Organize the mitotic spindle during cell division and help form cilia and flagella.",
            funFact: "Centrioles duplicate themselves before a cell divides, with each copy moving to opposite poles of the cell!",
            colorHex: 0x2E7D32,
            relativePosition: SIMD3<Float>(-0.02, -0.045, -0.01),
            size: SIMD3<Float>(0.008, 0.012, 0.008),
            shape: .cylinder
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000013")!,
            name: "Peroxisomes",
            description: "Small membrane-bound organelles containing oxidative enzymes. Break down fatty acids and amino acids, and detoxify harmful substances like hydrogen peroxide.",
            funFact: "Peroxisomes can replicate by simply dividing in two, similar to how bacteria reproduce!",
            colorHex: 0x827717,
            relativePosition: SIMD3<Float>(0.06, -0.03, -0.02),
            size: SIMD3<Float>(0.006, 0.006, 0.006),
            shape: .sphere
        ),
        CellOrganelle(
            id: UUID(uuidString: "00000001-0000-0000-0000-000000000014")!,
            name: "Cytoplasm",
            description: "The gel-like fluid (cytosol) filling the cell interior. Contains water, salts, organic molecules, and enzymes. All organelles are suspended within it.",
            funFact: "Cytoplasm is about 80% water and constantly streams within the cell, helping transport materials!",
            colorHex: 0xBBDEFB,
            relativePosition: SIMD3<Float>(0, 0, 0),
            size: SIMD3<Float>(0.14, 0.14, 0.14),
            shape: .sphere
        ),
    ]
}
