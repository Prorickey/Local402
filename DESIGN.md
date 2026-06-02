# Local402 — SwiftUI (macOS) Design & Implementation Guide

A Microsoft-Copilot-inspired **Fluent** feel — flourish mark, acrylic surfaces, answer cards, streaming shimmer — rendered on **Local402's dark-blue theme** and built for **resizable desktop macOS** windows. This is the companion to the implemented app: it reuses the existing `Theme` tokens, styles, and components (`Theme.color.*`, `.card()`, `PaymentInlineView`, `AccentButtonStyle`, …) and layers the Copilot-flavored surface on top.

**Principles**

- **Dark, calm canvas.** Local402 is dark-only (`preferredColorScheme(.dark)`). The deep navy `#0A0E1A` canvas stays quiet so content and payments pop.
- **One brand gesture.** Copilot's single warm flourish becomes Local402's **blue flourish** — an `accent → accentHover` sheen used for the assistant mark, streaming edge, and focus emphasis. It is brand, never state.
- **Acrylic, not flat.** Fluent vibrancy via `.regularMaterial` over the navy, with a faint surface tint and hairline stroke. macOS gives real vibrancy and real hover — lean into both.
- **Cost is first-class.** The Copilot "answer card" fuses with Local402's x402 model: inline `PaymentInlineView` pills and a per-answer **spend chip** in `paymentGreen`.
- **Desktop affordances.** Hover, pointer cursors, right-click menus, and keyboard shortcuts (`⌘↵` send, `⌘N` new chat) — things the iOS guide had no room for.

---

## 1. Color Tokens

Local402 already ships an `enum Theme` token namespace (see `Local402/Theme/Theme.swift`). The Copilot palette maps onto it 1:1 — **use `Theme.color.*`, never raw hex in views.**

| Copilot token | Local402 token | Hex |
|---|---|---|
| `cpCanvas` | `Theme.color.background` | `#0A0E1A` |
| `cpSurface` | `Theme.color.surface` | `#121A2E` |
| (elevated) | `Theme.color.surfaceElevated` | `#1B2640` |
| `cpDivider` | `Theme.color.surfaceStroke` | `#243048` |
| `cpTextPrimary` | `Theme.color.textPrimary` | `#E8ECF4` |
| `cpTextSecondary` | `Theme.color.textSecondary` | `#9AA7C2` |
| `cpTextTertiary` | `Theme.color.textTertiary` | `#5C6B8A` |
| `cpBlue` (brand) | `Theme.color.accent` | `#3B82F6` |
| `cpDarkBlue` (hover) | `Theme.color.accentHover` | `#60A5FA` |
| `cpBlueTint` | `Theme.color.accent.opacity(0.18)` | — |
| user turn fill | `Theme.color.userBubble` | `#1E3A8A` |
| `cpSuccess` | `Theme.color.paymentGreen` | `#22C55E` |
| (payment wash) | `Theme.color.paymentGreenSoft` | `#10331F` |

A handful of tokens the Copilot spec needs that aren't yet in `Theme` — add them alongside the existing palette in `Theme.swift`:

```swift
extension Theme.color {
    static let accentPressed = Color(hex: "#2563EB")   // pressed/active blue
    static let warning       = Color(hex: "#F59E0B")   // low balance, caution
    static let error         = Color(hex: "#EF4444")   // declined payment, failure
}

// The single brand gesture — on-theme blue flourish (replaces Copilot's coral→gold).
extension LinearGradient {
    /// Flourish mark, streaming edge, focus emphasis. Brand, not state.
    static let local402Flourish = LinearGradient(
        colors: [Theme.color.accent, Theme.color.accentHover],
        startPoint: .leading, endPoint: .trailing
    )

    /// Optional "value" variant for payment/earnings emphasis only.
    static let local402Value = LinearGradient(
        colors: [Theme.color.accent, Theme.color.paymentGreen],
        startPoint: .leading, endPoint: .trailing
    )
}
```

> **Why blue, not coral/gold?** The brief is "keep my color theme, get a Copilot feel." Copilot's identity is its one warm gesture; Local402's identity is blue. We keep the *concept* (a single recognizable brand gradient) and re-skin it to the navy/accent family so the flourish never fights the theme. Reserve `local402Value` for money moments.

