import SwiftUI
import Combine
import WebKit

// --- DATA MODELS ---

struct Todo: Identifiable, Codable {
    let id = UUID()
    let content: String
    var isCompleted: Bool
    let completion_deadline: String?
    
    enum CodingKeys: String, CodingKey {
        case content
        case isCompleted
        case completion_deadline
    }
}

struct Event: Identifiable, Codable {
    let id = UUID()
    let title: String
    let content: String
    let location: String?
    let start_date: String?
    let end_date: String?
    
    enum CodingKeys: String, CodingKey {
        case title
        case content
        case location
        case start_date
        case end_date
    }
}

struct Email: Identifiable, Codable {
    let id: String // API now returns ID, though we might just generate one on backend if not provided
    let from_addr: String
    let subject: String
    let date: String
    let preview: String
    let body_html: String
    let todos: [Todo]
    let events: [Event]
    
    enum CodingKeys: String, CodingKey {
        case id
        case from_addr
        case subject
        case date
        case preview
        case body_html
        case todos
        case events
    }
}

// --- VIEW MODELS ---

// Represents a single "card" in the deck
enum CardType: Identifiable {
    case todo(Todo)
    case event(Event)
    case originalEmail
    
    var id: String {
        switch self {
        case .todo(let t): return "todo-\(t.id)"
        case .event(let e): return "event-\(e.id)"
        case .originalEmail: return "original"
        }
    }
}

struct Card: Identifiable {
    let id = UUID()
    let emailId: String
    let emailSubject: String
    let type: CardType
    // We keep a reference to the full email mainly for the "original" view
    let email: Email
}

// Batch status response
struct BatchStatus: Codable {
    let status: String
    let message: String
    let last_updated: String?
    let count: Int
}

class EmailViewModel: ObservableObject {
    @Published var cards: [Card] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var statusMessage: String = ""
    @Published var batchStatus: String = "idle"  // idle, fetching, processing, completed, error
    @Published var slideDirection: SlideDirection = .forward
    
    enum SlideDirection {
        case forward
        case backward
    }
    
    func startEmailRefresh() {
        // Trigger the refresh endpoint (returns immediately)
        guard let url = URL(string: "http://127.0.0.1:8000/refresh-emails") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        isRefreshing = true
        errorMessage = nil
        statusMessage = "Refresh started..."
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.isRefreshing = false
                    self.errorMessage = "Refresh failed: \(error.localizedDescription)"
                    return
                }
                
