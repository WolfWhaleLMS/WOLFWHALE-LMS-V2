import SwiftUI

// MARK: - Data Models

enum PieceColor: Equatable {
    case white, black

    var opposite: PieceColor {
        self == .white ? .black : .white
    }
}

enum PieceType: Equatable {
    case king, queen, rook, bishop, knight, pawn
}

struct ChessPiece: Equatable {
    let type: PieceType
    let color: PieceColor
    var hasMoved: Bool = false

    var symbol: String {
        switch (type, color) {
        case (.king, .white): return "\u{2654}"
        case (.queen, .white): return "\u{2655}"
        case (.rook, .white): return "\u{2656}"
        case (.bishop, .white): return "\u{2657}"
        case (.knight, .white): return "\u{2658}"
        case (.pawn, .white): return "\u{2659}"
        case (.king, .black): return "\u{265A}"
        case (.queen, .black): return "\u{265B}"
        case (.rook, .black): return "\u{265C}"
        case (.bishop, .black): return "\u{265D}"
        case (.knight, .black): return "\u{265E}"
        case (.pawn, .black): return "\u{265F}"
        }
    }
}

struct ChessPosition: Equatable, Hashable {
    let row: Int
    let col: Int
}

// MARK: - Bot Difficulty

enum BotDifficulty: String, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var searchDepth: Int {
        switch self {
        case .easy: return 1
        case .medium: return 2
        case .hard: return 3
        }
    }
}

// MARK: - Move Undo Info

struct MoveUndoInfo {
    let from: ChessPosition
    let to: ChessPosition
    let movedPiece: ChessPiece
    let capturedPiece: ChessPiece?
    let previousEnPassant: ChessPosition?
    let previousCurrentTurn: PieceColor
    let previousIsCheck: Bool
    let previousIsCheckmate: Bool
    let previousIsStalemate: Bool
    let previousGameOver: Bool
    let previousMoveCount: Int
    let previousLastMove: (from: ChessPosition, to: ChessPosition)?
    // For en passant captures
    let epCapturedPiece: ChessPiece?
    let epCapturedPos: ChessPosition?
    // For castling
    let castleRookFrom: ChessPosition?
    let castleRookTo: ChessPosition?
    let castleRookPiece: ChessPiece?
    // For pawn promotion
    let promotedTo: ChessPiece?
}

// MARK: - Chess Game Logic

@Observable
class ChessGame {
    var board: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    var currentTurn: PieceColor = .white
    var selectedSquare: ChessPosition?
    var validMoveSquares: [ChessPosition] = []
    var isCheck: Bool = false
    var isCheckmate: Bool = false
    var isStalemate: Bool = false
    var capturedWhite: [ChessPiece] = []
    var capturedBlack: [ChessPiece] = []
    var moveCount: Int = 0
    var lastMove: (from: ChessPosition, to: ChessPosition)?
    var enPassantTarget: ChessPosition?
    var promotionPending: ChessPosition?
    var gameOver: Bool = false

    // Bot properties
    var isBotEnabled: Bool = true
    var botColor: PieceColor = .black
    var isBotThinking: Bool = false
    var botDifficulty: BotDifficulty = .medium

    init() {
        setupBoard()
    }

    func setupBoard() {
        board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        currentTurn = .white
        selectedSquare = nil
        validMoveSquares = []
        isCheck = false
        isCheckmate = false
        isStalemate = false
        capturedWhite = []
        capturedBlack = []
        moveCount = 0
        lastMove = nil
        enPassantTarget = nil
        promotionPending = nil
        gameOver = false
        isBotThinking = false

        // Black pieces (row 0 = top)
        board[0][0] = ChessPiece(type: .rook, color: .black)
        board[0][1] = ChessPiece(type: .knight, color: .black)
        board[0][2] = ChessPiece(type: .bishop, color: .black)
        board[0][3] = ChessPiece(type: .queen, color: .black)
        board[0][4] = ChessPiece(type: .king, color: .black)
        board[0][5] = ChessPiece(type: .bishop, color: .black)
        board[0][6] = ChessPiece(type: .knight, color: .black)
        board[0][7] = ChessPiece(type: .rook, color: .black)
        for col in 0..<8 {
            board[1][col] = ChessPiece(type: .pawn, color: .black)
        }

        // White pieces (row 7 = bottom)
        board[7][0] = ChessPiece(type: .rook, color: .white)
        board[7][1] = ChessPiece(type: .knight, color: .white)
        board[7][2] = ChessPiece(type: .bishop, color: .white)
        board[7][3] = ChessPiece(type: .queen, color: .white)
        board[7][4] = ChessPiece(type: .king, color: .white)
        board[7][5] = ChessPiece(type: .bishop, color: .white)
        board[7][6] = ChessPiece(type: .knight, color: .white)
        board[7][7] = ChessPiece(type: .rook, color: .white)
        for col in 0..<8 {
            board[6][col] = ChessPiece(type: .pawn, color: .white)
        }
    }

    // MARK: - Square Selection

    func selectSquare(row: Int, col: Int) {
        guard !gameOver else { return }
        // Don't allow interaction when bot is thinking
        guard !isBotThinking else { return }
        // Don't allow interaction when it's the bot's turn
        if isBotEnabled && currentTurn == botColor { return }

        let tappedPos = ChessPosition(row: row, col: col)

        // If we have a selected piece and this is a valid move destination
        if let selected = selectedSquare,
           validMoveSquares.contains(tappedPos) {
            movePiece(from: selected, to: tappedPos)
            triggerBotMoveIfNeeded()
            return
        }

        // If tapping a piece of the current player's color, select it
        if let piece = board[row][col], piece.color == currentTurn {
            selectedSquare = tappedPos
            validMoveSquares = legalMoves(for: piece, at: tappedPos)
        } else {
            // Deselect
            selectedSquare = nil
            validMoveSquares = []
        }
    }