Light mode is intentionally out of scope — Local402 pins `.preferredColorScheme(.dark)`. If a light variant is ever needed, mirror these tokens and drive both from the environment `colorScheme`.

---

## 2. Typography

Segoe UI / Cascadia Code aren't on macOS, and Local402 already standardizes on **SF Pro (system, rounded for display)** via `Theme.font.*`. Keep using those tokens; they are the macOS-native equivalent of the Copilot ramp and give you free Dynamic Type + optical sizing.

| Copilot role | Local402 token |
|---|---|
| `cpGreeting` | `Theme.font.largeTitle` (30, bold, rounded) |
| `cpTitle` | `Theme.font.title` (22, semibold, rounded) |
| `cpSection` / `cpAnswerH3` | `Theme.font.headline` (16, semibold) |
| `cpAnswerBody` / `cpUserTurn` / `cpPromptInput` | `Theme.font.body` (14) |
| `cpChip` / `cpTone` | `Theme.font.callout` (13, medium) |
| `cpMeta` | `Theme.font.caption` (11, medium) |
| `cpCode` | `Theme.font.mono` (12, monospaced) |
| `cpLabelUpper` | `Theme.font.caption` + `.tracking(0.6)` + `.uppercased()` |

If you specifically want the Fluent letterform on macOS, bundle **Inter** (humanist grotesque, closest free match) and register via the app target's `Info.plist` (`ATSApplicationFontsPath = Fonts`), then add an Inter-backed parallel ramp. Default to system — it reads as "native macOS Copilot."

```swift
// Optional convenience matching the iOS guide's escape hatch.
extension Font {
    static func l402(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
}
```

---

## 3. Signature Components (macOS-adapted)

### Acrylic Surface Modifier

Fluent acrylic = frosted material + faint tint + hairline + a soft blur-in. On macOS, honor **Reduce Transparency** by swapping the material for a solid surface (text contrast over vibrancy is a real concern on the dark canvas).

```swift
struct Local402Acrylic: ViewModifier {
    var cornerRadius: CGFloat = Theme.radius.lg
    var appears: Bool = true
    @State private var shown = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.color.surfaceStroke.opacity(0.8), lineWidth: 1)
            )
            .opacity(shown || !appears ? 1 : 0)
            .blur(radius: (shown || !appears || reduceMotion) ? 0 : 8)
            .onAppear {
                guard appears else { return }
                if reduceMotion { shown = true }
                else { withAnimation(.easeOut(duration: 0.22)) { shown = true } }
            }
    }

    @ViewBuilder private var surface: some View {
        if reduceTransparency {
            Theme.color.surface                     // solid fallback
        } else {
            ZStack {                                 // frosted + faint navy tint
                Rectangle().fill(.regularMaterial)
                Theme.color.surface.opacity(0.55)
            }
        }
    }
}

extension View {
    func local402Acrylic(cornerRadius: CGFloat = Theme.radius.lg, appears: Bool = true) -> some View {
        modifier(Local402Acrylic(cornerRadius: cornerRadius, appears: appears))
    }
}
```

> For stronger, window-correct vibrancy (sidebar, top bar), wrap an `NSVisualEffectView` (`material: .underWindowBackground`, `blendingMode: .behindWindow`) via `NSViewRepresentable`. Use the material modifier above for in-content cards; use the NSVisualEffect wrapper for the chrome.

### Flourish Mark

```swift
struct Local402Flourish: View {
    var size: CGFloat = 22
    var body: some View {
        Image(systemName: "sparkles")                // substitute for the swirl glyph
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(LinearGradient.local402Flourish)
            .frame(width: size, height: size)
            .accessibilityHidden(true)               // decorative
    }
}
```

### Answer Card (assistant turn — fused with x402 cost)

This is where Copilot's answer card meets Local402's payment model: the flourish mark, the streamed body, **inline payment pills** (reuse the shipped `PaymentInlineView`), and a hover-revealed action row plus a per-answer **spend chip**.

