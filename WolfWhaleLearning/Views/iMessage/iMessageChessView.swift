import SwiftUI

// MARK: - iMessage Chess View
//
// A compact chess board designed for iMessage's presentation sizes.
// This view is self-contained and compilable within the main app target.
// No Messages.framework imports are needed -- this is purely the UI component.
//
// In a real iMessage extension, MSMessagesAppViewController would host this view:
//
//   class MessagesViewController: MSMessagesAppViewController {
//       override func didBecomeActive(with conversation: MSConversation) {
//           super.didBecomeActive(with: conversation)
//
//           // Decode board state from incoming message, if any
//           var game = ChessGameState()
//           if let message = conversation.selectedMessage,
//              let url = message.url {
//               game = urlToBoardState(url) ?? ChessGameState()
//           }
//
//           let chessView = iMessageChessView(
//               game: game,
//               onSendMove: { updatedGame in
//                   self.sendChessMessage(game: updatedGame, conversation: conversation)
//               }
//           )
//           let hostingController = UIHostingController(rootView: chessView)
//           addChild(hostingController)
//           view.addSubview(hostingController.view)
//           hostingController.view.frame = view.bounds
//           hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//           hostingController.didMove(toParent: self)
//       }
//
//       private func sendChessMessage(game: ChessGameState, conversation: MSConversation) {
//           let message = MSMessage(session: conversation.selectedMessage?.session ?? MSSession())
//           let layout = MSMessageTemplateLayout()
//           layout.caption = "\(game.currentTurn == .white ? "Black" : "White") just moved"
//           layout.subcaption = "Your turn!"
//           layout.image = UIImage(systemName: "chess") // placeholder
//           message.layout = layout
//           message.url = boardStateToURL(game)
//           conversation.insert(message) { error in
//               if let error { print("Failed to send: \(error)") }
//           }
//       }
//   }

// MARK: - Chess Game State

struct ChessGameState {
    /// The 8x8 board. Row 0 = rank 8 (black's back rank), Row 7 = rank 1 (white's back rank).
    var board: [[IMsgPiece?]]
    var currentTurn: ChessColor = .white
    var moveHistory: [ChessMove] = []
    var selectedSquare: (row: Int, col: Int)?
    var validMoves: [(row: Int, col: Int)] = []
    var gameStatus: ChessGameStatus = .active

    init() {
        board = ChessGameState.initialBoard()
    }

    static func initialBoard() -> [[IMsgPiece?]] {
        var board = Array(repeating: Array<IMsgPiece?>(repeating: nil, count: 8), count: 8)

        // Black pieces (row 0 = rank 8)
        board[0] = [
            IMsgPiece(.rook, .black), IMsgPiece(.knight, .black),
            IMsgPiece(.bishop, .black), IMsgPiece(.queen, .black),
            IMsgPiece(.king, .black), IMsgPiece(.bishop, .black),
            IMsgPiece(.knight, .black), IMsgPiece(.rook, .black)
        ]
        board[1] = Array(repeating: IMsgPiece(.pawn, .black), count: 8)

        // White pieces (row 7 = rank 1)
        board[6] = Array(repeating: IMsgPiece(.pawn, .white), count: 8)
        board[7] = [
            IMsgPiece(.rook, .white), IMsgPiece(.knight, .white),
            IMsgPiece(.bishop, .white), IMsgPiece(.queen, .white),
            IMsgPiece(.king, .white), IMsgPiece(.bishop, .white),
            IMsgPiece(.knight, .white), IMsgPiece(.rook, .white)
        ]

        return board
    }

    /// Converts the board to FEN-like notation for URL encoding.
    /// Standard FEN piece placement: K=king, Q=queen, R=rook, B=bishop, N=knight, P=pawn
    /// Uppercase = white, lowercase = black. Numbers = consecutive empty squares.
    func toFEN() -> String {
        var fen = ""
        for row in 0..<8 {
            var emptyCount = 0
            for col in 0..<8 {
                if let piece = board[row][col] {
                    if emptyCount > 0 {
                        fen += "\(emptyCount)"
                        emptyCount = 0
                    }
                    fen += piece.fenCharacter
                } else {
                    emptyCount += 1
                }
            }
            if emptyCount > 0 {
                fen += "\(emptyCount)"
            }
            if row < 7 {
                fen += "/"
            }
        }
        // Active color
        fen += " \(currentTurn == .white ? "w" : "b")"
        return fen
    }

