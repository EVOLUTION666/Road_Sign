import Foundation
import CoreLocation

protocol ServiceLocationDelegate: AnyObject {
    func didUpdateCurrentSpeed(speed: Double)
}

class ServiceLocation: NSObject {
    
    private let locationManager = CLLocationManager()
    private (set) var currentSpeed: Double = 0
    weak var speedDelegate: ServiceLocationDelegate?
    
    func setupAuthorization() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
}

extension ServiceLocation: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        
        currentSpeed = location.speed * 3.6
        speedDelegate?.didUpdateCurrentSpeed(speed: currentSpeed)
    }
}