```swift
struct Local402AnswerCard: View {
    let message: ChatMessage          // role == .assistant
    var spentOnAnswer: Decimal = 0    // sum of this turn's PaymentEvents
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.md) {
            HStack(alignment: .top, spacing: Theme.spacing.md) {
                Local402Flourish(size: 22)

                VStack(alignment: .leading, spacing: Theme.spacing.sm) {
                    ForEach(message.segments) { segment in
                        switch segment {
                        case .text(let value):
                            Text(value)
                                .font(Theme.font.body)
                                .foregroundStyle(Theme.color.textPrimary)
                                .lineSpacing(6)            // ≈ 1.5 line-height
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        case .payment(let event):
                            PaymentInlineView(event: event)   // existing component
                        }
                    }
                }
            }

            if !message.isStreaming {
                HStack(spacing: Theme.spacing.lg) {
                    if spentOnAnswer > 0 { spendChip }
                    Spacer(minLength: 0)
                    Group {
                        actionIcon("doc.on.doc", help: "Copy")
                        actionIcon("arrow.clockwise", help: "Regenerate")
                        actionIcon("hand.thumbsup", help: "Good response")
                        actionIcon("hand.thumbsdown", help: "Bad response")
                        actionIcon("square.and.arrow.up", help: "Share")
                        actionIcon("ellipsis", help: "More")
                    }
                    .opacity(hovering ? 1 : 0)             // desktop: reveal on hover
                    .animation(.easeOut(duration: 0.15), value: hovering)
                }
                .padding(.leading, 34)
            }
        }
        .padding(Theme.spacing.lg)
        .frame(maxWidth: 720, alignment: .leading)         // readable measure
        .local402Acrylic(cornerRadius: Theme.radius.lg)
        .shadow(color: .black.opacity(0.25), radius: 10, y: 2)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Local402 response")
    }

    private var spendChip: some View {
        let label = PaymentEvent.currencyFormatter.string(from: spentOnAnswer as NSDecimalNumber) ?? "$0.00"
        return HStack(spacing: Theme.spacing.xs) {
            Image(systemName: "creditcard.fill").font(.system(size: 11, weight: .semibold))
            Text("Spent \(label) on this answer")
        }
        .paymentPill()                                     // existing green pill style
    }

    private func actionIcon(_ name: String, help: String) -> some View {
        Button { } label: {
            Image(systemName: name)
                .font(.system(size: 15))
                .foregroundStyle(Theme.color.textSecondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)                                        // macOS tooltip
    }
}
```

### User Turn

Copilot's asymmetric bubble, re-skinned to `Theme.color.userBubble`.

```swift
struct Local402UserTurn: View {
    let text: String
    var neutral: Bool = false

    var body: some View {
        HStack {
            Spacer(minLength: 64)
            Text(text)
                .font(Theme.font.body)
                .foregroundStyle(neutral ? Theme.color.textPrimary : .white)
                .padding(.vertical, Theme.spacing.md)
                .padding(.horizontal, Theme.spacing.lg)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: Theme.radius.lg, bottomLeadingRadius: Theme.radius.lg,
                        bottomTrailingRadius: Theme.radius.sm, topTrailingRadius: Theme.radius.lg
                    )
                    .fill(neutral ? Theme.color.surfaceElevated : Theme.color.userBubble)
                )
                .textSelection(.enabled)
        }
    }
}
```

### Spend-Mode Selector (Copilot's Tone selector, re-themed to Local402)

Copilot's Creative/Balanced/Precise becomes Local402's **spend posture** — how aggressively the agent reaches for paid tools. Same segmented-pill mechanic, on-theme, and it *means something* in a cost-aware app.

```swift
struct Local402SpendMode: View {
    @Binding var selection: Int      // 0 Frugal, 1 Balanced, 2 Thorough
    private let modes = ["Frugal", "Balanced", "Thorough"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(modes.indices, id: \.self) { i in
                Text(modes[i])
                    .font(Theme.font.callout)
                    .foregroundStyle(selection == i ? .white : Theme.color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(selection == i ? Theme.color.accent : .clear))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) { selection = i }
                    }
                    .help(modeHelp(i))
            }
        }
        .padding(3)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().strokeBorder(Theme.color.surfaceStroke, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spend mode, \(modes[selection])")
    }

    private func modeHelp(_ i: Int) -> String {
        ["Avoid paid tools unless essential",
         "Pay when the value clearly beats the cost",
         "Use whatever paid tools improve the answer"][i]
    }
}
```

