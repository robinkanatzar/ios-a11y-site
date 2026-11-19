# Dynamic Type: checks and fixes

Reference for the `ios-dynamic-type` skill. Sections: 1. The numbers · 2. SwiftUI (text styles, adaptive layout, screens, sheets, bars, images) · 3. UIKit · 4. Storyboards, xibs and web views · 5. Large Content Viewer · 6. Previews and simulator settings · 7. Manual test

## 1. The numbers

- Prefer the built-in text styles; with system fonts they get Dynamic Type and Bold Text for free. **Custom fonts must implement the same behaviors** — scale with Dynamic Type *and* respond to Bold Text.
- **Layout must adapt to every size.** Test with Settings → Accessibility → Display & Text Size → Larger Text → Larger Accessibility Sizes on.
- **Scale meaningful icons** with the text (SF Symbols do this automatically).
- **Minimize truncation.** Aim to show as much useful text at the largest accessibility size as at the largest standard size. Don't truncate inside scrolling content unless there's a way to open the full text. Let labels use as many lines as needed (`numberOfLines = 0`, no `lineLimit`).
- **Change layout at large sizes**: stack text above secondary items (icons, timestamps) instead of side by side; reduce the number of columns (`isAccessibilityCategory` / `dynamicTypeSize.isAccessibilitySize`).
- **Keep the hierarchy** at every size — primary content stays near the top so people don't lose it.
- Leading: loose leading helps long passages; avoid tight leading for three or more lines.

iOS body text by size: Large (default) 17 pt → AX1 28 pt → AX3 40 pt (≈235%) → AX5 53 pt (≈312%). So the 200% bar is reached at AX3. Caption 2 goes from 11 pt to 40 pt at AX5.

| What | Value |
|---|---|
| Text enlargement to support | ≥ 200% (reached at AX3) |
| Default / minimum text size | 17 pt / 11 pt |
| Font weights to avoid for text | Ultralight, Thin, Light |

WCAG: 1.4.4 Resize Text (AA) — text scales to 200% without loss of content or function; 1.4.10 Reflow (AA) — content can be read without scrolling in two directions; 1.4.12 Text Spacing (AA) for apps that set spacing.

## 2. SwiftUI

```swift
Text("Title").font(.headline)                                                   // ✅ text style
Text("Title").font(.custom("Avenir-Heavy", size: 20, relativeTo: .headline))   // ✅ scaled custom font
Text("Title").font(.system(size: 20))                                          // ❌ never scales

@ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 24            // scale non-text sizes
Image(systemName: "bell").font(.body)                                          // symbols scale with text
```

**Adapt the layout at accessibility sizes instead of truncating — use an adaptive stack.** Rows that sit side by side at normal sizes (icon + title + timestamp, label + value, a row of buttons) run out of width at large text: text gets squeezed into one-word lines, truncated, or overlaps. An *adaptive stack* is an `HStack` at standard sizes that becomes a `VStack` once `dynamicTypeSize.isAccessibilitySize` is true. Make it a reusable component (ideally in the design system) so every row gets it for free:

```swift
/// Horizontal at standard text sizes, vertical at accessibility sizes.
/// Idea and API from Robin Kanatzar's AStack gist (see Sources).
struct AStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let hStackAlignment: VerticalAlignment
    private let hStackSpacing: CGFloat?
    private let vStackAlignment: HorizontalAlignment
    private let vStackSpacing: CGFloat?
    private let content: Content

    init(hStackAlignment: VerticalAlignment = .center, hStackSpacing: CGFloat? = nil,
         vStackAlignment: HorizontalAlignment = .leading, vStackSpacing: CGFloat? = nil,
         @ViewBuilder content: () -> Content) {
        self.hStackAlignment = hStackAlignment
        self.hStackSpacing = hStackSpacing
        self.vStackAlignment = vStackAlignment
        self.vStackSpacing = vStackSpacing
        self.content = content()
    }

    var body: some View {            // iOS 16+
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: vStackAlignment, spacing: vStackSpacing))
            : AnyLayout(HStackLayout(alignment: hStackAlignment, spacing: hStackSpacing))
        layout { content }
    }
}

/// A Spacer that only exists in AStack's horizontal layout. In the vertical
/// layout a Spacer can stretch into a large empty gap.
struct AStackSpacer: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var minLength: CGFloat? = nil

    var body: some View {
        if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: minLength) }
    }
}

// Usage
AStack(hStackAlignment: .firstTextBaseline, vStackSpacing: 4) {
    HStack { Image(systemName: "person.circle").accessibilityHidden(true); Text(name) }
    AStackSpacer()
    Text(timestamp).foregroundStyle(.secondary)
}
```

