//
//  AIRecomendationCard.swift
//  sd-smart-parking
//
//  Created by Mateo on 8/04/26.
//
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
        @EnvironmentObject var parkingVM: ParkingViewModel
        
        private let model: GenerativeModel
        
        init() {
            let safetySettings = [
                SafetySetting(harmCategory: .harassment, threshold: .blockNone),
                SafetySetting(harmCategory: .hateSpeech, threshold: .blockNone),
                SafetySetting(harmCategory: .sexuallyExplicit, threshold: .blockNone),
                SafetySetting(harmCategory: .dangerousContent, threshold: .blockNone)
            ]
            
            self.model = GenerativeModel(
                name: "gemini-2.5-flash-lite", // Cambiado a flash estable para evitar errores
                apiKey: "AIzaSyD_te2nJttAzp07IHJOb8KFuBbzWuWVqyw",
                safetySettings: safetySettings
            )
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                // Header con Sparkles
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.subheadline.bold())
                        .foregroundColor(.blue)
                    Text("AI Suggestions")
                        .font(.headline)
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                // Área de texto dinámica
                VStack(alignment: .leading, spacing: 12) {
                    Text(aiResponse)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary.opacity(0.8))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .background(Color(.systemGray6).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // Botón de acción unificado
                Button(action: {
                    let free = parkingVM.totalAvailable
                    let occupied = parkingVM.totalOccupied
                    fetchAIRecommendation(free: free, occupied: occupied)
                }) {
                    HStack {
                        if isLoading {
                            Text("Analyzing Data...")
                        } else {
                            Image(systemName: "bolt.fill")
                            Text("Generate Suggestion")
                        }
                    }
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isLoading ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .disabled(isLoading)
            }
            .padding(20) // Igual que la LiveCapacityCard
            .frame(maxWidth: .infinity) // 👈 CLAVE: Se expande para llenar el ancho
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)) // Igual que la otra card
            .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    
    // FUNCIÓN ACTUALIZADA CON PARÁMETROS
    func fetchAIRecommendation(free: Int, occupied: Int) {
        isLoading = true
        let total = free + occupied
        // Construimos el prompt con los datos del ParkingViewModel
        let prompt = """
        Make a short suggestion (max 2 sentences) for someone traveling to Uniandes SD building in Bogota. 
        Current parking status: \(free) spots available and \(occupied) occupied and \(total) total. 
        Take into account traffic for this time of the day and assume they are driving. 
        Do not include bolds, italics, or greetings.
        """

        Task {
            print("📡 Iniciando llamada a Gemini con \(free) cupos...")
            do {
                let response = try await model.generateContent(prompt)
                await MainActor.run {
                    self.aiResponse = response.text ?? "No response available."
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Error detallado: \(error)")
                    self.aiResponse = "Error: Could not get recommendation."
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
