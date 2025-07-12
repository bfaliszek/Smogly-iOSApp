import Foundation

class UserDefaultsManager: ObservableObject {
    private let defaults = UserDefaults.standard
    
    // Keys for UserDefaults
    private enum Keys {
        static let selectedDataSource = "selectedDataSource"
    }
    
    // Published property for selected datasource
    @Published var selectedDataSource: DataSource {
        didSet {
            saveSelectedDataSource()
        }
    }
    
    init() {
        // Load saved datasource or default to ALL
        if let savedDataSourceString = defaults.string(forKey: Keys.selectedDataSource),
           let savedDataSource = DataSource(rawValue: savedDataSourceString) {
            self.selectedDataSource = savedDataSource
        } else {
            self.selectedDataSource = .all
        }
    }
    
    private func saveSelectedDataSource() {
        defaults.set(selectedDataSource.rawValue, forKey: Keys.selectedDataSource)
    }
    
    func resetToDefault() {
        selectedDataSource = .all
    }
} 