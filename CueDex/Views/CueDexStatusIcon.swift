import SwiftUI

struct CueDexStatusIcon: View {
    let isPaused: Bool

    var body: some View {
        Image(isPaused ? "MenuBarIconPaused" : "MenuBarIcon")
            .resizable()
            .renderingMode(.template)
            .scaledToFit()
        .frame(width: 18, height: 18)
    }
}

#Preview {
    HStack(spacing: 16) {
        CueDexStatusIcon(isPaused: false)
        CueDexStatusIcon(isPaused: true)
    }
    .padding()
}