    /// Parses a FEN-like string back into a board state.
    static func fromFEN(_ fen: String) -> ChessGameState? {
        let parts = fen.split(separator: " ")
        guard parts.count >= 1 else { return nil }

        let ranks = parts[0].split(separator: "/")
        guard ranks.count == 8 else { return nil }

        var game = ChessGameState()
        game.board = Array(repeating: Array<IMsgPiece?>(repeating: nil, count: 8), count: 8)

        for (rowIndex, rank) in ranks.enumerated() {
            var col = 0
            for char in rank {
                if let emptyCount = char.wholeNumberValue {
                    col += emptyCount
                } else {
                    guard col < 8 else { return nil }
                    game.board[rowIndex][col] = IMsgPiece.fromFEN(char)
                    col += 1
                }
            }
        }

        // Parse active color
        if parts.count >= 2 {
            game.currentTurn = parts[1] == "b" ? .black : .white
        }

        return game
    }
}

// MARK: - Chess Supporting Types

struct IMsgPiece: Equatable {
    let type: ChessPieceType
    let color: ChessColor

    init(_ type: ChessPieceType, _ color: ChessColor) {
        self.type = type
        self.color = color
    }

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

    var fenCharacter: String {
        let base: String
        switch type {
        case .king: base = "K"
        case .queen: base = "Q"
        case .rook: base = "R"
        case .bishop: base = "B"
        case .knight: base = "N"
        case .pawn: base = "P"
        }
        return color == .white ? base : base.lowercased()
    }

    static func fromFEN(_ char: Character) -> IMsgPiece? {
        let color: ChessColor = char.isUppercase ? .white : .black
        let type: ChessPieceType
        switch char.uppercased() {
        case "K": type = .king
        case "Q": type = .queen
        case "R": type = .rook
        case "B": type = .bishop
        case "N": type = .knight
        case "P": type = .pawn
        default: return nil
        }
        return IMsgPiece(type, color)
    }
}

enum ChessPieceType: String {
    case king, queen, rook, bishop, knight, pawn
}

enum ChessColor: String {
    case white, black

    var opposite: ChessColor {
        self == .white ? .black : .white
    }
}

struct ChessMove {
    let fromRow: Int
    let fromCol: Int
    let toRow: Int
    let toCol: Int
    let piece: IMsgPiece
    let captured: IMsgPiece?
}

enum ChessGameStatus {
    case active
    case check
    case checkmate
    case stalemate
    case resigned
}

// MARK: - URL Encoding/Decoding

/// Encodes the current board state into a URL for embedding in an MSMessage.
/// The URL uses a query parameter to carry the FEN string.
///
/// Example URL: wolfwhalechess://game?fen=rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR%20b
func boardStateToURL(_ game: ChessGameState) -> URL? {
    var components = URLComponents()
    components.scheme = "wolfwhalechess"
    components.host = "game"
    components.queryItems = [
        URLQueryItem(name: "fen", value: game.toFEN()),
        URLQueryItem(name: "moves", value: "\(game.moveHistory.count)")
    ]
    return components.url
}

/// Decodes a URL back into a ChessGameState.
/// Returns nil if the URL is malformed or the FEN is invalid.
func urlToBoardState(_ url: URL) -> ChessGameState? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let fenItem = components.queryItems?.first(where: { $0.name == "fen" }),
          let fen = fenItem.value else {
        return nil
    }
    return ChessGameState.fromFEN(fen)
}

// MARK: - iMessage Chess View

struct iMessageChessView: View {
    @State private var game = ChessGameState()
    @State private var showSendConfirmation = false
    @State private var moveJustMade = false

    /// Callback for when a move is sent in the iMessage extension context.
    /// In the main app, this can be nil or used for preview purposes.
    var onSendMove: ((ChessGameState) -> Void)?

