import FeniceCore
import SwiftUI

struct TutorAgendaView: View {
    @EnvironmentObject private var app: AppState
    let user: User

    var body: some View {
        let lessons = app.store.agenda(tutorId: user.id)
        let byDay = Dictionary(grouping: lessons) { app.store.calendar.startOfDay(for: $0.start) }

        List {
            if lessons.isEmpty {
                Text("Nessuna lezione in programma. Pubblica qualche fascia in Disponibilità.")
                    .foregroundStyle(.secondary)
            }
            ForEach(byDay.keys.sorted(), id: \.self) { day in
                Section(Format.day(day)) {
                    ForEach(byDay[day] ?? []) { booking in
                        NavigationLink {
                            BookingDetailView(bookingId: booking.id)
                        } label: {
                            AgendaRow(booking: booking)
                        }
                    }
                }
            }
        }
        .navigationTitle("Agenda")
    }
}

private struct AgendaRow: View {
    @EnvironmentObject private var app: AppState
    let booking: Booking

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(Format.timeRange(booking.start, booking.end))
                .monospacedDigit()
                .frame(width: 100, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(app.store.subjectName(booking.subjectId)) · \(app.store.userName(booking.studentId))")
                    .font(.headline)
                if !booking.note.isEmpty {
                    Text(booking.note)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if booking.canAdvance {
                StatusBadge(text: "Può anticipare", color: .teal)
            }
            if app.store.cancellation(forBooking: booking.id)?.status.isOpen == true {
                StatusBadge(text: "Annullamento chiesto", color: .orange)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AvailabilityView: View {
    @EnvironmentObject private var app: AppState
    let user: User

    @State private var day = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var startMinutes = 18 * 60
    @State private var endMinutes = 21 * 60

    var body: some View {
        let bands = app.store.availabilities(forTutor: user.id)

        Form {
            Section {
                DatePicker("Giorno", selection: $day, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                Picker("Dalle", selection: $startMinutes) {
                    ForEach(Array(Schedule.bandTimeOptions.dropLast(2)), id: \.self) { minutes in
                        Text(Format.clock(minutes: minutes)).tag(minutes)
                    }
                }
                Picker("Alle", selection: $endMinutes) {
                    ForEach(Schedule.bandTimeOptions.filter { $0 >= startMinutes + 60 }, id: \.self) { minutes in
                        Text(Format.clock(minutes: minutes)).tag(minutes)
                    }
                }
                HStack {
                    Spacer()
                    Button("Aggiungi fascia") { add() }
                        .buttonStyle(.borderedProminent)
                }
            } header: {
                Text("Nuova fascia")
            } footer: {
                Text("Gli studenti potranno prenotare con inizio ogni 30 minuti dentro la fascia. Le fasce finiscono al massimo alle 23:30.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Fasce in programma") {
                if bands.isEmpty {
                    Text("Non hai fasce future.")
                        .foregroundStyle(.secondary)
                }
                ForEach(bands) { band in
                    BandRow(band: band)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Disponibilità")
        .onChange(of: startMinutes) {
            if endMinutes < startMinutes + 60 {
                endMinutes = min(startMinutes + 60, Schedule.latestEndMinutes)
            }
        }
    }

    private func add() {
        let start = app.store.date(on: day, minutes: startMinutes)
        let end = app.store.date(on: day, minutes: endMinutes)
        app.perform("Fascia aggiunta") {
            _ = try app.store.addAvailability(tutorId: user.id, start: start, end: end)
        }
    }
}

private struct BandRow: View {
    @EnvironmentObject private var app: AppState
    let band: Availability

    var body: some View {
        let bookings = app.store.bookings(inAvailability: band.id)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Format.day(band.start))
                    .font(.headline)
                Text(Format.timeRange(band.start, band.end))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    app.perform("Fascia eliminata") {
                        try app.store.deleteAvailability(id: band.id, tutorId: band.tutorId)
                    }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .disabled(!bookings.isEmpty)
                .help(bookings.isEmpty ? "Elimina la fascia" : "Ci sono prenotazioni, non si può eliminare")
            }
            if bookings.isEmpty {
                Text("Nessuna prenotazione")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ForEach(bookings) { booking in
                Text("\(Format.timeRange(booking.start, booking.end))  \(app.store.subjectName(booking.subjectId)) con \(app.store.userName(booking.studentId))")
                    .font(.callout)
            }
        }
        .padding(.vertical, 2)
    }
}

struct TutorCancellationsView: View {
    @EnvironmentObject private var app: AppState
    let user: User

    var body: some View {
        let requests = app.store.openCancellations(forTutor: user.id)
        List {
            if requests.isEmpty {
                Text("Nessuna richiesta in attesa.")
                    .foregroundStyle(.secondary)
            }
            ForEach(requests) { request in
                CancellationRow(request: request, showActions: true)
            }
        }
        .navigationTitle("Annullamenti")
    }
}

/// usata sia dal tutor sia dall'admin
struct CancellationRow: View {
    @EnvironmentObject private var app: AppState
    let request: CancellationRequest
    var showActions = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lesson = app.store.booking(request.bookingId) {
                HStack {
                    Text("\(app.store.subjectName(lesson.subjectId)) · \(Format.dateTime(lesson.start))")
                        .font(.headline)
                    Spacer()
                    StatusBadge(text: request.isEarly ? "≥ 12 ore prima" : "< 12 ore prima", color: request.isEarly ? .green : .orange)
                    StatusBadge(text: request.status.label, color: request.status.color)
                }
                Text("Studente: \(app.store.userName(lesson.studentId)) · Tutor: \(app.store.userName(lesson.tutorId))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("“\(request.reason)”")
                .italic()
            if let decider = request.decidedById, let decidedAt = request.decidedAt {
                Text("Decisa da \(app.store.userName(decider)) il \(Format.timestamp(decidedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if showActions && request.status.isOpen {
                CancellationActions(request: request)
            }
        }
        .padding(.vertical, 4)
    }
}

struct TutorStudentsView: View {
    @EnvironmentObject private var app: AppState
    let user: User

    var body: some View {
        let students = app.store.students(ofTutor: user.id)
        List {
            if students.isEmpty {
                Text("Ancora nessuno studente ha prenotato con te.")
                    .foregroundStyle(.secondary)
            }
            ForEach(students) { student in
                HStack(spacing: 12) {
                    AvatarView(user: student, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(student.fullName)
                            .font(.headline)
                        Text(nextLessonText(student))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Format.euros(student.balanceCents))
                        .monospacedDigit()
                        .foregroundStyle(student.balanceCents < 0 ? Color.red : Color.primary)
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle("I miei studenti")
    }

    private func nextLessonText(_ student: User) -> String {
        guard let next = app.store.nextLesson(studentId: student.id, tutorId: user.id) else {
            return "Nessuna lezione in programma"
        }
        return "Prossima: \(app.store.subjectName(next.subjectId)), \(Format.dateTime(next.start))"
    }
}

struct TutorSubjectsView: View {
    @EnvironmentObject private var app: AppState
    let user: User

    var body: some View {
        Form {
            Section {
                ForEach(app.store.subjects) { subject in
                    Toggle(subject.name, isOn: binding(for: subject))
                }
            } footer: {
                Text("Gli studenti ti vedono solo per le materie attive qui.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Materie che insegno")
    }

    private func binding(for subject: Subject) -> Binding<Bool> {
        Binding(
            get: { user.subjectIds.contains(subject.id) },
            set: { enabled in
                app.perform {
                    try app.store.setTeaches(tutorId: user.id, subjectId: subject.id, enabled: enabled)
                }
            }
        )
    }
}
