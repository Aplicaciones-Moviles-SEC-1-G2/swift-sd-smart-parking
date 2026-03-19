//
//  ReportsView.swift
//  ParkingApp
//
//  Created by Mateo on 27/02/26.
//
// ReportsView.swift
// ReportsView.swift
import SwiftUI
import Charts

struct ReportsView: View {
    @EnvironmentObject var vm: ParkingViewModel
    @State private var selectedPeriod: ReportPeriod = .today
    
    enum ReportPeriod: String, CaseIterable {
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Period Selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(ReportPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // MARK: - Revenue Section
                    ReportSectionView(title: "Revenue", icon: "dollarsign.circle.fill", color: .green) {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                ReportStatCard(
                                    title: "Total",
                                    value: vm.totalRevenue(for: selectedPeriod).formatted(.currency(code: "COP").presentation(.narrow)),
                                    icon: "sum",
                                    color: .green
                                )
                                ReportStatCard(
                                    title: "Avg per Vehicle",
                                    value: vm.avgRevenuePerVehicle(for: selectedPeriod).formatted(.currency(code: "COP").presentation(.narrow)),
                                    icon: "car.fill",
                                    color: .blue
                                )
                            }
                            
                            ReportStatCard(
                                title: "Vehicles that hit daily cap",
                                value: "\(vm.vehiclesAtCap(for: selectedPeriod))",
                                icon: "exclamationmark.circle.fill",
                                color: .orange
                            )
                            
                            // Gráfica de ingresos
                            RevenueChart(data: vm.revenueChartData(for: selectedPeriod), period: selectedPeriod)
                        }
                    }
                    
                    // MARK: - Occupancy Section
                    ReportSectionView(title: "Occupancy", icon: "square.grid.3x3.fill", color: .blue) {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                ReportStatCard(
                                    title: "Avg Occupancy",
                                    value: "\(Int(vm.avgOccupancy(for: selectedPeriod) * 100))%",
                                    icon: "percent",
                                    color: .blue
                                )
                                ReportStatCard(
                                    title: "Peak Hour",
                                    value: vm.peakHour(for: selectedPeriod),
                                    icon: "clock.fill",
                                    color: .purple
                                )
                            }
                            
                            // Heatmap de horas pico
                            OccupancyChart(data: vm.occupancyChartData(for: selectedPeriod), period: selectedPeriod)
                        }
                    }
                    
                    // MARK: - Vehicles Section
                    ReportSectionView(title: "Vehicles", icon: "car.fill", color: .purple) {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                ReportStatCard(
                                    title: "Total Entries",
                                    value: "\(vm.totalEntries(for: selectedPeriod))",
                                    icon: "arrow.down.circle.fill",
                                    color: .green
                                )
                                ReportStatCard(
                                    title: "Total Exits",
                                    value: "\(vm.totalExits(for: selectedPeriod))",
                                    icon: "arrow.up.circle.fill",
                                    color: .red
                                )
                            }
                            
                            HStack(spacing: 16) {
                                ReportStatCard(
                                    title: "Registered",
                                    value: "\(vm.registeredVehicles(for: selectedPeriod))",
                                    icon: "checkmark.circle.fill",
                                    color: .blue
                                )
                                ReportStatCard(
                                    title: "Unregistered",
                                    value: "\(vm.unregisteredVehicles(for: selectedPeriod))",
                                    icon: "questionmark.circle.fill",
                                    color: .orange
                                )
                            }
                            
                            // Gráfica de vehículos
                            VehiclesChart(data: vm.vehiclesChartData(for: selectedPeriod), period: selectedPeriod)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Reports")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Report Section Container
struct ReportSectionView<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal)
            
            content
                .padding(.horizontal)
        }
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        .padding(.horizontal)
    }
}

// MARK: - Stat Card
struct ReportStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 18, weight: .bold))
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

// MARK: - Revenue Chart
struct RevenueChart: View {
    let data: [ChartDataPoint]
    let period: ReportsView.ReportPeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Revenue Over Time")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Chart(data) { point in
                BarMark(
                    x: .value("Time", point.label),
                    y: .value("Revenue", point.value)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(6)
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(format: .currency(code: "COP").presentation(.narrow))
            }
        }
    }
}

// MARK: - Occupancy Chart
struct OccupancyChart: View {
    let data: [ChartDataPoint]
    let period: ReportsView.ReportPeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Occupancy by Hour")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Chart(data) { point in
                BarMark(
                    x: .value("Hour", point.label),
                    y: .value("Occupancy %", point.value)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(6)
            }
            .frame(height: 180)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%") }
                    AxisGridLine()
                }
            }
        }
    }
}

// MARK: - Vehicles Chart
struct VehiclesChart: View {
    let data: [ChartDataPoint]
    let period: ReportsView.ReportPeriod
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vehicle Activity")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Chart(data) { point in
                LineMark(
                    x: .value("Time", point.label),
                    y: .value("Vehicles", point.value)
                )
                .foregroundStyle(Color.purple.gradient)
                .symbol(Circle())
                
                AreaMark(
                    x: .value("Time", point.label),
                    y: .value("Vehicles", point.value)
                )
                .foregroundStyle(Color.purple.opacity(0.1).gradient)
            }
            .frame(height: 180)
        }
    }
}

// MARK: - Chart Data Point
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

#Preview {
    ReportsView()
        .environmentObject(ParkingViewModel())
}
