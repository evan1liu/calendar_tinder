import SwiftUI
import Combine

// 1. The Data Model matches the JSON from our Python Backend
struct Email: Identifiable, Codable {
    // API returns: from_addr, subject, date, preview
    // We can use UUID() for id since the API doesn't return a guaranteed simple ID, or use subject+date as a hack.
    // Ideally the API should return an ID, but let's make it Identifiable locally.
    let id = UUID()
    let from_addr: String
    let subject: String
    let date: String
    let preview: String
    
    enum CodingKeys: String, CodingKey {
        case from_addr
        case subject
        case date
        case preview
    }
}

// 2. The ViewModel to fetch data
class EmailViewModel: ObservableObject {
    @Published var emails: [Email] = []
    @Published var currentIndex: Int = 0
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchEmails() {
        guard let url = URL(string: "http://127.0.0.1:8000/emails") else { return }
        
        isLoading = true
        errorMessage = nil
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error: \(error.localizedDescription)\nMake sure Python backend is running!"
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let decodedEmails = try JSONDecoder().decode([Email].self, from: data)
                    self.emails = decodedEmails
                } catch {
                    self.errorMessage = "Failed to decode: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func nextEmail() {
        if currentIndex < emails.count - 1 {
            currentIndex += 1
        }
    }
    
    func previousEmail() {
        if currentIndex > 0 {
            currentIndex -= 1
        }
    }
}

// 3. The View
struct ContentView: View {
    @StateObject var viewModel = EmailViewModel()
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading emails from Python...")
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                Button("Retry") {
                    viewModel.fetchEmails()
                }
            } else if viewModel.emails.isEmpty {
                Text("No emails found.")
                Button("Load Emails") {
                    viewModel.fetchEmails()
                }
            } else {
                // Card View
                let email = viewModel.emails[viewModel.currentIndex]
                
                VStack(alignment: .leading, spacing: 20) {
                    Text(email.subject)
                        .font(.title)
                        .bold()
                    
                    Text("From: \(email.from_addr)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(email.date)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Divider()
                    
                    Text(email.preview)
                        .font(.body)
                        .padding(.top)
                    
                    Spacer()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 5)
                .padding()
                
                // Navigation Buttons
                HStack(spacing: 40) {
                    Button(action: {
                        withAnimation { viewModel.previousEmail() }
                    }) {
                        Image(systemName: "arrow.left.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(viewModel.currentIndex > 0 ? .blue : .gray)
                    }
                    .disabled(viewModel.currentIndex == 0)
                    
                    Text("\(viewModel.currentIndex + 1) / \(viewModel.emails.count)")
                        .font(.headline)
                    
                    Button(action: {
                        withAnimation { viewModel.nextEmail() }
                    }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .foregroundColor(viewModel.currentIndex < viewModel.emails.count - 1 ? .blue : .gray)
                    }
                    .disabled(viewModel.currentIndex == viewModel.emails.count - 1)
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            viewModel.fetchEmails()
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