                // Successfully started - now user can manually check status
                self.statusMessage = "Refresh started! Press 'Check Status' to see progress."
                self.isRefreshing = false
                self.batchStatus = "processing"
            }
        }.resume()
    }
    
    func checkRefreshStatus() {
        guard let url = URL(string: "http://127.0.0.1:8000/refresh-status") else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                guard let data = data, error == nil else {
                    self.errorMessage = "Failed to check status"
                    return
                }
                
                do {
                    let status = try JSONDecoder().decode(BatchStatus.self, from: data)
                    self.batchStatus = status.status
                    self.statusMessage = status.message
                    
                    switch status.status {
                    case "completed":
                        // Auto-fetch the processed emails
                        self.fetchProcessedEmails()
                    case "error":
                        self.errorMessage = status.message
                    default:
                        break
                    }
                } catch {
                    self.errorMessage = "Failed to decode status: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func fetchProcessedEmails() {
        guard let url = URL(string: "http://127.0.0.1:8000/processed-emails") else { return }
        
        isLoading = true
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                self.statusMessage = ""
                
                if let error = error {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let emails = try JSONDecoder().decode([Email].self, from: data)
                    self.buildCards(from: emails)
                    if emails.isEmpty {
                        self.statusMessage = "No todos or events found in your emails."
                    }
                } catch {
                    self.errorMessage = "Failed to decode: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    private func buildCards(from emails: [Email]) {
        var newCards: [Card] = []
        
        for email in emails {
            // 1. Add Event Cards
            for event in email.events {
                newCards.append(Card(emailId: email.id, emailSubject: email.subject, type: .event(event), email: email))
            }
            
            // 2. Add Todo Cards
            for todo in email.todos {
                newCards.append(Card(emailId: email.id, emailSubject: email.subject, type: .todo(todo), email: email))
            }
            
            // 3. Always add "View Original" card at the end of the email's stack
            // (or if no events/todos, this is the only card)
            newCards.append(Card(emailId: email.id, emailSubject: email.subject, type: .originalEmail, email: email))
        }
        
        self.cards = newCards
        self.currentIndex = 0
    }
    
    func nextCard() {
        if currentIndex < cards.count - 1 {
            slideDirection = .forward
            currentIndex += 1
        }
    }
    
    func previousCard() {
        if currentIndex > 0 {
            slideDirection = .backward
            currentIndex -= 1
        }
    }
}

// --- VIEWS ---

struct CardView: View {
    let card: Card
    
    var body: some View {
        VStack {
            switch card.type {
            case .event(let event):
                VStack(spacing: 20) {
                    Image(systemName: "calendar")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.blue)
                    
                    Text("Event Detected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(event.title)
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if let location = event.location, !location.isEmpty {
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text(location)
                            }
                        }
                        
                        if let startDate = event.start_date, let endDate = event.end_date {
                            HStack {
                                Image(systemName: "clock")
                                Text("\(startDate) - \(endDate)")
                            }
                        } else if let startDate = event.start_date {
                            HStack {
                                Image(systemName: "clock")
                                Text(startDate)
                            }
                        }
                        
                        if !event.content.isEmpty {
                             Text(event.content)
                                .font(.body)
                                .padding(.top, 5)
                        }
                    }
                    .font(.subheadline)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding()
                
            case .todo(let todo):
                VStack(spacing: 20) {
                    Image(systemName: "checklist")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)
                    
                    Text("Todo Detected")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(todo.content)
                        .font(.title2)
                        .bold()
                        .multilineTextAlignment(.center)
                    
                    if let deadline = todo.completion_deadline, !deadline.isEmpty {
                        HStack {
                            Image(systemName: "hourglass")
                            Text("Due: \(deadline)")
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                }
                .padding()
                
            case .originalEmail:
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "envelope.open.fill")
                        Text("Original Email")
                    }
                    .font(.headline)
                    .padding(.bottom, 5)
                    
                    Divider()
                    
                    WebView(htmlContent: card.email.body_html)
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
        .padding()
    }
}

struct ContentView: View {
    @StateObject var viewModel = EmailViewModel()
    
    var body: some View {
        VStack {
            if viewModel.isLoading || viewModel.isRefreshing {
                VStack(spacing: 16) {
                    ProgressView()
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Text("Error").font(.headline)
                    Text(error).foregroundColor(.red).padding()
                    
                    HStack(spacing: 16) {
                        Button("Retry Fetch") {
                            viewModel.fetchProcessedEmails()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        Button("Start New Refresh") {
                            viewModel.errorMessage = nil
                            viewModel.startEmailRefresh()
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
            } else if viewModel.cards.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "tray")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .foregroundColor(.gray)
                    
                    Text("No processed emails found.")
                        .font(.headline)
                    
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 12) {
                        Button("Start Email Refresh") {
                            viewModel.startEmailRefresh()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        if viewModel.batchStatus == "processing" || viewModel.batchStatus == "fetching" {
                            Button("Check Status") {
                                viewModel.checkRefreshStatus()
                            }
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        Button("Load Existing") {
                            viewModel.fetchProcessedEmails()
                        }
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
            } else {
                // Main Interface
                VStack(spacing: 0) {
                    // Top Header: Email Subject
                    // We display the subject of the *current card*
                    Text(viewModel.cards[viewModel.currentIndex].emailSubject)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
                        .zIndex(1) // Keep on top
                    
                    Spacer()
                    
                    // Middle: Card Deck
                    // We only show the current card for simplicity with the current arrow navigation
                    CardView(card: viewModel.cards[viewModel.currentIndex])
                        .transition(.asymmetric(
                            insertion: .move(edge: viewModel.slideDirection == .forward ? .trailing : .leading),
                            removal: .move(edge: viewModel.slideDirection == .forward ? .leading : .trailing)
                        ))
                        .id(viewModel.currentIndex) // Force redraw for transition
                    
                    Spacer()
                    
                    // Bottom: Navigation
                    HStack(spacing: 40) {
                        Button(action: {
                            withAnimation { viewModel.previousCard() }
                        }) {
                            Image(systemName: "arrow.left.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundColor(viewModel.currentIndex > 0 ? .blue : .gray)
                        }
                        .disabled(viewModel.currentIndex == 0)
                        
                        Text("\(viewModel.currentIndex + 1) / \(viewModel.cards.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            withAnimation { viewModel.nextCard() }
                        }) {
                            Image(systemName: "arrow.right.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundColor(viewModel.currentIndex < viewModel.cards.count - 1 ? .blue : .gray)
                        }
                        .disabled(viewModel.currentIndex == viewModel.cards.count - 1)
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            // Start by fetching existing; user can manually refresh
            viewModel.fetchProcessedEmails()
        }
        .background(Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