### Prompt Bar (acrylic, focus accent, desktop keys)

macOS changes: no haptics, add `⌘↵` to send, `.help()` tooltips, real hover, and a focus ring in `accent`.

```swift
struct Local402PromptBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool
    var isStreaming: Bool = false
    let onSend: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: Theme.spacing.md) {
            iconButton("plus", help: "Add context") { }

            TextField("Message Local402", text: $text, axis: .vertical)
                .font(Theme.font.body)
                .textFieldStyle(.plain)
                .foregroundStyle(Theme.color.textPrimary)
                .focused($focused)
                .lineLimit(1...6)
                .onSubmit(submit)                                  // Enter sends

            sendButton
        }
        .padding(.horizontal, Theme.spacing.lg)
        .padding(.vertical, Theme.spacing.sm)
        .frame(minHeight: 52)
        .background(.regularMaterial)
        .background(Theme.color.surfaceElevated.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius.xl, style: .continuous)
                .strokeBorder(focused ? Theme.color.accent : Theme.color.surfaceStroke,
                              lineWidth: focused ? 1.5 : 1)
                .animation(.easeOut(duration: 0.18), value: focused)
        )
        // Cmd+Return always sends, even mid-edit.
        .background(
            Button("", action: submit).keyboardShortcut(.return, modifiers: .command).hidden()
        )
    }

    private func submit() { guard !text.isEmpty, !isStreaming else { return }; onSend() }

    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 20)).foregroundStyle(Theme.color.textSecondary)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    @ViewBuilder private var sendButton: some View {
        if isStreaming {
            Button(action: onStop) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.color.accent))
            }
            .buttonStyle(.plain).help("Stop generating")
        } else {
            let active = !text.isEmpty
            Button(action: submit) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(active ? .white : Theme.color.textTertiary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(active ? Theme.color.accent : Color.clear))
            }
            .buttonStyle(.plain).disabled(!active).help("Send")
        }
    }
}
```

> The shipped `ChatInputBar` already covers Local402's baseline; adopt the acrylic background, focus ring, and `⌘↵` from here to give it the Copilot feel.

### Suggestion Chip + Pressable Style (with hover)

```swift
struct Local402SuggestionChip: View {
    let label: String
    var featured: Bool = false
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacing.sm) {
                if featured { Local402Flourish(size: 12) }
                Text(label).font(Theme.font.callout).foregroundStyle(Theme.color.textPrimary)
            }
            .padding(.vertical, Theme.spacing.sm)
            .padding(.horizontal, Theme.spacing.lg)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    hovering ? Theme.color.accent.opacity(0.6) : Theme.color.surfaceStroke,
                    lineWidth: 1)
            )
        }
        .buttonStyle(Local402PressableStyle())
        .onHover { hovering = $0 }
    }
}

struct Local402PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
```

---

## 4. Streaming Shimmer + Thinking

The shipped `ChatStore` streams tokens and `TypingIndicatorView` covers the dots. To get the Copilot warmth, overlay a low-opacity **blue** sweep (the flourish family) on streaming text and use a flourish-gradient thinking pulse. Both must yield to **Reduce Motion** (still append tokens — only the cosmetic sweep stops).

```swift
struct Local402StreamingText: View {
    let text: String
    @State private var phase: CGFloat = -0.3
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(Theme.font.body)
            .foregroundStyle(Theme.color.textPrimary)
            .lineSpacing(6)
            .overlay(shimmer)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { phase = 1.3 }
            }
    }

    @ViewBuilder private var shimmer: some View {
        if !reduceMotion {
            LinearGradient(
                colors: [.clear,
                         Theme.color.accentHover.opacity(0.28),
                         Theme.color.accent.opacity(0.18),
                         .clear],
                startPoint: .init(x: phase, y: 0.5),
                endPoint: .init(x: phase + 0.3, y: 0.5)
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
        }
    }
}

struct Local402Thinking: View {
    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(LinearGradient.local402Flourish)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animating ? 1 : 0.5)
                    .animation(reduceMotion ? nil :
                        .easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15),
                        value: animating)
            }
        }
        .onAppear { animating = true }
        .accessibilityLabel("Local402 is thinking")
    }
}
```

