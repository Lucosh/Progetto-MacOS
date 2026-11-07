import FeniceCore
import SwiftUI

/// materia -> durata -> tutor -> giorno e ora -> riepilogo
struct BookingWizardView: View {
    @EnvironmentObject private var app: AppState
    let user: User

    @State private var subjectId: Int?
    @State private var duration = 60
    @State private var canAdvance = false
    @State private var tutorId: Int?
    @State private var day: Date?
    @State private var slot: TimeSlot?
    @State private var note = ""

    var body: some View {
        Form {
            Section("1 · Materia e durata") {
                Picker("Materia", selection: $subjectId) {
                    Text("Scegli una materia").tag(Int?.none)
                    ForEach(app.store.subjects) { subject in
                        Text(subject.name).tag(Int?.some(subject.id))
                    }
                }
                Picker("Durata", selection: $duration) {
                    ForEach(Schedule.lessonDurations, id: \.self) { minutes in
                        Text(Format.duration(minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Sono disponibile ad anticipare la lezione", isOn: $canAdvance)
            }
            if let subjectId {
                tutorSection(subjectId)
            }
            if let tutorId {
                slotSection(tutorId)
            }
            if let slot, let subjectId, let tutorId {
                summarySection(slot: slot, subjectId: subjectId, tutorId: tutorId)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Prenota una lezione")
        .onChange(of: subjectId) { resetFromTutor() }
        .onChange(of: duration) { resetFromTutor() }
        .onChange(of: tutorId) {
            day = nil
            slot = nil
        }
        .onChange(of: day) { slot = nil }
    }

    private func resetFromTutor() {
        tutorId = nil
        day = nil
        slot = nil
    }

    @ViewBuilder
    private func tutorSection(_ subjectId: Int) -> some View {
        let tutors = app.store.availableTutors(subjectId: subjectId, durationMinutes: duration, studentId: user.id)
        Section("2 · Tutor") {
            if tutors.isEmpty {
                Text("Nessun tutor ha orari liberi per questa materia e durata. Prova con un'altra durata o riprova più avanti.")
                    .foregroundStyle(.secondary)
            }
            ForEach(tutors) { tutor in
                Button {
                    tutorId = tutor.id
                } label: {
                    HStack {
                        AvatarView(user: tutor)
                        Text(tutor.fullName)
                        Spacer()
                        if tutorId == tutor.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.fenice)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func slotSection(_ tutorId: Int) -> some View {
        let slots = app.store.freeSlots(tutorId: tutorId, studentId: user.id, durationMinutes: duration)
        let days = Array(Set(slots.map { app.store.calendar.startOfDay(for: $0.start) })).sorted()
        Section("3 · Giorno e orario") {
            Picker("Giorno", selection: $day) {
                Text("Scegli un giorno").tag(Date?.none)
                ForEach(days, id: \.self) { item in
                    Text(Format.day(item)).tag(Date?.some(item))
                }
            }
            if let day {
                let daySlots = slots.filter { app.store.calendar.isDate($0.start, inSameDayAs: day) }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(daySlots) { item in
                        SlotButton(title: Format.time(item.start), selected: slot == item) {
                            slot = item
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private func summarySection(slot: TimeSlot, subjectId: Int, tutorId: Int) -> some View {
        Section("4 · Riepilogo") {
            LabeledContent("Materia", value: app.store.subjectName(subjectId))
            LabeledContent("Tutor", value: app.store.userName(tutorId))
            LabeledContent("Quando", value: "\(Format.day(slot.start)), \(Format.timeRange(slot.start, slot.end))")
            LabeledContent("Prezzo", value: Format.euros(app.store.price(subjectId: subjectId, durationMinutes: duration)))
            TextField("Nota per il tutor (facoltativa)", text: $note, axis: .vertical)
                .lineLimit(2...4)
            Text("\(note.count)/300")
                .font(.caption)
                .foregroundStyle(note.count > 300 ? Color.red : Color.secondary)
            Text("Non paghi adesso: la lezione viene scalata dal saldo 12 ore prima dell'inizio.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Conferma prenotazione") {
                    confirm(slot: slot, subjectId: subjectId, tutorId: tutorId)
                }
                .buttonStyle(.borderedProminent)
                .disabled(note.count > 300)
            }
        }
    }

    private func confirm(slot: TimeSlot, subjectId: Int, tutorId: Int) {
        let error = app.attempt("Lezione prenotata!") {
            _ = try app.store.bookLesson(
                studentId: user.id,
                tutorId: tutorId,
                subjectId: subjectId,
                start: slot.start,
                durationMinutes: duration,
                canAdvance: canAdvance,
                note: note
            )
        }
        if let error {
            app.errorMessage = error
        } else {
            self.subjectId = nil
            note = ""
            canAdvance = false
        }
    }
}

private struct SlotButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .monospacedDigit()
                .frame(width: 70)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(selected ? Color.fenice : Color.secondary.opacity(0.12))
                )
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
