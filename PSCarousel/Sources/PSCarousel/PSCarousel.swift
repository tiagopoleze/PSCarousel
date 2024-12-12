import SwiftUI

public enum CarouselEffect {
    case v0
    case v1
    case v2
    
    func effect(_ proxy: GeometryProxy) -> CGFloat {
        switch self {
        case .v0: 0
        case .v1: proxy.frame(in: .scrollView).minX
        case .v2: min((proxy.frame(in: .scrollView).minX * 1.4), (proxy.size.width * 1.4))
        }
    }
}

public protocol CarouselItem: Identifiable & Equatable { }

public struct CarouselView<
    Content: View,
    Item: RandomAccessCollection
>: View where Item: MutableCollection, Item.Element: CarouselItem {
    private let pagingControlSpacing: CGFloat
    private let spacing: CGFloat
    private let height: CGFloat
    private let width: CGFloat
    private let pageIndicatorTintColor: UIColor
    private let currentPageIndicatorTintColor: UIColor
    private let effect: CarouselEffect
    
    @Binding var data: Item
    @ViewBuilder var content: (Binding<Item.Element>) -> Content
    
    @State private var activeID: UUID?
    
    public init(
        effect: CarouselEffect = .v0,
        height: CGFloat = 403,
        width: CGFloat = 310,
        pageIndicatorTintColor: UIColor = .gray,
        currentPageIndicatorTintColor: UIColor = .black,
        pagingControlSpacing: CGFloat = 8,
        spacing: CGFloat = 16,
        data: Binding<Item>,
        content: @escaping (Binding<Item.Element>) -> Content
    ) {
        self.effect = effect
        self.height = height
        self.width = width
        self.pagingControlSpacing = pagingControlSpacing
        self.spacing = spacing
        self.pageIndicatorTintColor = pageIndicatorTintColor
        self.currentPageIndicatorTintColor = currentPageIndicatorTintColor
        _data = data
        self.content = content
    }
    
    public var body: some View {
        VStack(spacing: pagingControlSpacing) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: spacing) {
                    ForEach($data) { item in
                        GeometryReader { proxy in
                            content(item)
                                .offset(x: -effect.effect(proxy))
                                .scaleEffect(scale(for: proxy), anchor: .center)
                                .frame(width: proxy.size.width * 2.5)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipShape(.rect(cornerRadius: 15))
                        }
                        .frame(width: width, height: height)
                        .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                            view.scaleEffect(phase.isIdentity ? 1 : 0.95)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $activeID)
            .frame(height: height)
            .safeAreaPadding(.horizontal, (UIScreen.main.bounds.width - width)/2)
            CarouselPagingControl(
                numberOfPages: data.count,
                activePage: activePage,
                currentPageIndicatorTintColor: currentPageIndicatorTintColor,
                pageIndicatorTintColor: pageIndicatorTintColor
            ) { value in
                if let index = value as? Item.Index, data.indices.contains(index) {
                    if let id = data[index].id as? UUID {
                        withAnimation(.snappy(duration: 0.35, extraBounce: 0)) {
                            activeID = id
                        }
                    }
                }
                
            }
        }
    }
    
    var activePage: Int {
        if let index = data.firstIndex(where: { $0.id as? UUID == activeID }) as? Int {
            return index
        }
        return 0
    }
    
    private func scale(for geometry: GeometryProxy) -> CGFloat {
        let midX = geometry.frame(in: .global).midX
        let screenWidth = UIScreen.main.bounds.width
        let distanceFromCenter = abs(midX - screenWidth / 2)
        
        let minScale: CGFloat = 0.9
        let maxScale: CGFloat = 1.0
        let threshold: CGFloat = screenWidth / 2
        
        return max(minScale, maxScale - (distanceFromCenter / threshold) * (maxScale - minScale))
    }
}

struct CarouselPagingControl: UIViewRepresentable {
    let numberOfPages: Int
    let activePage: Int
    let currentPageIndicatorTintColor: UIColor
    let pageIndicatorTintColor: UIColor
    let onPageChange: (Int) -> Void
    
    func makeUIView(context: Context) -> UIPageControl {
        let view = UIPageControl()
        view.currentPage = activePage
        view.numberOfPages = numberOfPages
        view.currentPageIndicatorTintColor = currentPageIndicatorTintColor
        view.pageIndicatorTintColor = pageIndicatorTintColor
        view.addTarget(context.coordinator, action: #selector(Coordinator.onPageUpdate(control:)), for: .valueChanged)
        return view
    }
    
    func updateUIView(_ uiView: UIPageControl, context: Context) {
        uiView.numberOfPages = numberOfPages
        uiView.currentPage = activePage
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPageChange: onPageChange)
    }
    
    class Coordinator: NSObject {
        var onPageChange: (Int) -> Void
        
        init(onPageChange: @escaping (Int) -> Void) {
            self.onPageChange = onPageChange
        }
        
        @MainActor @objc func onPageUpdate(control: UIPageControl) {
            onPageChange(control.currentPage)
        }
    }
}

struct Testing: CarouselItem {
    var id: UUID = .init()
    var color: Color
    
    init(color: Color) {
        self.color = color
    }
}

struct TestingImage: CarouselItem {
    var id: UUID = .init()
    var imageResource: ImageResource
    
    init(imageResource: ImageResource) {
        self.imageResource = imageResource
    }
}

#Preview {
    @Previewable @State var colors: [Testing] = [
        .init(color: .red),
        .init(color: .blue),
        .init(color: .green),
        .init(color: .yellow),
        .init(color: .purple),
        .init(color: .orange)
    ]
    
    @Previewable @State var images: [TestingImage] = [
        .init(imageResource: .city1),
        .init(imageResource: .city2),
        .init(imageResource: .city3)
    ]
    CarouselView(data: $colors) { color in
        RoundedRectangle(cornerRadius: 25)
            .fill(color.color.wrappedValue.gradient)
    }
    
    CarouselView(effect: .v2, data: $images) { imageResource in
        Image(imageResource.imageResource.wrappedValue)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}
