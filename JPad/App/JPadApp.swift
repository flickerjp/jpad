import SwiftUI

@main
struct JPadApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = MainViewModel()
    @State private var showOnboarding = !OnboardingStore.hasCompleted
    @State private var didPrepareLaunchAudio = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showOnboarding {
                    OnboardingView(midiService: viewModel.midiService) {
                        OnboardingStore.markCompleted()
                        showOnboarding = false
                        viewModel.consumePendingPresetImportIfNeeded()
                    }
                } else {
                    MainView(viewModel: viewModel)
                }
            }
            .onOpenURL { url in
                viewModel.handleIncomingPresetFile(url)
            }
            .task {
                PadEditorUIVersion.setCurrent(.v11)
                guard !didPrepareLaunchAudio else { return }
                didPrepareLaunchAudio = true
                viewModel.midiService.preparePreviewAudioIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.midiService.refreshEndpoints()
                    viewModel.midiService.preparePreviewAudioAfterReturningToForeground()
                }
            }
        }
    }
}
