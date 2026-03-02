import Foundation
import SwiftData

@Model
final class UserSettings {
    var selectedStateId: String = "IL"
    var selectedDistrict: Int? = nil
    var districtResolutionMethod: String? = nil

    init(selectedStateId: String = "IL") {
        self.selectedStateId = selectedStateId
    }
}
