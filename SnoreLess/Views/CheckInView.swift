import SwiftUI
import SwiftData

struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // 체크인 항목
    @State private var coffeeAfternoon = false
    @State private var exercised = false
    @State private var alcohol = false
    @State private var stressLevel = 3

    var body: some View {
        Form {
            Section("생활 습관") {
                Toggle("오후에 커피를 마셨나요?", isOn: $coffeeAfternoon)
                Toggle("오늘 운동했나요?", isOn: $exercised)
                Toggle("오늘 술을 마셨나요?", isOn: $alcohol)
            }

            Section("스트레스") {
                Picker("오늘의 스트레스 레벨", selection: $stressLevel) {
                    ForEach(1...5, id: \.self) { level in
                        Text(stressLabel(for: level))
                            .tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Button {
                    saveCheckIn()
                } label: {
                    Text("저장")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationTitle("오늘의 체크인")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 저장
    private func saveCheckIn() {
        let checkIn = DailyCheckIn(
            date: .now,
            coffeeAfternoon: coffeeAfternoon,
            exercised: exercised,
            alcohol: alcohol,
            stressLevel: stressLevel
        )
        modelContext.insert(checkIn)

        do {
            try modelContext.save()
        } catch {
            print("체크인 저장 실패: \(error)")
        }

        dismiss()
    }

    // MARK: - 스트레스 레벨 라벨
    private func stressLabel(for level: Int) -> String {
        switch level {
        case 1: return "1"
        case 2: return "2"
        case 3: return "3"
        case 4: return "4"
        case 5: return "5"
        default: return "\(level)"
        }
    }
}

#Preview {
    NavigationStack {
        CheckInView()
    }
    .modelContainer(for: DailyCheckIn.self, inMemory: true)
}
