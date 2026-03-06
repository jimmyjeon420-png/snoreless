import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var healthKitManager = HealthKitManager()

    @State private var currentPage = 0
    @State private var isRequestingPermissions = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentPage) {
                // 페이지 1: 같이 자는 사람을 위해
                page1.tag(0)

                // 페이지 2: 권한 요청
                page2.tag(1)

                // 페이지 3: 시작 안내
                page3.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 페이지 1: 같이 자는 사람을 위해
    private var page1: some View {
        VStack(spacing: 32) {
            Spacer()

            // 일러스트
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: 200, height: 200)

                Image(systemName: "bed.double.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text(String(localized: "같이 자는 사람을 위해"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(String(localized: "옆 사람의 잠을 지켜주는\n조용한 코골이 관리"))
                    .font(.body)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Spacer()

            Button {
                withAnimation {
                    currentPage = 1
                }
            } label: {
                Text(String(localized: "다음"))
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }

    // MARK: - 페이지 2: 권한 요청
    private var page2: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 200, height: 200)

                VStack(spacing: 16) {
                    Image(systemName: "waveform.and.mic")
                        .font(.system(size: 44))
                        .foregroundStyle(.cyan)

                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                }
            }

            VStack(spacing: 12) {
                Text(String(localized: "몇 가지 권한이 필요해요"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 16) {
                    permissionRow(
                        icon: "waveform.and.mic",
                        color: .cyan,
                        title: String(localized: "마이크 (워치)"),
                        desc: String(localized: "코골이 소리를 감지합니다")
                    )

                    permissionRow(
                        icon: "heart.fill",
                        color: .green,
                        title: String(localized: "건강 데이터"),
                        desc: String(localized: "수면 패턴과 심박수를 분석합니다")
                    )

                    permissionRow(
                        icon: "bell.fill",
                        color: .orange,
                        title: String(localized: "알림"),
                        desc: String(localized: "아침 리포트를 알려드립니다")
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            Spacer()

            Button {
                requestPermissions()
            } label: {
                HStack {
                    if isRequestingPermissions {
                        ProgressView()
                            .tint(.black)
                    }
                    Text(isRequestingPermissions ? String(localized: "설정 중...") : String(localized: "권한 허용하기"))
                        .font(.headline)
                        .foregroundStyle(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(isRequestingPermissions)
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }

    // MARK: - 페이지 3: 시작 안내
    private var page3: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: 200, height: 200)

                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.system(size: 70))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 12) {
                Text(String(localized: "준비 완료"))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text(String(localized: "잠들기 전, 워치에서\n'수면 시작'을 눌러주세요"))
                    .font(.body)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text(String(localized: "코골이를 감지하면 살짝 진동으로\n자세를 바꾸도록 도와드릴게요"))
                    .font(.callout)
                    .foregroundStyle(.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 4)
            }

            Spacer()

            Button {
                withAnimation {
                    hasCompletedOnboarding = true
                }
            } label: {
                Text(String(localized: "시작하기"))
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 60)
        }
    }

    // MARK: - 권한 행 헬퍼
    private func permissionRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
        }
    }

    // MARK: - 권한 요청
    private func requestPermissions() {
        isRequestingPermissions = true

        // HealthKit 권한
        Task {
            do {
                try await healthKitManager.requestAuthorization()
            } catch {
                print("[Onboarding] HealthKit 권한 요청 실패: \(error)")
            }

            // 알림 권한
            await NotificationManager.shared.requestAuthorization()

            await MainActor.run {
                isRequestingPermissions = false
                withAnimation {
                    currentPage = 2
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
}
