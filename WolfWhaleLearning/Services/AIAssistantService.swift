import Foundation
import FoundationModels

@MainActor @Observable
final class AIAssistantService {
    static let shared = AIAssistantService()

    var isProcessing = false
    var isAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    private var session: LanguageModelSession?

    struct AIMessage: Identifiable, Sendable {
        let id = UUID()
        let content: String
        let isUser: Bool
        let timestamp = Date()
    }

    var messages: [AIMessage] = []

    func startNewSession() {
        let instructions = """
        You are a helpful study assistant for students using the WolfWhale Learning Management System. \
        You help with homework, explain concepts, quiz students, summarize topics, and provide study tips. \
        Keep responses concise and educational. You are friendly and encouraging. \
        If asked about non-educational topics, gently redirect to learning-related discussions.
        """
        session = LanguageModelSession(instructions: instructions)
        messages = []
    }

    func sendMessage(_ text: String) async {
        guard let session else {
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
