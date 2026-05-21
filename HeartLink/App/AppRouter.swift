import SwiftUI
import Observation

@MainActor
@Observable
final class RouterPath {
    var path: [Route] = []
    var presentedSheet: SheetDestination?

    func navigate(to route: Route) {
        path.append(route)
    }

    func present(_ sheet: SheetDestination) {
        presentedSheet = sheet
    }
}

@MainActor
@Observable
final class TabRouter {
    private var routers: [AppTab: RouterPath] = [:]

    func router(for tab: AppTab) -> RouterPath {
        if let router = routers[tab] {
            return router
        }
        let router = RouterPath()
        routers[tab] = router
        return router
    }

    func binding(for tab: AppTab) -> Binding<[Route]> {
        let router = router(for: tab)
        return Binding(
            get: { router.path },
            set: { router.path = $0 }
        )
    }
}

enum Route: Hashable {
    case memory(String)
    case goal(String)
    case game(String)
}

enum SheetDestination: Identifiable, Hashable {
    case addMemory
    case settings

    var id: String { String(describing: self) }
}
