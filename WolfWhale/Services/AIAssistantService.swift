import Foundation

#if canImport(FoundationModels)
import FoundationModels

@MainActor @Observable
final class AIAssistantService {
    static let shared = AIAssistantService()

    var isProcessing = false
    var isAvailable: Bool {
        if #available(iOS 26, *) {
            return SystemLanguageModel.default.isAvailable
        }
        return false
    }

    @ObservationIgnored
    private var _session: AnyObject?

    struct AIMessage: Identifiable, Sendable {
        let id = UUID()
        let content: String
        let isUser: Bool
        let timestamp = Date()
    }

    var messages: [AIMessage] = []

    func startNewSession() {
        guard #available(iOS 26, *) else { return }
        let instructions = """
        You are a helpful study assistant for students using the WolfWhale Learning Management System. \
        You help with homework, explain concepts, quiz students, summarize topics, and provide study tips. \
        Keep responses concise and educational. You are friendly and encouraging. \
        If asked about non-educational topics, gently redirect to learning-related discussions.
        """
        _session = LanguageModelSession(instructions: instructions)
        messages = []
    }

    func sendMessage(_ text: String) async {
        guard #available(iOS 26, *) else { return }
        guard let session = _session as? LanguageModelSession else {
            startNewSession()
            await sendMessage(text)
            return
        }

        let userMessage = AIMessage(content: text, isUser: true)
        messages.append(userMessage)
        isProcessing = true

        do {
            let response = try await session.respond(to: text)
            let aiMessage = AIMessage(content: response.content, isUser: false)
            messages.append(aiMessage)
        } catch {
            let errorMessage = AIMessage(content: "I'm sorry, I couldn't process that. Please try again.", isUser: false)
            messages.append(errorMessage)
        }

        isProcessing = false
    }

    func clearHistory() {
        messages = []
        startNewSession()
    }
}

#else

@MainActor @Observable
final class AIAssistantService {
    static let shared = AIAssistantService()

    var isProcessing = false
    var isAvailable: Bool { false }

    struct AIMessage: Identifiable, Sendable {
        let id = UUID()
        let content: String
        let isUser: Bool
        let timestamp = Date()
    }

    var messages: [AIMessage] = []

    func startNewSession() {
        messages = []
    }

    func sendMessage(_ text: String) async {
        let userMessage = AIMessage(content: text, isUser: true)
        messages.append(userMessage)
        let errorMessage = AIMessage(content: "AI Assistant requires iOS 26 or later with Apple Intelligence.", isUser: false)
        messages.append(errorMessage)
    }

    func clearHistory() {
        messages = []
    }
}

#endif