    /// The compact cell size for iMessage layout. Standard chess apps in iMessage
    /// use approximately 36-40pt squares so the board fits in the compact height (~300pt).
    private let cellSize: CGFloat = 36

    var body: some View {
        VStack(spacing: 12) {
            turnIndicator
            boardView
            moveInfo
            actionButtons
        }
        .padding(16)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        .padding(8)
    }

    // MARK: - Turn Indicator

    private var turnIndicator: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(game.currentTurn == .white ? .white : .black)
                .stroke(.gray.opacity(0.4), lineWidth: 1)
                .frame(width: 16, height: 16)

            Text(turnText)
                .font(.headline.bold())
                .foregroundStyle(.primary)

            Spacer()

            statusBadge
        }
        .padding(.horizontal, 4)
    }

    private var turnText: String {
        switch game.gameStatus {
        case .checkmate:
            return "\(game.currentTurn.opposite.rawValue.capitalized) wins!"
        case .stalemate:
            return "Stalemate - Draw"
        case .check:
            return "\(game.currentTurn.rawValue.capitalized)'s turn (Check!)"
        case .resigned:
            return "\(game.currentTurn.opposite.rawValue.capitalized) wins by resignation"
        case .active:
            return "\(game.currentTurn.rawValue.capitalized)'s turn"
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch game.gameStatus {
        case .check:
            Label("Check", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange, in: Capsule())
        case .checkmate:
            Label("Checkmate", systemImage: "crown.fill")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.red, in: Capsule())
        case .stalemate:
            Label("Draw", systemImage: "equal.circle.fill")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.gray, in: Capsule())
        default:
            EmptyView()
        }
    }

    // MARK: - Board View

    private var boardView: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { col in
                        squareView(row: row, col: col)
                    }
                }
            }
        }
        .clipShape(.rect(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 6, y: 3)
    }

    private func squareView(row: Int, col: Int) -> some View {
        let isLight = (row + col) % 2 == 0
        let isSelected = game.selectedSquare?.row == row && game.selectedSquare?.col == col
        let isValidMove = game.validMoves.contains { $0.row == row && $0.col == col }
        let piece = game.board[row][col]

        return ZStack {
            // Square background
            Rectangle()
                .fill(squareColor(isLight: isLight, isSelected: isSelected, isValidMove: isValidMove))

            // Valid move indicator
            if isValidMove {
                if piece != nil {
                    // Capture indicator: ring around the square
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.purple.opacity(0.6), lineWidth: 3)
                        .padding(2)
                } else {
                    // Move indicator: small dot
                    Circle()
                        .fill(Color.purple.opacity(0.4))
                        .frame(width: cellSize * 0.3, height: cellSize * 0.3)
                }
            }

            // Chess piece
            if let piece {
                Text(piece.symbol)
                    .font(.system(size: cellSize * 0.65))
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .onTapGesture {
            handleSquareTap(row: row, col: col)
        }
    }

    private func squareColor(isLight: Bool, isSelected: Bool, isValidMove: Bool) -> Color {
        if isSelected {
            return Color.purple.opacity(0.5)
        }
        if isValidMove {
            return isLight
                ? Color.purple.opacity(0.15)
                : Color.purple.opacity(0.25)
        }
        return isLight
            ? Color(red: 0.93, green: 0.90, blue: 0.96)  // Light purple tint
            : Color(red: 0.55, green: 0.45, blue: 0.68)   // Purple-blue
    }

    // MARK: - Move Info

    private var moveInfo: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundStyle(.secondary)
                .font(.caption)
            Text("Move \(game.moveHistory.count + 1)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let lastMove = game.moveHistory.last {
                HStack(spacing: 4) {
                    Text("Last:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(lastMove.piece.symbol) \(columnLetter(lastMove.fromCol))\(8 - lastMove.fromRow)\u{2192}\(columnLetter(lastMove.toCol))\(8 - lastMove.toRow)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // New Game button
            Button {
                withAnimation(.spring(response: 0.3)) {
                    game = ChessGameState()
                    moveJustMade = false
                }
            } label: {
                Label("New Game", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.quaternary, in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            // Send Move button (primary action in iMessage context)
            Button {
                if let onSendMove {
                    onSendMove(game)
                }
                showSendConfirmation = true
                moveJustMade = false
            } label: {
                Label("Send Move", systemImage: "paperplane.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: moveJustMade ? [.purple, .blue] : [.gray, .gray.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: moveJustMade ? .purple.opacity(0.4) : .clear, radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(!moveJustMade)
            .hapticFeedback(.success, trigger: showSendConfirmation)
        }
        .overlay {
            if showSendConfirmation {
                sendConfirmationOverlay
            }
        }
    }

    private var sendConfirmationOverlay: some View {
        Text("Move sent!")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.green, in: Capsule())
            .transition(.scale.combined(with: .opacity))
            .task {
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation {
                    showSendConfirmation = false
                }
            }
    }

    // MARK: - Game Logic

    private func handleSquareTap(row: Int, col: Int) {
        guard game.gameStatus == .active || game.gameStatus == .check else { return }

        if let selected = game.selectedSquare {
            // If tapping a valid move destination, execute the move
            if game.validMoves.contains(where: { $0.row == row && $0.col == col }) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    executeMove(from: selected, to: (row, col))
                }
                return
            }

            // If tapping the same square, deselect
            if selected.row == row && selected.col == col {
                withAnimation(.easeInOut(duration: 0.15)) {
                    game.selectedSquare = nil
                    game.validMoves = []
                }
                return
            }
        }

        // Select a piece of the current turn's color
        if let piece = game.board[row][col], piece.color == game.currentTurn {
            withAnimation(.easeInOut(duration: 0.15)) {
                game.selectedSquare = (row, col)
                game.validMoves = calculateValidMoves(for: row, col: col)
            }
        } else {
            withAnimation(.easeInOut(duration: 0.15)) {
                game.selectedSquare = nil
                game.validMoves = []
            }
        }
    }

    private func executeMove(from: (row: Int, col: Int), to: (row: Int, col: Int)) {
        guard let piece = game.board[from.row][from.col] else { return }

        let captured = game.board[to.row][to.col]
        let move = ChessMove(
            fromRow: from.row, fromCol: from.col,
            toRow: to.row, toCol: to.col,
            piece: piece, captured: captured
        )

        game.board[to.row][to.col] = piece
        game.board[from.row][from.col] = nil

        // Pawn promotion (auto-promote to queen for simplicity)
        if piece.type == .pawn {
            if (piece.color == .white && to.row == 0) ||
               (piece.color == .black && to.row == 7) {
                game.board[to.row][to.col] = IMsgPiece(.queen, piece.color)
            }
        }

        game.moveHistory.append(move)
        game.selectedSquare = nil
        game.validMoves = []
        game.currentTurn = game.currentTurn.opposite
        moveJustMade = true

        // Check for check/checkmate (simplified)
        if isKingInCheck(color: game.currentTurn) {
            if hasNoLegalMoves(color: game.currentTurn) {
                game.gameStatus = .checkmate
            } else {
                game.gameStatus = .check
            }
        } else if hasNoLegalMoves(color: game.currentTurn) {
            game.gameStatus = .stalemate
        } else {
            game.gameStatus = .active
        }
    }

    // MARK: - Move Calculation

    private func calculateValidMoves(for row: Int, col: Int) -> [(row: Int, col: Int)] {
        guard let piece = game.board[row][col] else { return [] }

        var moves: [(row: Int, col: Int)] = []

        switch piece.type {
        case .pawn:
            moves = pawnMoves(row: row, col: col, color: piece.color)
        case .rook:
            moves = slidingMoves(row: row, col: col, color: piece.color, directions: [(0,1),(0,-1),(1,0),(-1,0)])
        case .bishop:
            moves = slidingMoves(row: row, col: col, color: piece.color, directions: [(1,1),(1,-1),(-1,1),(-1,-1)])
        case .queen:
            moves = slidingMoves(row: row, col: col, color: piece.color, directions: [(0,1),(0,-1),(1,0),(-1,0),(1,1),(1,-1),(-1,1),(-1,-1)])
        case .knight:
            moves = knightMoves(row: row, col: col, color: piece.color)
        case .king:
            moves = kingMoves(row: row, col: col, color: piece.color)
        }

        // Filter out moves that would leave own king in check
        return moves.filter { move in
            !wouldBeInCheck(from: (row, col), to: move, color: piece.color)
        }
    }

    private func pawnMoves(row: Int, col: Int, color: ChessColor) -> [(row: Int, col: Int)] {
        var moves: [(row: Int, col: Int)] = []
        let direction = color == .white ? -1 : 1
        let startRow = color == .white ? 6 : 1

        // Forward one
        let oneForward = row + direction
        if isInBounds(oneForward, col) && game.board[oneForward][col] == nil {
            moves.append((oneForward, col))

            // Forward two from starting position
            let twoForward = row + direction * 2
            if row == startRow && game.board[twoForward][col] == nil {
                moves.append((twoForward, col))
            }
        }

        // Diagonal captures
        for dc in [-1, 1] {
            let newCol = col + dc
            if isInBounds(oneForward, newCol),
               let target = game.board[oneForward][newCol],
               target.color != color {
                moves.append((oneForward, newCol))
            }
        }

        return moves
    }

    private func slidingMoves(row: Int, col: Int, color: ChessColor, directions: [(Int, Int)]) -> [(row: Int, col: Int)] {
        var moves: [(row: Int, col: Int)] = []

        for (dr, dc) in directions {
            var r = row + dr
            var c = col + dc
            while isInBounds(r, c) {
                if let target = game.board[r][c] {
                    if target.color != color {
                        moves.append((r, c))
                    }
                    break
                }
                moves.append((r, c))
                r += dr
                c += dc
            }
        }

        return moves
    }

    private func knightMoves(row: Int, col: Int, color: ChessColor) -> [(row: Int, col: Int)] {
        let offsets = [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)]
        return offsets.compactMap { (dr, dc) in
            let r = row + dr, c = col + dc
            guard isInBounds(r, c) else { return nil }
            if let target = game.board[r][c], target.color == color { return nil }
            return (r, c)
        }
    }

    private func kingMoves(row: Int, col: Int, color: ChessColor) -> [(row: Int, col: Int)] {
        let offsets = [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]
        return offsets.compactMap { (dr, dc) in
            let r = row + dr, c = col + dc
            guard isInBounds(r, c) else { return nil }
            if let target = game.board[r][c], target.color == color { return nil }
            return (r, c)
        }
    }

    // MARK: - Check Detection

    private func isKingInCheck(color: ChessColor) -> Bool {
        // Find the king
        guard let kingPos = findKing(color: color) else { return false }

        // Check if any opposing piece attacks the king
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = game.board[row][col], piece.color != color {
                    let attacks = rawMoves(for: piece, row: row, col: col)
                    if attacks.contains(where: { $0.row == kingPos.row && $0.col == kingPos.col }) {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func wouldBeInCheck(from: (row: Int, col: Int), to: (row: Int, col: Int), color: ChessColor) -> Bool {
        // Simulate the move
        var tempBoard = game.board
        tempBoard[to.row][to.col] = tempBoard[from.row][from.col]
        tempBoard[from.row][from.col] = nil

        // Find king position after move
        var kingRow = -1, kingCol = -1
        for r in 0..<8 {
            for c in 0..<8 {
                if let p = tempBoard[r][c], p.type == .king && p.color == color {
                    kingRow = r
                    kingCol = c
                }
            }
        }
        guard kingRow >= 0 else { return true }

        // Check if any opponent piece attacks the king in the simulated board
        for r in 0..<8 {
            for c in 0..<8 {
                if let piece = tempBoard[r][c], piece.color != color {
                    let attacks = rawMovesOnBoard(for: piece, row: r, col: c, board: tempBoard)
                    if attacks.contains(where: { $0.row == kingRow && $0.col == kingCol }) {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func hasNoLegalMoves(color: ChessColor) -> Bool {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = game.board[row][col], piece.color == color {
                    let moves = calculateValidMoves(for: row, col: col)
                    if !moves.isEmpty { return false }
                }
            }
        }
        return true
    }

    private func findKing(color: ChessColor) -> (row: Int, col: Int)? {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = game.board[row][col], piece.type == .king && piece.color == color {
                    return (row, col)
                }
            }
        }
        return nil
    }

    /// Raw moves without check validation (to avoid infinite recursion).
    private func rawMoves(for piece: IMsgPiece, row: Int, col: Int) -> [(row: Int, col: Int)] {
        return rawMovesOnBoard(for: piece, row: row, col: col, board: game.board)
    }

    private func rawMovesOnBoard(for piece: IMsgPiece, row: Int, col: Int, board: [[IMsgPiece?]]) -> [(row: Int, col: Int)] {
        switch piece.type {
        case .pawn:
            return pawnAttacks(row: row, col: col, color: piece.color)
        case .rook:
            return slidingMovesOnBoard(row: row, col: col, color: piece.color, directions: [(0,1),(0,-1),(1,0),(-1,0)], board: board)
        case .bishop:
            return slidingMovesOnBoard(row: row, col: col, color: piece.color, directions: [(1,1),(1,-1),(-1,1),(-1,-1)], board: board)
        case .queen:
            return slidingMovesOnBoard(row: row, col: col, color: piece.color, directions: [(0,1),(0,-1),(1,0),(-1,0),(1,1),(1,-1),(-1,1),(-1,-1)], board: board)
        case .knight:
            return knightMovesOnBoard(row: row, col: col, color: piece.color, board: board)
        case .king:
            return kingMovesOnBoard(row: row, col: col, color: piece.color, board: board)
        }
    }

    /// Pawn attack squares only (diagonals), used for check detection.
    private func pawnAttacks(row: Int, col: Int, color: ChessColor) -> [(row: Int, col: Int)] {
        let direction = color == .white ? -1 : 1
        var attacks: [(row: Int, col: Int)] = []
        for dc in [-1, 1] {
            let r = row + direction, c = col + dc
            if isInBounds(r, c) {
                attacks.append((r, c))
            }
        }
        return attacks
    }

    private func slidingMovesOnBoard(row: Int, col: Int, color: ChessColor, directions: [(Int, Int)], board: [[IMsgPiece?]]) -> [(row: Int, col: Int)] {
        var moves: [(row: Int, col: Int)] = []
        for (dr, dc) in directions {
            var r = row + dr, c = col + dc
            while isInBounds(r, c) {
                if let target = board[r][c] {
                    if target.color != color { moves.append((r, c)) }
                    break
                }
                moves.append((r, c))
                r += dr
                c += dc
            }
        }
        return moves
    }

    private func knightMovesOnBoard(row: Int, col: Int, color: ChessColor, board: [[IMsgPiece?]]) -> [(row: Int, col: Int)] {
        let offsets = [(-2,-1),(-2,1),(-1,-2),(-1,2),(1,-2),(1,2),(2,-1),(2,1)]
        return offsets.compactMap { (dr, dc) in
            let r = row + dr, c = col + dc
            guard isInBounds(r, c) else { return nil }
            if let target = board[r][c], target.color == color { return nil }
            return (r, c)
        }
    }

    private func kingMovesOnBoard(row: Int, col: Int, color: ChessColor, board: [[IMsgPiece?]]) -> [(row: Int, col: Int)] {
        let offsets = [(-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)]
        return offsets.compactMap { (dr, dc) in
            let r = row + dr, c = col + dc
            guard isInBounds(r, c) else { return nil }
            if let target = board[r][c], target.color == color { return nil }
            return (r, c)
        }
    }

    // MARK: - Helpers

    private func isInBounds(_ row: Int, _ col: Int) -> Bool {
        row >= 0 && row < 8 && col >= 0 && col < 8
    }

    private func columnLetter(_ col: Int) -> String {
        UnicodeScalar(97 + col).map { String(Character($0)) } ?? "?"
    }
}

// MARK: - Preview

#Preview("iMessage Chess - Compact") {
    iMessageChessView()
        .frame(maxWidth: 340)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("iMessage Chess - Full Width") {
    iMessageChessView()
        .padding()
        .background(Color(.systemGroupedBackground))
}