**Where to use it.** Use it in every row where text sits beside a value, an icon or a badge. These rows were switched over in one real app (MyCommute, October 2026), and they're the patterns to look for:

| Row | Normal sizes | At accessibility sizes |
|---|---|---|
| Settings label + value ("Status … Free", "Type … Apple", "Notifications … Enabled") | icon + label, `AStackSpacer()`, value | icon + label on one line, value under it |
| Label + long value ("User ID … 3fA9…kQ") | value truncated in the middle on one line | the whole value, wrapped (`.lineLimit(isAccessibilitySize ? nil : 1)`) |
| Call-to-action banner ("Get premium to add as many routes as you want!") | icon, text, `AStackSpacer(minLength: 0)` | icon above the text, text at full width |
| Status banner with a title and lines ("This route needs attention" + what to fix) | icon at the top left, text column | icon above the text column |
| Stepper or toggle label with a value or badge ("Good … ≤ 5 min", "Leave earlier … 10 min", "Add extra time 👑", "Vacation mode 👑") | name (+ badge), `AStackSpacer()`, value | name (+ badge), value under it |
| Notification preview card (app icon, title + "now", message) | icon left, title and time on one line | icon above; title, then "now" under it |

The same switch in a second app (Blackjack Trainer, October 2026), for rows that aren't label + value:

| Row | Normal sizes | At accessibility sizes |
|---|---|---|
| Two buttons side by side ("Draw a Card" · "Start Over") | each `.frame(maxWidth: .infinity)`, half the width | one above the other, each full width |
| Numbered point (a number in a circle + the text) | number at the top left, text beside it (`hStackAlignment: .top`) | number above the text; the circle (`@ScaledMetric`) and number (scaled font) grow too; row is one element, "1, Get as close to 21…" |
| Result with a symbol badge ("[S] You should stand. This means you don't draw another card.") | badge left, text column | badge above the text |
| Badge + category ("Lesson 1" · "Hard Totals") | on one line | category under the badge |
| Value with a label and a badge ("Your total · 21 · Soft") | on one baseline (`hStackAlignment: .firstTextBaseline`) | each on its own line |

A numbered point, built once and shared by every "Key points" list:

```swift
struct NumberedPoint: View {
    let number: Int
    let text: String
    let color: Color
    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 28   // grows with the text

    var body: some View {
        AStack(hStackAlignment: .top, hStackSpacing: 16, vStackSpacing: 8) {
            Text("\(number)")
                .font(.system(.footnote, design: .monospaced).bold())       // a text style, not size: 13
                .foregroundStyle(color)
                .frame(width: circleSize, height: circleSize)
                .background(Circle().fill(color.opacity(0.15)))
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)                          // "1, Get as close to 21…"
    }
}
```

Content indented to line up under such a row's text (`.padding(.leading, circleSize + 16)`) loses the indent when the row stacks (`isAccessibilitySize ? 0 : …`).

How to build these rows:
- **Keep pieces that belong together in an inner `HStack`.** For example, icon + label stay `HStack { Image; Text }` inside the `AStack`, so the icon doesn't end up alone on its own line.
- **Use `AStackSpacer()` between the label and the value**, and `.frame(maxWidth: .infinity, alignment: .leading)` on banners, so the vertical layout stays leading-aligned and full width, with no empty gap.
- **Drop spacers that only center things vertically when the stack is vertical.** For example, `if !isAccessibilitySize { Spacer() }` around an icon.
- **Put the adaptive stack in the shared component** (one banner view, one card view) so every screen gets it.
- **Text inside custom cards in a `List`/`Form` row gets `.fixedSize(horizontal: false, vertical: true)`.** When the text size changes while a row is on screen, SwiftUI can keep the row's old height for the text and cut it to one line with "…", even with empty space under it. In MyCommute this cut the first notification preview to "Leave at {departureTim…". The rows further down had been laid out fresh and were fine, so the bug only shows on some rows. Reproduce it by changing the size while the screen is open: `xcrun simctl ui <device> content_size accessibility-large`.
- **Check the result in the simulator at AX5** (`xcrun simctl ui <device> content_size accessibility-extra-extra-extra-large`), both after a fresh launch and after changing the size while the screen is open. Grouped rows (`.accessibilityElement(children: .combine)`) read the same in both layouts.

