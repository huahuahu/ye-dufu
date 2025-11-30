import UIKit
import HMedia
import HData
import Observation
import HConstants

class DownloadManagerViewController: UIViewController {
    private let tableView = UITableView()
    private let cacheManager = CacheManager.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservation()
    }
    
    private func setupUI() {
        title = "下载管理"
        view.backgroundColor = .systemBackground
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSelf))
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DownloadCell.self, forCellReuseIdentifier: "DownloadCell")
    }
    
    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
    
    private func setupObservation() {
        let updater = Updater(controller: self)
        withObservationTracking {
            _ = cacheManager.downloadingURLs
            _ = cacheManager.downloadStates
            _ = cacheManager.cacheUpdateToken
            Task { @MainActor in
                self.tableView.reloadData()
            }
        } onChange: {
            Task { @MainActor in
                updater.update()
            }
        }
    }
    
    private struct Updater: Sendable {
        weak var controller: DownloadManagerViewController?
        @MainActor
        func update() {
            controller?.setupObservation()
        }
    }
}

extension DownloadManagerViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Chapter.all.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DownloadCell", for: indexPath) as! DownloadCell
        let chapter = Chapter.all[indexPath.row]
        cell.configure(with: chapter)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

class DownloadCell: UITableViewCell {
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let actionButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private var chapter: Chapter?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(stackView)
        contentView.addSubview(actionButton)
        contentView.addSubview(deleteButton)
        
        stackView.translatesAutoresizingMaskIntoConstraints = false
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .fill
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(detailLabel)
        stackView.addArrangedSubview(progressView)
        
        detailLabel.font = .monospacedDigitSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .regular)
        detailLabel.textColor = .secondaryLabel
        
        deleteButton.setImage(UIImage(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        
        NSLayoutConstraint.activate([
            deleteButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            deleteButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 44),
            deleteButton.heightAnchor.constraint(equalToConstant: 44),
            
            actionButton.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
            actionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -16)
        ])
        
        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
    }
    
    func configure(with chapter: Chapter) {
        self.chapter = chapter
        titleLabel.text = chapter.title
        updateButtonState()
    }
    
    private func updateButtonState() {
        guard let chapter = chapter else { return }
        let cacheManager = CacheManager.shared
        
        if cacheManager.isDownloaded(resource: chapter.audioResource) {
            actionButton.setTitle("Downloaded", for: .normal)
            actionButton.isEnabled = false
            deleteButton.isHidden = false
            progressView.isHidden = true
            if let size = cacheManager.getFileSize(for: chapter.audioResource) {
                detailLabel.text = "Size: \(size)"
            } else {
                detailLabel.text = "Downloaded"
            }
        } else if cacheManager.isDownloading(resource: chapter.audioResource) {
            actionButton.setTitle("Downloading...", for: .normal)
            actionButton.isEnabled = false
            deleteButton.isHidden = true
            progressView.isHidden = false
            
            if let state = cacheManager.getDownloadState(for: chapter.audioResource) {
                progressView.progress = Float(state.progress)
                let written = ByteCountFormatter.string(fromByteCount: state.totalBytesWritten, countStyle: .file)
                let total = ByteCountFormatter.string(fromByteCount: state.totalBytesExpectedToWrite, countStyle: .file)
                detailLabel.text = "\(written) / \(total)"
            } else {
                progressView.progress = 0
                detailLabel.text = "Downloading..."
            }
        } else {
            actionButton.setTitle("Download", for: .normal)
            actionButton.isEnabled = true
            deleteButton.isHidden = true
            progressView.isHidden = true
            detailLabel.text = "Not Downloaded"
        }
    }
    
    @objc private func buttonTapped() {
        guard let chapter = chapter else { return }
        CacheManager.shared.cache(resource: chapter.audioResource)
        // UI update will happen via observation
        updateButtonState()
    }
    
    @objc private func deleteButtonTapped() {
        guard let chapter = chapter else { return }
        CacheManager.shared.removeCache(for: chapter.audioResource)
        // UI update will happen via observation
        updateButtonState()
    }
}
