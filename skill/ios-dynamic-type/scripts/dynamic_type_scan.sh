#!/usr/bin/env bash
# Dynamic Type scan for iOS projects (SwiftUI + UIKit + storyboards/xibs).
# Prints *candidates* to review by reading the code — not confirmed issues.
# Usage: dynamic_type_scan.sh [source-dir]   (defaults to current directory)
# Compatible with macOS bash 3.2, BSD grep and BSD awk.
# Part of the free ios-dynamic-type skill by Accessible Mobile Apps.

ROOT="${1:-.}"
if [ ! -d "$ROOT" ]; then
  echo "Not a directory: $ROOT" >&2
  exit 1
fi

EXCLUDES="--exclude-dir=Pods --exclude-dir=Carthage --exclude-dir=.build --exclude-dir=DerivedData --exclude-dir=SourcePackages --exclude-dir=.git --exclude-dir=build --exclude-dir=Derived --exclude-dir=*Tests"
MAX=40  # max lines shown per check

# section <title> <why>
section() {
  printf '\n## %s\n%s\n' "$1" "$2"
}

# show: read grep output on stdin, cap length, print count
show() {
  local out count
  out="$(grep -vE '^[^:]*:[0-9]+: *//')"
  if [ -z "$out" ]; then
    echo "  (none)"
    return
  fi
  count=$(printf '%s\n' "$out" | wc -l | tr -d ' ')
  printf '%s\n' "$out" | head -n "$MAX" | sed 's/^/  /'
  if [ "$count" -gt "$MAX" ]; then
    echo "  … and $((count - MAX)) more"
  fi
}

swift_grep() {
  # shellcheck disable=SC2086
  grep -rnE --include='*.swift' $EXCLUDES "$@" "$ROOT" 2>/dev/null
}

ib_grep() {
  # shellcheck disable=SC2086
  grep -rnE --include='*.storyboard' --include='*.xib' --exclude='LaunchScreen*' $EXCLUDES "$@" "$ROOT" 2>/dev/null
}

swift_files() {
  # shellcheck disable=SC2086
  grep -rlE --include='*.swift' $EXCLUDES "$@" "$ROOT" 2>/dev/null
}

# Info.plist files and Xcode project files (generated Info.plist keys live in project.pbxproj).
plist_files() {
  # shellcheck disable=SC2086
  grep -rlE --include='*.plist' --include='*.pbxproj' $EXCLUDES "$@" "$ROOT" 2>/dev/null
}

all_swift_files() {
  swift_files '.'
}

# UI files: SwiftUI views/modifiers/styles or UIKit view/controller subclasses.
UI_PATTERN='var body: some View|func body\(content:|func makeBody\(configuration:|: *UI[A-Za-z]*(View|Controller|Cell) *[{,]'
ui_files() {
  swift_files "$UI_PATTERN"
}


echo "# Dynamic Type scan: $ROOT"
echo "Candidates only — confirm each by reading the surrounding code."

