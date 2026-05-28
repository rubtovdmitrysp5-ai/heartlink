import SwiftUI
import UIKit

struct ImageCropItem: Identifiable {
    let id = UUID()
    let imageData: Data
    let title: String
    let aspectRatio: CGFloat
    let maxPixelSize: CGFloat
}

struct ImageCropSheet: View {
    let item: ImageCropItem
    let onComplete: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private var image: UIImage? {
        UIImage(data: item.imageData)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RomanticBackground()

                VStack(spacing: 18) {
                    Text("Переместите и увеличьте фото")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    GeometryReader { proxy in
                        let availableWidth = min(proxy.size.width - 32, 360)
                        let cropSize = CGSize(width: availableWidth, height: availableWidth / item.aspectRatio)

                        ZStack {
                            if let image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: cropSize.width, height: cropSize.height)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                                    .gesture(dragGesture)
                                    .simultaneousGesture(magnificationGesture)
                            } else {
                                EmptyStateView(title: "Фото не открылось", subtitle: "Выберите другое изображение.", systemImage: "photo")
                            }

                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .strokeBorder(.white.opacity(0.9), lineWidth: 2)
                                .frame(width: cropSize.width, height: cropSize.height)
                                .allowsHitTesting(false)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    PrimaryActionButton(title: "Применить кадрирование", systemImage: "crop") {
                        guard let image, let cropped = crop(image: image) else { return }
                        onComplete(cropped)
                        dismiss()
                    }
                    .disabled(image == nil)

                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private func crop(image: UIImage) -> Data? {
        guard let cgImage = image.cgImage else { return nil }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let cropAspect = item.aspectRatio
        let baseScale = max(1 / imageWidth, (1 / cropAspect) / imageHeight)
        let effectiveScale = baseScale * scale
        let visibleWidth = min(imageWidth, 1 / effectiveScale)
        let visibleHeight = min(imageHeight, (1 / cropAspect) / effectiveScale)
        let centerX = imageWidth / 2 - offset.width / effectiveScale
        let centerY = imageHeight / 2 - offset.height / effectiveScale
        let originX = min(max(centerX - visibleWidth / 2, 0), imageWidth - visibleWidth)
        let originY = min(max(centerY - visibleHeight / 2, 0), imageHeight - visibleHeight)
        let cropRect = CGRect(x: originX, y: originY, width: visibleWidth, height: visibleHeight)

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }

        let outputWidth = min(item.maxPixelSize, CGFloat(croppedCGImage.width))
        let outputHeight = outputWidth / cropAspect
        let outputSize = CGSize(width: outputWidth, height: outputHeight)
        let croppedImage = UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let rendered = renderer.image { _ in
            croppedImage.draw(in: CGRect(origin: .zero, size: outputSize))
        }

        return rendered.jpegData(compressionQuality: 0.84)
    }
}
