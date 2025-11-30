//
//  ViewController.swift
//  Ye-Dufu
//
//  Created by teguo on 2025/11/28.
//

import UIKit
import HMedia
import Observation
import HConstants

@MainActor
final class ViewController: UIViewController {
    
    private let tableView = UITableView()
    private let miniPlayerView = UIView()
    private let titleLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let playPauseButton = UIButton(type: .system)
    private let player = AudioPlayerModel.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        HLog.info("ViewController loaded", category: .ui)
        setupUI()
        setupTableView()
        setupMiniPlayer()
        setupObservation()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        title = HConstants.appTitle
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrow.down.circle"), style: .plain, target: self, action: #selector(showDownloads))
        
        // Add subviews
        view.addSubview(tableView)
        view.addSubview(miniPlayerView)
        
        miniPlayerView.addSubview(progressView)
        miniPlayerView.addSubview(titleLabel)
        miniPlayerView.addSubview(playPauseButton)
        
        // Layout constraints (using Auto Layout)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        miniPlayerView.translatesAutoresizingMaskIntoConstraints = false
        progressView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Mini Player
            miniPlayerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            miniPlayerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            miniPlayerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            miniPlayerView.heightAnchor.constraint(equalToConstant: 60),
            
            // Progress View
            progressView.topAnchor.constraint(equalTo: miniPlayerView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: miniPlayerView.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: miniPlayerView.trailingAnchor),
            
            // Play/Pause Button
            playPauseButton.trailingAnchor.constraint(equalTo: miniPlayerView.trailingAnchor, constant: -16),
            playPauseButton.centerYAnchor.constraint(equalTo: miniPlayerView.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 44),
            playPauseButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Title Label
            titleLabel.leadingAnchor.constraint(equalTo: miniPlayerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: playPauseButton.leadingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: miniPlayerView.centerYAnchor),
            
            // Table View
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: miniPlayerView.topAnchor)
        ])
        
        miniPlayerView.backgroundColor = .secondarySystemBackground
        
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.addTarget(self, action: #selector(togglePlayPause), for: .touchUpInside)
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showPlayerControl))
        miniPlayerView.addGestureRecognizer(tapGesture)
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    private func setupMiniPlayer() {
        updateChapterState()
        updatePlaybackState()
    }
    
    private func setupObservation() {
        setupChapterObservation()
        setupPlaybackObservation()
    }
    
    private func setupChapterObservation() {
        let updater = Updater(controller: self)
        withObservationTracking {
            _ = player.currentChapter
            Task { @MainActor in
                self.updateChapterState()
            }
        } onChange: {
            Task { @MainActor in
                updater.updateChapter()
            }
        }
    }
    
    private func setupPlaybackObservation() {
        let updater = Updater(controller: self)
        withObservationTracking {
            _ = player.isPlaying
            _ = player.currentTime
            _ = player.duration
            Task { @MainActor in
                self.updatePlaybackState()
            }
        } onChange: {
            Task { @MainActor in
                updater.updatePlayback()
            }
        }
    }
    
    private struct Updater: Sendable {
        weak var controller: ViewController?
        
        @MainActor
        func updateChapter() {
            controller?.setupChapterObservation()
        }
        
        @MainActor
        func updatePlayback() {
            controller?.setupPlaybackObservation()
        }
    }
    
    private func updateChapterState() {
        if let chapter = player.currentChapter {
            titleLabel.text = chapter.title
            miniPlayerView.isHidden = false
        } else {
            titleLabel.text = "Not Playing"
            miniPlayerView.isHidden = true
        }
        tableView.reloadData()
    }
    
    private func updatePlaybackState() {
        let iconName = player.isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: iconName), for: .normal)
        
        if player.duration > 0 {
            progressView.progress = Float(player.currentTime / player.duration)
        } else {
            progressView.progress = 0
        }
    }
    
    @objc private func togglePlayPause() {
        HLog.info("Toggle play/pause tapped", category: .ui)
        player.togglePlayPause()
    }
    
    @objc private func showDownloads() {
        HLog.info("Show downloads tapped", category: .ui)
        let downloadManagerVC = DownloadManagerViewController()
        let nav = UINavigationController(rootViewController: downloadManagerVC)
        present(nav, animated: true)
    }
    
    @objc private func showPlayerControl() {
        HLog.info("Show player control tapped", category: .ui)
        let playerControlVC = PlayerControlViewController()
        let nav = UINavigationController(rootViewController: playerControlVC)
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Chapter.all.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let chapter = Chapter.all[indexPath.row]
        cell.textLabel?.text = chapter.title
        
        if chapter.title == player.currentChapter?.title {
            cell.accessoryType = .checkmark
            cell.textLabel?.textColor = .systemBlue
        } else {
            cell.accessoryType = .none
            cell.textLabel?.textColor = .label
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let chapter = Chapter.all[indexPath.row]
        HLog.info("Selected chapter: \(chapter.title)", category: .ui)
        player.play(chapter: chapter)
    }
}

