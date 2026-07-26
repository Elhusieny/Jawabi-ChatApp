private struct ChatStoreModifier: ViewModifier {
    let container: ModelContainer
    let signalR: SignalRService
 
    @StateObject private var chatStore: ChatStore
 
    init(container: ModelContainer, signalR: SignalRService) {
        self.container  = container
        self.signalR    = signalR
        // Use the main actor context so it is always on the main thread
        _chatStore = StateObject(wrappedValue: ChatStore(modelContext: container.mainContext))
    }
 
    func body(content: Content) -> some View {
        content
            .environmentObject(chatStore)
            .onAppear {
                chatStore.bind(to: signalR)
            }
    }
}
 
extension View {
    func withChatStore(container: ModelContainer, signalR: SignalRService) -> some View {
        modifier(ChatStoreModifier(container: container, signalR: signalR))
    }
}
 