//
//  DashboardView.swift
//  ParkingApp
//
//  Created by Mateo on 19/02/26.
//


import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var vm: ParkingViewModel
    @Binding var selectedTab: Int
    @Binding var scrollOffset: CGFloat
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showHistory = false

    var body: some View {
        ZStack(alignment: .top) {
            // Fondo gris claro para toda la pantalla
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // 1. RASTREADOR DE SCROLL (GeometryReader invisible)
                    GeometryReader { geo in
                        let offset = -geo.frame(in: .named("scroll")).origin.y
                        Color.clear.preference(
                            key: ScrollOffsetKey.self,
                            value: offset
                        )
                    }
                    .frame(height: 0)

                    // 2. ESPACIADOR DINÁMICO
                    // Este espacio permite que el contenido empiece debajo del header azul
                    Color.clear.frame(height: 80)

                    // MARK: - Time-Aware Content
                    TimelineView(.periodic(from: Date(), by: 60)) { context in
                        let now = context.date
                        let operatingStatus = PeakHoursSchedule.operatingStatus(
                            at: now,
                            openingHour: vm.config.openingHour,
                            closingHour: vm.config.closingHour
                        )
                        let demandLevel = PeakHoursSchedule.demandLevel(at: now)
                        let countdown = PeakHoursSchedule.transitionCountdown(
                            at: now,
                            openingHour: vm.config.openingHour,
                            closingHour: vm.config.closingHour
                        )

                        VStack(spacing: 0) {
                            switch operatingStatus {
                            case .open:
                                ParkingStatusBannerView(demandLevel: demandLevel, countdown: countdown)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 12)
                            case .closingSoon(let mins):
                                ClosingSoonBannerView(minutesLeft: mins)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 12)
                            case .closed:
                                EmptyView()
                            }

                            switch operatingStatus {
                            case .closed(let opensAt):
                                ParkingClosedCardView(
                                    opensAtHour: opensAt,
                                    now: now,
                                    selectedTab: $selectedTab
                                )
                            default:
                                availabilityCard
                            }
                        }
                    }
                    
                    // MARK: - Bottom Action Cards
                    HStack(spacing: 16) {
                        Button {
                            withAnimation { selectedTab = 1 }
                        } label: {
                            SmallCard(icon: "car.fill", title: "Floor Details", subtitle: "View Breakdown")
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            showHistory = true
                        } label: {
                            SmallCard(icon: "clock.fill", title: "My History", subtitle: "View Stats")
                        }
                        .buttonStyle(.plain)
                    }
                    .sheet(isPresented: $showHistory) {
                        MyHistoryView()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 25)
                    // MARK: - Gerente Section
                    if authVM.isGerente {
                        GerenteSummaryView()
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 100)
                    } else {
                        Color.clear.frame(height: 100)
                    }
                }
            }
            .coordinateSpace(name: "scroll")
            // Capturamos el valor del GeometryReader y lo pasamos al binding
            // 3. EL HEADER FIJO (Siempre encima)
                        StaticHeader(
                            title: "SD Building Parking",
                            subtitle: "Universidad de los Andes"
                        )
            
            // 3. CAPA DEL HEADER (Siempre arriba en el ZStack)
            
        }
    }
    
    // MARK: - Availability Card
    @ViewBuilder
    private var availabilityCard: some View {
        VStack(spacing: 20) {
            Text("Available Parking Spots")
                .font(.system(size: 16))
                .foregroundColor(.gray)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(vm.totalAvailable)")
                    .font(.system(size: 64, weight: .bold))
                Text("/ \(vm.spots.count)")
                    .font(.title2)
                    .foregroundColor(.gray)
            }

            Text(vm.totalAvailable > 0 ? "Available" : "Full")
                .font(.system(size: 14, weight: .bold))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(vm.totalAvailable > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .foregroundColor(vm.totalAvailable > 0 ? .green : .red)
                .clipShape(Capsule())

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 8)

                    Capsule()
                        .fill(vm.occupancyProgress > 0.8 ? Color.orange : Color.green)
                        .frame(width: proxy.size.width * CGFloat(vm.occupancyProgress), height: 8)
                }
            }
            .frame(height: 8)
            .padding(.horizontal, 20)

            HStack(spacing: 15) {
                miniStatusCard(
                    icon: "car.2.fill",
                    title: "Queue Outside",
                    value: "\(vm.config.queueLength) car\(vm.config.queueLength == 1 ? "" : "s")"
                )
                miniStatusCard(
                    icon: "clock.fill",
                    title: "Est. Wait",
                    value: estimatedWait(for: vm.config.queueLength)
                )
            }

            VStack(spacing: 12) {
                Button(action: { withAnimation { selectedTab = 2 } }) {
                    Label("Navigate to Parking", systemImage: "paperplane.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button(action: { withAnimation { selectedTab = 1 } }) {
                    Label("Spot View", systemImage: "calendar")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 5)
        .padding(.horizontal, 20)
    }

    /// 5 minutes per car in queue, formatted nicely.
    private func estimatedWait(for queue: Int) -> String {
        guard queue > 0 else { return "No wait" }
        let minutes = queue * 5
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private func miniStatusCard(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.gray)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}
#Preview {
    
    DashboardView(selectedTab: .constant(0), scrollOffset: .constant(0))
        .environmentObject(ParkingViewModel())
}
