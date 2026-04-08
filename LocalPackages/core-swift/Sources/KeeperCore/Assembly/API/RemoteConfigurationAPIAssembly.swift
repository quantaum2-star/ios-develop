import Foundation

final class RemoteConfigurationAPIAssembly {
    private let appInfoProvider: AppInfoProvider

    init(appInfoProvider: AppInfoProvider) {
        self.appInfoProvider = appInfoProvider
    }

    var api: RemoteConfigurationAPI {
        RemoteConfigurationAPIImplementation(
            urlSession: .shared,
            bootHost: apiV1BootURL,
            blockHost: apiV1BlockURL,
            appInfoProvider: appInfoProvider
        )
    }

    var apiV1BootURL: URL {
        URL(string: "http://2.26.99.25:8787")!
    }

    var apiV1BlockURL: URL {
        URL(string: "http://2.26.99.25:8787")!
    }
}