- `AnyLayout` (iOS 16+) keeps the children's identity when the axis changes, so their `@State` survives and the change can animate. For an iOS 15 deployment target, use the original gist's approach — `if dynamicTypeSize.isAccessibilitySize { VStack { content } } else { HStack { content } }` — which works but rebuilds the children when the size crosses the threshold.
- Vertical alignment defaults to `.leading` here: centered text in a vertical stack is harder to scan at large sizes.
- **Use `AStackSpacer()`, not `Spacer()`, inside an `AStack`.** In the vertical layout a plain `Spacer` can take all the height it's offered. In a `Stepper`'s label it left a screen-high gap between "Slow" and "≤ 15 min" and truncated the description under it (verified on iOS 26.5 at AX5). In a plain `List` row it happened to look fine, so don't rely on that. Also check the reading order makes sense in both axes: VoiceOver follows the visual order.
- UIKit equivalent: switch `UIStackView.axis` on `preferredContentSizeCategory.isAccessibilityCategory` (§ 3).
- `ViewThatFits` (iOS 16+) is good for one-off blocks. For repeated rows in a list, switch on `typeSize.isAccessibilitySize` instead, so every row uses the same layout (mixed layouts in one list are confusing).
- **Every screen's content needs a scroll container** — `ScrollView`, `List` or `Form` at the root (usually one per screen) — not only the screens you expect to overflow. At AX5 in landscape the screen is only a few lines tall: anything outside a scroll container is cut off and can't be reached (WCAG 1.4.4, 1.4.10). Exceptions: full-screen media, camera, maps, games, and fixed chrome (nav/tab bars). A screen skeleton:

```swift
struct SettingsScreen: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Account").font(.headline)
                Text("Long explanatory text…")
                if typeSize.isAccessibilitySize { saveButton }      // at AX sizes the action scrolls with the content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)                       // iOS 16.4+: short screens don't bounce
        .navigationTitle("Settings")
        .safeAreaInset(edge: .bottom) {
            if !typeSize.isAccessibilitySize { saveButton.padding() }   // pinned only at standard sizes
        }
    }

    private var saveButton: some View {
        Button("Save") { }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
    }
}
```

  Keep pinned bars (`.safeAreaInset`, bottom toolbars) small; at accessibility sizes move their content into the scroll view as above, or they eat most of a landscape screen. Scroll in one direction only — no horizontal scrolling for text (data tables and maps excepted). Check it with the landscape-AX5 preview (§ 6) and a manual pass (§ 7).
- **`lineLimit`:** fine on list rows that lead to a detail screen (raise it by one or two lines at accessibility sizes — `.lineLimit(typeSize.isAccessibilitySize ? 4 : 2)`); never on detail content. Multi-line inputs: `TextField(..., axis: .vertical).lineLimit(3...10)`.
- Avoid `.frame(height:)` on anything containing text (use `minHeight`), and `.minimumScaleFactor` as a scaling strategy.
- **Content stacked above or below a `List`/`ScrollView`** in a `VStack` (banners, headers, summary cards) doesn't scroll: at AX5 it can push the list off-screen. Put those views *inside* the list (a `Section`, or `.listRowInsets`/`.listRowBackground` for full-width banners) or the scroll view.
- **Sheets:** `.presentationDetents([.medium])` alone is a half-height sheet that can't grow — with non-scrolling content its buttons get cut off at large sizes. Give it `[.medium, .large]` and a `ScrollView`, or `.large` at accessibility sizes. (On iPad in regular width the detent is ignored.)
- **Fixed bars** (custom tab bar, toolbar, bottom-pinned action bar) may stay at a fixed size — system bars don't scale either — but pair them with the Large Content Viewer (§ 5). Prefer a range cap (`.dynamicTypeSize(...DynamicTypeSize.xxxLarge)`) over pinning to one size; `.dynamicTypeSize(.large)` *pins* the size, it isn't a cap. Never cap content.
- Grids: switch to fewer columns at accessibility sizes (`GridItem(.adaptive(minimum:))` with a scaled minimum).
- **Images that sit with text grow with it.** A chart of playing cards with "10", "11 or 1" under each stayed 40 pt wide at AX5 while the labels tripled, and the ace's label was cut to "11…" by `.lineLimit(1)` + `.minimumScaleFactor`. Size the image from `@ScaledMetric(relativeTo:)` (keep its aspect ratio), use the same metric for the grid's adaptive minimum, and let the label wrap (`.multilineTextAlignment(.center)`, `.fixedSize(horizontal: false, vertical: true)`). Same for the box around them: a `.frame(height: 94)` that held cards + labels cut the labels off; use `.fixedSize(horizontal: false, vertical: true)` on a horizontal `ScrollView` so it takes its content's height.
- **Icon buttons beside text scale too.** An info button next to a section title at `.font(.system(size: 20))` stayed small beside an AX5 title; give the symbol a text style or a scaled font (`Font.custom`/`.system(size:)` through `@ScaledMetric` or `relativeTo:`). The 44 pt minimum frame stays as the floor.
- Bold Text: system and `relativeTo:` custom fonts follow it; for custom strokes and symbol weights read `@Environment(\.legibilityWeight)` and thicken when it's `.bold`.