    func triggerBotMoveIfNeeded() {
        if isBotEnabled && currentTurn == botColor && !isCheckmate && !isStalemate {
            isBotThinking = true
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                await botMove()
            }
        }
    }

    // MARK: - Move Execution

    func movePiece(from: ChessPosition, to: ChessPosition) {
        guard let piece = board[from.row][from.col] else { return }

        // Handle en passant capture
        if piece.type == .pawn, to == enPassantTarget {
            let capturedRow = from.row
            if let captured = board[capturedRow][to.col] {
                if captured.color == .white {
                    capturedBlack.append(captured)
                } else {
                    capturedWhite.append(captured)
                }
            }
            board[capturedRow][to.col] = nil
        }

        // Handle capture
        if let captured = board[to.row][to.col] {
            if captured.color == .white {
                capturedBlack.append(captured)
            } else {
                capturedWhite.append(captured)
            }
        }

        // Handle castling
        if piece.type == .king && abs(to.col - from.col) == 2 {
            if to.col == 6 {
                // Kingside castle
                var rook = board[from.row][7]
                rook?.hasMoved = true
                board[from.row][5] = rook
                board[from.row][7] = nil
            } else if to.col == 2 {
                // Queenside castle
                var rook = board[from.row][0]
                rook?.hasMoved = true
                board[from.row][3] = rook
                board[from.row][0] = nil
            }
        }

        // Set en passant target
        if piece.type == .pawn && abs(to.row - from.row) == 2 {
            let epRow = (from.row + to.row) / 2
            enPassantTarget = ChessPosition(row: epRow, col: to.col)
        } else {
            enPassantTarget = nil
        }

        // Move the piece
        var movedPiece = piece
        movedPiece.hasMoved = true
        board[to.row][to.col] = movedPiece
        board[from.row][from.col] = nil

        lastMove = (from: from, to: to)
        moveCount += 1

        // Handle pawn promotion
        if piece.type == .pawn {
            if (piece.color == .white && to.row == 0) || (piece.color == .black && to.row == 7) {
                // Auto-promote to queen
                board[to.row][to.col] = ChessPiece(type: .queen, color: piece.color, hasMoved: true)
            }
        }

        // Switch turns
        currentTurn = currentTurn.opposite
        selectedSquare = nil
        validMoveSquares = []

        // Check game state
        isCheck = isKingInCheck(color: currentTurn)

        if !hasAnyLegalMoves(color: currentTurn) {
            gameOver = true
            if isCheck {
                isCheckmate = true
            } else {
                isStalemate = true
            }
        }
    }

    // MARK: - Legal Move Calculation (filters moves that leave king in check)

    func legalMoves(for piece: ChessPiece, at position: ChessPosition) -> [ChessPosition] {
        let pseudoMoves = pseudoLegalMoves(for: piece, at: position)
        return pseudoMoves.filter { move in
            !wouldLeaveKingInCheck(from: position, to: move, color: piece.color)
        }
    }

    func hasAnyLegalMoves(color: PieceColor) -> Bool {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col], piece.color == color {
                    let pos = ChessPosition(row: row, col: col)
                    if !legalMoves(for: piece, at: pos).isEmpty {
                        return true
                    }
                }
            }
        }
        return false
    }

    // MARK: - Pseudo-Legal Move Generation

    func pseudoLegalMoves(for piece: ChessPiece, at position: ChessPosition) -> [ChessPosition] {
        switch piece.type {
        case .pawn: return pawnMoves(for: piece, at: position)
        case .rook: return rookMoves(for: piece, at: position)
        case .bishop: return bishopMoves(for: piece, at: position)
        case .queen: return queenMoves(for: piece, at: position)
        case .knight: return knightMoves(for: piece, at: position)
        case .king: return kingMoves(for: piece, at: position)
        }
    }

    private func pawnMoves(for piece: ChessPiece, at pos: ChessPosition) -> [ChessPosition] {
        var moves: [ChessPosition] = []
        let direction = piece.color == .white ? -1 : 1
        let startRow = piece.color == .white ? 6 : 1

        // Forward one
        let oneForward = pos.row + direction
        if isInBounds(oneForward, pos.col) && board[oneForward][pos.col] == nil {
            moves.append(ChessPosition(row: oneForward, col: pos.col))

            // Forward two from starting position
            let twoForward = pos.row + 2 * direction
            if pos.row == startRow && board[twoForward][pos.col] == nil {
                moves.append(ChessPosition(row: twoForward, col: pos.col))
            }
        }

        // Diagonal captures
        for dc in [-1, 1] {
            let newCol = pos.col + dc
            if isInBounds(oneForward, newCol) {
                if let target = board[oneForward][newCol], target.color != piece.color {
                    moves.append(ChessPosition(row: oneForward, col: newCol))
                }
                // En passant
                if let epTarget = enPassantTarget,
                   epTarget.row == oneForward && epTarget.col == newCol {
                    moves.append(ChessPosition(row: oneForward, col: newCol))
                }
            }
        }

        return moves
    }

    private func rookMoves(for piece: ChessPiece, at pos: ChessPosition) -> [ChessPosition] {
        return slidingMoves(for: piece, at: pos, directions: [(0, 1), (0, -1), (1, 0), (-1, 0)])
    }

    private func bishopMoves(for piece: ChessPiece, at pos: ChessPosition) -> [ChessPosition] {
        return slidingMoves(for: piece, at: pos, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1)])
    }

    private func queenMoves(for piece: ChessPiece, at pos: ChessPosition) -> [ChessPosition] {
        return slidingMoves(for: piece, at: pos, directions: [
            (0, 1), (0, -1), (1, 0), (-1, 0),
            (1, 1), (1, -1), (-1, 1), (-1, -1)
        ])
    }

    private func slidingMoves(for piece: ChessPiece, at pos: ChessPosition, directions: [(Int, Int)]) -> [ChessPosition] {
        var moves: [ChessPosition] = []
        for (dr, dc) in directions {
            var r = pos.row + dr
            var c = pos.col + dc
            while isInBounds(r, c) {
                if let target = board[r][c] {
                    if target.color != piece.color {
                        moves.append(ChessPosition(row: r, col: c))
                    }
                    break
                }
                moves.append(ChessPosition(row: r, col: c))
                r += dr
                c += dc
            }
        }
        return moves
    }

    private func knightMoves(for piece: ChessPiece, at pos: ChessPosition) -> [ChessPosition] {
        var moves: [ChessPosition] = []
        let offsets = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
        for (dr, dc) in offsets {
            let r = pos.row + dr
            let c = pos.col + dc
            if isInBounds(r, c) {
                if let target = board[r][c] {
                    if target.color != piece.color {
                        moves.append(ChessPosition(row: r, col: c))
                    }
                } else {
                    moves.append(ChessPosition(row: r, col: c))
                }
            }
        }
        return moves
    }

    private func kingMoves(for piece: ChessPiece, at pos: ChessPosition) -> [ChessPosition] {
        var moves: [ChessPosition] = []
        let offsets = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
        for (dr, dc) in offsets {
            let r = pos.row + dr
            let c = pos.col + dc
            if isInBounds(r, c) {
                if let target = board[r][c] {
                    if target.color != piece.color {
                        moves.append(ChessPosition(row: r, col: c))
                    }
                } else {
                    moves.append(ChessPosition(row: r, col: c))
                }
            }
        }

        // Castling
        if !piece.hasMoved && !isKingInCheck(color: piece.color) {
            let row = pos.row
            // Kingside castling
            if let rook = board[row][7], rook.type == .rook && !rook.hasMoved {
                if board[row][5] == nil && board[row][6] == nil {
                    if !isSquareAttacked(row: row, col: 5, by: piece.color.opposite) &&
                       !isSquareAttacked(row: row, col: 6, by: piece.color.opposite) {
                        moves.append(ChessPosition(row: row, col: 6))
                    }
                }
            }
            // Queenside castling
            if let rook = board[row][0], rook.type == .rook && !rook.hasMoved {
                if board[row][1] == nil && board[row][2] == nil && board[row][3] == nil {
                    if !isSquareAttacked(row: row, col: 2, by: piece.color.opposite) &&
                       !isSquareAttacked(row: row, col: 3, by: piece.color.opposite) {
                        moves.append(ChessPosition(row: row, col: 2))
                    }
                }
            }
        }

        return moves
    }

    // MARK: - Check Detection

    func isKingInCheck(color: PieceColor) -> Bool {
        guard let kingPos = findKing(color: color) else { return false }
        return isSquareAttacked(row: kingPos.row, col: kingPos.col, by: color.opposite)
    }

    func findKing(color: PieceColor) -> ChessPosition? {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col],
                   piece.type == .king && piece.color == color {
                    return ChessPosition(row: row, col: col)
                }
            }
        }
        return nil
    }

    func isSquareAttacked(row: Int, col: Int, by attackerColor: PieceColor) -> Bool {
        // Check knight attacks
        let knightOffsets = [(-2, -1), (-2, 1), (-1, -2), (-1, 2), (1, -2), (1, 2), (2, -1), (2, 1)]
        for (dr, dc) in knightOffsets {
            let r = row + dr
            let c = col + dc
            if isInBounds(r, c),
               let piece = board[r][c],
               piece.type == .knight && piece.color == attackerColor {
                return true
            }
        }

        // Check pawn attacks
        let pawnDir = attackerColor == .white ? 1 : -1
        for dc in [-1, 1] {
            let r = row + pawnDir
            let c = col + dc
            if isInBounds(r, c),
               let piece = board[r][c],
               piece.type == .pawn && piece.color == attackerColor {
                return true
            }
        }

        // Check king attacks
        let kingOffsets = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
        for (dr, dc) in kingOffsets {
            let r = row + dr
            let c = col + dc
            if isInBounds(r, c),
               let piece = board[r][c],
               piece.type == .king && piece.color == attackerColor {
                return true
            }
        }

        // Check sliding attacks (rook/queen on straight lines)
        let straightDirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        for (dr, dc) in straightDirs {
            var r = row + dr
            var c = col + dc
            while isInBounds(r, c) {
                if let piece = board[r][c] {
                    if piece.color == attackerColor && (piece.type == .rook || piece.type == .queen) {
                        return true
                    }
                    break
                }
                r += dr
                c += dc
            }
        }

        // Check sliding attacks (bishop/queen on diagonals)
        let diagDirs = [(1, 1), (1, -1), (-1, 1), (-1, -1)]
        for (dr, dc) in diagDirs {
            var r = row + dr
            var c = col + dc
            while isInBounds(r, c) {
                if let piece = board[r][c] {
                    if piece.color == attackerColor && (piece.type == .bishop || piece.type == .queen) {
                        return true
                    }
                    break
                }
                r += dr
                c += dc
            }
        }

        return false
    }

    // MARK: - Simulation

    func wouldLeaveKingInCheck(from: ChessPosition, to: ChessPosition, color: PieceColor) -> Bool {
        // Save state
        let savedFrom = board[from.row][from.col]
        let savedTo = board[to.row][to.col]
        let savedEnPassant = enPassantTarget

        // Handle en passant capture in simulation
        var epCapturedPiece: ChessPiece?
        var epCapturedPos: ChessPosition?
        if let piece = savedFrom, piece.type == .pawn, to == enPassantTarget {
            let capturedRow = from.row
            epCapturedPiece = board[capturedRow][to.col]
            epCapturedPos = ChessPosition(row: capturedRow, col: to.col)
            board[capturedRow][to.col] = nil
        }

        // Simulate move
        board[to.row][to.col] = savedFrom
        board[from.row][from.col] = nil

        // Handle castling rook movement in simulation
        var rookSaved: (from: ChessPosition, to: ChessPosition, piece: ChessPiece?)?
        if let piece = savedFrom, piece.type == .king && abs(to.col - from.col) == 2 {
            if to.col == 6 {
                rookSaved = (from: ChessPosition(row: from.row, col: 7),
                             to: ChessPosition(row: from.row, col: 5),
                             piece: board[from.row][7])
                board[from.row][5] = board[from.row][7]
                board[from.row][7] = nil
            } else if to.col == 2 {
                rookSaved = (from: ChessPosition(row: from.row, col: 0),
                             to: ChessPosition(row: from.row, col: 3),
                             piece: board[from.row][0])
                board[from.row][3] = board[from.row][0]
                board[from.row][0] = nil
            }
        }

        let inCheck = isKingInCheck(color: color)

        // Restore state
        board[from.row][from.col] = savedFrom
        board[to.row][to.col] = savedTo
        enPassantTarget = savedEnPassant

        if let epPos = epCapturedPos {
            board[epPos.row][epPos.col] = epCapturedPiece
        }

        if let rs = rookSaved {
            board[rs.from.row][rs.from.col] = rs.piece
            board[rs.to.row][rs.to.col] = nil
        }

        return inCheck
    }

    // MARK: - Bot AI

    private func pieceValue(_ type: PieceType) -> Int {
        switch type {
        case .pawn: return 100
        case .knight: return 320
        case .bishop: return 330
        case .rook: return 500
        case .queen: return 900
        case .king: return 20000
        }
    }

    func evaluateBoard() -> Int {
        var score = 0
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col] {
                    let value = pieceValue(piece.type)
                    // Add positional bonus for center control
                    let centerBonus = (piece.type == .pawn || piece.type == .knight) ?
                        max(0, 10 - abs(row - 4) * 3 - abs(col - 4) * 3) : 0
                    score += piece.color == .white ? (value + centerBonus) : -(value + centerBonus)
                }
            }
        }
        // Bonus for check
        if isCheck { score += currentTurn == .white ? -50 : 50 }
        return score
    }

    /// Evaluates a board snapshot without accessing any instance state.
    /// Used by the background AI computation to avoid data races with @Observable properties.
    nonisolated func evaluateBoardSnapshot(_ board: [[ChessPiece?]]) -> Int {
        var score = 0
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col] {
                    let value = pieceValue(piece.type)
                    let centerBonus = (piece.type == .pawn || piece.type == .knight) ?
                        max(0, 10 - abs(row - 4) * 3 - abs(col - 4) * 3) : 0
                    score += piece.color == .white ? (value + centerBonus) : -(value + centerBonus)
                }
            }
        }
        return score
    }

    /// Generates pseudo-legal moves for a piece on the given board snapshot.
    /// Used by the background AI computation to avoid data races with @Observable properties.
    nonisolated func generateMoves(for piece: ChessPiece, at position: ChessPosition, board: [[ChessPiece?]], enPassant: ChessPosition?) -> [ChessPosition] {
        func inBounds(_ r: Int, _ c: Int) -> Bool { r >= 0 && r < 8 && c >= 0 && c < 8 }

        func sliding(directions: [(Int, Int)]) -> [ChessPosition] {
            var moves: [ChessPosition] = []
            for (dr, dc) in directions {
                var r = position.row + dr
                var c = position.col + dc
                while inBounds(r, c) {
                    if let target = board[r][c] {
                        if target.color != piece.color { moves.append(ChessPosition(row: r, col: c)) }
                        break
                    }
                    moves.append(ChessPosition(row: r, col: c))
                    r += dr; c += dc
                }
            }
            return moves
        }

        switch piece.type {
        case .pawn:
            var moves: [ChessPosition] = []
            let dir = piece.color == .white ? -1 : 1
            let startRow = piece.color == .white ? 6 : 1
            let oneForward = position.row + dir
            if inBounds(oneForward, position.col) && board[oneForward][position.col] == nil {
                moves.append(ChessPosition(row: oneForward, col: position.col))
                let twoForward = position.row + 2 * dir
                if position.row == startRow && board[twoForward][position.col] == nil {
                    moves.append(ChessPosition(row: twoForward, col: position.col))
                }
            }
            for dc in [-1, 1] {
                let nc = position.col + dc
                if inBounds(oneForward, nc) {
                    if let target = board[oneForward][nc], target.color != piece.color {
                        moves.append(ChessPosition(row: oneForward, col: nc))
                    }
                    if let ep = enPassant, ep.row == oneForward && ep.col == nc {
                        moves.append(ChessPosition(row: oneForward, col: nc))
                    }
                }
            }
            return moves
        case .knight:
            var moves: [ChessPosition] = []
            for (dr, dc) in [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)] {
                let r = position.row + dr, c = position.col + dc
                if inBounds(r, c) {
                    if let target = board[r][c] { if target.color != piece.color { moves.append(ChessPosition(row: r, col: c)) } }
                    else { moves.append(ChessPosition(row: r, col: c)) }
                }
            }
            return moves
        case .bishop:
            return sliding(directions: [(1,1),(1,-1),(-1,1),(-1,-1)])
        case .rook:
            return sliding(directions: [(0,1),(0,-1),(1,0),(-1,0)])
        case .queen:
            return sliding(directions: [(0,1),(0,-1),(1,0),(-1,0),(1,1),(1,-1),(-1,1),(-1,-1)])
        case .king:
            var moves: [ChessPosition] = []
            for (dr, dc) in [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)] {
                let r = position.row + dr, c = position.col + dc
                if inBounds(r, c) {
                    if let target = board[r][c] { if target.color != piece.color { moves.append(ChessPosition(row: r, col: c)) } }
                    else { moves.append(ChessPosition(row: r, col: c)) }
                }
            }
            // Note: castling is omitted in AI search for simplicity; the AI
            // still benefits from the full legal-move set on the real board
            // for its top-level candidate list.
            return moves
        }
    }

    func allLegalMoves(for color: PieceColor) -> [(from: ChessPosition, to: ChessPosition)] {
        var moves: [(from: ChessPosition, to: ChessPosition)] = []
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col], piece.color == color {
                    let pos = ChessPosition(row: row, col: col)
                    let legal = legalMoves(for: piece, at: pos)
                    for dest in legal {
                        moves.append((from: pos, to: dest))
                    }
                }
            }
        }
        return moves
    }

    func makeMove(from: ChessPosition, to: ChessPosition, simulated: Bool) -> MoveUndoInfo {
        guard let movedPiece = board[from.row][from.col] else {
            // No piece at source — return a no-op undo info so callers never crash.
            return MoveUndoInfo(
                from: from, to: to,
                movedPiece: ChessPiece(type: .pawn, color: currentTurn),
                capturedPiece: nil,
                previousEnPassant: enPassantTarget,
                previousCurrentTurn: currentTurn,
                previousIsCheck: isCheck,
                previousIsCheckmate: isCheckmate,
                previousIsStalemate: isStalemate,
                previousGameOver: gameOver,
                previousMoveCount: moveCount,
                previousLastMove: lastMove,
                epCapturedPiece: nil, epCapturedPos: nil,
                castleRookFrom: nil, castleRookTo: nil, castleRookPiece: nil,
                promotedTo: nil
            )
        }
        let capturedPiece = board[to.row][to.col]
        let prevEnPassant = enPassantTarget
        let prevTurn = currentTurn
        let prevCheck = isCheck
        let prevCheckmate = isCheckmate
        let prevStalemate = isStalemate
        let prevGameOver = gameOver
        let prevMoveCount = moveCount
        let prevLastMove = lastMove

        // En passant capture
        var epCaptured: ChessPiece? = nil
        var epPos: ChessPosition? = nil
        if movedPiece.type == .pawn, to == enPassantTarget {
            let capturedRow = from.row
            epCaptured = board[capturedRow][to.col]
            epPos = ChessPosition(row: capturedRow, col: to.col)
            board[capturedRow][to.col] = nil
        }

        // Castling
        var castleRookFrom: ChessPosition? = nil
        var castleRookTo: ChessPosition? = nil
        var castleRookPiece: ChessPiece? = nil
        if movedPiece.type == .king && abs(to.col - from.col) == 2 {
            if to.col == 6 {
                castleRookFrom = ChessPosition(row: from.row, col: 7)
                castleRookTo = ChessPosition(row: from.row, col: 5)
                castleRookPiece = board[from.row][7]
                var rook = board[from.row][7]
                rook?.hasMoved = true
                board[from.row][5] = rook
                board[from.row][7] = nil
            } else if to.col == 2 {
                castleRookFrom = ChessPosition(row: from.row, col: 0)
                castleRookTo = ChessPosition(row: from.row, col: 3)
                castleRookPiece = board[from.row][0]
                var rook = board[from.row][0]
                rook?.hasMoved = true
                board[from.row][3] = rook
                board[from.row][0] = nil
            }
        }

        // Set en passant target
        if movedPiece.type == .pawn && abs(to.row - from.row) == 2 {
            let epRow = (from.row + to.row) / 2
            enPassantTarget = ChessPosition(row: epRow, col: to.col)
        } else {
            enPassantTarget = nil
        }

        // Move the piece
        var moved = movedPiece
        moved.hasMoved = true
        board[to.row][to.col] = moved
        board[from.row][from.col] = nil

        // Pawn promotion (auto-queen)
        var promotedTo: ChessPiece? = nil
        if movedPiece.type == .pawn {
            if (movedPiece.color == .white && to.row == 0) || (movedPiece.color == .black && to.row == 7) {
                let promoted = ChessPiece(type: .queen, color: movedPiece.color, hasMoved: true)
                board[to.row][to.col] = promoted
                promotedTo = promoted
            }
        }

        // Switch turn and update state
        currentTurn = currentTurn.opposite
        lastMove = (from: from, to: to)
        moveCount += 1

        if simulated {
            // For simulated moves, compute check but skip checkmate/stalemate (expensive)
            isCheck = isKingInCheck(color: currentTurn)
        } else {
            // Full game state update
            isCheck = isKingInCheck(color: currentTurn)
            if !hasAnyLegalMoves(color: currentTurn) {
                gameOver = true
                if isCheck {
                    isCheckmate = true
                } else {
                    isStalemate = true
                }
            }
        }

        return MoveUndoInfo(
            from: from,
            to: to,
            movedPiece: movedPiece,
            capturedPiece: capturedPiece,
            previousEnPassant: prevEnPassant,
            previousCurrentTurn: prevTurn,
            previousIsCheck: prevCheck,
            previousIsCheckmate: prevCheckmate,
            previousIsStalemate: prevStalemate,
            previousGameOver: prevGameOver,
            previousMoveCount: prevMoveCount,
            previousLastMove: prevLastMove,
            epCapturedPiece: epCaptured,
            epCapturedPos: epPos,
            castleRookFrom: castleRookFrom,
            castleRookTo: castleRookTo,
            castleRookPiece: castleRookPiece,
            promotedTo: promotedTo
        )
    }

    func undoMove(_ info: MoveUndoInfo) {
        // Restore the moved piece to its original position
        board[info.from.row][info.from.col] = info.movedPiece
        // Restore what was on the destination square
        board[info.to.row][info.to.col] = info.capturedPiece

        // Undo en passant capture
        if let epPos = info.epCapturedPos {
            board[epPos.row][epPos.col] = info.epCapturedPiece
        }

        // Undo castling
        if let rookFrom = info.castleRookFrom, let rookTo = info.castleRookTo {
            board[rookFrom.row][rookFrom.col] = info.castleRookPiece
            board[rookTo.row][rookTo.col] = nil
        }

        // Restore game state
        enPassantTarget = info.previousEnPassant
        currentTurn = info.previousCurrentTurn
        isCheck = info.previousIsCheck
        isCheckmate = info.previousIsCheckmate
        isStalemate = info.previousIsStalemate
        gameOver = info.previousGameOver
        moveCount = info.previousMoveCount
        lastMove = info.previousLastMove
    }

    func minimax(depth: Int, alpha: Int, beta: Int, isMaximizing: Bool) -> Int {
        if depth == 0 || isCheckmate || isStalemate {
            return evaluateBoard()
        }

        var alpha = alpha
        var beta = beta
        let color: PieceColor = isMaximizing ? .white : .black

        if isMaximizing {
            var maxEval = Int.min
            for move in allLegalMoves(for: color) {
                let undoInfo = makeMove(from: move.from, to: move.to, simulated: true)
                let eval = minimax(depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: false)
                undoMove(undoInfo)
                maxEval = max(maxEval, eval)
                alpha = max(alpha, eval)
                if beta <= alpha { break }
            }
            return maxEval == Int.min ? evaluateBoard() : maxEval
        } else {
            var minEval = Int.max
            for move in allLegalMoves(for: color) {
                let undoInfo = makeMove(from: move.from, to: move.to, simulated: true)
                let eval = minimax(depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: true)
                undoMove(undoInfo)
                minEval = min(minEval, eval)
                beta = min(beta, eval)
                if beta <= alpha { break }
            }
            return minEval == Int.max ? evaluateBoard() : minEval
        }
    }

    @MainActor
    func botMove() async {
        guard !gameOver else { isBotThinking = false; return }

        let depth = botDifficulty.searchDepth
        let isMax = botColor == .white
        let difficulty = botDifficulty

        let moves = allLegalMoves(for: botColor)
        guard !moves.isEmpty else { isBotThinking = false; return }

        // Run CPU-intensive minimax off the main actor to avoid blocking the UI.
        // We snapshot the mutable board state into a local copy so the background
        // computation never touches @Observable properties that the UI reads.
        let boardSnapshot = board
        let enPassantSnapshot = enPassantTarget
        let currentTurnSnapshot = currentTurn

        let bestMove: (from: ChessPosition, to: ChessPosition) = await Task.detached { [self] in
            // Work on a local copy — the real @Observable board is untouched.
            var localBoard = boardSnapshot
            var localEnPassant = enPassantSnapshot
            var localCurrentTurn = currentTurnSnapshot

            // -- Local helpers that mirror makeMove/undoMove but operate on the local copy --
            func localMakeMove(from: ChessPosition, to: ChessPosition) -> MoveUndoInfo {
                guard let movedPiece = localBoard[from.row][from.col] else {
                    return MoveUndoInfo(
                        from: from, to: to,
                        movedPiece: ChessPiece(type: .pawn, color: localCurrentTurn),
                        capturedPiece: nil,
                        previousEnPassant: localEnPassant,
                        previousCurrentTurn: localCurrentTurn,
                        previousIsCheck: false,
                        previousIsCheckmate: false,
                        previousIsStalemate: false,
                        previousGameOver: false,
                        previousMoveCount: 0,
                        previousLastMove: nil,
                        epCapturedPiece: nil, epCapturedPos: nil,
                        castleRookFrom: nil, castleRookTo: nil, castleRookPiece: nil,
                        promotedTo: nil
                    )
                }
                let capturedPiece = localBoard[to.row][to.col]
                let prevEnPassant = localEnPassant
                let prevTurn = localCurrentTurn

                // En passant capture
                var epCaptured: ChessPiece? = nil
                var epPos: ChessPosition? = nil
                if movedPiece.type == .pawn, to == localEnPassant {
                    let capturedRow = from.row
                    epCaptured = localBoard[capturedRow][to.col]
                    epPos = ChessPosition(row: capturedRow, col: to.col)
                    localBoard[capturedRow][to.col] = nil
                }

                // Castling
                var castleRookFrom: ChessPosition? = nil
                var castleRookTo: ChessPosition? = nil
                var castleRookPiece: ChessPiece? = nil
                if movedPiece.type == .king && abs(to.col - from.col) == 2 {
                    if to.col == 6 {
                        castleRookFrom = ChessPosition(row: from.row, col: 7)
                        castleRookTo = ChessPosition(row: from.row, col: 5)
                        castleRookPiece = localBoard[from.row][7]
                        var rook = localBoard[from.row][7]
                        rook?.hasMoved = true
                        localBoard[from.row][5] = rook
                        localBoard[from.row][7] = nil
                    } else if to.col == 2 {
                        castleRookFrom = ChessPosition(row: from.row, col: 0)
                        castleRookTo = ChessPosition(row: from.row, col: 3)
                        castleRookPiece = localBoard[from.row][0]
                        var rook = localBoard[from.row][0]
                        rook?.hasMoved = true
                        localBoard[from.row][3] = rook
                        localBoard[from.row][0] = nil
                    }
                }

                // Set en passant target
                if movedPiece.type == .pawn && abs(to.row - from.row) == 2 {
                    localEnPassant = ChessPosition(row: (from.row + to.row) / 2, col: to.col)
                } else {
                    localEnPassant = nil
                }

                // Move the piece
                var moved = movedPiece
                moved.hasMoved = true
                localBoard[to.row][to.col] = moved
                localBoard[from.row][from.col] = nil

                // Pawn promotion (auto-queen)
                var promotedTo: ChessPiece? = nil
                if movedPiece.type == .pawn {
                    if (movedPiece.color == .white && to.row == 0) || (movedPiece.color == .black && to.row == 7) {
                        let promoted = ChessPiece(type: .queen, color: movedPiece.color, hasMoved: true)
                        localBoard[to.row][to.col] = promoted
                        promotedTo = promoted
                    }
                }

                localCurrentTurn = localCurrentTurn.opposite

                return MoveUndoInfo(
                    from: from, to: to, movedPiece: movedPiece, capturedPiece: capturedPiece,
                    previousEnPassant: prevEnPassant, previousCurrentTurn: prevTurn,
                    previousIsCheck: false, previousIsCheckmate: false,
                    previousIsStalemate: false, previousGameOver: false,
                    previousMoveCount: 0, previousLastMove: nil,
                    epCapturedPiece: epCaptured, epCapturedPos: epPos,
                    castleRookFrom: castleRookFrom, castleRookTo: castleRookTo,
                    castleRookPiece: castleRookPiece, promotedTo: promotedTo
                )
            }

            func localUndoMove(_ info: MoveUndoInfo) {
                localBoard[info.from.row][info.from.col] = info.movedPiece
                localBoard[info.to.row][info.to.col] = info.capturedPiece
                if let epPos = info.epCapturedPos {
                    localBoard[epPos.row][epPos.col] = info.epCapturedPiece
                }
                if let rf = info.castleRookFrom, let rt = info.castleRookTo {
                    localBoard[rf.row][rf.col] = info.castleRookPiece
                    localBoard[rt.row][rt.col] = nil
                }
                localEnPassant = info.previousEnPassant
                localCurrentTurn = info.previousCurrentTurn
            }

            func localEvaluateBoard() -> Int {
                self.evaluateBoardSnapshot(localBoard)
            }

            func localIsInBounds(_ row: Int, _ col: Int) -> Bool {
                row >= 0 && row < 8 && col >= 0 && col < 8
            }

            func localMinimax(depth: Int, alpha: Int, beta: Int, isMaximizing: Bool) -> Int {
                if depth == 0 { return localEvaluateBoard() }
                let color: PieceColor = isMaximizing ? .white : .black
                // Generate moves from the local board
                var localMoves: [(from: ChessPosition, to: ChessPosition)] = []
                for r in 0..<8 {
                    for c in 0..<8 {
                        if let piece = localBoard[r][c], piece.color == color {
                            let from = ChessPosition(row: r, col: c)
                            let targets = self.generateMoves(for: piece, at: from, board: localBoard, enPassant: localEnPassant)
                            for t in targets {
                                localMoves.append((from: from, to: t))
                            }
                        }
                    }
                }
                if isMaximizing {
                    var maxEval = Int.min
                    var alpha = alpha
                    for move in localMoves {
                        let undo = localMakeMove(from: move.from, to: move.to)
                        let eval = localMinimax(depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: false)
                        localUndoMove(undo)
                        maxEval = max(maxEval, eval)
                        alpha = max(alpha, eval)
                        if beta <= alpha { break }
                    }
                    return maxEval == Int.min ? localEvaluateBoard() : maxEval
                } else {
                    var minEval = Int.max
                    var beta = beta
                    for move in localMoves {
                        let undo = localMakeMove(from: move.from, to: move.to)
                        let eval = localMinimax(depth: depth - 1, alpha: alpha, beta: beta, isMaximizing: true)
                        localUndoMove(undo)
                        minEval = min(minEval, eval)
                        beta = min(beta, eval)
                        if beta <= alpha { break }
                    }
                    return minEval == Int.max ? localEvaluateBoard() : minEval
                }
            }

            // -- Evaluate each candidate move --
            var candidateMove = moves[0]
            var candidateEval = isMax ? Int.min : Int.max

            for move in moves {
                let undoInfo = localMakeMove(from: move.from, to: move.to)
                let eval = localMinimax(depth: depth - 1, alpha: Int.min, beta: Int.max, isMaximizing: !isMax)
                localUndoMove(undoInfo)

                if isMax {
                    if eval > candidateEval {
                        candidateEval = eval
                        candidateMove = move
                    }
                } else {
                    if eval < candidateEval {
                        candidateEval = eval
                        candidateMove = move
                    }
                }
            }

            // Add slight randomness for easy mode to avoid always picking the "best"
            if difficulty == .easy {
                // 30% chance to pick a random move instead
                if Int.random(in: 0..<10) < 3, let randomMove = moves.randomElement() {
                    return randomMove
                }
            }

            return candidateMove
        }.value

        movePiece(from: bestMove.from, to: bestMove.to)
        isBotThinking = false
    }

    // MARK: - Utilities

    private func isInBounds(_ row: Int, _ col: Int) -> Bool {
        row >= 0 && row < 8 && col >= 0 && col < 8
    }
}

