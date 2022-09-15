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

import Charts
import Combine
import JacquardSDK
import MaterialComponents
import SVProgressHUD
import UIKit

class IMUStreamingViewController: UIViewController {

  private enum Constants {
    static let startRecording = "Start"
    static let stopRecording = "Stop"
  }

  @IBOutlet private weak var accelerometerChart: UIView!
  @IBOutlet private weak var gyroscopeChart: UIView!
  @IBOutlet private weak var startStopButton: UIButton!
  @IBOutlet private weak var recordingIndicatorView: UIView!

  lazy var accelerometerLineChartView = createLineChart()
  lazy var gyroscopeLineChartView = createLineChart()

  private var observers = [Cancellable]()
  private var imuModule: IMUModuleImplementation?
  private var tagPublisher: AnyPublisher<ConnectedTag, Never>

  // This flag is defined to indicate that process of imu streaming has started and loading modal will be shown to block the any user interaction.
  // Once the imu sample data starts receiving, based on this flag loading modal will be dismissed.
  // It will set to `true` on imu streaming process starts and will set to `false` once it starts to receive the imu sample data.
  private var loadingModalPresented = false

  init(tagPublisher: AnyPublisher<ConnectedTag, Never>) {
    self.tagPublisher = tagPublisher
    super.init(nibName: "IMUStreamingViewController", bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // There is no way to differentiate whether data collection(if in progress) is initiated in
    // store mode or streaming mode. For both of them, the data collection status returned by the
    // tag is ".logging".
    // Hence, the data collection mode has to be tracked by writing a custom config on the tag.
    tagPublisher
      .prefix(1)
      .sink { [weak self] tag in
        guard let self = self else { return }
        self.imuModule = IMUModuleImplementation(connectedTag: tag)

        self.initializeIMUModule()
      }.addTo(&observers)

    NotificationCenter.default.addObserver(
      forName: UIApplication.willResignActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }
      self.stopStreaming()
    }

    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      guard let self = self else { return }
      if self.startStopButton.title(for: .normal) == Constants.stopRecording {
        self.startStreaming()
      }
    }

    configureAccelerometerChart()
    configureGyroscopeChart()

