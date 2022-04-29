import UIKit

class MainView: UIView {
    
    let containerView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.image = UIImage(named: "tabBar")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let speedLimitImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "60")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let currentRoadSignImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    let currentSpeedLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.italicSystemFont(ofSize: 35)
        label.textColor = .white
        label.text = "60"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let kilometersPerHourLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.italicSystemFont(ofSize: 20)
        label.textColor = .white
        label.text = "km/h"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    lazy var currentSpeedVerticalStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(self.currentSpeedLabel)
        stackView.addArrangedSubview(self.kilometersPerHourLabel)
        return stackView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupSubviews() {
        backgroundColor = .white
        addSubview(containerView)
        containerView.addSubview(currentRoadSignImageView)
        containerView.addSubview(speedLimitImageView)
        containerView.addSubview(currentSpeedVerticalStackView)
        
        NSLayoutConstraint.activate([
            containerView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            
            speedLimitImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            speedLimitImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1/3),
            speedLimitImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            speedLimitImageView.heightAnchor.constraint(equalToConstant: 60),
            
            currentRoadSignImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            currentRoadSignImageView.centerYAnchor.constraint(equalTo: speedLimitImageView.centerYAnchor),
            currentRoadSignImageView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 1/3),
            currentRoadSignImageView.heightAnchor.constraint(equalToConstant: 60),
            
            currentSpeedVerticalStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            currentSpeedVerticalStackView.trailingAnchor.constraint(equalTo: currentRoadSignImageView.leadingAnchor),
            currentSpeedVerticalStackView.centerYAnchor.constraint(equalTo: currentRoadSignImageView.centerYAnchor),
        ])
    }
}
