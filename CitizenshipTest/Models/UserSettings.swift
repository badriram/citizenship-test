import Foundation
import SwiftData

@Model
final class UserSettings {
    var selectedStateId: String = ""
    var selectedDistrict: Int? = nil
    var districtResolutionMethod: String? = nil

    init(selectedStateId: String = "") {
        self.selectedStateId = selectedStateId
    }
}