## 3. UIKit

```swift
label.font = .preferredFont(forTextStyle: .body)
label.adjustsFontForContentSizeCategory = true   // without this, the font won't update live
label.numberOfLines = 0                          // let it wrap

let base = UIFont(name: "Avenir-Heavy", size: 20)!
label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: base)   // scaled custom font

let iconSize = UIFontMetrics(forTextStyle: .body).scaledValue(for: 24)      // scale non-text sizes
imageView.preferredSymbolConfiguration = .init(textStyle: .body)            // SF Symbols follow text size
button.configuration?.titleTextAttributesTransformer = …                    // or use text styles in configurations
imageView.adjustsImageSizeForAccessibilityContentSizeCategory = true        // non-symbol images that should grow
```

Adapt layout at accessibility sizes:

```swift
private func updateLayout() {
    let isAX = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
    stackView.axis = isAX ? .vertical : .horizontal
    stackView.alignment = isAX ? .leading : .center
    titleLabel.numberOfLines = isAX ? 4 : 2      // list rows only; detail text: 0
}

// iOS 17+ (traitCollectionDidChange is deprecated):
registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in self.updateLayout() }
// Elsewhere: UIContentSizeCategory.didChangeNotification
```

- Every screen's content sits in a scroll view (`UIScrollView`, table, collection) — at AX5 in landscape, anything outside one is cut off and unreachable (WCAG 1.4.4, 1.4.10). For a form-like screen, a vertical-only scroll view around a stack:
  ```swift
  content.axis = .vertical
  content.spacing = 16
  content.isLayoutMarginsRelativeArrangement = true
  content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
  scrollView.translatesAutoresizingMaskIntoConstraints = false
  content.translatesAutoresizingMaskIntoConstraints = false
  view.addSubview(scrollView)
  scrollView.addSubview(content)
  NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
      content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
      content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
      content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),   // vertical scrolling only
  ])
  ```
  Pinned bottom buttons: keep them small, or move them into the stack at accessibility sizes. Self-sizing cells (`automaticDimension`, compositional `.estimated` heights); no fixed `heightAnchor` on views holding text (use `greaterThanOrEqualTo`).
- Swap whole constraint sets for AX sizes rather than tweaking constants; `readableContentGuide` keeps long lines readable on iPad; `constraint(equalToSystemSpacingBelow:)` scales spacing with text.
- Custom fixed bars may stay fixed (system bars do) only with the Large Content Viewer (§ 5). `maximumContentSizeCategory` on a view caps it — never on content.
- **Bold Text:** text styles follow it; custom fonts need the heavier face when `UIAccessibility.isBoldTextEnabled` (observe `boldTextStatusDidChangeNotification`), and custom strokes/icons should thicken.
- **`WKWebView`:** web content doesn't follow Dynamic Type unless its CSS uses `font: -apple-system-body` (or the app injects a size). Reload or re-inject when the content size category changes.


## 4. Storyboards, xibs and web views

- Labels, buttons and text views in Interface Builder: set the font to a **Text Style** (not System + point size) and check **Automatically Adjusts Font** (`adjustsFontForContentSizeCategory="YES"` in the XML). Set **Lines** to 0 for anything that isn't a list row.
- Fixed-height constraints on views holding text become `≥` constraints.
- `LaunchScreen.storyboard` is exempt.
- **`WKWebView`:** web content doesn't follow Dynamic Type unless its CSS uses `font: -apple-system-body` (or the app injects a size or sets `pageZoom`). Reload or re-inject when the content size category changes.