section "Project signals" ""
echo "  UI files: $(ui_files | wc -l | tr -d ' ')"
echo "  Files reading Dynamic Type size: $(swift_files 'dynamicTypeSize|ScaledMetric|preferredContentSizeCategory|UIFontMetrics' | wc -l | tr -d ' ')"
echo "  Files with an adaptive stack (AStack / isAccessibilitySize / isAccessibilityCategory): $(swift_files 'AStack|isAccessibilitySize|isAccessibilityCategory' | wc -l | tr -d ' ')"
section "Fixed font sizes on text (don't scale with Dynamic Type)" \
  "Use text styles, Font.custom(_:size:relativeTo:), @ScaledMetric, or UIFontMetrics. Lines with an SF Symbol nearby are skipped (decorative hero icons are usually fine). Includes Font properties defined outside .font(...), e.g. a reader font in settings."
{
  ui_or_all=$(swift_files '\.system\(size:|\.custom\(|UIFont')
  printf '%s\n' "$ui_or_all" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    awk -v F="$f" '
      { L[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          hit = 0
          if (L[i] ~ /^[ \t]*\/\//) continue
          if (L[i] ~ /\.system\(size:/) hit = 1
          if (L[i] ~ /\.custom\("[^"]*", *size:/ && L[i] !~ /relativeTo/) hit = 1
          if (L[i] ~ /UIFont\.(systemFont|boldSystemFont|monospacedSystemFont|italicSystemFont)\(ofSize:|UIFont\(name:/ && L[i] !~ /scaledFont/) hit = 1
          if (!hit) continue
          icon = 0
          for (j = i - 3; j <= i; j++) if (j >= 1 && L[j] ~ /Image\(systemName:|Image\(decorative:|systemImage:/) icon = 1
          if (!icon) printf "%s:%d:%s\n", F, i, L[i]
        }
      }' "$f"
  done
} | show

section "UIKit files with text but no adjustsFontForContentSizeCategory" \
  "Without it, preferred fonts won't update when the user changes text size."
swift_files 'UILabel|UITextField|UITextView' | while IFS= read -r f; do
  grep -q 'adjustsFontForContentSizeCategory' "$f" || echo "$f"
done | show

section "Single-line limits and shrink-to-fit" \
  "Truncation and shrinking hide content from large-text users. Fine for secondary text; not for essential content."
swift_grep '\.lineLimit\(1\)|numberOfLines *= *1\b|minimumScaleFactor|adjustsFontSizeToFitWidth *= *true' | show

section "Screens with no scroll container (WCAG 1.4.4, 1.4.10)" \
  "At the largest text size in landscape, a screen that isn't inside a ScrollView / List / Form / table / collection loses content off the edge, and nobody can scroll to it. Screens = SwiftUI views with .navigationTitle or presented as sheet / fullScreenCover / popover / navigation destination, and UIKit view controllers with labels or controls. Full-screen media, maps, camera and games are skipped. Also look for content stacked above/below a List or ScrollView in a VStack (banners, headers): it doesn't scroll — move it inside the list. Confirm in the simulator at AX5 in landscape."
{
  SCROLL_RE='ScrollView|List[ ({]|Form[ ({]|Table[ ({]|TextEditor[ ({]|WebView|ScrollViewReader'
  SKIP_RE='Map[ ({]|MapReader|VideoPlayer|SpriteView|SceneView|RealityView|ARView|Camera|AVCapture|TabView|NavigationSplitView|\.tabViewStyle\(\.page'
  BUILTIN='Text Button Label Image VStack HStack ZStack Group NavigationStack NavigationView NavigationLink Color EmptyView AnyView ScrollView List Form Section Spacer Divider Link Toggle Menu ForEach GeometryReader LazyVStack LazyHStack LazyVGrid LazyHGrid Grid GridRow TextField SecureField Picker Slider Stepper ProgressView Circle Rectangle RoundedRectangle Capsule Shape ViewThatFits AnyLayout ContentUnavailableView ShareLink LabeledContent DatePicker ColorPicker TabView Toolbar ToolbarItem ToolbarItemGroup DisclosureGroup Table Chart'
  # 1. names of views presented as destinations
  DEST=$(ui_files | while IFS= read -r f; do
    awk -v B=" $BUILTIN " '
      { L[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          if (L[i] !~ /\.sheet\(|\.fullScreenCover\(|\.popover\(|navigationDestination\(|NavigationLink\(destination:/) continue
          for (j = i; j <= i + 3 && j <= NR; j++) {
            t = L[j]
            while (match(t, /[A-Z][A-Za-z0-9_]*\(/)) {
              n = substr(t, RSTART, RLENGTH - 1); t = substr(t, RSTART + RLENGTH)
              if (index(B, " " n " ") == 0) { print n; j = NR + 1; break }
            }
          }
        }
      }' "$f"
  done | sort -u | tr '\n' ' ')
  # 2. SwiftUI screens without a scroll container in their own body
  ui_files | while IFS= read -r f; do
    SR="$SCROLL_RE" SK="$SKIP_RE" awk -v F="$f" -v DEST=" $DEST " -v B=" $BUILTIN " '
      function cnt(s, re,   t) { t = s; return gsub(re, "", t) }
      { L[NR] = $0 }
      END {
        SR = ENVIRON["SR"]; SK = ENVIRON["SK"]
        for (i = 1; i <= NR; i++) {
          if (L[i] !~ /struct [A-Z][A-Za-z0-9_]*[^{]*: *(some )?View/ || L[i] ~ /^[ \t]*\/\//) continue
          name = L[i]; sub(/.*struct /, "", name); sub(/[^A-Za-z0-9_].*/, "", name)
          d = cnt(L[i], "{") - cnt(L[i], "}"); body = L[i]; j = i
          while (d > 0 && j < NR) { j++; body = body "\n" L[j]; d += cnt(L[j], "{") - cnt(L[j], "}") }
          screen = (body ~ /\.navigationTitle\(/) || index(DEST, " " name " ") > 0
          if (!screen || body ~ SR || body ~ SK || body !~ /Text\(|Label\(|TextField\(|Button[ ({]/) { i = j; continue }
          kids = ""; t = body; k = 0
          if (index(t, "var body")) t = substr(t, index(t, "var body"))
          while (match(t, /(^|[^A-Za-z0-9_.])[A-Z][A-Za-z0-9_]*\(/) && k < 3) {
            n = substr(t, RSTART, RLENGTH - 1); t = substr(t, RSTART + RLENGTH); sub(/^[^A-Z]/, "", n)
            if (index(B, " " n " ") == 0 && n != name && index(kids, n) == 0 && n !~ /^(String|Int|Double|Bool|Date|URL|UUID|Locale|Font|EdgeInsets|Binding|State|Environment|AttributedString|LocalizedStringKey|Array|Set|Dictionary|Query|FillStyle|StrokeStyle|Path|Angle|UnitPoint|Animation|Calendar|Task|Measurement)$/ && n !~ /^(CG|NS|UI|AV)[A-Z]/ && n !~ /(Service|Manager|Model|Store|Provider|Formatter|Style|Descriptor|Request|Gesture)$/) { kids = kids (kids ? ", " : "") n; k++ }
          }
          printf "%s:%d:struct %s%s\n", F, i, name, (kids ? " [no scroll container here — check children: " kids "]" : " [no scroll container]")
          i = j
        }
      }' "$f"
  done
  # 3. UIKit view controllers with content but no scrolling view
  swift_files ': *UI[A-Za-z]*ViewController *[{,]' | while IFS= read -r f; do
    grep -qE 'UILabel|UITextField|UIButton|UIStackView' "$f" || continue
    grep -qE 'UIScrollView|UITableView|UICollectionView|UITextView|WKWebView|UIHostingController|TableViewController|CollectionViewController|MKMapView|AVPlayerViewController|AVCapture|SKView|ARView' "$f" && continue
    echo "$f  [view controller with labels/controls and no scrolling view]"
  done
  # 4. scrolling switched off, and bottom-pinned content that eats the screen at AX5
  swift_grep '\.scrollDisabled\(true\)|isScrollEnabled *= *false' | sed 's/$/  [scrolling disabled]/'
  swift_grep '\.safeAreaInset\(edge: *\.bottom|ToolbarItem[A-Za-z]*\(placement: *\.bottomBar' | sed 's/$/  [pinned bottom content: keep it small at AX5 or move it into the scroll content]/'
} | show

section "Fixed heights without a width (may clip text at large sizes)" \
  "Height-only frames often wrap text-bearing containers. Prefer minHeight / greaterThanOrEqualTo. Thin bars (<12pt) and icon frames with a width are skipped; image/cover frames still need a quick look."
{
  swift_grep '\.frame\(([^)]*[ ,])?height: *[0-9]' | grep -v 'width:' | grep -vE 'height: *([0-9]|1[01])(\.[0-9]+)? *\)'
  swift_grep 'heightAnchor\.constraint\(equalToConstant:'
} | show

section "Fixed-height sheets" \
  "presentationDetents([.height(N)]) or [.medium] alone can't grow: at large text sizes non-scrolling content (and its buttons) gets cut off. Add .large and a ScrollView."
swift_grep 'presentationDetents\(\[[^]]*\.height\(|presentationDetents\(\[ *\.medium *\]\)' | show

section "Dynamic Type caps" \
  "Capping is acceptable per-component with the Large Content Viewer, not app-wide."
swift_grep '\.dynamicTypeSize\(|maximumContentSizeCategory' | show


section "Light font weights and text under 11 pt" \
  "HIG: avoid Ultralight/Thin/Light weights for text; iOS minimum text size is 11 pt."
swift_grep '(fontWeight\(|weight: *)\.(ultraLight|thin|light)\b|UIFont\.Weight\.(ultraLight|thin|light)|\.system\(size: *([0-9]|10)(\.[0-9]+)? *[,)]|ofSize: *([0-9]|10)(\.[0-9]+)? *[,)]' | show

# --- Storyboards / xibs ------------------------------------------------------

section "Storyboard/xib fixed-size fonts" \
  "Use Text Styles and 'Automatically Adjusts Font'. (LaunchScreen is skipped.)"
ib_grep 'fontDescription[^>]*pointSize=' | grep -v 'style=' | show

section "Storyboard/xib labels without adjustsFontForContentSizeCategory" \
  "Labels need adjustsFontForContentSizeCategory=\"YES\" to follow text-size changes."
ib_grep '<label ' | grep -v 'adjustsFontForContentSizeCategory="YES"' | show


section "Web content (WKWebView)" \
  "Web views don't follow Dynamic Type or the app's accessibility code. The page needs its own WCAG check; scale text with CSS 'font: -apple-system-body' or WKWebView.pageZoom, and test VoiceOver inside it."
swift_files 'WKWebView|WebPage\(' | show

echo
echo "Done. This scan covers Dynamic Type only. VoiceOver, Voice Control, contrast, motion,"
echo "touch targets, forms and WCAG mapping are in iOS Accessibility Pro (accessible-mobile-apps)."
