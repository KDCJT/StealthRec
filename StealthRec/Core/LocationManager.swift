// LocationManager.swift
// StealthRec — 位置记录与地理编码

import Foundation
import CoreLocation

final class LocationManager: NSObject {

    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    private(set) var currentLocation: CLLocation?
    private(set) var currentAddress: String = ""
    private(set) var currentCity: String = ""

    var onLocationUpdate: ((RecordingLocation) -> Void)?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
    }

    // MARK: - 启动位置追踪
    func startTracking() {
        let status = CLLocationManager.authorizationStatus()
        switch status {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
            manager.startUpdatingLocation()
        case .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("[LocationManager] 位置权限被拒绝")
        @unknown default:
            break
        }
    }

    // MARK: - 获取当前录音位置（拍摄快照）
    func captureCurrentLocation(completion: @escaping (RecordingLocation?) -> Void) {
        guard let location = currentLocation else {
            completion(nil)
            return
        }

        // 使用已有地址
        if !currentAddress.isEmpty {
            let recLocation = RecordingLocation(
                coordinate: location.coordinate,
                address: currentAddress,
                city: currentCity,
                accuracy: location.horizontalAccuracy
            )
            completion(recLocation)
            return
        }

        // 否则立即编码
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                completion(nil)
                return
            }

            let address = self.formatAddress(from: placemark)
            let city = placemark.locality ?? placemark.administrativeArea ?? ""

            let recLocation = RecordingLocation(
                coordinate: location.coordinate,
                address: address,
                city: city,
                accuracy: location.horizontalAccuracy
            )
            completion(recLocation)
        }
    }

    // MARK: - 中文地址格式化
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []

        if let country = placemark.country, country != "中国" {
            components.append(country)
        }
        if let province = placemark.administrativeArea {
            components.append(province)
        }
        if let city = placemark.locality {
            if city != placemark.administrativeArea {
                components.append(city)
            }
        }
        if let district = placemark.subLocality {
            components.append(district)
        }
        if let street = placemark.thoroughfare {
            components.append(street)
        }

        return components.joined()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // 只接受精度合理的位置
        guard location.horizontalAccuracy > 0,
              location.horizontalAccuracy < 500 else { return }

        self.currentLocation = location

        // 反向地理编码（频率限制：同一位置不重复请求）
        if let prev = currentLocation,
           location.distance(from: prev) < 200,
           !currentAddress.isEmpty {
            return
        }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self,
                  let placemark = placemarks?.first,
                  error == nil else { return }

            let address = self.formatAddress(from: placemark)
            let city = placemark.locality ?? placemark.administrativeArea ?? ""

            self.currentAddress = address
            self.currentCity = city

            let recLocation = RecordingLocation(
                coordinate: location.coordinate,
                address: address,
                city: city,
                accuracy: location.horizontalAccuracy
            )
            self.onLocationUpdate?(recLocation)

            // 如果正在录音，更新当前元数据的位置
            if RecordingEngine.shared.isRecording {
                RecordingEngine.shared.updateCurrentLocation(recLocation)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[LocationManager] 定位失败: \(error.localizedDescription)")
    }
}
