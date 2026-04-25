//
//  aiVM.swift
//  sd-smart-parking
//
//  Created by Mateo on 8/04/26.
//

import SwiftUI
import GoogleGenerativeAI
import Combine

@MainActor
class AIViewModel: ObservableObject {
    @Published var aiResponse: String = "Presiona generar para analizar tu llegada al edificio SD."
    @Published var isLoading: Bool = false
    let myKey = Secrets.apiKey
    
    private let model: GenerativeModel

    init() {
        // Configuramos los ajustes de seguridad para evitar bloqueos por palabras como "tráfico"
        let safetySettings = [
            SafetySetting(harmCategory: .harassment, threshold: .blockNone),
            SafetySetting(harmCategory: .dangerousContent, threshold: .blockNone)
        ]
        
        // Usamos el modelo más estable y económico para 2026
        self.model = GenerativeModel(
            name: "gemini-2.5-flash-lite",
            apiKey: myKey,
            safetySettings: safetySettings
        )
    }

    /// Función para obtener la recomendación basada en los datos del parkingVM
    func getAIRecommendation(free: Int, occupied: Int) {
        self.isLoading = true
        
        // Construcción del contexto dinámico
        let total = free + occupied
        let prompt = """
        Actúa como un asistente inteligente de movilidad para la Universidad de los Andes en Bogotá.
        Contexto actual del parqueadero Edificio SD:
        - Cupos libres: \(free)
        - Cupos ocupados: \(occupied)
        - Capacidad total: \(total)

        Instrucciones:
        1. Si los cupos libres son menos de 5, advierte seriamente sobre la alta ocupación.
        2. Si hay más de 15 libres, menciona que el ingreso será fluido.
        3. Mantén la respuesta en máximo 2 frases cortas y con un tono amable pero profesional.
        4. No uses saludos genéricos como 'Hola', ve directo al grano.
        """

        Task {
            do {
                let response = try await model.generateContent(prompt)
                
                // Actualizamos la UI en el hilo principal
                await MainActor.run {
                    if let text = response.text {
                        self.aiResponse = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else {
                        self.aiResponse = "La IA no pudo generar un consejo en este momento."
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Error Gemini: \(error.localizedDescription)")
                    self.aiResponse = "Error de conexión. Intenta de nuevo en unos segundos."
                    self.isLoading = false
                }
            }
        }
    }
}