// MARK: - Chess Game View

struct ChessGameView: View {
    @State private var game = ChessGame()
    @State private var selectionTrigger = false
    @State private var captureTrigger = false
    @State private var showGameOverAlert = false

    private let lightSquare = Color(red: 240/255, green: 217/255, blue: 181/255)
    private let darkSquare = Color(red: 181/255, green: 136/255, blue: 99/255)
    private let selectedColor = Color.yellow.opacity(0.6)
    private let lastMoveColor = Color.blue.opacity(0.25)
    private let checkColor = Color.red.opacity(0.5)
    private let fileLabels = ["a", "b", "c", "d", "e", "f", "g", "h"]

    var body: some View {
        VStack(spacing: 0) {
            botControlBar
            statusBar
            capturedPiecesRow(color: .white)
            chessBoard
            capturedPiecesRow(color: .black)
            controlBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Chess")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .sensoryFeedback(.success, trigger: captureTrigger)
        .alert(gameOverTitle, isPresented: $showGameOverAlert) {
            Button("New Game") {
                game.setupBoard()
            }
            Button("Review Board", role: .cancel) {}
        } message: {
            Text(gameOverMessage)
        }
        .onChange(of: game.gameOver) { _, newValue in
            if newValue {
                showGameOverAlert = true
            }
        }
    }

    // MARK: - Bot Control Bar

    private var botControlBar: some View {
        HStack(spacing: 12) {
            // Bot toggle
            Button {
                game.isBotEnabled.toggle()
                if !game.isBotEnabled {
                    game.isBotThinking = false
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: game.isBotEnabled ? "cpu.fill" : "person.2.fill")
                        .font(.caption)
                    Text(game.isBotEnabled ? "vs Bot" : "vs Player")
                        .font(.caption.bold())
                }
                .foregroundStyle(game.isBotEnabled ? .purple : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(game.isBotEnabled ? Color.purple.opacity(0.15) : Color(.systemGray5))
                )
            }

            if game.isBotEnabled {
                // Difficulty picker
                HStack(spacing: 4) {
                    ForEach(BotDifficulty.allCases, id: \.rawValue) { difficulty in
                        Button {
                            game.botDifficulty = difficulty
                        } label: {
                            Text(difficulty.rawValue)
                                .font(.caption2.bold())
                                .foregroundStyle(game.botDifficulty == difficulty ? .white : .purple)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(game.botDifficulty == difficulty ? Color.purple : Color.purple.opacity(0.1))
                                )
                        }
                    }
                }
            }

            Spacer()

            // Thinking indicator
            if game.isBotThinking {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Thinking...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(game.currentTurn == .white ? .white : .black)
                .frame(width: 18, height: 18)
                .overlay {
                    Circle()
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                }

            if game.isCheckmate {
                Text("\(game.currentTurn == .white ? "Black" : "White") wins by checkmate!")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
            } else if game.isStalemate {
                Text("Stalemate - Draw!")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
            } else if game.isBotThinking {
                Text("Bot is thinking...")
                    .font(.subheadline.bold())
                    .foregroundStyle(.purple)
            } else if game.isCheck {
                Text("\(game.currentTurn == .white ? "White" : "Black") is in check!")
                    .font(.subheadline.bold())
                    .foregroundStyle(.red)
            } else {
                Text("\(game.currentTurn == .white ? "White" : "Black") to move")
                    .font(.subheadline.bold())
            }

            Spacer()

            Text("Move \(game.moveCount + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    // MARK: - Captured Pieces

    private func capturedPiecesRow(color: PieceColor) -> some View {
        let pieces = color == .white ? game.capturedWhite : game.capturedBlack
        return HStack(spacing: 2) {
            if pieces.isEmpty {
                Text(" ")
                    .font(.system(size: 16))
            } else {
                ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                    Text(piece.symbol)
                        .font(.system(size: 16))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(height: 28)
    }

    // MARK: - Chess Board

    private var chessBoard: some View {
        GeometryReader { geometry in
            let boardSize = min(geometry.size.width - 32, geometry.size.height)
            let squareSize = boardSize / 8

            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { col in
                            squareView(row: row, col: col, size: squareSize)
                        }
                    }
                }
            }
            .border(Color(.systemGray3), width: 2)
            .frame(width: squareSize * 8, height: squareSize * 8)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 16)
    }

    private func squareView(row: Int, col: Int, size: CGFloat) -> some View {
        let isLight = (row + col) % 2 == 0
        let pos = ChessPosition(row: row, col: col)
        let isSelected = game.selectedSquare == pos
        let isValidMove = game.validMoveSquares.contains(pos)
        let isLastMoveSquare = game.lastMove?.from == pos || game.lastMove?.to == pos
        let piece = game.board[row][col]
        let isKingInCheck = game.isCheck && piece?.type == .king && piece?.color == game.currentTurn

        return ZStack {
            // Base square color
            Rectangle()
                .fill(isLight ? lightSquare : darkSquare)

            // Last move highlight
            if isLastMoveSquare && !isSelected {
                Rectangle()
                    .fill(lastMoveColor)
            }

            // Selected square highlight
            if isSelected {
                Rectangle()
                    .fill(selectedColor)
            }

            // King in check highlight
            if isKingInCheck {
                Rectangle()
                    .fill(checkColor)
            }

            // Piece
            if let piece = piece {
                Text(piece.symbol)
                    .font(.system(size: size * 0.7))
                    .minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }

            // Valid move indicator
            if isValidMove {
                if piece != nil {
                    // Capture indicator: corner triangles
                    Rectangle()
                        .fill(.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1)
                                .stroke(Color.green.opacity(0.8), lineWidth: size * 0.08)
                        )
                } else {
                    // Move indicator: dot
                    Circle()
                        .fill(Color.green.opacity(0.5))
                        .frame(width: size * 0.3, height: size * 0.3)
                }
            }

            // Coordinate labels
            if row == 7 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(fileLabels[col])
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(isLight ? darkSquare : lightSquare)
                            .padding(1)
                    }
                }
            }
            if col == 0 {
                VStack {
                    HStack {
                        Text("\(8 - row)")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(isLight ? darkSquare : lightSquare)
                            .padding(1)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture {
            // Don't allow taps when bot is thinking or it's the bot's turn
            guard !game.isBotThinking else { return }
            if game.isBotEnabled && game.currentTurn == game.botColor { return }

            let hadSelection = game.selectedSquare != nil
            let isCapture = isValidMove && piece != nil
            let isEnPassantCapture = isValidMove && game.board[game.selectedSquare?.row ?? 0][game.selectedSquare?.col ?? 0]?.type == .pawn && pos == game.enPassantTarget

            game.selectSquare(row: row, col: col)

            if hadSelection && isValidMove {
                if isCapture || isEnPassantCapture {
                    captureTrigger.toggle()
                } else {
                    selectionTrigger.toggle()
                }
            } else if game.selectedSquare != nil {
                selectionTrigger.toggle()
            }
        }
        .accessibilityLabel(squareAccessibilityLabel(row: row, col: col))
        .accessibilityHint(squareAccessibilityHint(row: row, col: col))
    }

    // MARK: - Control Bar

    private var controlBar: some View {
        HStack(spacing: 20) {
            Button {
                game.setupBoard()
            } label: {
                Label("New Game", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
            }
            .disabled(game.isBotThinking)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Game Over Helpers

    private var gameOverTitle: String {
        if game.isCheckmate {
            return "Checkmate!"
        } else if game.isStalemate {
            return "Stalemate!"
        }
        return "Game Over"
    }

    private var gameOverMessage: String {
        if game.isCheckmate {
            let winner = game.currentTurn == .white ? "Black" : "White"
            return "\(winner) wins! Great game."
        } else if game.isStalemate {
            return "The game is a draw by stalemate. Neither player wins."
        }
        return ""
    }

    // MARK: - Accessibility

    private func squareAccessibilityLabel(row: Int, col: Int) -> String {
        let file = fileLabels[col]
        let rank = 8 - row
        let squareName = "\(file)\(rank)"
        if let piece = game.board[row][col] {
            let colorName = piece.color == .white ? "White" : "Black"
            let pieceName = "\(piece.type)".capitalized
            return "\(colorName) \(pieceName) on \(squareName)"
        }
        return "Empty square \(squareName)"
    }

    private func squareAccessibilityHint(row: Int, col: Int) -> String {
        let pos = ChessPosition(row: row, col: col)
        if game.validMoveSquares.contains(pos) {
            return "Double tap to move here"
        }
        if let piece = game.board[row][col], piece.color == game.currentTurn {
            return "Double tap to select this piece"
        }
        return ""
    }
}

#Preview {
    NavigationStack {
        ChessGameView()
    }
}
