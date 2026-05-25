import SwiftUI

struct JChordSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var showsOuterChrome = true

    var body: some View {
        let control = HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.heavy))
                        .foregroundStyle(selection == option ? JChordTheme.text : JChordTheme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            selection == option
                                ? JPadChromeTheme.buttonIdleFill
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
        }

        if showsOuterChrome {
            control
                .padding(6)
                .background(JPadChromeTheme.panelBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(JPadChromeTheme.panelBorder, lineWidth: 1)
                )
        } else {
            control
        }
    }
}