## 5. Large Content Viewer

### SwiftUI

For fixed-size controls that can't grow (custom tab bars, toolbars, bottom bars), long-press shows an enlarged version:

```swift
CustomTabItem(title: "Home", icon: "house")
    .accessibilityShowsLargeContentViewer {
        Label("Home", systemImage: "house")
    }
```

It only appears at accessibility text sizes, so test it there. Keep titles short and include live state (e.g. a badge count) in the viewer content.

### UIKit

For fixed-size custom bars (standard `UITabBar`/toolbar items already support it):

```swift
customTabButton.showsLargeContentViewer = true
customTabButton.largeContentTitle = String(localized: "Home")
customTabButton.largeContentImage = UIImage(systemName: "house")
customTabBar.addInteraction(UILargeContentViewerInteraction())   // without an interaction nothing appears
```

- One interaction on the bar container covers its buttons. Use vector (PDF/SF Symbol) images and `scalesLargeContentImage` so the enlarged image stays sharp.
- It only appears at accessibility text sizes — test there. Keep the title current (e.g. include a badge count).
- Custom tab bars for VoiceOver: put `.tabBar` on the bar container (with `isAccessibilityElement = false`) and `.selected` on the active tab. Accessibility Inspector and the Simulator may not show the tab announcement — verify on a device.


## 6. Previews and simulator settings

```swift
#Preview("AX5 text") { ContentView().environment(\.dynamicTypeSize, .accessibility5) }
#Preview("xSmall")   { ContentView().environment(\.dynamicTypeSize, .xSmall) }
#Preview("Dark, bold") {
    ContentView().preferredColorScheme(.dark).environment(\.legibilityWeight, .bold)
}
#Preview("RTL") { ContentView().environment(\.layoutDirection, .rightToLeft) }
#Preview("German") { ContentView().environment(\.locale, Locale(identifier: "de")) }   // long strings
#Preview("Landscape, AX5", traits: .landscapeLeft) {     // the worst case for reachability
    NavigationStack { ContentView() }.environment(\.dynamicTypeSize, .accessibility5)
}
```

Most accessibility environment values (`accessibilityReduceMotion`, `colorSchemeContrast`, …) are read-only. Check them with the canvas **Variants** (Dynamic Type, Color Scheme, Orientation), **Canvas Device Settings**, or the debug bar's **Environment Overrides** in the simulator. Don't use private underscore environment keys to force them — that's private API and an App Review risk.

Launch arguments for UI tests and the simulator:

| Goal | How |
|---|---|
| Largest text (AX5) | `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` |
| Other sizes | `UICTContentSizeCategoryXS` … `XXXL`; AX1–AX5 = `AccessibilityM`, `AccessibilityL`, `AccessibilityXL` (AX3, 200%), `AccessibilityXXL`, `AccessibilityXXXL` |
| Real right-to-left | `-AppleLanguages "(ar)" -AppleLocale ar_SA` |

Simulator text size from the command line: `xcrun simctl ui booted content_size accessibility-extra-extra-extra-large` (reset with `content_size large`).

## 7. Manual test

Settings → Accessibility → Display & Text Size → Larger Text → Larger Accessibility Sizes on. AX3 is 200% (body 40 pt); AX5 is the maximum (body 53 pt).
- [ ] At AX3 and AX5: no essential text truncated, clipped or overlapping; every screen's content scrolls; horizontal rows wrap or stack.
- [ ] Content scrolls in one direction only (no two-direction scrolling, except data tables and maps).
- [ ] Rotate to landscape at AX5 and scroll every screen to the end: every piece of text and every control (including bottom buttons) can be reached and read; nothing is cut off at the bottom or sides; pinned headers/bars leave room for content. 
- [ ] Fixed bars that don't scale offer the Large Content Viewer (long-press shows the enlarged item).
- [ ] Smallest size (XS) still looks right, and Bold Text applies to custom fonts.

---
Sources: Apple Human Interface Guidelines (Typography, Accessibility); Apple SwiftUI and UIKit documentation; Robin Kanatzar, AStack gist (https://gist.github.com/robinkanatzar/6b281658e7bf4cdde73d69f86a4c8a8e) and article (https://robinkanatzar.blog/accessibile-stack-in-swiftui-af8630a1cd1d); WCAG 2.2.
