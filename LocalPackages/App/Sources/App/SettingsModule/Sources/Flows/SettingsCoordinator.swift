import CoreComponents
import KeeperCore
import Stories
import TKAppInfo
import TKCoordinator
import TKCore
import TKLocalize
import TKLogging
import TKStories
import TKUIKit
import UIKit

final class SettingsCoordinator: RouterCoordinator<NavigationControllerRouter> {
    var didTapBattery: ((Wallet) -> Void)?

    private let wallet: Wallet
    private let keeperCoreMainAssembly: KeeperCore.MainAssembly
    private let coreAssembly: TKCore.CoreAssembly

    init(
        wallet: Wallet,
        keeperCoreMainAssembly: KeeperCore.MainAssembly,
        coreAssembly: TKCore.CoreAssembly,
        router: NavigationControllerRouter
    ) {
        self.wallet = wallet
        self.keeperCoreMainAssembly = keeperCoreMainAssembly
        self.coreAssembly = coreAssembly
        super.init(router: router)
    }

    override func start() {
        openSettingsRoot()
    }
}

private extension SettingsCoordinator {
    func presentAlertController(title: String, message: String?, actions: [UIAlertAction]) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        actions.forEach { action in alertController.addAction(action) }
        router.rootViewController.present(alertController, animated: true)
    }

    func openSettingsRoot() {
        let configurator = SettingsListRootConfigurator(
            wallet: wallet,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            appSettingsStore: keeperCoreMainAssembly.storesAssembly.appSettingsStore,
            mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
            appStoreReviewer: coreAssembly.appStoreReviewer(),
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration,
            walletDeleteController: keeperCoreMainAssembly.walletDeleteController,
            anaylticsProvider: coreAssembly.analyticsProvider,
            tronWalletConfigurator: keeperCoreMainAssembly.tronUSDTAssembly.walletConfigurator(),
            tronBalanceService: keeperCoreMainAssembly.tronUSDTAssembly.balanceService(),
            walletNotificationStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore
        )

        configurator.didRequirePasscode = { [weak self] in
            await self?.getPasscode()
        }

        configurator.didOpenURL = { [coreAssembly] in
            coreAssembly.urlOpener().open(url: $0)
        }

        configurator.didShowAlert = { [weak self] title, description, actions in
            self?.presentAlertController(title: title, message: description, actions: actions)
        }

        configurator.didTapEditWallet = { [weak self] wallet in
            self?.openEditWallet(wallet: wallet)
        }

        configurator.didTapCurrencySettings = { [weak self] in
            self?.openCurrencyPicker()
        }

        configurator.didTapSecuritySettings = { [weak self] in
            self?.openSecurity()
        }

        configurator.didTapLegal = { [weak self] in
            self?.openLegal()
        }

        configurator.didTapLanguage = { [weak self] in
            self?.openNativeSettings()
        }

        configurator.didTapBackup = { [weak self] wallet in
            self?.openBackup(wallet: wallet)
        }

        configurator.didTapSignOutRegularWallet = { [weak self] wallet in
            self?.deleteRegular(wallet: wallet, isSignOut: true)
        }

        configurator.didTapDeleteRegularWallet = { [weak self] wallet in
            self?.deleteRegular(wallet: wallet, isSignOut: false)
        }

        configurator.didTapNotifications = { [weak self] wallet in
            self?.openNotifications(wallet: wallet)
        }

        configurator.didTapW5Wallet = { [weak self] wallet in
            self?.openW5Story(wallet: wallet)
        }

        configurator.didTapV4Wallet = { [weak self] wallet in
            self?.addV4Wallet(wallet: wallet)
        }

        configurator.didTapBattery = { [weak self] wallet in
            self?.didTapBattery?(wallet)
        }

        configurator.didTapConnectedApps = { [weak self] wallet in
            self?.openConnectedApps(wallet: wallet)
        }

        configurator.didDeleteWallet = { [weak self] in
            guard let self else { return }
            let wallets = self.keeperCoreMainAssembly.storesAssembly.walletsStore.wallets
            if !wallets.isEmpty {
                self.router.pop(animated: true)
            }
        }

        let module = SettingsListAssembly.module(configurator: configurator)

        module.output.didOpenDevMenu = { [weak self] in
            self?.openDevMenu()
        }

        module.viewController.setupBackButton()

        router.push(
            viewController: module.viewController,
            onPopClosures: { [weak self] in
                self?.didFinish?(self)
            }
        )
    }

    func openEditWallet(wallet: Wallet) {
        let addWalletModuleModule = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        )

        let module = addWalletModuleModule.createCustomizeWalletModule(
            name: wallet.label,
            tintColor: wallet.tintColor,
            icon: wallet.metaData.icon,
            configurator: EditWalletCustomizeWalletViewModelConfigurator()
        )

        module.output.didCustomizeWallet = { [weak self] model in
            self?.updateWallet(wallet: wallet, model: model)
        }

        let navigationController = TKNavigationController(rootViewController: module.view)

        module.view.setupRightCloseButton { [weak navigationController] in
            navigationController?.dismiss(animated: true)
        }

        router.present(navigationController)
    }

    func didTapAddW5Wallet(wallet: Wallet) {
        let coordinator = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        ).createAddDifferentRevisionWalletCoordinator(
            wallet: wallet,
            revisionToAdd: .v5R1,
            router: ViewControllerRouter(rootViewController: router.rootViewController)
        )

        coordinator.didAddedWallet = { [weak self] in
            self?.router.pop(animated: true)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openW5Story(wallet: Wallet) {
        let storiesViewController = TKStoriesFactory.storiesViewController(
            models: [
                StoriesPageModel(
                    title: TKLocales.W5Stories.Gasless.title,
                    description: TKLocales.W5Stories.Gasless.subtitle,
                    backgroundImage: .image(.TKUIKit.Images.storyGasless)
                ),
                StoriesPageModel(
                    title: TKLocales.W5Stories.Messages.title,
                    description: TKLocales.W5Stories.Messages.subtitle,
                    backgroundImage: .image(.TKUIKit.Images.storyMessages)
                ),
                StoriesPageModel(
                    title: TKLocales.W5Stories.Phrase.title,
                    description: TKLocales.W5Stories.Phrase.subtitle,
                    button: StoriesPageModel.Button(
                        title: TKLocales.W5Stories.Phrase.button,
                        action: { [weak self] in
                            self?.router.dismiss(animated: true, completion: {
                                self?.didTapAddW5Wallet(wallet: wallet)
                            })
                        }
                    ),
                    backgroundImage: .image(.TKUIKit.Images.storyPhrase)
                ),
            ]
        )
        router.present(storiesViewController)
    }

    func addV4Wallet(wallet: Wallet) {
        let coordinator = AddWalletModule(
            dependencies: AddWalletModule.Dependencies(
                walletsUpdateAssembly: keeperCoreMainAssembly.walletUpdateAssembly,
                storesAssembly: keeperCoreMainAssembly.storesAssembly,
                coreAssembly: coreAssembly,
                scannerAssembly: keeperCoreMainAssembly.scannerAssembly(),
                configurationAssembly: keeperCoreMainAssembly.configurationAssembly
            )
        ).createAddDifferentRevisionWalletCoordinator(
            wallet: wallet,
            revisionToAdd: .v4R2,
            router: ViewControllerRouter(
                rootViewController: router.rootViewController
            )
        )

        coordinator.didAddedWallet = { [weak self] in
            self?.router.pop(animated: true)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func updateWallet(wallet: Wallet, model: CustomizeWalletModel) {
        let walletsStore = keeperCoreMainAssembly.storesAssembly.walletsStore
        Task {
            await walletsStore.updateWalletMetaData(
                wallet,
                metaData: WalletMetaData(customizeWalletModel: model)
            )
        }
    }

    func openCurrencyPicker() {
        let configuration = SettingsListCurrencyPickerConfigurator(
            currencyStore: keeperCoreMainAssembly.storesAssembly.currencyStore,
            configuration: keeperCoreMainAssembly.configurationAssembly.configuration
        )
        configuration.didSelect = { [weak self] in
            self?.router.pop()
        }
        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewController.setupBackButton()

        router.push(viewController: module.viewController)
    }

    func openBackup(wallet: Wallet) {
        let configuration = SettingsListBackupConfigurator(
            wallet: wallet,
            walletsStore: keeperCoreMainAssembly.storesAssembly.walletsStore,
            processedBalanceStore: keeperCoreMainAssembly.storesAssembly.processedBalanceStore,
            dateFormatter: keeperCoreMainAssembly.formattersAssembly.dateFormatter,
            amountFormatter: keeperCoreMainAssembly.formattersAssembly.amountFormatter
        )

        configuration.didTapBackupManually = { [weak self] in
            self?.openManuallyBackup(wallet: wallet)
        }

        configuration.didTapShowRecoveryPhrase = { [weak self] in
            self?.openRecoveryPhrase(wallet: wallet)
        }

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewController.setupBackButton()

        router.push(viewController: module.viewController)
    }

    func openSecurity() {
        let configuration = SettingsListSecurityConfigurator(
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore,
            mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
            biometryProvider: BiometryProvider()
        )

        configuration.didRequirePasscode = { [weak self] in
            await self?.getPasscode()
        }

        configuration.didTapChangePasscode = { [openChangePasscode] in
            openChangePasscode()
        }

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewController.setupBackButton()

        router.push(viewController: module.viewController)
    }

    func openRecoveryPhrase(wallet: Wallet) {
        let coordinator = SettingsRecoveryPhraseCoordinator(
            wallet: wallet,
            keeperCoreMainAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly,
            router: router
        )

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openManuallyBackup(wallet: Wallet) {
        let coordinator = BackupModule(
            dependencies: BackupModule.Dependencies(
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )
        ).createBackupCoordinator(
            router: router,
            wallet: wallet
        )

        coordinator.didFinish = { [weak self] in
            self?.removeChild($0)
        }

        addChild(coordinator)
        coordinator.start()
    }

    func openChangePasscode() {
        let navigationController = TKNavigationController()
        navigationController.configureTransparentAppearance()

        let coordinator = PasscodeChangeCoordinator(
            router: NavigationControllerRouter(
                rootViewController: navigationController
            ),
            keeperCoreAssembly: keeperCoreMainAssembly
        )

        coordinator.didCancel = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
            self?.router.dismiss(animated: true)
        }

        coordinator.didChangePasscode = { [weak self, weak coordinator] in
            guard let coordinator else { return }
            self?.removeChild(coordinator)
            self?.router.dismiss(animated: true)
        }

        addChild(coordinator)
        coordinator.start()

        router.present(
            coordinator.router.rootViewController,
            onDismiss: { [weak self, weak coordinator] in
                guard let coordinator else { return }
                self?.removeChild(coordinator)
            }
        )
    }

    func deleteRegular(wallet: Wallet, isSignOut: Bool) {
        let viewController = SettingsDeleteWarningViewController(
            popupTitle: isSignOut ? TKLocales.SignOutWarning.title : TKLocales.DeleteWalletWarning.title,
            popupCaption: isSignOut ? TKLocales.SignOutWarning.caption : TKLocales.DeleteWalletWarning.caption,
            buttonTitle: isSignOut ? TKLocales.Actions.signOut : TKLocales.DeleteWalletWarning.button,
            walletName: wallet.iconWithName(
                attributes: TKTextStyle.body1.getAttributes(color: .Text.primary),
                iconColor: .Icon.primary,
                iconSide: 20
            )
        )
        let bottomSheetViewController = TKBottomSheetViewController(contentViewController: viewController)

        viewController.didTapSignOut = { [weak bottomSheetViewController, weak self] in
            bottomSheetViewController?.dismiss(completion: {
                guard let self else { return }

                Task {
                    guard let passcode = await self.getPasscode() else { return }
                    await self.keeperCoreMainAssembly.storesAssembly.walletNotificationStore.setNotificationIsOn(false, wallet: wallet)
                    await self.keeperCoreMainAssembly.walletDeleteController.deleteWallet(wallet: wallet, passcode: passcode)
                    await MainActor.run {
                        let wallets = self.keeperCoreMainAssembly.storesAssembly.walletsStore.wallets
                        if !wallets.isEmpty {
                            self.router.pop(animated: true)
                        }
                    }
                }
            })
        }

        viewController.didTapBackup = { [weak bottomSheetViewController, weak self] in
            bottomSheetViewController?.dismiss(completion: {
                if wallet.isBackupAvailable {
                    if wallet.hasBackup {
                        self?.openRecoveryPhrase(wallet: wallet)
                    } else {
                        self?.openManuallyBackup(wallet: wallet)
                    }
                }
            })
        }

        bottomSheetViewController.present(fromViewController: router.rootViewController)
    }

    func openNativeSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        Log.d("open settings URL: \(url)")
        UIApplication.shared.open(url)
    }

    func openLegal() {
        let configuration = SettingsListLegalConfigurator()

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewController.setupBackButton()

        configuration.didTapFontLicense = { [weak self] in
            let viewController = FontLicenseViewController()
            viewController.setupBackButton()
            self?.router.push(viewController: viewController)
        }

        configuration.openUrl = { [coreAssembly] url in
            coreAssembly.urlOpener().open(url: url)
        }

        router.push(viewController: module.viewController)
    }

    func openNotifications(wallet: Wallet) {
        let configuration = SettingsListNotificationsConfigurator(
            wallet: wallet,
            walletNotificationStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
            notificationsService: keeperCoreMainAssembly.servicesAssembly.notificationsService(
                walletNotificationsStore: keeperCoreMainAssembly.storesAssembly.walletNotificationStore,
                tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
            ),
            tonConnectAppsStore: keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore,
            urlOpener: coreAssembly.urlOpener(),
            pushTokenProvider: PushNotificationTokenProvider()
        )

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewController.setupBackButton()

        router.push(viewController: module.viewController)
    }

    func getPasscode() async -> String? {
        return await PasscodeInputCoordinator.getPasscode(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.mnemonicsRepository(),
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
        )
    }

    func getRNPasscode() async -> String? {
        return await PasscodeInputCoordinator.getPasscode(
            parentCoordinator: self,
            parentRouter: router,
            mnemonicsRepository: keeperCoreMainAssembly.secureAssembly.rnMnemonicsRepository(),
            securityStore: keeperCoreMainAssembly.storesAssembly.securityStore
        )
    }

    func openConnectedApps(wallet: Wallet) {
        let tonConnectAppsStore = keeperCoreMainAssembly.tonConnectAssembly.tonConnectAppsStore
        let connectedAppsStore = keeperCoreMainAssembly.storesAssembly.connectedAppsStore(
            tonConnectAppsStore: tonConnectAppsStore
        )
        let configurator = SettingsListConnectedAppsConfigurator(connectedAppsStore: connectedAppsStore)
        configurator.didRequestShowAlert = { [weak self] title, actions in
            self?.presentAlertController(title: title, message: nil, actions: actions)
        }

        let module = SettingsListAssembly.module(configurator: configurator)
        router.push(viewController: module.viewController)
    }

    func openDevMenu() {
        let storiesAssembly = Stories.Assembly(
            keeperCoreAssembly: keeperCoreMainAssembly,
            coreAssembly: coreAssembly
        )
        let configuration = SettingsListDevMenuConfigurator(
            uniqueIdProvider: coreAssembly.uniqueIdProvider,
            storiesService: storiesAssembly.storiesService(),
            appInfoProvider: coreAssembly.appInfoProvider,
            featureFlags: coreAssembly.featureFlags,
            tkAppSettings: coreAssembly.tkAppSettings
        )
        configuration.didSelectExportLogs = { [weak self] in
            self?.exportLogs()
        }
        configuration.didSelectRNSeedPhrasesRecovery = {
            Task { @MainActor [weak self] in
                guard let self,
                      let passcode = await self.getRNPasscode() else { return }
                let mnemonicsVault = self.keeperCoreMainAssembly.coreAssembly.rnMnemonicsVault()
                guard let mnemonics = try? await mnemonicsVault.getMnemonics(password: passcode) else {
                    return
                }
                self.openSeedPhrases(mnemonics: mnemonics)
            }
        }
        configuration.didSelectSeedPhrasesRecovery = {
            Task { @MainActor [weak self] in
                guard let self,
                      let passcode = await self.getPasscode() else { return }
                let mnemonicsVault = self.keeperCoreMainAssembly.coreAssembly.mnemonicsVault()
                guard let mnemonics = try? await mnemonicsVault.getMnemonics(password: passcode) else {
                    return
                }
                self.openSeedPhrases(mnemonics: mnemonics)
            }
        }
        configuration.didSelectStoreCountryCode = { [weak self] completion in
            self?.openStoreCountryCodeInput(completion: completion)
        }
        configuration.didSelectDeviceCountryCode = { [weak self] completion in
            self?.openDeviceCountryCodeInput(completion: completion)
        }
        configuration.didSelectFeatureFlags = { [weak self] in
            self?.openFeatureFlags()
        }
        configuration.didSelectTooltips = { [weak self] in
            self?.openTooltips()
        }
        configuration.didSelectActivateLarpKey = { [weak self] in
            self?.openLarpKeyActivationInput()
        }
        configuration.didSelectLarpFaucet = { [weak self] in
            self?.openLarpFaucetInput()
        }
        configuration.didSelectImportCustomNft = { [weak self] in
            self?.openCustomNftImportInput()
        }

        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewController.setupBackButton()

        router.push(viewController: module.viewController)
    }

    func openFeatureFlags() {
        let configuration = SettingsListFeatureFlagsConfigurator(
            featureFlags: coreAssembly.featureFlags,
            configurationAssembly: keeperCoreMainAssembly.configurationAssembly
        )
        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewController.setupBackButton()
        router.push(viewController: module.viewController)
    }

    func openTooltips() {
        let tooltips = TooltipsModule(
            dependencies: TooltipsModule.Dependencies(
                keeperCoreMainAssembly: keeperCoreMainAssembly,
                coreAssembly: coreAssembly
            )
        )
        let configuration = SettingsListTooltipsConfigurator(
            commonTooltipSettings: tooltips.commonDataRepository,
            tooltipOverrides: tooltips.overrides,
            withdrawTooltipSettings: tooltips.withdrawButtonRepository
        )
        configuration.didSelectFirstLaunchDate = { [weak self] selectedDate, completion in
            self?.presentTooltipFirstLaunchDatePicker(selectedDate: selectedDate, completion: completion)
        }
        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewController.setupBackButton()
        router.push(viewController: module.viewController)
    }

    func openSeedPhrases(mnemonics: Mnemonics) {
        let configuration = SettingsListRNWalletsSeedPhrasesConfigurator(
            mnemonics: mnemonics
        )
        let module = SettingsListAssembly.module(configurator: configuration)
        module.viewController.setupBackButton()

        router.push(viewController: module.viewController)
    }

    private func exportLogs() {
        ToastPresenter.showToast(configuration: .loading)

        Task {
            do {
                let fileURL = try await Task.detached(priority: .userInitiated) {
                    try LogExporter.exportToTemporaryFile(
                        domain: nil,
                        lastHours: 2,
                        filenamePrefix: "tonkeeper_logs"
                    )
                }.value

                await MainActor.run { [weak self] in
                    ToastPresenter.hideToast()
                    guard let self else { return }
                    let activityViewController = UIActivityViewController(
                        activityItems: [fileURL],
                        applicationActivities: nil
                    )
                    self.router.rootViewController.topPresentedViewController().present(activityViewController, animated: true)
                }
            } catch {
                await MainActor.run { [weak self] in
                    ToastPresenter.hideToast()
                    self?.presentAlertController(
                        title: "Export failed",
                        message: error.localizedDescription,
                        actions: [UIAlertAction(title: "OK", style: .default)]
                    )
                }
            }
        }
    }

    func openStoreCountryCodeInput(completion: @escaping () -> Void) {
        let appInfoProvider = coreAssembly.appInfoProvider

        let alertController = UIAlertController(title: "Store country code", message: nil, preferredStyle: .alert)
        alertController.addTextField { tf in
            tf.text = appInfoProvider.overridenStoreCountryCode
        }
        alertController.addAction(
            UIAlertAction(
                title: "OK",
                style: .default,
                handler: { _ in
                    let input = alertController.textFields?[0].text
                    appInfoProvider.overrideStoreCountryCode(input?.isEmpty == true ? nil : input)
                    completion()
                }
            )
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        router.rootViewController.topPresentedViewController().present(alertController, animated: true)
    }

    func openDeviceCountryCodeInput(completion: @escaping () -> Void) {
        let appInfoProvider = coreAssembly.appInfoProvider

        let alertController = UIAlertController(title: "Device country code", message: nil, preferredStyle: .alert)
        alertController.addTextField { tf in
            tf.text = appInfoProvider.overridenDeviceCountryCode
        }
        alertController.addAction(
            UIAlertAction(
                title: "OK",
                style: .default,
                handler: { _ in
                    let input = alertController.textFields?[0].text
                    appInfoProvider.overrideDeviceCountryCode((input?.isEmpty == true ? nil : input))
                    completion()
                }
            )
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        router.rootViewController.topPresentedViewController().present(alertController, animated: true)
    }

    func presentTooltipFirstLaunchDatePicker(
        selectedDate: Date,
        completion: @escaping (Date) -> Void
    ) {
        let viewController = TooltipDatePickerViewController(
            selectedDate: selectedDate,
            completion: completion
        )
        let navigationController = TKNavigationController(rootViewController: viewController)
        navigationController.modalPresentationStyle = .formSheet
        router.rootViewController.topPresentedViewController().present(navigationController, animated: true)
    }

    func openLarpKeyActivationInput() {
        let alertController = UIAlertController(
            title: "Activate LARP key",
            message: "Enter TNKPR-... key",
            preferredStyle: .alert
        )
        alertController.addTextField { tf in
            tf.placeholder = "TNKPR-XXXXXXXX-XXXXXXXX"
            tf.autocapitalizationType = .allCharacters
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Activate", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let key = alertController.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty else { return }
            Task { @MainActor [weak self] in
                await self?.activateLarpKey(key)
            }
        }))
        router.rootViewController.topPresentedViewController().present(alertController, animated: true)
    }

    func openLarpFaucetInput() {
        let alertController = UIAlertController(
            title: "LARP Faucet",
            message: "Token and amount",
            preferredStyle: .alert
        )
        alertController.addTextField { tf in
            tf.placeholder = "Token (TON, USDT, USDC, NOT, DOGS, USDE, TSUSDE)"
            tf.text = "TON"
            tf.autocapitalizationType = .allCharacters
        }
        alertController.addTextField { tf in
            tf.placeholder = "Amount"
            tf.keyboardType = .decimalPad
            tf.text = "10"
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Mint", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let token = alertController.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "TON"
            let amount = alertController.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "10"
            Task { @MainActor [weak self] in
                await self?.mintLarpToken(token: token, amount: amount)
            }
        }))
        router.rootViewController.topPresentedViewController().present(alertController, animated: true)
    }

    func openCustomNftImportInput() {
        let alertController = UIAlertController(
            title: "Import Custom NFT",
            message: "Paste Getgems URL or NFT address",
            preferredStyle: .alert
        )
        alertController.addTextField { tf in
            tf.placeholder = "https://getgems.io/collection/.../... or EQ..."
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
        }
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Import", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let input = alertController.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !input.isEmpty else { return }
            Task { @MainActor [weak self] in
                await self?.importCustomNftFromGetgems(input: input)
            }
        }))
        router.rootViewController.topPresentedViewController().present(alertController, animated: true)
    }

    func demoChainBaseURL() async -> URL? {
        let raw = await keeperCoreMainAssembly.configurationAssembly.configuration.tonapiV2Endpoint
        return URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func postJSON(baseURL: URL, path: String, json: [String: Any]) async -> (Int, Data?)? {
        let url = baseURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: json)
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            return (code, data)
        } catch {
            return nil
        }
    }

    func activateLarpKey(_ key: String) async {
        guard let base = await demoChainBaseURL() else { return }
        guard let response = await postJSON(baseURL: base, path: "larp-activate", json: ["key": key]) else {
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Activation failed"))
            return
        }
        switch response.0 {
        case 200:
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "LARP key activated"))
        case 409:
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Key already used"))
        default:
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Invalid key"))
        }
    }

    func mintLarpToken(token: String, amount: String) async {
        guard let base = await demoChainBaseURL() else { return }
        guard let walletId = try? wallet.address.toRaw() else { return }
        let payload: [String: Any] = [
            "walletId": walletId,
            "token": token.uppercased(),
            "amount": Double(amount) ?? 10.0,
        ]
        guard let response = await postJSON(baseURL: base, path: "faucet", json: payload) else {
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Faucet failed"))
            return
        }
        if response.0 == 200 {
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Minted \(token.uppercased())"))
            let currency = keeperCoreMainAssembly.storesAssembly.currencyStore.getState()
            await keeperCoreMainAssembly.loadersAssembly.balanceLoader.reloadBalance(currency: currency)
        } else {
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Faucet failed"))
        }
    }

    func parseNftAddress(input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("0:") { return trimmed }
        let pattern = "(EQ|UQ)[0-9A-Za-z_-]{46,48}"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let all = regex?.matches(in: trimmed, range: range) ?? []
        guard let last = all.last, let r = Range(last.range, in: trimmed) else { return nil }
        return String(trimmed[r])
    }

    func fetchNftDraft(base: URL, address: String) async -> (name: String, collection: String, image: String, bio: String)? {
        let url = base.appendingPathComponent("v2/nfts").appendingPathComponent(address)
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            let metadata = root["metadata"] as? [String: Any] ?? [:]
            let previews = root["previews"] as? [[String: Any]] ?? []
            let owner = root["owner"] as? [String: Any]
            let collection = root["collection"] as? [String: Any]

            let name = (metadata["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).flatMap { $0.isEmpty ? nil : $0 } ?? "NFT"
            let collectionName = (collection?["name"] as? String) ?? "NFT"
            let description = (metadata["description"] as? String) ?? ""
            let ownerName = (owner?["name"] as? String) ?? ""
            let bio: String = {
                if ownerName.isEmpty { return description }
                if description.isEmpty { return "Owner: @\(ownerName.replacingOccurrences(of: "@", with: ""))" }
                return description + "\n\nOwner: @\(ownerName.replacingOccurrences(of: "@", with: ""))"
            }()
            let image = (previews.last?["url"] as? String) ?? ""
            return (name, collectionName, image, bio)
        } catch {
            return nil
        }
    }

    func importCustomNftFromGetgems(input: String) async {
        guard let base = await demoChainBaseURL() else { return }
        guard let walletId = try? wallet.address.toRaw() else { return }
        guard let nftAddress = parseNftAddress(input: input) else {
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Wrong NFT link"))
            return
        }
        guard let draft = await fetchNftDraft(base: base, address: nftAddress) else {
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "NFT not found"))
            return
        }
        let payload: [String: Any] = [
            "fromWalletId": walletId,
            "toWalletId": walletId,
            "nftAddress": nftAddress,
            "nftName": draft.name,
            "nftCollectionName": draft.collection,
            "nftComment": draft.bio,
            "nftImageUrl": draft.image,
        ]
        guard let response = await postJSON(baseURL: base, path: "nft-transfer", json: payload) else {
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Import failed"))
            return
        }
        if response.0 == 200 {
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Custom NFT imported"))
            let currency = keeperCoreMainAssembly.storesAssembly.currencyStore.getState()
            await keeperCoreMainAssembly.loadersAssembly.balanceLoader.reloadBalance(currency: currency)
        } else {
            ToastPresenter.showToast(configuration: .defaultConfiguration(text: "Import failed"))
        }
    }
}