---

## 5. Navigation (macOS desktop — keeps the Local402 flow)

Local402's flow is preserved: **chat is the main surface**, and the **in-app top bar** carries branding on the left with **Wallet ($)** and **Settings (⚙)** tabs on the right (see `AppTopBar` / `MainView`). The Copilot adaptation gives the top bar **acrylic chrome** and adds an *optional* collapsible **chat-history sidebar** — the one genuinely desktop-Copilot pattern — without displacing the right-side tabs.

```swift
struct Local402Shell: View {
    @Environment(AppState.self) private var appState
    @State private var historyOpen = true            // persistent on desktop, collapsible

    var body: some View {
        HStack(spacing: 0) {
            if historyOpen {
                Local402HistorySidebar()
                    .frame(width: 280)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            VStack(spacing: 0) {
                topBar                                // branding + history toggle + Wallet/Settings
                Divider().overlay(Theme.color.surfaceStroke)

                switch appState.selectedTab {         // existing routing
                case .chat:     ChatView()
                case .wallet:   WalletView()
                case .settings: SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.color.background)
        .animation(.easeOut(duration: 0.25), value: historyOpen)
    }

    private var topBar: some View {
        HStack(spacing: Theme.spacing.md) {
            Button { withAnimation { historyOpen.toggle() } } label: {
                Image(systemName: "sidebar.left").font(.system(size: 18))
                    .foregroundStyle(Theme.color.textSecondary)
            }
            .buttonStyle(.plain).help("Toggle chat history")
            .keyboardShortcut("\\", modifiers: .command)   // ⌘\ like Xcode/VS Code

            AppTopBar()                                     // existing: brand + Wallet/Settings tabs
        }
        .padding(.horizontal, Theme.spacing.lg)
        .padding(.vertical, Theme.spacing.sm)
        .background(.regularMaterial)                       // acrylic chrome
    }
}

struct Local402HistorySidebar: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacing.sm) {
            Button { } label: {
                HStack { Image(systemName: "square.and.pencil"); Text("New chat").font(Theme.font.headline) }
                    .padding(.vertical, Theme.spacing.md).padding(.horizontal, Theme.spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: Theme.radius.md).fill(Theme.color.accent))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain).keyboardShortcut("n", modifiers: .command)   // ⌘N

            Text("TODAY")
                .font(Theme.font.caption).tracking(0.6)
                .foregroundStyle(Theme.color.textTertiary)
                .padding(.top, Theme.spacing.lg).padding(.leading, Theme.spacing.xs)

            // Recents: ~44pt rows; active row gets .local402Acrylic + a 3pt leading accent bar.
            Spacer()
        }
        .padding(Theme.spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)                       // NSVisualEffect for stronger vibrancy
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.color.surfaceStroke).frame(width: 1)
        }
    }
}
```

**Window** (set in `Local402App`): resizable, `.defaultSize(width: 1100, height: 760)`, `minWidth: 760`, dark canvas. Constrain chat content to a `maxWidth: 720` readable column centered in the available space. No `UIScreen`, no fixed phone frame — this is a desktop window.

---

## 6. Motion

```swift
// Acrylic blur-in   — Local402Acrylic ramps opacity + blur 8→0 over 0.22s (skipped on Reduce Motion)
// Streaming shimmer — Local402StreamingText sweeps a low-opacity blue (accent) gradient
// Thinking pulse    — Local402Thinking, flourish dots before the first token
// Send ⇄ Stop morph
.animation(.spring(response: 0.2, dampingFraction: 0.7), value: isStreaming)
// Spend-mode pill slide
.animation(.spring(response: 0.2, dampingFraction: 0.7), value: selection)
// Prompt focus ring
.animation(.easeOut(duration: 0.18), value: focused)
// History sidebar collapse
.animation(.easeOut(duration: 0.25), value: historyOpen)
// Tab content cross-fade (existing MainView)
.animation(.easeInOut(duration: 0.2), value: appState.selectedTab)
```

All idle/cosmetic motion (flourish shimmer, thinking pulse, acrylic blur-in) must check `@Environment(\.accessibilityReduceMotion)` and degrade to a cross-fade or no-op. Token streaming itself never stops.

