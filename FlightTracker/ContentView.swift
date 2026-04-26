import SwiftUI

struct ContentView: View {
    @State private var flightNumber = ""
    @State private var selectedDate = Date()
    @State private var flights: [Flight] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @FocusState private var isFlightNumberFocused: Bool
    
    let service = FlightService()
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack {
                Spacer()
                    .frame(height: 180)

                VStack(spacing: 20) {
                    if flights.isEmpty && errorMessage == nil {
                        searchForm
                    } else {
                        Button {
                            resetSearch()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        resultsHeader

                        if let errorMessage {
                            messageCard(errorMessage, systemImage: "exclamationmark.circle.fill", tint: .red)
                        }

                        if !flights.isEmpty {
                            ScrollView {
                                VStack(spacing: 16) {
                                    ForEach(flights) { flight in
                                        FlightCardView(flight: flight)
                                    }
                                }
                            }
                        }
                    }

                    if isLoading {
                        ProgressView("Looking up flight")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 32)

            logoView
        }
    }
    
    func loadFlight() async {
        let normalizedFlightNumber = flightNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !normalizedFlightNumber.isEmpty else {
            errorMessage = "Enter a flight number."
            flights = []
            return
        }

        flightNumber = normalizedFlightNumber
        isLoading = true
        errorMessage = nil
        flights = []

        do {
            flights = try await service.fetchFlights(
                flightNumber: normalizedFlightNumber,
                date: apiDate(selectedDate)
            )

            if flights.isEmpty {
                errorMessage = "No flights found for \(normalizedFlightNumber)."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func resetSearch() {
        flightNumber = ""
        flights = []
        errorMessage = nil
        isFlightNumberFocused = true
    }

    func displayDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy"
        return formatter.string(from: date)
    }

    func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var searchForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Track a flight")
                .font(.title3.weight(.semibold))

            TextField("Enter flight (e.g. CX549)", text: $flightNumber)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($isFlightNumberFocused)
                .onSubmit {
                    Task {
                        await loadFlight()
                    }
                }
                .onAppear {
                    isFlightNumberFocused = true
                }

            DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)

            Text("Selected Date: \(displayDate(selectedDate))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Track Flight") {
                Task {
                    await loadFlight()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading)
            .frame(maxWidth: .infinity, alignment: .center)

            if let errorMessage {
                messageCard(errorMessage, systemImage: "exclamationmark.circle.fill", tint: .red)
            }
        }
    }

    @ViewBuilder
    var resultsHeader: some View {
        if !flights.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(flights.count) result\(flights.count == 1 ? "" : "s")")
                    .font(.headline)

                Text("Showing matches for \(flightNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    func messageCard(_ message: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    var logoView: some View {
        HStack(spacing: 10) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 28))
            Text("FlightTracker")
                .font(.title2.weight(.semibold))
        }
        .foregroundStyle(.blue)
        .padding(.top, 24)
    }
}
