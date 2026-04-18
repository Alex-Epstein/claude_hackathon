//
//  CameraLoggerView.swift
//  Appetight
//

import SwiftUI
import PhotosUI
import UIKit

struct CameraLoggerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    @State private var pickerSource: ImagePicker.Source?
    @State private var image: UIImage?
    @State private var analyzing = false
    @State private var analysis: FoodAnalysis?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(.rect(cornerRadius: 16))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(Brand.green)
                            Text("Snap a food photo")
                                .font(.headline)
                            Text("Claude will identify it and estimate the calories.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .padding()
                        .background(.gray.opacity(0.06), in: .rect(cornerRadius: 16))
                    }

                    HStack(spacing: 10) {
                        Button {
                            pickerSource = .camera
                        } label: {
                            Label("Camera", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            pickerSource = .library
                        } label: {
                            Label("Library", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.red.opacity(0.08), in: .rect(cornerRadius: 8))
                    }

                    if image != nil && analysis == nil {
                        Button {
                            Task { await analyze() }
                        } label: {
                            HStack {
                                if analyzing { ProgressView().controlSize(.small) }
                                Text(analyzing ? "Analyzing..." : "Analyze Food")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(analyzing)
                    }

                    if let analysis {
                        analysisCard(analysis)
                    }
                }
                .padding()
            }
            .navigationTitle("Camera Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(item: $pickerSource) { src in
                ImagePicker(source: src) { picked in
                    image = picked
                    analysis = nil
                    errorMessage = nil
                }
                .ignoresSafeArea()
            }
        }
    }

    private func analysisCard(_ a: FoodAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(a.name).font(.headline)
            Text("\(a.calories) kcal")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(Brand.green)
            if let s = a.servingDescription {
                Text(s).font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label("\(Int(a.proteinG))g protein", systemImage: "p.circle")
                    .font(.caption)
                Label("\(Int(a.carbsG))g carbs", systemImage: "c.circle")
                    .font(.caption)
                Label("\(Int(a.fatG))g fat", systemImage: "f.circle")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            Button {
                appState.addMeal(MealLog(
                    name: a.name,
                    calories: a.calories,
                    proteinG: a.proteinG,
                    carbsG: a.carbsG,
                    fatG: a.fatG,
                    source: .camera
                ))
                dismiss()
            } label: {
                Label("Log It", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(Brand.green.opacity(0.08), in: .rect(cornerRadius: 12))
    }

    private func analyze() async {
        guard let image,
              let data = image.jpegData(compressionQuality: 0.7)
        else { return }
        analyzing = true
        errorMessage = nil
        defer { analyzing = false }

        let base64 = data.base64EncodedString()
        do {
            analysis = try await AnthropicService.shared.analyzeFoodImage(base64Jpeg: base64)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - UIKit wrappers

struct ImagePicker: UIViewControllerRepresentable {
    enum Source: String, Identifiable {
        case camera, library
        var id: String { rawValue }
    }

    let source: Source
    let onPick: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIViewController {
        switch source {
        case .camera:
            #if targetEnvironment(simulator)
            // Simulator can't use camera — fall back to photo picker
            var cfg = PHPickerConfiguration(photoLibrary: .shared())
            cfg.filter = .images
            cfg.selectionLimit = 1
            let p = PHPickerViewController(configuration: cfg)
            p.delegate = context.coordinator
            return p
            #else
            let p = UIImagePickerController()
            p.sourceType = .camera
            p.delegate = context.coordinator
            return p
            #endif
        case .library:
            var cfg = PHPickerConfiguration(photoLibrary: .shared())
            cfg.filter = .images
            cfg.selectionLimit = 1
            let p = PHPickerViewController(configuration: cfg)
            p.delegate = context.coordinator
            return p
        }
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let img = info[.originalImage] as? UIImage {
                parent.onPick(img)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                guard let self, let img = obj as? UIImage else { return }
                DispatchQueue.main.async { self.parent.onPick(img) }
            }
        }
    }
}
