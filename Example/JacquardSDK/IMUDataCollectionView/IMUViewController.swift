// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Combine
import JacquardSDK
import MaterialComponents
import SVProgressHUD

struct IMUSessionCellModel: Hashable {
  let session: IMUSession

  static func == (lhs: IMUSessionCellModel, rhs: IMUSessionCellModel) -> Bool {
    return lhs.session.name == rhs.session.name
  }

  func hash(into hasher: inout Hasher) {
    session.name.hash(into: &hasher)
  }
}

private enum IMUSessionSection: Int {
  case current
  case past
  var title: String {
    switch self {
    case .current: return "CURRENT SESSION"
    case .past: return "PAST SESSIONS"
    }
  }
}

class IMUSession: Codable {
  var name: String
  var metadata: IMUSessionInfo?
  var fileURL: URL?

  init(name: String, metadata: IMUSessionInfo? = nil, fileURL: URL? = nil) {
    self.name = name
    self.metadata = metadata
    self.fileURL = fileURL
  }
}

final class IMUViewController: UIViewController {

  private enum Constants {
    static let startRecording = "Record"
    static let stopRecording = "Stop Recording"
    static let imuSessionsStoreKey = "IMUSessionsStoreKey"
    static let recordingInProgressWarning =
      "Session recording is in progress. Please stop recording first."
    static let cancelTitle = "Cancel"
  }

  // MARK: IBOutlets

  @IBOutlet private weak var startStopButton: UIButton!
  @IBOutlet private weak var sessionTableView: UITableView!
  @IBOutlet private weak var recordingIndicatorView: UIView!

  private var imuDiffableDataSource:
    UITableViewDiffableDataSource<IMUSessionSection, IMUSessionCellModel>?

  // MARK: Instance vars

  private var observers = [Cancellable]()
  /// Convenience stream that only contains the tag.
  private var tagPublisher: AnyPublisher<ConnectedTag, Never>
  private var imuModule: IMUModuleImplementation?
  private var imuSessions = [IMUSession]()
  private var sessionDownloadProgressVC: ProgressAlertViewController?
  private var isRecordingInProgress = false
  private var menuButton: UIBarButtonItem?

  private var recordingTimer: Timer?

  private enum DownloadedSessionPath {
    static let imuDirectory =
      FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask)[0].appendingPathComponent("IMUFiles")

