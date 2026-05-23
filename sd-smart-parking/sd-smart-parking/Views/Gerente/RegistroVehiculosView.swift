//
//  RegistroVehiculosView.swift
//  ParkingApp
//
//  Created by Mateo on 27/02/26.
//
// RegistroVehiculosView.swift
import SwiftUI


struct RegistroVehiculosView: View {
    @EnvironmentObject var vm: ParkingViewModel
    @State private var searchText: String = ""
    @State private var selectedFilter: RecordFilter = .all
    @State private var selectedRecord: VehicleRecord? = nil
    @State private var showingCreateRecord: Bool = false
    @State private var showingBulkLookup: Bool = false
    @State private var showingPinned: Bool = false
    @StateObject private var pinnedVM = PinnedPlatesViewModel()
    
    
    
    
    enum RecordFilter: String, CaseIterable {
        case all = "All"
        case entry = "Entries"
        case exit = "Exits"
        case today = "Today"
        //case unregistered = "Unregistered"
    }
    
    var filteredRecords: [VehicleRecord] {
        vm.vehicleRecords
            .filter { record in
                searchText.isEmpty ? true : record.plate.localizedCaseInsensitiveContains(searchText)
            }
            .filter { record in
                switch selectedFilter {
                case .all: return true
                case .entry: return record.type == .entry
                case .exit: return record.type == .exit
                case.today: return Calendar.current.isDateInToday(record.timestamp)
                //case .unregistered: return !record.isRegistered
                }
            }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                // MARK: - Filter Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(RecordFilter.allCases, id: \.self) { filter in
                            FilterChip(
                                title: filter.rawValue,
                                isSelected: selectedFilter == filter
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedFilter = filter
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGroupedBackground))
                
                // MARK: - Main List
                if filteredRecords.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredRecords) { record in
                            Button {
                                selectedRecord = record
                            } label: {
                                RecordRowView(record: record)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color(.systemGroupedBackground))
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    vm.deleteRecord(record)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    pinnedVM.toggle(record.plate)
                                } label: {
                                    if pinnedVM.isPinned(record.plate) {
                                        Label("Unpin", systemImage: "star.slash")
                                    } else {
                                        Label("Pin", systemImage: "star.fill")
                                    }
                                }
                                .tint(.yellow)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .background(Color(.systemGroupedBackground))
                    .toolbarBackground(.visible, for: .navigationBar)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Vehicle Registry")
            .searchable(text: $searchText, prompt: "Search plate")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingBulkLookup = true
                    } label: {
                        Image(systemName: "magnifyingglass.circle")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Bulk plate lookup")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingPinned = true
                    } label: {
                        Image(systemName: pinnedVM.pinned.isEmpty ? "star" : "star.fill")
                            .foregroundStyle(.yellow)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pinned plates")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {

                        showingCreateRecord = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            // 🔹 NAVEGACIÓN MODERNA USANDO EL BOOL
            .navigationDestination(isPresented: $showingCreateRecord) {
                CreateRecordView()
            }
            .sheet(item: $selectedRecord) { record in
                RecordDetailView(record: record).environmentObject(vm)
            }
            .sheet(isPresented: $showingBulkLookup) {
                BulkPlateLookupView()
                    .environmentObject(vm)
                    .environmentObject(NetworkMonitor.shared)
            }
            .sheet(isPresented: $showingPinned, onDismiss: { pinnedVM.reload() }) {
                PinnedPlatesView()
                    .environmentObject(vm)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "car.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.4))
            Text("No records found")
                .foregroundColor(.gray)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}


// MARK: - Updated Components (English)

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.white)
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }
}

struct RecordRowView: View {
    let record: VehicleRecord
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "car.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.plate)
                        .font(.system(size: 16, weight: .bold))
                    
                    if !record.isRegistered {
                        Text("Unregistered")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                    }
                }
                
                if let email = record.ownerEmail {
                    Text(email)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Text(record.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 4) {
                Image(systemName: record.type == .entry ? "arrow.down.right.circle.fill" : "arrow.up.forward.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(record.type == .entry ? .green : .blue)
                Text(record.type == .entry ? "Entry" : "Exit")
                    .font(.system(size: 11))
                    .foregroundColor(record.type == .entry ? .green : .blue)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(16)
    }
}

#Preview {
    RegistroVehiculosView()
        .environmentObject(ParkingViewModel())
}
