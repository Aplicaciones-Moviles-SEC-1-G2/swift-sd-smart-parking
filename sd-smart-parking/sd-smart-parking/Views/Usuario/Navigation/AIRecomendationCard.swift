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
    
    // El VM de parqueo para sacar los datos reales
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
            name: "gemini-2.5-flash-lite",
            apiKey: "AIzaSyD_te2nJttAzp07IHJOb8KFuBbzWuWVqyw",
            safetySettings: safetySettings
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text("IA suggestions")
                    .font(.headline)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                
                if isLoading {
                    ProgressView("Generating suggestions...")
                        .padding()
                } else {
                    Text(aiResponse)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true) // ✅ Esto asegura que el texto no se corte
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: 150)
                }
            }
            
            Button(action: {
                // Obtenemos los datos actuales y llamamos a la función
                let free = parkingVM.totalAvailable
                let occupied = parkingVM.totalOccupied
                fetchAIRecommendation(free: free, occupied: occupied)
                
            }) {
                Text(isLoading ? "Generating..." : "Generate")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isLoading)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 5)
        .padding()
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
