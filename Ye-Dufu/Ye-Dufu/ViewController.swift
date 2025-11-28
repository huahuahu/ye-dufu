//
//  ViewController.swift
//  Ye-Dufu
//
//  Created by teguo on 2025/11/28.
//

import UIKit
import HMedia
import Observation

@MainActor
final class ViewController: UIViewController {
    
    private let tableView = UITableView()
    private let miniPlayerView = UIView()
    private let titleLabel = UILabel()
    private let playPauseButton = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    private let player = AudioPlayerModel.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTableView()
        setupMiniPlayer()
        setupObservation()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
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
    }
    
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    private func setupMiniPlayer() {
        updateMiniPlayer()
    }
    
    private func setupObservation() {
        let updater = Updater(controller: self)
        withObservationTracking {
            _ = player.currentChapter
            _ = player.isPlaying
            _ = player.currentTime
            _ = player.duration
            
            Task { @MainActor in
                self.updateMiniPlayer()
            }
        } onChange: {
            Task { @MainActor in
                updater.update()
            }
        }
    }
    
    private struct Updater: Sendable {
        weak var controller: ViewController?
        
        @MainActor
        func update() {
            controller?.setupObservation()
        }
    }
    
    private func updateMiniPlayer() {
        if let chapter = player.currentChapter {
            titleLabel.text = chapter.title
            miniPlayerView.isHidden = false
        } else {
            titleLabel.text = "Not Playing"
            miniPlayerView.isHidden = true
        }
        
        let iconName = player.isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.setImage(UIImage(systemName: iconName), for: .normal)
        
        if player.duration > 0 {
            progressView.progress = Float(player.currentTime / player.duration)
        } else {
            progressView.progress = 0
        }
    }
    
    @objc private func togglePlayPause() {
        player.togglePlayPause()
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
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let chapter = Chapter.all[indexPath.row]
        player.play(chapter: chapter)
    }
}