    static func filePath(for session: IMUSession) -> URL {
      if !FileManager.default.fileExists(atPath: DownloadedSessionPath.imuDirectory.path) {
        try? FileManager.default.createDirectory(
          at: DownloadedSessionPath.imuDirectory,
          withIntermediateDirectories: true,
          attributes: nil
        )
      }
      return imuDirectory.appendingPathComponent("\(session.name).bin")
    }
  }

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
    super.init(nibName: "IMUViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  // MARK: View life cycle

  override func viewDidLoad() {
    super.viewDidLoad()

    startStopButton.setTitle(Constants.startRecording, for: .normal)
    recordingIndicatorView.isHidden = true
    tagPublisher
      .prefix(1)
      .sink { [weak self] tag in
        guard let self = self else { return }
        self.imuModule = IMUModuleImplementation(connectedTag: tag)
        self.initializeIMUModule()
        // List locally downloaded sessions.
        self.listDownloadedSessions()
      }.addTo(&observers)
    configureSessionTableView()

    menuButton = UIBarButtonItem(
      image: UIImage(named: "ic_overflow_menu"), style: .plain, target: self,
      action: #selector(self.menuButtonTapped))
    navigationItem.rightBarButtonItem = menuButton
    navigationItem.rightBarButtonItem?.tintColor = .black

    let backButton = UIBarButtonItem(
      image: UIImage(named: "back"), style: .plain, target: self,
      action: #selector(self.backButtonTapped))
    navigationItem.leftBarButtonItem = backButton
    navigationItem.leftBarButtonItem?.tintColor = .black
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    observers.forEach { $0.cancel() }
  }

  // MARK: IBActions and selectors

  @IBAction func startIMUSession(_ sender: UIButton) {
    if startStopButton.title(for: .normal) == Constants.startRecording {
      startRecording()
    } else {
      stopRecording()
    }
  }

  @objc private func menuButtonTapped() {
    let actionsheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    actionsheet.addAction(
      UIAlertAction(
        title: "Delete all sessions",
        style: .default,
        handler: { [weak self] _ in
          self?.showDeleteAllSessionsAlert()
        }))
    actionsheet.addAction(
      UIAlertAction(title: Constants.cancelTitle, style: .cancel, handler: nil))
    present(actionsheet, animated: true, completion: nil)
  }

  @objc private func backButtonTapped() {
    if startStopButton.title(for: .normal) == Constants.startRecording {
      // No recording is in progress. Unload the module to save the battery draining.
      // Upon revisiting this screen, during initialization process, module will be
      // loaded again.
      SVProgressHUD.show()
      imuModule?.deactivateModule().sink { [weak self] completion in
        SVProgressHUD.dismiss()
        switch completion {
        case .failure(let error):
          print("Received error while deactivating module: \(error)")
        case .finished:
          break
        }
        self?.navigationController?.popViewController(animated: true)
      } receiveValue: { [weak self] _ in
        SVProgressHUD.dismiss()
        print("Successfully deactivated the module.")
        self?.navigationController?.popViewController(animated: true)
      }
      .addTo(&observers)

    } else {
      navigationController?.popViewController(animated: true)
    }
  }
}

// MARK: Alerts and UI handling

extension IMUViewController {

  private func showDeleteAllSessionsAlert() {
    guard !isRecordingInProgress else {
      MDCSnackbarManager.default.show(
        MDCSnackbarMessage(text: Constants.recordingInProgressWarning))
      return
    }
    let alertViewController = AlertViewController()
    let acceptHandler: () -> Void = { [weak self] in
      self?.deleteAllSessions()
    }
    alertViewController.configureAlertView(
      title: "Delete All Sessions",
      description: "Are you sure you want to delete all sessions?",
      acceptButtonTitle: "Delete",
      cancelButtonTitle: Constants.cancelTitle,
      acceptAction: acceptHandler,
      cancelAction: nil
    )
    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    present(alertViewController, animated: true)
  }

  private func showDeleteSessionAlert(session: IMUSession) {
    let alertViewController = AlertViewController()
    let acceptHandler: () -> Void = { [weak self] in
      self?.deleteSession(session)
    }
    alertViewController.configureAlertView(
      title: "Delete Session",
      description: "Are you sure you want to delete this session?",
      acceptButtonTitle: "Delete",
      cancelButtonTitle: Constants.cancelTitle,
      acceptAction: acceptHandler,
      cancelAction: nil
    )
    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    present(alertViewController, animated: true)
  }

  private func showDownloadProgressAlert(index: Int) {
    sessionDownloadProgressVC = ProgressAlertViewController()
    guard let sessionDownloadProgressVC = sessionDownloadProgressVC else {
      assertionFailure("sessionDownloadProgressVC is not instantiated.")
      return
    }
    sessionDownloadProgressVC.configureView(
      title: "Downloading...",
      description: "Keep the Jacquard app open, the download may take a few minutes.",
      progressTitle: "Downloading",
      actionHandler: { [weak self] in
        self?.cancelSessionDownload()
      }
    )
    sessionDownloadProgressVC.modalPresentationStyle = .custom
    sessionDownloadProgressVC.modalTransitionStyle = .crossDissolve
    present(sessionDownloadProgressVC, animated: true) { [weak self] in
      self?.downloadSession(index)
    }
  }

  private func showLowMemoryAlert() {
    let alertViewController = AlertViewController()
    let alertDescription =
      """
      There is not enough available space to start a new recording. Free up space by deleting \
      existing sessions.
      """
    alertViewController.configureAlertView(
      title: "Storage Full",
      description: alertDescription,
      acceptButtonTitle: "Got it",
      cancelButtonTitle: nil,
      acceptAction: nil,
      cancelAction: nil
    )
    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    present(alertViewController, animated: true)
  }

  private func showLowBatteryAlert() {
    let alertViewController = AlertViewController()
    let alertDescription =
      "Your Tag must be charged to a minimum of 50% to start recording. Please charge your Tag and try again."
    alertViewController.configureAlertView(
      title: "Insufficient battery charge",
      description: alertDescription,
      acceptButtonTitle: "Got it",
      cancelButtonTitle: nil,
      acceptAction: nil,
      cancelAction: nil
    )
    alertViewController.modalPresentationStyle = .custom
    alertViewController.modalTransitionStyle = .crossDissolve
    present(alertViewController, animated: true)
  }

  private func showSessionDetailsScreen(sessionData: IMUSessionData) {
    let sessionDetailsVC = IMUSessionDetailsViewController()
    sessionDetailsVC.selectedSession = sessionData
    navigationController?.pushViewController(sessionDetailsVC, animated: true)
  }

  private func showSessionFileShareSheet(fileURL: URL) {
    var filesToShare = [Any]()
    filesToShare.append(fileURL)
    let activityViewController = UIActivityViewController(
      activityItems: filesToShare, applicationActivities: nil)
    present(activityViewController, animated: true)
  }
}

// MARK: IMU Module APIs usage

extension IMUViewController {

  private func initializeIMUModule() {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return
    }
    SVProgressHUD.show()
    imuModule.initialize().sink { result in
      SVProgressHUD.dismiss()
      switch result {
      case .failure(let error):
        print("IMU initialize error: \(error)")
        MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "IMU initialize error: \(error)."))
      case .finished:
        break
      }
    } receiveValue: { [weak self] in
      SVProgressHUD.dismiss()
      print("IMU initialized")
      self?.checkDataCollectionStatus()
    }.addTo(&self.observers)
  }

  private func checkDataCollectionStatus() {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return
    }
    SVProgressHUD.show()
    imuModule.checkStatus()
      .sink { result in
        SVProgressHUD.dismiss()
        switch result {
        case .failure(let error):
          print("Could not check the data collection status: \(error)")
          MDCSnackbarManager.default.show(
            MDCSnackbarMessage(text: "DC status check error:\(error)."))
        case .finished:
          break
        }
      } receiveValue: { [weak self] status in
        SVProgressHUD.dismiss()
        guard let self = self else { return }
        print("Received data collection status: \(status)")
        switch status {
        case .idle:
          self.listIMUSessions()
          return
        case .lowBattery:
          self.showLowBatteryAlert()
          self.listIMUSessions()
        case .lowMemory:
          self.showLowMemoryAlert()
          self.listIMUSessions()
        case .logging:
          self.checkDCModeAndHandleIMURecording()
        default:
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "DC status:\(status)."))
          break
        }
        self.updateDataSource()
        self.sessionTableView.reloadData()
      }
      .addTo(&observers)
  }

  private func listIMUSessions() {

    imuSessions.removeAll()
    listDownloadedSessions()
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return
    }

    SVProgressHUD.show()

    // TODO(b/196551264): Revisit listSessions() API to provide response even in case of an empty
    // session list. Check for FW fix.
    // In case of an empty session list, SDK does not provide any response to listSessions() API.
    // So, dismissing the progress view after 3 seconds.
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(3)) {
      SVProgressHUD.dismiss()
    }

    // Call listSessions api and sink immediately on the returned publisher to observe IMUSessions.
    imuModule.listSessions().sink { result in
      SVProgressHUD.dismiss()
      switch result {
      case .failure(let error):
        print("List Sessions error: \(error)")
        MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "List Sessions error: \(error)"))
      case .finished:
        break
      }
    } receiveValue: { [weak self] sessionInfo in
      SVProgressHUD.dismiss()
      guard let self = self else { return }
      print("IMUSession received: \(sessionInfo)")
      let session = IMUSession(name: sessionInfo.sessionID, metadata: sessionInfo, fileURL: nil)
      self.imuSessions.append(session)
      self.updateDataSource()
      self.sessionTableView.reloadData()
    }
    .addTo(&observers)
  }

  private func listDownloadedSessions() {

    let fileManager = FileManager.default
    let documentsURL = DownloadedSessionPath.imuDirectory
    do {
      let fileURLs = try fileManager.contentsOfDirectory(
        at: documentsURL,
        includingPropertiesForKeys: nil
      )
      imuSessions.append(
        contentsOf:
          fileURLs.map {
            // Remove the extension from session name.
            let name = $0.deletingPathExtension().lastPathComponent
            return IMUSession(name: name, metadata: nil, fileURL: $0)
          })
      self.updateDataSource()
      sessionTableView.reloadData()
    } catch {
      print("Could not local files at \(documentsURL) error: \(error)")
    }
  }

  private func startRecording() {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return
    }
    SVProgressHUD.show()
    // Provide a unique SessionID, less than 30 characters.
    let name = String(format: "%.0f", Date().timeIntervalSinceReferenceDate)
    imuModule.startRecording(sessionID: name, samplingRate: IMUSamplingRate.low)
      .sink { [weak self] result in
        SVProgressHUD.dismiss()
        guard let self = self else { return }
        switch result {
        case .failure(let error):
          print("Could not start IMUSession: \(error)")
          if (error as? ModuleError) == .lowMemory {
            self.showLowMemoryAlert()
          } else {
            MDCSnackbarManager.default.show(
              MDCSnackbarMessage(text: "Start recording error: \(error)"))
          }
          self.startStopButton.setTitle(Constants.startRecording, for: .normal)
          self.recordingIndicatorView.isHidden = true
        case .finished:
          break
        }
      } receiveValue: { [weak self] status in
        SVProgressHUD.dismiss()
        guard let self = self else { return }
        switch status {
        case .logging:
          self.handleStartRecording(name: name)
        case .lowBattery:
          self.showLowBatteryAlert()
        case .lowMemory:
          self.showLowMemoryAlert()
        default:
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "Error:\(status)."))
          break
        }
      }
      .addTo(&observers)
  }

  private func checkDCModeAndHandleIMURecording() {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return
    }
    SVProgressHUD.show()
    imuModule.getDataCollectionMode()
      .sink { result in
        SVProgressHUD.dismiss()
        switch result {
        case .failure(let error):
          MDCSnackbarManager.default.show(
            MDCSnackbarMessage(text: "Get Data collection mode error: \(error)"))
        case .finished:
          break
        }
      } receiveValue: { [weak self] mode in
        guard let self = self else { return }
        SVProgressHUD.dismiss()
        if mode == .store {
          self.handleStartRecording(name: "Recording in progress...")
        } else if mode == .streaming {
          // Data collection in streaming mode is already in progress.
          // Show the message to user and navigate back to home screen.
          MDCSnackbarManager.default.show(
            MDCSnackbarMessage(text: "Data collection in streaming mode is already in progress."))
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.navigationController?.popViewController(animated: true)
          }
        } else {
          assertionFailure(
            "DataCollectionMode `none` is not expected as DataCollectionStatus is `.logging`.")
        }
      }
      .addTo(&observers)
  }

  private func handleStartRecording(name: String) {

    print("IMU recording started")
    isRecordingInProgress = true
    startStopButton.setTitle(Constants.stopRecording, for: .normal)
    recordingIndicatorView.isHidden = false

    let currentSession = IMUSession(name: name)
    imuSessions.insert(currentSession, at: 0)
    updateDataSource()
    recordingTimer = Timer.scheduledTimer(
      withTimeInterval: 1, repeats: true,
      block: { [weak self] _ in
        guard let self = self else { return }
        self.updateSessionTime()
      })

  }

  private func stopRecording() {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return
    }
    SVProgressHUD.show()
    imuModule.stopRecording()
      .sink { [weak self] result in
        SVProgressHUD.dismiss()
        guard let self = self else { return }
        switch result {
        case .failure(let error):
          print("Could not stop Session: \(error)")
          MDCSnackbarManager.default.show(
            MDCSnackbarMessage(text: "Stop recording error: \(error)"))
          self.startStopButton.setTitle(Constants.stopRecording, for: .normal)
          self.recordingIndicatorView.isHidden = false
        case .finished:
          break
        }
      } receiveValue: { [weak self] in
        SVProgressHUD.dismiss()
        guard let self = self else { return }
        print("IMU recording stopped")
        self.isRecordingInProgress = false
        self.recordingTimer?.invalidate()
        self.startStopButton.setTitle(Constants.startRecording, for: .normal)
        self.recordingIndicatorView.isHidden = true
        self.listIMUSessions()
      }
      .addTo(&observers)
  }

  private func deleteAllSessions() {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return
    }
    SVProgressHUD.show()
    imuModule.eraseAllSessions()
      .sink { result in
        SVProgressHUD.dismiss()
        switch result {
        case .failure(let error):
          print("Could not delete all sessions: \(error)")
          MDCSnackbarManager.default.show(
            MDCSnackbarMessage(text: "Delete sessions error: \(error)"))
        case .finished:
          break
        }
      } receiveValue: { [weak self] in
        SVProgressHUD.dismiss()
        guard let self = self else { return }
        print("All sessions deleted.")
        self.deleteAllLocalSessions()
        self.imuSessions.removeAll()
        self.updateDataSource()
        self.sessionTableView.reloadData()
      }
      .addTo(&observers)
  }

  private func deleteAllLocalSessions() {
    let fileManager = FileManager.default
    let documentsURL = DownloadedSessionPath.imuDirectory
    do {
      try fileManager.removeItem(at: documentsURL)
      self.imuSessions.removeAll()
      self.updateDataSource()
      sessionTableView.reloadData()
    } catch {
      print("Could not local files at \(documentsURL) error: \(error)")
    }
  }

  private func deleteSession(_ session: IMUSession) {
    // Check is session is a locally downloaded.
    guard session.fileURL == nil else {
      deleteLocalSession(session)
      return
    }

    guard let imuModule = imuModule, let sessionInfo = session.metadata else {
      assertionFailure("IMU module or session info not available.")
      return
    }
    SVProgressHUD.show()
    imuModule.eraseSession(sessionInfo)
      .sink { result in
        SVProgressHUD.dismiss()
        switch result {
        case .failure(let error):
          print("Could not delete session: \(session.name)")
          MDCSnackbarManager.default.show(
            MDCSnackbarMessage(text: "Delete session error: \(error)"))
        case .finished:
          break
        }
      } receiveValue: { [weak self] in
        SVProgressHUD.dismiss()
        guard let self = self else { return }
        print("Session deleted: \(session.name).")
        self.imuSessions.removeAll { $0.name == session.name }
        self.updateDataSource()
        self.sessionTableView.reloadData()
      }
      .addTo(&observers)
  }

  private func deleteLocalSession(_ session: IMUSession) {
    let fileManager = FileManager.default
    let documentsURL = DownloadedSessionPath.imuDirectory
    guard let fileURL = session.fileURL else {
      return
    }
    do {
      try fileManager.removeItem(at: fileURL)
      self.imuSessions.removeAll { session.fileURL == $0.fileURL }
      self.updateDataSource()
      sessionTableView.reloadData()
    } catch {
      print("Could not local files at \(documentsURL) error: \(error)")
    }
  }

  func downloadSession(_ index: Int) {
    guard
      let imuModule = imuModule,
      let session = imuSessions[index].metadata
    else {
      assertionFailure("IMU module or session unavailable")
      return
    }

    imuModule.downloadIMUSessionData(session: session)
      .sink { completion in
        switch completion {
        case .finished:
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "IMU file downloaded."))
        case .failure(let error):
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "\(error)"))
        }
      } receiveValue: { [weak self] downloadState in
        guard let self = self else { return }
        switch downloadState {
        case .downloading(let progress):
          print("IMU downloading... \(progress)%")
          self.sessionDownloadProgressVC?.progress = Float(progress)
        case .downloaded(let filePath):
          print("IMU state downloaded IMU file \(filePath)")
          self.sessionDownloadProgressVC?.progress = 100.0
          self.sessionDownloadProgressVC?.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.sessionDownloadProgressVC = nil
            let downloadedSession = self.imuSessions[index]
            self.copyFileLocally(filePath: filePath, session: downloadedSession)
          }
        }
      }
      .addTo(&observers)
  }

  func copyFileLocally(filePath: URL, session: IMUSession?) {
    do {
      guard let session = session else {
        return
      }
      let sessionPath = DownloadedSessionPath.filePath(for: session)
      try FileManager.default.copyItem(at: filePath, to: sessionPath)
      session.fileURL = sessionPath
      listIMUSessions()
    } catch {
      print("Cannot copy item : \(error)")
    }
  }

  private func createIMURawDocumentsDataFolder() throws {
    if !FileManager.default.fileExists(atPath: DownloadedSessionPath.imuDirectory.path) {
      try FileManager.default.createDirectory(
        at: DownloadedSessionPath.imuDirectory,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }
  }

  func parseSessionData(session: IMUSession) {
    guard
      let imuModule = imuModule,
      let filePath = session.fileURL
    else {
      return
    }
    imuModule.parseIMUSession(at: filePath)
      .sink { completion in
        switch completion {
        case .finished:
          print("IMU file parsing finished.")
        case .failure(let error):
          print("IMU file parsing error: \(error)")
        }
      } receiveValue: { (fullyParsed, session) in
        print("IMU session: \(session.metadata.sessionID) has: \(session.samples.count) samples")
        self.showSessionDetailsScreen(sessionData: session)
      }
      .addTo(&observers)
  }

  private func cancelSessionDownload() {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return
    }
    SVProgressHUD.show()
    imuModule.stopDownloading()
      .sink { result in
        SVProgressHUD.dismiss()
        switch result {
        case .failure(let error):
          print("Could not stop IMUSession download: \(error)")
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "Stop download error: \(error)"))
        case .finished:
          break
        }
      } receiveValue: {
        SVProgressHUD.dismiss()
        print("IMU session download stopped")
      }
      .addTo(&observers)
  }
}

