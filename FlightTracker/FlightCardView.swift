import SwiftUI

struct FlightCardView: View {
    let flight: Flight

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flight.flight.iata ?? "Unknown Flight")
                        .font(.headline)

                    Text(flight.airline?.name ?? "Airline unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(flight.flight_status.capitalized)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.16))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            HStack(alignment: .top) {
                airportColumn(
                    title: "Departure",
                    airport: flight.departure.airport,
                    code: flight.departure.iata,
                    time: flight.departure.scheduled,
                    timeZoneIdentifier: flight.departure.timezone,
                    delay: flight.departure.delay,
                    alignment: .leading
                )

                Spacer()

                Image(systemName: "airplane")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 18)

                Spacer()

                airportColumn(
                    title: "Arrival",
                    airport: flight.arrival.airport,
                    code: flight.arrival.iata,
                    time: flight.arrival.scheduled,
                    timeZoneIdentifier: flight.arrival.timezone,
                    delay: flight.arrival.delay,
                    alignment: .trailing
                )
            }

            if let expectedDurationText {
                Text("Expected duration: \(expectedDurationText)")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack {
                detailPill(title: "Airline", value: flight.airline?.iata ?? "N/A")
                detailPill(title: "Number", value: flight.flight.number ?? "N/A")
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }

    @ViewBuilder
    func airportColumn(
        title: String,
        airport: String?,
        code: String?,
        time: String?,
        timeZoneIdentifier: String?,
        delay: Int?,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(airport ?? "Airport unavailable")
                .font(.subheadline)

            Text(code ?? "N/A")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(localTimeString(for: time, timeZoneIdentifier: timeZoneIdentifier))
                .font(.title3.weight(.semibold))

            if let timeZoneLabel = timeZoneLabel(for: timeZoneIdentifier, scheduledTime: time) {
                Text(timeZoneLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let deviceLocalTime = deviceLocalTimeString(for: time, timeZoneIdentifier: timeZoneIdentifier) {
                Text("Your time: \(deviceLocalTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let delay, delay > 0 {
                Text("\(delay)m delay")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    func detailPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    func localTimeString(for isoString: String?, timeZoneIdentifier: String?) -> String {
        guard let date = scheduledDate(from: isoString, timeZoneIdentifier: timeZoneIdentifier) else {
            return isoString ?? "N/A"
        }

        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        display.timeZone = timeZone(for: timeZoneIdentifier) ?? .current

        return display.string(from: date)
    }

    func timeZoneLabel(for timeZoneIdentifier: String?, scheduledTime: String?) -> String? {
        guard let timeZone = timeZone(for: timeZoneIdentifier) else {
            return nil
        }

        let abbreviationDate = scheduledDate(from: scheduledTime, timeZoneIdentifier: timeZoneIdentifier) ?? Date()
        let abbreviation = timeZone.abbreviation(for: abbreviationDate) ?? timeZone.identifier
        return "\(abbreviation) local time"
    }

    func deviceLocalTimeString(for isoString: String?, timeZoneIdentifier: String?) -> String? {
        guard let date = scheduledDate(from: isoString, timeZoneIdentifier: timeZoneIdentifier) else {
            return nil
        }

        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        display.timeZone = .current
        return display.string(from: date)
    }

    func timeZone(for identifier: String?) -> TimeZone? {
        guard let identifier, !identifier.isEmpty else {
            return nil
        }

        return TimeZone(identifier: identifier)
    }

    func scheduledDate(from isoString: String?, timeZoneIdentifier: String?) -> Date? {
        guard
            let isoString,
            let timeZone = timeZone(for: timeZoneIdentifier)
        else {
            return nil
        }

        let localTimestamp = String(isoString.prefix(19))
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = timeZone
        return formatter.date(from: localTimestamp)
    }

    var expectedDurationText: String? {
        guard
            let departureDate = scheduledDate(
                from: flight.departure.scheduled,
                timeZoneIdentifier: flight.departure.timezone
            ),
            let arrivalDate = scheduledDate(
                from: flight.arrival.scheduled,
                timeZoneIdentifier: flight.arrival.timezone
            ),
            arrivalDate > departureDate
        else {
            return nil
        }

        let components = Calendar.current.dateComponents([.hour, .minute], from: departureDate, to: arrivalDate)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }

        return "\(minutes)m"
    }

    var statusColor: Color {
        switch flight.flight_status.lowercased() {
        case "active", "scheduled":
            return .green
        case "landed":
            return .blue
        case "cancelled", "incident", "diverted":
            return .red
        default:
            return .orange
        }
    }
}
