import UIKit
import HMedia
import MediaPlayer
import Observation
import HConstants

@MainActor
class PlayerControlViewController: UIViewController {
    
    private let player = AudioPlayerModel.shared
    
    // UI Elements
    private let progressSlider = UISlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    
    private let playPauseButton = UIButton(type: .system)
    private let seekBackButton = UIButton(type: .system)
    private let seekForwardButton = UIButton(type: .system)
    
    private let volumeView: UIView = {
        #if targetEnvironment(simulator)
        // 模拟器环境：使用普通UISlider，因为MPVolumeView在模拟器上无法控制系统音量
        // UISlider只是UI控件，不会实际改变系统音量，仅用于测试界面
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 1
        return slider
        #else
        // 真机环境：使用MPVolumeView
        // MPVolumeView是系统提供的音量控制组件，直接控制设备的系统音量
        // 包含音量滑块和AirPlay按钮（如果有可用设备）
        // 优点：与系统音量同步，支持硬件音量键，自动适配深色模式
        let mpView =  MPVolumeView()
//        mpView.showsRouteButton = true
        return mpView
        #endif
    }()
    
    private var isSeeking = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        HLog.info("PlayerControlViewController loaded", category: .ui)
        setupUI()
        setupObservation()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Configure UI Elements
        progressSlider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        progressSlider.addTarget(self, action: #selector(sliderTouchEnded), for: [.touchUpInside, .touchUpOutside])
        progressSlider.addTarget(self, action: #selector(sliderTouchStarted), for: .touchDown)
        
        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        currentTimeLabel.textColor = .secondaryLabel
        currentTimeLabel.text = "0:00"
        
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        durationLabel.textColor = .secondaryLabel
        durationLabel.text = "0:00"
        
        let config = UIImage.SymbolConfiguration(pointSize: 32)
        playPauseButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        
        seekBackButton.setImage(UIImage(systemName: "gobackward.15", withConfiguration: config), for: .normal)
        seekBackButton.addTarget(self, action: #selector(seekBack), for: .touchUpInside)
        
        seekForwardButton.setImage(UIImage(systemName: "goforward.15", withConfiguration: config), for: .normal)
        seekForwardButton.addTarget(self, action: #selector(seekForward), for: .touchUpInside)
        
        // Stack Views
        let timeStack = UIStackView(arrangedSubviews: [currentTimeLabel, progressSlider, durationLabel])
        timeStack.axis = .horizontal
        timeStack.spacing = 8
        timeStack.alignment = .center
        
        let controlsStack = UIStackView(arrangedSubviews: [seekBackButton, playPauseButton, seekForwardButton])
        controlsStack.axis = .horizontal
        controlsStack.spacing = 40
        controlsStack.alignment = .center
        controlsStack.distribution = .equalCentering
        
        let mainStack = UIStackView(arrangedSubviews: [timeStack, controlsStack, volumeView])
        mainStack.axis = .vertical
        mainStack.spacing = 30
        mainStack.alignment = .fill
        
        view.addSubview(mainStack)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            mainStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            volumeView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        if let slider = volumeView as? UISlider {
            slider.addTarget(self, action: #selector(volumeChanged(_:)), for: .valueChanged)
            slider.value = player.volume
        }
    }
    
    private func setupObservation() {
        let updater = Updater(controller: self)
        withObservationTracking {
            _ = player.currentChapter
            _ = player.isPlaying
            _ = player.currentTime
            _ = player.duration
            
            Task { @MainActor in
                self.updateUI()
            }
        } onChange: {
            Task { @MainActor in
                updater.update()
            }
        }
    }
    
    private struct Updater: Sendable {
        weak var controller: PlayerControlViewController?
        
        @MainActor
        func update() {
            controller?.setupObservation()
        }
    }
    
    private func updateUI() {
        self.title = player.currentChapter?.title
        let iconName = player.isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: iconName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 32)), for: .normal)
        
        if !isSeeking {
            if player.duration > 0 {
                progressSlider.value = Float(player.currentTime / player.duration)
            } else {
                progressSlider.value = 0
            }
            currentTimeLabel.text = formatTime(player.currentTime)
        }
        
        durationLabel.text = formatTime(player.duration)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // Actions
    
    @objc private func togglePlayPause() {
        HLog.info("Toggle play/pause tapped in player control", category: .ui)
        player.togglePlayPause()
    }
    
    @objc private func seekBack() {
        HLog.info("Seek back tapped", category: .ui)
        let newTime = max(0, player.currentTime - 15)
        player.seek(to: newTime)
    }
    
    @objc private func seekForward() {
        HLog.info("Seek forward tapped", category: .ui)
        let newTime = min(player.duration, player.currentTime + 15)
        player.seek(to: newTime)
    }
    
    @objc private func sliderTouchStarted() {
        isSeeking = true
    }
    
    @objc private func sliderValueChanged() {
        let time = Double(progressSlider.value) * player.duration
        currentTimeLabel.text = formatTime(time)
    }
    
    
    @objc private func volumeChanged(_ sender: UISlider) {
        player.volume = sender.value
    }
    @objc private func sliderTouchEnded() {
        let time = Double(progressSlider.value) * player.duration
        HLog.info("Seek to \(time) via slider", category: .ui)
        player.seek(to: time)
        isSeeking = false
    }
}
