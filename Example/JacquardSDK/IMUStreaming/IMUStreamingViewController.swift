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
    // tag is ".recordingInProgress".
    // Hence, the data collection mode has to be tracked by writing a custom config on the tag.
    // TODO(b/203487028): Save DC mode on tag and handle tag re-connection scenarios to
    // resume IMU streaming.
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
      self.startStreaming()
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
      recordingIndicatorView.isHidden = false
      startStopButton.setTitle(Constants.stopRecording, for: .normal)
      startStreaming()
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
      assertionFailure("** IMU module not available.")
      return
    }
    imuModule.initialize().sink { result in
      switch result {
      case .failure(let error):
        print("** IMU initialize error: \(error)")
      case .finished:
        break
      }
    } receiveValue: { _ in
      print("** IMU initialized")
    }.addTo(&self.observers)
  }

  private func startStreaming() {
    self.imuModule?.startIMUStreaming().sink { result in
      switch result {
      case .failure(let error):
        print("** Start streaming error: \(error)")
      case .finished:
        break
      }
    } receiveValue: { [weak self] sample in
      guard let self = self else { return }
      print("**\(sample)")
      self.renderGraph(sample)
    }.addTo(&self.observers)
  }

  private func stopStreaming() {
    imuModule?.stopIMUStreaming().sink { result in
      switch result {
      case .failure(let error):
        print("** Stop streaming error: \(error)")
      case .finished:
        break
      }
    } receiveValue: { _ in
      print("** Streaming stopped.")
    }.addTo(&observers)
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
      let acX = acData.getDataSetByIndex(0).entryCount
      acData.addEntry(ChartDataEntry(x: Double(acX), y: Double(acceleration.x)), dataSetIndex: 0)
      acData.addEntry(ChartDataEntry(x: Double(acX), y: Double(acceleration.y)), dataSetIndex: 1)
      acData.addEntry(ChartDataEntry(x: Double(acX), y: Double(acceleration.z)), dataSetIndex: 2)
      acData.notifyDataChanged()
      accelerometerLineChartView.notifyDataSetChanged()
      accelerometerLineChartView.setVisibleXRangeMaximum(50)
      accelerometerLineChartView.moveViewToX(Double(acData.entryCount))
    }

    if let gyData = gyroscopeLineChartView.data {
      let gyro = sample.gyro
      let gyX = gyData.getDataSetByIndex(0).entryCount
      gyData.addEntry(ChartDataEntry(x: Double(gyX), y: Double(gyro.x)), dataSetIndex: 0)
      gyData.addEntry(ChartDataEntry(x: Double(gyX), y: Double(gyro.y)), dataSetIndex: 1)
      gyData.addEntry(ChartDataEntry(x: Double(gyX), y: Double(gyro.z)), dataSetIndex: 2)
      gyData.notifyDataChanged()
      gyroscopeLineChartView.notifyDataSetChanged()
      gyroscopeLineChartView.setVisibleXRangeMaximum(50)
      gyroscopeLineChartView.moveViewToX(Double(gyData.entryCount))
    }
  }
}