---

## 7. SF Symbols

| Component | Symbol | Size |
|---|---|---|
| Flourish (brand) | `sparkles` | 12–56pt |
| Send | `arrow.up` | 17pt |
| Stop streaming | `stop.fill` | 13pt |
| Add context | `plus` | 20pt |
| Copy | `doc.on.doc` | 15pt |
| Like / Dislike | `hand.thumbsup` / `hand.thumbsdown` | 15pt |
| Regenerate | `arrow.clockwise` | 15pt |
| Share | `square.and.arrow.up` | 15pt |
| More | `ellipsis` | 15pt |
| History toggle | `sidebar.left` | 18pt |
| New chat | `square.and.pencil` | 18pt |
| Search (sidebar) | `magnifyingglass` | 16pt |
| Conversation row | `bubble.left` | 16pt |
| Wallet tab (money) | `dollarsign.circle` | 16pt |
| Settings tab | `gearshape` | 16pt |
| Payment event | `creditcard.fill` | 11pt |
| Account | `person.crop.circle` | 24pt |

---

## 8. Minimum macOS & Accessibility

- **Target:** macOS 14 (Sonoma) for `.regularMaterial`, `UnevenRoundedRectangle`, `@Observable`, `.scrollTargetBehavior`. The shipped project targets macOS 15.7 — comfortably above. `.sensoryFeedback` exists on macOS 14+ but there's **no haptic hardware** except Force Touch trackpads; prefer no haptics, or `NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime:)` for trackpad-only flourishes. Do **not** port the iOS `UIImpactFeedbackGenerator`.
- **Hover & pointer (desktop-only):** reveal answer-card actions on `.onHover`; add `.help(_:)` tooltips on every icon button; use `.pointerStyle(.link)` (macOS 15) or an `NSCursor` push on interactive chrome.
- **Keyboard:** `⌘↵` send, `⌘N` new chat, `⌘\` toggle history, `⌘,` Settings, `Esc` to stop streaming. Make the prompt field the default focus.
- **Reduce Transparency:** when `accessibilityReduceTransparency` is on, swap every `.regularMaterial` for solid `Theme.color.surface` / `surfaceElevated` so text keeps contrast over the navy.
- **Reduce Motion:** stop the flourish shimmer and streaming sweep, skip the acrylic blur-in, cross-fade the sidebar — but keep appending tokens.
- **VoiceOver:** announce the answer card as "Local402 response"; the send button as "Send" / "Stop generating"; the flourish is decorative (`.accessibilityHidden(true)`); the spend-mode selector exposes a "Spend mode, Balanced" picker semantic; payment pills read their amount + resource (e.g. "Paid $0.02, Tavily search").
- **Color is never the only signal:** the blue flourish is brand, not state; pair focus with the stroke ring + VoiceOver focus, and payment success with the `creditcard` glyph + text, not green alone.
- **Contrast:** `textSecondary #9AA7C2` and `textPrimary #E8ECF4` on the navy surfaces pass WCAG AA at body sizes; keep `textTertiary #5C6B8A` for ≥13pt only.
- **Dynamic Type:** support it on greeting, answer body/headings, user turn, and chips; pin the prompt-bar base height (52pt), sidebar day labels, and spend-mode labels so the chrome stays stable.

---

### Mapping summary

| Copilot (iOS) | Local402 (macOS) |
|---|---|
| Coral→gold flourish | Blue `accent→accentHover` flourish |
| Light canvas / `#F3F3F3` surfaces | Dark navy `#0A0E1A` / `#121A2E` |
| `cpBlue #0078D4` | `accent #3B82F6` |
| Tone: Creative/Balanced/Precise | **Spend mode: Frugal/Balanced/Thorough** |
| Answer card | Answer card **+ inline x402 pills + spend chip** |
| Hamburger → overlay sidebar | Collapsible **persistent** history sidebar (`⌘\`) |
| Bottom nav, no tab bar | Top bar with Wallet ($) / Settings (⚙) tabs (kept) |
| Haptics (`UIImpactFeedbackGenerator`) | None (or trackpad `NSHapticFeedbackManager`) |
| Touch only | Hover, pointer, tooltips, keyboard shortcuts |