    recordingIndicatorView.isHidden = true
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    stopStreaming()
  }

  @IBAction func startStreamingButtonTapped(_ sender: Any) {
    if startStopButton.title(for: .normal) == Constants.startRecording {
      checkDataCollectionStatus()
        .sink { completion in
          if case .failure(let error) = completion {
            MDCSnackbarManager.default.show(
              MDCSnackbarMessage(text: "DC status check error: \(error)"))
          }
        } receiveValue: { [weak self] status in
          guard let self = self else { return }
          if status {
            self.recordingIndicatorView.isHidden = false
            self.startStopButton.setTitle(Constants.stopRecording, for: .normal)
            self.startStreaming()
          }
        }.addTo(&observers)
    } else {
      recordingIndicatorView.isHidden = true
      startStopButton.setTitle(Constants.startRecording, for: .normal)
      stopStreaming()
    }
  }

  @IBAction func stopStreamingButtonTapped(_ sender: Any) {
    stopStreaming()
  }

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
        MDCSnackbarManager.default.show(
          MDCSnackbarMessage(text: "IMU initialize error: \(error)"))
      case .finished:
        break
      }
    } receiveValue: { [weak self] _ in
      guard let self = self else { return }
      SVProgressHUD.dismiss()
      self.checkDataCollectionStatus()
        .sink { completion in
          if case .failure(let error) = completion {
            MDCSnackbarManager.default.show(
              MDCSnackbarMessage(text: "DC status check error: \(error)"))
          }
        } receiveValue: { _ in
        }.addTo(&self.observers)

    }.addTo(&self.observers)
  }

  private func checkDataCollectionStatus() -> AnyPublisher<Bool, Error> {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return Fail(error: ModuleError.moduleUnavailable).eraseToAnyPublisher()
    }
    let publisher = PassthroughSubject<Bool, Error>()
    SVProgressHUD.show()
    imuModule.checkStatus()
      .sink { result in
        SVProgressHUD.dismiss()
        switch result {
        case .failure(let error):
          MDCSnackbarManager.default.show(
            MDCSnackbarMessage(text: "DC status check error:\(error)."))
          publisher.send(completion: .failure(error))
        case .finished:
          break
        }
      } receiveValue: { [weak self] status in
        guard let self = self else { return }
        SVProgressHUD.dismiss()
        switch status {
        case .lowBattery:
          self.showErrorOnSnackbar(message: "Low tag battery !")
        case .lowMemory:
          self.showErrorOnSnackbar(message: "Low tag memory !")
        case .logging:
          self.checkIfLoggingIsInOtherMode(publisher)
        default:
          MDCSnackbarManager.default.show(MDCSnackbarMessage(text: "DC status:\(status)."))
          publisher.send(true)
          break
        }
        publisher.send(completion: .finished)
      }
      .addTo(&observers)
    return publisher.eraseToAnyPublisher()
  }

  private func checkIfLoggingIsInOtherMode(_ publisher: PassthroughSubject<Bool, Error>) {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      publisher.send(completion: .failure(ModuleError.moduleUnavailable))
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
          publisher.send(completion: .failure(error))
        case .finished:
          break
        }
      } receiveValue: { [weak self] mode in
        guard let self = self else { return }
        SVProgressHUD.dismiss()
        if mode == .store {
          // Data collection in store mode is already in progress.
          // Show the message to user and navigate back to home screen.
          MDCSnackbarManager.default.show(
            MDCSnackbarMessage(text: "Data collection in store mode is already in progress."))
          DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.navigationController?.popViewController(animated: true)
          }
        } else {
          publisher.send(true)
        }
        publisher.send(completion: .finished)
      }
      .addTo(&observers)
  }

  private func showErrorOnSnackbar(message: String) {
    MDCSnackbarManager.default.show(
      MDCSnackbarMessage(text: message))
  }

  private func startStreaming() {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return
    }
    showLoadingModal()
    imuModule.startIMUStreaming(samplingRate: IMUSamplingRate.low).sink { [weak self] result in
      guard let self = self else { return }
      switch result {
      case .failure(let error):
        self.dismissLoadingModal()
        self.showErrorOnSnackbar(message: "Start streaming error: \(error)")
      case .finished:
        break
      }
    } receiveValue: { [weak self] sample in
      guard let self = self else { return }
      if self.loadingModalPresented {
        self.dismissLoadingModal()
      }

      self.renderGraph(sample)
    }.addTo(&self.observers)
  }

  private func stopStreaming() {
    guard let imuModule = imuModule else {
      assertionFailure("IMU module not available.")
      return
    }
    imuModule.stopIMUStreaming().sink { result in
      switch result {
      case .failure(let error):
        print("Stop streaming error: \(error)")
      case .finished:
        break
      }
    } receiveValue: { _ in
      print("Streaming stopped.")
    }.addTo(&observers)
  }

  private func showLoadingModal() {
    loadingModalPresented = true
    SVProgressHUD.show()
  }

  private func dismissLoadingModal() {
    SVProgressHUD.dismiss()
    loadingModalPresented = false
  }

  private func createLineChart() -> LineChartView {
    let chartView = LineChartView()
    chartView.rightAxis.enabled = false
    chartView.drawGridBackgroundEnabled = false
    chartView.xAxis.enabled = false
    chartView.pinchZoomEnabled = true
    chartView.clipsToBounds = true
    chartView.clipValuesToContentEnabled = true

    let leftAxis = chartView.leftAxis
    leftAxis.labelTextColor = .white
    leftAxis.drawGridLinesEnabled = false
    leftAxis.labelPosition = .outsideChart
    leftAxis.axisMinimum = Double(CShort.min)
    leftAxis.axisMaximum = Double(CShort.max)
    return chartView
  }

  private func configureAccelerometerChart() {
    let chartWidth = accelerometerChart.bounds.size.width - 48
    let chartHeight = accelerometerChart.bounds.size.height - 64
    accelerometerChart.addSubview(accelerometerLineChartView)
    accelerometerLineChartView.frame = CGRect(x: 24, y: 8, width: chartWidth, height: chartHeight)

    let xDataSet = createDataSet("AX", color: .systemRed)
    let yDataSet = createDataSet("AY", color: .systemGreen)
    let zDataSet = createDataSet("AZ", color: .systemBlue)

    let chartData = LineChartData(dataSets: [xDataSet, yDataSet, zDataSet])
    chartData.setDrawValues(false)
    accelerometerLineChartView.data = chartData
  }

  private func configureGyroscopeChart() {
    let chartWidth = gyroscopeChart.bounds.size.width - 48
    let chartHeight = gyroscopeChart.bounds.size.height - 64
    gyroscopeChart.addSubview(gyroscopeLineChartView)
    gyroscopeLineChartView.frame = CGRect(x: 24, y: 8, width: chartWidth, height: chartHeight)

    let xDataSet = createDataSet("GX", color: .systemRed)
    let yDataSet = createDataSet("GY", color: .systemGreen)
    let zDataSet = createDataSet("GZ", color: .systemBlue)

    let chartData = LineChartData(dataSets: [xDataSet, yDataSet, zDataSet])
    chartData.setDrawValues(false)
    gyroscopeLineChartView.data = chartData
  }

  private func createDataSet(_ label: String, color: UIColor) -> LineChartDataSet {
    let dataSet = LineChartDataSet(entries: [ChartDataEntry](), label: label)
    dataSet.drawCirclesEnabled = false
    dataSet.mode = .cubicBezier
    dataSet.lineWidth = 2
    dataSet.setColor(color)
    return dataSet
  }

  private func renderGraph(_ sample: IMUSample) {
    if let acData = accelerometerLineChartView.data {
      let acceleration = sample.acceleration
      if let acX = acData.dataSet(at: 0)?.entryCount {
        acData.appendEntry(ChartDataEntry(x: Double(acX), y: Double(acceleration.x)), toDataSet: 0)
        acData.appendEntry(ChartDataEntry(x: Double(acX), y: Double(acceleration.y)), toDataSet: 1)
        acData.appendEntry(ChartDataEntry(x: Double(acX), y: Double(acceleration.z)), toDataSet: 2)
        acData.notifyDataChanged()
        accelerometerLineChartView.notifyDataSetChanged()
        accelerometerLineChartView.setVisibleXRangeMaximum(50)
        accelerometerLineChartView.moveViewToX(Double(acData.entryCount))
      }
    }

    if let gyData = gyroscopeLineChartView.data {
      let gyro = sample.gyro
      if let gyX = gyData.dataSet(at: 0)?.entryCount {
        gyData.appendEntry(ChartDataEntry(x: Double(gyX), y: Double(gyro.x)), toDataSet: 0)
        gyData.appendEntry(ChartDataEntry(x: Double(gyX), y: Double(gyro.y)), toDataSet: 1)
        gyData.appendEntry(ChartDataEntry(x: Double(gyX), y: Double(gyro.z)), toDataSet: 2)
        gyData.notifyDataChanged()
        gyroscopeLineChartView.notifyDataSetChanged()
        gyroscopeLineChartView.setVisibleXRangeMaximum(50)
        gyroscopeLineChartView.moveViewToX(Double(gyData.entryCount))
      }
    }
  }
}
