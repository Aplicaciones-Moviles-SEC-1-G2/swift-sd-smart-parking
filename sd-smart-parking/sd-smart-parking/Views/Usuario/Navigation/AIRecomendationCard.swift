//
//  AIRecomendationCard.swift
//  sd-smart-parking
//
//  Created by Mateo on 8/04/26.
//
import SwiftUI
import GoogleGenerativeAI
import SwiftUI



struct AIRecommendationCard: View {
    @State private var aiResponse: String = "Press generate to have an AI preview of your trip to Uniandes"
    @State private var isLoading: Bool = false
    @EnvironmentObject var vm: ParkingViewModel
    @EnvironmentObject var userRepo: UserRepository // 👈 Detector de conexión
    
    let myKey = Secrets.apiKey
    private let model: GenerativeModel
    
    init() {
        // ... (Tu init se mantiene igual)
        self.model = GenerativeModel(name: "gemini-2.5-flash-lite", apiKey: myKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: - HEADER
            HStack(spacing: 8) {
                Image(systemName: userRepo.isOffline ? "wifi.slash" : "sparkles")
                    .font(.subheadline.bold())
                    .foregroundColor(userRepo.isOffline ? .orange : .blue)
                
                Text(userRepo.isOffline ? "AI Suggestions (Offline)" : "AI Suggestions")
                    .font(.headline)
                
                Spacer()
                
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }
            
            // MARK: - ÁREA DE TEXTO DINÁMICA
            VStack(alignment: .leading, spacing: 12) {
                // Lógica de Mensaje Offline
                if userRepo.isOffline {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Connection lost. We can't generate new AI recommendations right now.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.orange)
                            .bold()
                        
                        Text("Pro-tip: We recommend leaving early to avoid potential delays and securing your parking spot before peak hours.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.primary.opacity(0.8))
                    }
                } else {
                    Text(aiResponse)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(userRepo.isOffline ? Color.orange.opacity(0.05) : Color(.systemGray6).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.orange.opacity(userRepo.isOffline ? 0.3 : 0), lineWidth: 1)
            )
            
            // MARK: - BOTÓN DE ACCIÓN
            Button(action: {
                fetchAIRecommendation(free: vm.totalAvailable, occupied: vm.totalOccupied)
            }) {
                HStack {
                    if isLoading {
                        Text("Analyzing Data...")
                    } else {
                        Image(systemName: userRepo.isOffline ? "clock.fill" : "bolt.fill")
                        Text(userRepo.isOffline ? "Offline Mode" : "Generate Suggestion")
                    }
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(userRepo.isOffline || isLoading ? Color.gray.gradient : Color.blue.gradient)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .disabled(userRepo.isOffline || isLoading) // Deshabilitado si offline
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
    }
    
    

    
    // MARK: - FETCH LOGIC
    func fetchAIRecommendation(free: Int, occupied: Int) {
        // Doble validación de seguridad
        guard !userRepo.isOffline else { return }
        
        isLoading = true
        let total = free + occupied
        let peak = vm.peakHour
        let calendar = Calendar.current
        let hora = calendar.component(.hour, from: Date())
        let minutos = calendar.component(.minute, from: Date())

        let prompt = """
        Make a short suggestion (max 2 sentences) for someone traveling to Uniandes SD building in Bogota. 
        Current parking status: \(free) spots available and \(occupied) occupied and \(total) total. 
        Current time: \(hora):\(minutos)
        Parking peak hour: \(String(describing: peak))
        Take into account traffic for this time of the day and assume they are driving. 
        Do not include bolds, italics, or greetings.
        """

        Task {
            do {
                let response = try await model.generateContent(prompt)
                await MainActor.run {
                    self.aiResponse = response.text ?? "No response available."
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.aiResponse = "Recommendation unavailable at the moment."
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    // Inyectamos una instancia de prueba para que la Preview no haga crash
    AIRecommendationCard()
        .environmentObject(ParkingViewModel())
}