// MARK: Table view configuration

extension IMUViewController {

  private func configureSessionTableView() {
    let nib = UINib(nibName: IMUSessionTableViewCell.reuseIdentifier, bundle: nil)
    sessionTableView.register(nib, forCellReuseIdentifier: IMUSessionTableViewCell.reuseIdentifier)

    sessionTableView.dataSource = imuDiffableDataSource
    sessionTableView.delegate = self

    imuDiffableDataSource = UITableViewDiffableDataSource<IMUSessionSection, IMUSessionCellModel>(
      tableView: sessionTableView,
      cellProvider: { (tableView, indexPath, sessionModel) -> UITableViewCell? in
        let cell = tableView.dequeueReusableCell(
          withIdentifier: IMUSessionTableViewCell.reuseIdentifier,
          for: indexPath
        )
        guard
          let sessionCell = cell as? IMUSessionTableViewCell
        else {
          assertionFailure("Cell can not be casted to IMUSessionTableViewCell.")
          return cell
        }
        sessionCell.configureCell(model: sessionModel)
        sessionCell.actionDelegate = self
        return sessionCell
      })
  }

  func updateDataSource() {
    sessionTableView.isHidden = imuSessions.isEmpty

    imuSessions.sort {
      return $0.name > $1.name
    }

    var sessions = imuSessions.map { IMUSessionCellModel(session: $0) }

    var snapshot = NSDiffableDataSourceSnapshot<IMUSessionSection, IMUSessionCellModel>()
    if isRecordingInProgress {
      if let currentSession = sessions.first {
        sessions.remove(at: 0)
        snapshot.appendSections([.current, .past])
        snapshot.appendItems([currentSession], toSection: .current)
      }
    } else {
      snapshot.appendSections([.past])
    }
    snapshot.appendItems(sessions, toSection: .past)
    self.imuDiffableDataSource?.apply(snapshot)

    menuButton?.isEnabled = !sessions.isEmpty
  }

