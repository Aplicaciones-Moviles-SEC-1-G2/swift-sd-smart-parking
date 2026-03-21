//
//  ScrollOffsetKey.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//

import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    // Valor por defecto (cero scroll)
    static var defaultValue: CGFloat = 0

    // Función que combina los valores de los hijos
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