  private func updateSessionTime() {
    let firstCellIndex = IndexPath(item: 0, section: 0)
    guard
      let cell = sessionTableView.cellForRow(at: firstCellIndex) as? IMUSessionTableViewCell,
      let model = imuSessions.first
    else {
      assertionFailure("Cell or IMUSession model not available, this should not happen")
      return
    }
    cell.updateSessionTime(model.name)
  }

}

extension IMUViewController: UITableViewDelegate {

  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let headerView = JacquardSectionHeader(
      frame: CGRect(x: 0.0, y: 0.0, width: sessionTableView.frame.width, height: 40.0))
    if tableView.numberOfSections == 2 {
      switch section {
      case 0:
        headerView.title = IMUSessionSection.current.title
      case 1:
        headerView.title = IMUSessionSection.past.title
      default:
        headerView.title = IMUSessionSection.past.title
      }
    } else {
      headerView.title = IMUSessionSection.past.title
    }

    return headerView
  }

  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 40.0
  }
}

extension IMUViewController: IMUSessionActionDelegate {

  func didSelectSession(_ cell: IMUSessionTableViewCell, for action: IMUSessionAction) {

    guard let tappedIndexPath = sessionTableView.indexPath(for: cell),
      let diffableDataSource = imuDiffableDataSource,
      let cellModel = diffableDataSource.itemIdentifier(for: tappedIndexPath)
    else {
      assertionFailure("Cell model for selected cell could not be fetched.")
      return
    }

    switch action {
    case .view:
      parseSessionData(session: cellModel.session)
    case .delete:
      if isRecordingInProgress {
        MDCSnackbarManager.default.show(
          MDCSnackbarMessage(text: Constants.recordingInProgressWarning))
      } else {
        showDeleteSessionAlert(session: cellModel.session)
      }
    case .download:
      if isRecordingInProgress {
        MDCSnackbarManager.default.show(
          MDCSnackbarMessage(text: Constants.recordingInProgressWarning))
      } else {
        guard cellModel.session.metadata != nil else {
          assertionFailure("Session metadata not available.")
          return
        }
        showDownloadProgressAlert(index: tappedIndexPath.row)
      }
    case .share:
      guard let sessionFileURL = cellModel.session.fileURL else {
        assertionFailure("Session file URL not available.")
        return
      }
      showSessionFileShareSheet(fileURL: sessionFileURL)
    }
  }
}
