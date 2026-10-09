<!--
HIG Doctor 2.0.3 (raintree-technology/apple-hig-skills at 3ec08f5), guideline snapshot 2025-02-02.
Run on 2026-10-09 from packages/cli with bun 1.3.11:
  bun src/cli.ts /Users/ralfchille/Developer/causabee --stdout --no-baseline \
    --exclude ".build/**,.build-app/**,.claude/**,site/**,Tests/**,LocalBench/**,*.html"
--stdout was used instead of --export so that nothing was written to the repository root.
The "Instructions for AI Evaluator" below are the tool's own output, kept as produced.
What was carried into the review and what was discarded: section 7 of ../HIG-REVIEW.md.
-->

# HIG Audit: causabee

**Generated**: 2026-10-09
**Project**: /Users/ralfchille/Developer/causabee
**Frameworks detected**: swiftui, uikit
**Files scanned**: 117 code, 0 style, 1 config

**Quick stats**: 199 potential concerns, 1998 positive patterns, 884 component usages detected across 11 HIG categories

## Instructions for AI Evaluator

You are reviewing a project for Apple Human Interface Guidelines compliance.
The HIG principles (accessibility, color systems, typography, responsive layout, motion) apply to all surfaces — native, web, and cross-platform.
For each category below, evaluate the code excerpts against the HIG reference material.

**Scoring**: Rate each category 1-10:
- **9-10**: Excellent HIG compliance, follows best practices
- **7-8**: Good compliance with minor improvements possible
- **5-6**: Partial compliance, several areas need attention
- **3-4**: Significant HIG violations
- **1-2**: Major violations or missing fundamental practices

**Output**: For each category, provide:
1. Score (1-10)
2. What's done well (cite specific code)
3. What needs improvement (cite specific file:line)
4. Specific fix recommendations

## Category: Foundations

*2071 detections across 42 file(s) — 199 concern(s), 1869 positive(s)*

### Code Excerpts

**Sources/CausabeeShare/ShareViewController\.swift**
~~~swift
L130: Text(why).multilineTextAlignment(.center).foregroundStyle(.secondary) // ✓ good
L130: Text(why).multilineTextAlignment(.center).foregroundStyle(.secondary) // ✓ good
L146: Text("INTO").font(.caption).foregroundStyle(.secondary).kerning(0.5) // ✓ good
L146: Text("INTO").font(.caption).foregroundStyle(.secondary).kerning(0.5) // ✓ good
L146: Text("INTO").font(.caption).foregroundStyle(.secondary).kerning(0.5) // ✓ good
L159: .font(.caption).foregroundStyle(.secondary) // ✓ good
L159: .font(.caption).foregroundStyle(.secondary) // ✓ good
L159: .font(.caption).foregroundStyle(.secondary) // ✓ good
L182: Image(systemName: "doc.richtext").font(.title2).foregroundStyle(.secondary) // ✓ good
L182: Image(systemName: "doc.richtext").font(.title2).foregroundStyle(.secondary) // ✓ good
L182: Image(systemName: "doc.richtext").font(.title2).foregroundStyle(.secondary) // ✓ good
L182: Image(systemName: "doc.richtext").font(.title2).foregroundStyle(.secondary) // ⚠ concern
L194: .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L194: .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L194: .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
// ... and 11 more matches
~~~

**Sources/Causabee/PageFind\.swift**
~~~swift
L107: Image(systemName: "magnifyingglass").foregroundStyle(open ? .secondary : .primary) // ✓ good
L107: Image(systemName: "magnifyingglass").foregroundStyle(open ? .secondary : .primary) // ⚠ concern
L125: .font(.caption.monospacedDigit()).foregroundStyle(.secondary).fixedSize() // ✓ good
L125: .font(.caption.monospacedDigit()).foregroundStyle(.secondary).fixedSize() // ✓ good
L126: Button(action: find.previous) { Image(systemName: "chevron.up") } // ⚠ concern
L128: Button(action: find.next) { Image(systemName: "chevron.down") } // ⚠ concern
L131: Button(action: close) { Image(systemName: "xmark.circle.fill") } // ⚠ concern
L132: .buttonStyle(.borderless).foregroundStyle(.secondary).help("Close (esc)") // ✓ good
L132: .buttonStyle(.borderless).foregroundStyle(.secondary).help("Close (esc)") // ✓ good
L142: .overlay { if open, focused { Capsule().strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 3) } } // ✓ good
L213: if let problem = voice.problem { Text(problem).font(.caption).foregroundStyle(Theme.warning).padding(.horizontal, 4) } // ✓ good
L215: .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4).padding(.bottom, 4) // ✓ good
L215: .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4).padding(.bottom, 4) // ✓ good
L215: .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4).padding(.bottom, 4) // ✓ good
L242: Text(day).font(.caption).foregroundStyle(.secondary) // ✓ good
// ... and 30 more matches
~~~

**Sources/Causabee/Conversation\.swift**
~~~swift
L400: Image(systemName: AssistantAdd(rawValue: pinned.kind) == nil ? "pin.fill" : "plus").font(.caption).foregroundStyle(Theme.gold) // ✓ good
L400: Image(systemName: AssistantAdd(rawValue: pinned.kind) == nil ? "pin.fill" : "plus").font(.caption).foregroundStyle(Theme.gold) // ⚠ concern
L404: Text(pinned.text).lineLimit(2).foregroundStyle(.primary) // ✓ good
L404: Text(pinned.text).lineLimit(2).foregroundStyle(.primary) // ✓ good
L407: Button(action: unpin) { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) } // ✓ good
L407: Button(action: unpin) { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) } // ⚠ concern
L419: Text(problem).font(.caption).foregroundStyle(Theme.warning).padding(.horizontal, 8) // ✓ good
L439: Image(systemName: "plus").font(.system(size: 15)).frame(width: 34, height: 34).contentShape(Rectangle()) // ⚠ concern
L439: Image(systemName: "plus").font(.system(size: 15)).frame(width: 34, height: 34).contentShape(Rectangle()) // ⚠ concern
L442: .foregroundStyle(.secondary) // ✓ good
L442: .foregroundStyle(.secondary) // ✓ good
L444: .accessibilityLabel("Add to this matter") // ✓ good
L448: Image(systemName: "plus").font(.system(size: 15)).frame(width: 34, height: 34).contentShape(Rectangle()) // ⚠ concern
L448: Image(systemName: "plus").font(.system(size: 15)).frame(width: 34, height: 34).contentShape(Rectangle()) // ⚠ concern
L451: .foregroundStyle(.secondary) // ✓ good
// ... and 4 more matches
~~~

**Sources/Causabee/MailCheck\.swift**
~~~swift
L292: @Environment(\.accessibilityReduceMotion) private var reduceMotion // ✓ good
L314: Text(digest).font(.caption2).foregroundStyle(.secondary).lineLimit(2) // ✓ good
L314: Text(digest).font(.caption2).foregroundStyle(.secondary).lineLimit(2) // ✓ good
L314: Text(digest).font(.caption2).foregroundStyle(.secondary).lineLimit(2) // ✓ good
L326: .menuStyle(.borderlessButton).fixedSize().font(.caption) // ✓ good
L334: .buttonStyle(.gold).font(.caption) // ✓ good
L382: Text("Review ›").font(.caption).foregroundStyle(Theme.gold) // ✓ good
L393: Text(text).font(.caption).foregroundStyle(.secondary) // ✓ good
L393: Text(text).font(.caption).foregroundStyle(.secondary) // ✓ good
L393: Text(text).font(.caption).foregroundStyle(.secondary) // ✓ good
L396: Text("No new mail.").font(.caption).foregroundStyle(.secondary) // ✓ good
L396: Text("No new mail.").font(.caption).foregroundStyle(.secondary) // ✓ good
L396: Text("No new mail.").font(.caption).foregroundStyle(.secondary) // ✓ good
L412: Label(text, systemImage: "checkmark.circle").font(.caption).foregroundStyle(Theme.done) // ✓ good
L416: Image(systemName: "xmark").font(.caption.weight(.semibold)).foregroundStyle(.secondary) // ✓ good
// ... and 34 more matches
~~~

**Sources/Causabee/AskSteps\.swift**
~~~swift
L26: Image(systemName: "checkmark").font(.caption2.weight(.semibold)).foregroundStyle(Theme.done) // ⚠ concern
L37: .font(.caption).foregroundStyle(.secondary) // ✓ good
L37: .font(.caption).foregroundStyle(.secondary) // ✓ good
L37: .font(.caption).foregroundStyle(.secondary) // ✓ good
~~~

**Sources/Causabee/OverviewWeek\.swift**
~~~swift
L53: Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).rotationEffect(.degrees(showsEarlier ? 180 : 0)) // ⚠ concern
L55: .font(.caption).foregroundStyle(.secondary).contentShape(Rectangle()) // ✓ good
L55: .font(.caption).foregroundStyle(.secondary).contentShape(Rectangle()) // ✓ good
L55: .font(.caption).foregroundStyle(.secondary).contentShape(Rectangle()) // ✓ good
L111: .foregroundStyle(.secondary) // ✓ good
L111: .foregroundStyle(.secondary) // ✓ good
L113: .foregroundStyle(.primary) // ✓ good
L113: .foregroundStyle(.primary) // ✓ good
L144: .font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L144: .font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L144: .font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L169: Image(systemName: "exclamationmark.circle").font(.caption).padding(.top, 2) // ✓ good
L169: Image(systemName: "exclamationmark.circle").font(.caption).padding(.top, 2) // ⚠ concern
L172: Text("the longest since \(late.first?.due.map(Dates.short) ?? "")").font(.caption) // ✓ good
L193: .font(.caption).foregroundStyle(Theme.warning).lineLimit(1) // ✓ good
// ... and 6 more matches
~~~

**Sources/Causabee/SetupAssistant\.swift**
~~~swift
L146: Text("Set up Causabee").font(.headline).padding(.bottom, SetupState.isFresh ? 4 : 12) // ✓ good
L156: Image(systemName: isDone(item) ? "checkmark.circle.fill" : item.icon) // ⚠ concern
L157: .foregroundStyle(isDone(item) ? Theme.done : .secondary) // ✓ good
L161: if item == .calendar { Text("optional").font(.caption2).foregroundStyle(.secondary) } // ✓ good
L161: if item == .calendar { Text("optional").font(.caption2).foregroundStyle(.secondary) } // ✓ good
L161: if item == .calendar { Text("optional").font(.caption2).foregroundStyle(.secondary) } // ✓ good
L171: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L171: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L171: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L230: Image(systemName: isDone(item) ? "checkmark.circle.fill" : item == .calendar ? "circle" : "exclamationmark.circle") // ⚠ concern
L231: .foregroundStyle(isDone(item) ? Theme.done : item == .calendar ? .secondary : Theme.warning) // ✓ good
L238: .font(.headline) // ✓ good
L264: var body: some View { Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) } // ✓ good
L264: var body: some View { Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) } // ✓ good
L290: .font(.body) // ✓ good
// ... and 7 more matches
~~~

**Sources/Causabee/ModelChoice\.swift**
~~~swift
L54: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L54: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L54: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L59: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L59: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L59: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L70: .font(.caption).foregroundStyle(.secondary) // ✓ good
L70: .font(.caption).foregroundStyle(.secondary) // ✓ good
L70: .font(.caption).foregroundStyle(.secondary) // ✓ good
L74: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L74: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L74: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L112: .font(.caption).foregroundStyle(found ? Theme.done : Theme.warning) // ✓ good
L123: if let error { Text(error).font(.caption).foregroundStyle(Theme.warning) } // ✓ good
L217: Image(systemName: "bolt.fill").font(.system(size: size)) // ⚠ concern
// ... and 4 more matches
~~~

**Sources/Causabee/MatterStatusView\.swift**
~~~swift
L261: if let at = matter.summaryAt, !auto { Text(Dates.short(at)).font(.caption).foregroundStyle(.secondary) } // ✓ good
L261: if let at = matter.summaryAt, !auto { Text(Dates.short(at)).font(.caption).foregroundStyle(.secondary) } // ✓ good
L261: if let at = matter.summaryAt, !auto { Text(Dates.short(at)).font(.caption).foregroundStyle(.secondary) } // ✓ good
L272: Text("Writing the summary …").font(.caption).foregroundStyle(.secondary) // ✓ good
L272: Text("Writing the summary …").font(.caption).foregroundStyle(.secondary) // ✓ good
L272: Text("Writing the summary …").font(.caption).foregroundStyle(.secondary) // ✓ good
L279: .buttonStyle(.plain).font(.caption).underline().foregroundStyle(.secondary) // ✓ good
L279: .buttonStyle(.plain).font(.caption).underline().foregroundStyle(.secondary) // ✓ good
L279: .buttonStyle(.plain).font(.caption).underline().foregroundStyle(.secondary) // ✓ good
L288: if let summaryError { Text(summaryError).font(.caption).foregroundStyle(Theme.warning).textSelection(.enabled) } // ✓ good
L333: if let why = matter.nextStepWhy { Text(why).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).explanation() } // ✓ good
L333: if let why = matter.nextStepWhy { Text(why).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).explanation() } // ✓ good
L338: Text(rule.why).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).explanation() // ✓ good
L338: Text(rule.why).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true).explanation() // ✓ good
L340: Text("NEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary) // ✓ good
// ... and 183 more matches
~~~

**Sources/Causabee/CalendarChip\.swift**
~~~swift
L42: .font(.caption).foregroundStyle(Theme.done) // ✓ good
L48: Label("no longer in \(where_)", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Theme.warning) // ✓ good
L49: Button("Add again", action: add).buttonStyle(.gold).font(.caption) // ✓ good
L50: Button("Disconnect") { connect(nil) }.buttonStyle(.gold).font(.caption) // ✓ good
L55: .font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L55: .font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L55: .font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L56: Button("Connect") { connect(match.id) }.buttonStyle(.gold).font(.caption) // ✓ good
L60: .buttonStyle(.gold).font(.caption) // ✓ good
L63: if let error { Text(error).font(.caption).foregroundStyle(Theme.warning).lineLimit(1) } // ✓ good
L139: Image(systemName: "calendar") // ⚠ concern
L144: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L144: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L144: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L147: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
// ... and 11 more matches
~~~

**Sources/Causabee/ShotView\.swift**
~~~swift
L74: .onTapGesture { NSWorkspace.shared.open(shot.file) } // ⚠ concern
L79: .onTapGesture { NSWorkspace.shared.open(shot.file) } // ⚠ concern
L83: Text(kindLabel).font(.caption.weight(.semibold)).foregroundStyle(.secondary) // ✓ good
L83: Text(kindLabel).font(.caption.weight(.semibold)).foregroundStyle(.secondary) // ✓ good
L88: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L88: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L88: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L107: if let id { Button("open ›") { open(id) }.buttonStyle(.plain).foregroundStyle(.secondary) } // ✓ good
L107: if let id { Button("open ›") { open(id) }.buttonStyle(.plain).foregroundStyle(.secondary) } // ✓ good
L113: Text("Dismissed — nothing was taken into a matter.").font(.caption).foregroundStyle(.secondary) // ✓ good
L113: Text("Dismissed — nothing was taken into a matter.").font(.caption).foregroundStyle(.secondary) // ✓ good
L113: Text("Dismissed — nothing was taken into a matter.").font(.caption).foregroundStyle(.secondary) // ✓ good
L115: Button("Bring back", action: bringBack).buttonStyle(.gold).font(.caption) // ✓ good
L128: HStack(spacing: 8) { BeeLoader(size: 13); Text(text).foregroundStyle(.secondary) } // ✓ good
L128: HStack(spacing: 8) { BeeLoader(size: 13); Text(text).foregroundStyle(.secondary) } // ✓ good
// ... and 35 more matches
~~~

**Sources/Causabee/CausabeeApp\.swift**
~~~swift
L658: .ignoresSafeArea(.container, edges: .top) // ⚠ concern
L667: .ignoresSafeArea() // ⚠ concern
L693: .accessibilityLabel("Ask Causabee") // ✓ good
L712: .padding(.leading, WindowMetrics.sidebarButtonX).padding(.top, WindowMetrics.sidebarButtonTop - 2).ignoresSafeArea() // ⚠ concern
L725: .font(.body) // ✓ good
L733: .tint(.primary) // ✓ good
L839: Text(matter.name).font(.body).lineLimit(1).foregroundStyle(matter.isClosed ? .secondary : .primary) // ✓ good
L839: Text(matter.name).font(.body).lineLimit(1).foregroundStyle(matter.isClosed ? .secondary : .primary) // ✓ good
L844: if new > 0 { Text("\(new) new \(new == 1 ? "mail" : "mails")").font(.caption).foregroundStyle(Theme.warning) } // ✓ good
L845: if late > 0 { Text("\(late) overdue").font(.caption).foregroundStyle(Theme.warning) } // ✓ good
~~~

**Sources/Causabee/Theme\.swift**
~~~swift
L88: UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1) // ⚠ concern
L88: UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1) // ⚠ concern
L181: Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary) // ✓ good
L181: Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary) // ✓ good
L183: if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) } // ✓ good
L183: if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) } // ✓ good
L183: if let detail { Text(detail).font(.caption).foregroundStyle(.secondary) } // ✓ good
L224: .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 0.5)) // ✓ good
L281: Image(systemName: "arrow.up").font(.system(size: 16, weight: .regular)).foregroundStyle(.black) // ⚠ concern
L281: Image(systemName: "arrow.up").font(.system(size: 16, weight: .regular)).foregroundStyle(.black) // ⚠ concern
L298: .font(.system(size: size * 0.5)) // ⚠ concern
L299: .foregroundStyle(matter.isClosed ? .secondary : .primary) // ✓ good
L302: .accessibilityHidden(true) // ✓ good
L350: Text("Icon for this matter").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 14) // ✓ good
L355: Image(systemName: icon.symbol).font(.system(size: glyph)) // ⚠ concern
// ... and 63 more matches
~~~

**Sources/Causabee/BeeLoader\.swift**
~~~swift
L12: @Environment(\.accessibilityReduceMotion) private var reduceMotion // ✓ good
L24: .accessibilityHidden(true) // ✓ good
L125: @Environment(\.accessibilityReduceMotion) private var reduceMotion // ✓ good
L141: .accessibilityHidden(true) // ✓ good
L168: HStack(spacing: 8) { BeeLoader(); Text("Sorting in 12 mails …").foregroundStyle(.secondary) } // ✓ good
L168: HStack(spacing: 8) { BeeLoader(); Text("Sorting in 12 mails …").foregroundStyle(.secondary) } // ✓ good
L169: HStack(spacing: 6) { BeeLoader(size: 14); Text("Causabee is on it …").font(.caption).foregroundStyle(.secondary) } // ✓ good
L169: HStack(spacing: 6) { BeeLoader(size: 14); Text("Causabee is on it …").font(.caption).foregroundStyle(.secondary) } // ✓ good
L169: HStack(spacing: 6) { BeeLoader(size: 14); Text("Causabee is on it …").font(.caption).foregroundStyle(.secondary) } // ✓ good
~~~

**Sources/Causabee/CloudSync\.swift**
~~~swift
L180: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L180: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L180: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L195: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L195: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L195: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L198: Text("Takes effect when Causabee starts again.").font(.caption).foregroundStyle(Theme.warning) // ✓ good
L205: Text("Now: \(started.label) · \(sync.account)").font(.caption) // ✓ good
L207: .font(.caption).foregroundStyle(.secondary) // ✓ good
L207: .font(.caption).foregroundStyle(.secondary) // ✓ good
L207: .font(.caption).foregroundStyle(.secondary) // ✓ good
L208: if let error = sync.lastError { Text(error).font(.caption).foregroundStyle(Theme.warning).textSelection(.enabled) } // ✓ good
L212: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L212: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L212: .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
~~~

**Sources/Causabee/FolderSaver\.swift**
~~~swift
L61: .font(.caption).lineLimit(1).truncationMode(.middle) // ✓ good
L68: Text("One folder per matter inside it").font(.caption).foregroundStyle(.secondary) // ✓ good
L68: Text("One folder per matter inside it").font(.caption).foregroundStyle(.secondary) // ✓ good
L68: Text("One folder per matter inside it").font(.caption).foregroundStyle(.secondary) // ✓ good
L73: if let busy = saver.busy { ProgressView().controlSize(.small); Text(busy).font(.caption).foregroundStyle(.secondary) } // ✓ good
L73: if let busy = saver.busy { ProgressView().controlSize(.small); Text(busy).font(.caption).foregroundStyle(.secondary) } // ✓ good
L73: if let busy = saver.busy { ProgressView().controlSize(.small); Text(busy).font(.caption).foregroundStyle(.secondary) } // ✓ good
L74: else if let last = saver.last { Text(last).font(.caption).foregroundStyle(.secondary) } // ✓ good
L74: else if let last = saver.last { Text(last).font(.caption).foregroundStyle(.secondary) } // ✓ good
L74: else if let last = saver.last { Text(last).font(.caption).foregroundStyle(.secondary) } // ✓ good
L81: .font(.caption).foregroundStyle(Theme.warning).fixedSize(horizontal: false, vertical: true) // ✓ good
L84: .font(.caption).foregroundStyle(.secondary) // ✓ good
L84: .font(.caption).foregroundStyle(.secondary) // ✓ good
L84: .font(.caption).foregroundStyle(.secondary) // ✓ good
~~~

**Sources/Causabee/IntroView\.swift**
~~~swift
L51: .font(.title3).foregroundStyle(.secondary) // ✓ good
L51: .font(.title3).foregroundStyle(.secondary) // ✓ good
L51: .font(.title3).foregroundStyle(.secondary) // ✓ good
L57: .font(.callout) // ✓ good
L71: .buttonStyle(.borderless).foregroundStyle(.secondary) // ✓ good
L71: .buttonStyle(.borderless).foregroundStyle(.secondary) // ✓ good
L79: .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { index = dot } } // ⚠ concern
~~~

**Sources/Causabee/CardActions\.swift**
~~~swift
L570: Image(systemName: line.symbol).font(symbol).foregroundStyle(.secondary).frame(width: 20) // ✓ good
L570: Image(systemName: line.symbol).font(symbol).foregroundStyle(.secondary).frame(width: 20) // ✓ good
L570: Image(systemName: line.symbol).font(symbol).foregroundStyle(.secondary).frame(width: 20) // ⚠ concern
L572: Text(line.title).font(title).foregroundStyle(open == nil ? .secondary : .primary) // ✓ good
L574: if !line.detail.isEmpty { Text(line.detail).font(.caption2).foregroundStyle(.secondary) } // ✓ good
L574: if !line.detail.isEmpty { Text(line.detail).font(.caption2).foregroundStyle(.secondary) } // ✓ good
L574: if !line.detail.isEmpty { Text(line.detail).font(.caption2).foregroundStyle(.secondary) } // ✓ good
L577: if open != nil { Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.secondary) } // ✓ good
L577: if open != nil { Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.secondary) } // ✓ good
L577: if open != nil { Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.secondary) } // ⚠ concern
L587: .accessibilityHint(open == nil ? "" : "Shows it in its matter") // ✓ good
L598: .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle) // ✓ good
L598: .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle) // ✓ good
L598: .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle) // ✓ good
L679: .accessibilityHidden(!copied) // ✓ good
// ... and 6 more matches
~~~

**Sources/Causabee/AssistantView\.swift**
~~~swift
L114: Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary) // ✓ good
L114: Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary) // ✓ good
L114: Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary) // ⚠ concern
L114: Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary) // ⚠ concern
L120: .accessibilityLabel("Close the assistant") // ✓ good
L134: .font(.callout).foregroundStyle(.secondary) // ✓ good
L134: .font(.callout).foregroundStyle(.secondary) // ✓ good
L134: .font(.callout).foregroundStyle(.secondary) // ✓ good
L140: .buttonStyle(.gold).font(.caption) // ✓ good
L147: .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, index == 0 ? 16 : 24) // ✓ good
L147: .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, index == 0 ? 16 : 24) // ✓ good
L147: .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, index == 0 ? 16 : 24) // ✓ good
L325: Image(systemName: newAnswer ? "arrow.down" : "chevron.down").font(.body.weight(.semibold)) // ⚠ concern
L328: .foregroundStyle(newAnswer ? .primary : .secondary) // ✓ good
L347: Text(line).font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
// ... and 96 more matches
~~~

**Sources/Causabee/Components\.swift**
~~~swift
L29: .fill(selected ? Color.secondary.opacity(0.08) : .clear) // ✓ good
L43: Image(systemName: "sidebar.left").font(.title3).foregroundStyle(.secondary) // ✓ good
L43: Image(systemName: "sidebar.left").font(.title3).foregroundStyle(.secondary) // ✓ good
L43: Image(systemName: "sidebar.left").font(.title3).foregroundStyle(.secondary) // ✓ good
L43: Image(systemName: "sidebar.left").font(.title3).foregroundStyle(.secondary) // ⚠ concern
L48: .accessibilityLabel("Sidebar").accessibilityIdentifier("window.sidebar") // ✓ good
L87: .font(.caption) // ✓ good
L112: Image(systemName: auto ? "bolt.fill" : "bolt").font(.body) // ✓ good
L112: Image(systemName: auto ? "bolt.fill" : "bolt").font(.body) // ⚠ concern
L113: .foregroundStyle(auto ? Color.black : Color.secondary) // ✓ good
L123: .accessibilityLabel("Auto") // ✓ good
L124: .accessibilityValue(auto ? "On" : "Off") // ✓ good
L139: Image(systemName: "eyeglasses").font(.title3) // ✓ good
L139: Image(systemName: "eyeglasses").font(.title3) // ⚠ concern
L140: .foregroundStyle(navigation.reading ? Color.black : Color.secondary) // ✓ good
// ... and 13 more matches
~~~

**Sources/CausabeePhone/PeopleAndLinks\.swift**
~~~swift
L51: .onTapGesture { choose?(party) } // ⚠ concern
L105: Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(.secondary) // ✓ good
L105: Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(.secondary) // ✓ good
L105: Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(.secondary) // ✓ good
L105: Image(systemName: "person.crop.circle").font(.title2).foregroundStyle(.secondary) // ⚠ concern
L107: Text("\(Text(party.name).fontWeight(.medium))\(Text(membership.role.map { " · \($0)" } ?? "").foregroundStyle(.secondary))") // ✓ good
L107: Text("\(Text(party.name).fontWeight(.medium))\(Text(membership.role.map { " · \($0)" } ?? "").foregroundStyle(.secondary))") // ✓ good
L111: Text(share.isMost ? share.text + " · the most" : share.text).font(.caption) // ✓ good
L112: .foregroundStyle(share.isMost ? Theme.gold : .secondary) // ✓ good
L118: Text("also written: " + also.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2) // ✓ good
L118: Text("also written: " + also.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2) // ✓ good
L118: Text("also written: " + also.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary).lineLimit(2) // ✓ good
L122: Text("also in: " + elsewhere.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) // ✓ good
L122: Text("also in: " + elsewhere.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) // ✓ good
L122: Text("also in: " + elsewhere.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary) // ✓ good
// ... and 32 more matches
~~~

**Sources/CausabeePhone/PhoneFolder\.swift**
~~~swift
L48: Text("In the demo, files stay in the demo.").font(.footnote).foregroundStyle(.secondary) // ✓ good
L48: Text("In the demo, files stay in the demo.").font(.footnote).foregroundStyle(.secondary) // ✓ good
L48: Text("In the demo, files stay in the demo.").font(.footnote).foregroundStyle(.secondary) // ✓ good
L52: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L52: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L52: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L61: if let failure { Text(failure).font(.footnote).foregroundStyle(Theme.warning) } // ✓ good
L69: .font(.footnote).foregroundStyle(inside.isEmpty ? Theme.warning : Color.secondary) // ✓ good
L69: .font(.footnote).foregroundStyle(inside.isEmpty ? Theme.warning : Color.secondary) // ✓ good
L72: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L72: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L72: .font(.footnote).foregroundStyle(.secondary) // ✓ good
~~~

**Sources/CausabeePhone/Welcome\.swift**
~~~swift
L29: Image(systemName: "eyeglasses").font(.footnote) // ✓ good
L29: Image(systemName: "eyeglasses").font(.footnote) // ⚠ concern
L33: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L33: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L33: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L53: .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L53: .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) // ✓ good
L62: Text("Next, on Oct 6: The medical service visits").font(.subheadline).foregroundStyle(.secondary) // ✓ good
L62: Text("Next, on Oct 6: The medical service visits").font(.subheadline).foregroundStyle(.secondary) // ✓ good
L62: Text("Next, on Oct 6: The medical service visits").font(.subheadline).foregroundStyle(.secondary) // ✓ good
L67: .accessibilityLabel("An example: Care for Mum after her fall. Next, on October 6, the medical service visits.") // ✓ good
L98: Image(systemName: done ? "checkmark.circle.fill" : "circle") // ⚠ concern
L99: .font(.title3).foregroundStyle(done ? Theme.done : .secondary) // ✓ good
L99: .font(.title3).foregroundStyle(done ? Theme.done : .secondary) // ✓ good
L102: Text(detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) // ✓ good
// ... and 2 more matches
~~~

**Sources/CausabeePhone/SettingsSheet\.swift**
~~~swift
L27: if accounts.isEmpty { Text("Not set up yet").foregroundStyle(.secondary) } // ✓ good
L27: if accounts.isEmpty { Text("Not set up yet").foregroundStyle(.secondary) } // ✓ good
L47: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L47: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L47: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L48: if auto { Text(AutoUpdate.spentWords ?? "Auto has spent nothing today on next steps and summaries").font(.footnote).foregroundStyle(.secondary) } // ✓ good
L48: if auto { Text(AutoUpdate.spentWords ?? "Auto has spent nothing today on next steps and summaries").font(.footnote).foregroundStyle(.secondary) } // ✓ good
L48: if auto { Text(AutoUpdate.spentWords ?? "Auto has spent nothing today on next steps and summaries").font(.footnote).foregroundStyle(.secondary) } // ✓ good
L51: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L51: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L51: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L62: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L62: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L62: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L69: .font(.footnote).foregroundStyle(.secondary) // ✓ good
// ... and 10 more matches
~~~

**Sources/CausabeePhone/Pad\.swift**
~~~swift
L31: Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary) // ✓ good
L31: Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.secondary) // ✓ good
L45: Text("Overview").font(.headline) // ✓ good
L69: Image(systemName: "chevron.right").font(.caption2.weight(.semibold)) // ⚠ concern
L73: .foregroundStyle(.secondary) // ✓ good
L73: .foregroundStyle(.secondary) // ✓ good
L79: .accessibilityHint(showsClosed ? "Hides the closed matters" : "Shows the closed matters") // ✓ good
L112: .accessibilityValue(auto ? "On" : "Off") // ✓ good
L125: Image(systemName: symbol).font(.system(size: 20, weight: .medium)) // ⚠ concern
L125: Image(systemName: symbol).font(.system(size: 20, weight: .medium)) // ⚠ concern
L126: .foregroundStyle(on ? Color.black : Color.primary) // ✓ good
L132: .accessibilityLabel(label) // ✓ good
L144: Image(systemName: "sidebar.left").font(.system(size: 20, weight: .medium)) // ⚠ concern
L144: Image(systemName: "sidebar.left").font(.system(size: 20, weight: .medium)) // ⚠ concern
L145: .foregroundStyle(Color.primary) // ✓ good
// ... and 1 more matches
~~~

**Sources/CausabeePhone/MatterScreen\.swift**
~~~swift
L121: Color.clear.contentShape(Rectangle()).onTapGesture { // ⚠ concern
L222: .accessibilityLabel("Icon").accessibilityHint("Chooses another icon") // ✓ good
L222: .accessibilityLabel("Icon").accessibilityHint("Chooses another icon") // ✓ good
L241: Button { startFinding() } label: { Image(systemName: "magnifyingglass") } // ⚠ concern
L242: .tint(.primary) // ✓ good
L243: .accessibilityLabel("Find in this matter") // ✓ good
L252: Image(systemName: "eyeglasses") // ⚠ concern
L253: .foregroundStyle(navigation.reading ? Color.black : Color.primary) // ✓ good
L257: .accessibilityLabel(navigation.reading ? "Deactivate Reading Mode" : "Activate Reading Mode") // ✓ good
L271: } label: { Image(systemName: "ellipsis") } // ⚠ concern
L272: .tint(.primary) // ✓ good
L273: .accessibilityLabel("More") // ✓ good
L352: .accessibilityLabel("Icon").accessibilityHint("Chooses another icon") // ✓ good
L352: .accessibilityLabel("Icon").accessibilityHint("Chooses another icon") // ✓ good
L373: Image(systemName: "magnifyingglass").foregroundStyle(.secondary) // ✓ good
// ... and 100 more matches
~~~

**Sources/CausabeePhone/Scans\.swift**
~~~swift
L74: .ignoresSafeArea() // ⚠ concern
~~~

**Sources/CausabeePhone/WeekStrip\.swift**
~~~swift
L54: Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).rotationEffect(.degrees(showsEarlier ? 180 : 0)) // ⚠ concern
L56: .font(.caption).foregroundStyle(.secondary) // ✓ good
L56: .font(.caption).foregroundStyle(.secondary) // ✓ good
L56: .font(.caption).foregroundStyle(.secondary) // ✓ good
L77: Image(systemName: "exclamationmark.circle") // ⚠ concern
L80: Text("the longest since \(late.first?.due.map(Dates.short) ?? "")").font(.caption) // ✓ good
L83: Image(systemName: "chevron.down").font(.footnote.weight(.semibold)) // ⚠ concern
L91: .accessibilityHint(showsOverdue ? "Hides the list" : "Shows the list") // ✓ good
L99: Text(todo.text).font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading) // ✓ good
L99: Text(todo.text).font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading) // ✓ good
L99: Text(todo.text).font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading) // ✓ good
L101: .font(.caption).foregroundStyle(Theme.warning).lineLimit(1) // ✓ good
L119: .foregroundStyle(.secondary) // ✓ good
L119: .foregroundStyle(.secondary) // ✓ good
L121: .foregroundStyle(.primary) // ✓ good
// ... and 15 more matches
~~~

**Sources/CausabeePhone/OverviewScreen\.swift**
~~~swift
L57: Divider().ignoresSafeArea() // ⚠ concern
L63: Divider().ignoresSafeArea() // ⚠ concern
L159: .font(.footnote.weight(.semibold)).foregroundStyle(.secondary) // ✓ good
L159: .font(.footnote.weight(.semibold)).foregroundStyle(.secondary) // ✓ good
L202: Image(systemName: "archivebox").foregroundStyle(.secondary) // ✓ good
L202: Image(systemName: "archivebox").foregroundStyle(.secondary) // ✓ good
L202: Image(systemName: "archivebox").foregroundStyle(.secondary) // ⚠ concern
L206: .font(.subheadline).padding(14).phoneBox() // ✓ good
L214: .font(.footnote).foregroundStyle(Theme.gold).padding(.top, 8) // ✓ good
L240: } label: { Image(systemName: "ellipsis") } // ⚠ concern
L241: .tint(.primary) // ✓ good
L242: .accessibilityLabel("More") // ✓ good
L257: Image(systemName: "magnifyingglass").foregroundStyle(.secondary) // ✓ good
L257: Image(systemName: "magnifyingglass").foregroundStyle(.secondary) // ✓ good
L257: Image(systemName: "magnifyingglass").foregroundStyle(.secondary) // ⚠ concern
// ... and 22 more matches
~~~

**Sources/CausabeePhone/Parts\.swift**
~~~swift
L37: Text(text).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) // ✓ good
L37: Text(text).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) // ✓ good
L37: Text(text).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) // ✓ good
L106: .accessibilityLabel("Ask Causabee") // ✓ good
L107: .accessibilityHint("Hold to add to a matter") // ✓ good
L135: Image(systemName: auto ? "bolt.fill" : "bolt").font(.system(size: 15, weight: .medium)) // ⚠ concern
L135: Image(systemName: auto ? "bolt.fill" : "bolt").font(.system(size: 15, weight: .medium)) // ⚠ concern
L136: .foregroundStyle(auto ? Color.black : Color.secondary) // ✓ good
L144: .accessibilityLabel("Auto") // ✓ good
L145: .accessibilityValue(auto ? "On" : "Off") // ✓ good
L146: .accessibilityHint("New mail and files are read at once, or only when you say so") // ✓ good
L170: guard let picture = renderer.uiImage else { return Image(systemName: "bubble.left.and.bubble.right") } // ⚠ concern
L193: Text(matter.name).font(Theme.phoneCardTitleFont).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true) // ✓ good
L193: Text(matter.name).font(Theme.phoneCardTitleFont).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true) // ✓ good
L196: Text("Next, on \(Dates.short(next.day)): \(next.what)").font(.subheadline).foregroundStyle(.secondary).lineLimit(2) // ✓ good
// ... and 7 more matches
~~~

**Sources/CausabeePhone/PhoneShots\.swift**
~~~swift
L225: .font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L225: .font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L225: .font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L227: Text("Saved on this iPhone, in \(PhoneShots.place).").font(.caption).foregroundStyle(.secondary) // ✓ good
L227: Text("Saved on this iPhone, in \(PhoneShots.place).").font(.caption).foregroundStyle(.secondary) // ✓ good
L227: Text("Saved on this iPhone, in \(PhoneShots.place).").font(.caption).foregroundStyle(.secondary) // ✓ good
L231: HStack(spacing: 8) { BeeLoader(size: 15); Text("Scanning it on this iPhone …").font(.subheadline).foregroundStyle(.secondary) } // ✓ good
L231: HStack(spacing: 8) { BeeLoader(size: 15); Text("Scanning it on this iPhone …").font(.subheadline).foregroundStyle(.secondary) } // ✓ good
L231: HStack(spacing: 8) { BeeLoader(size: 15); Text("Scanning it on this iPhone …").font(.subheadline).foregroundStyle(.secondary) } // ✓ good
L236: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L236: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L236: .font(.footnote).foregroundStyle(.secondary) // ✓ good
L243: HStack(spacing: 8) { BeeLoader(size: 15); Text("Sorting it in …").font(.subheadline).foregroundStyle(.secondary) } // ✓ good
L243: HStack(spacing: 8) { BeeLoader(size: 15); Text("Sorting it in …").font(.subheadline).foregroundStyle(.secondary) } // ✓ good
L243: HStack(spacing: 8) { BeeLoader(size: 15); Text("Sorting it in …").font(.subheadline).foregroundStyle(.secondary) } // ✓ good
// ... and 29 more matches
~~~

**Sources/CausabeePhone/PhoneMailCheck\.swift**
~~~swift
L412: @Environment(\.accessibilityReduceMotion) private var reduceMotion // ✓ good
L450: Text("\(count) new \(count == 1 ? "mail" : "mails")").font(.subheadline.weight(.medium)).foregroundStyle(.primary) // ✓ good
L450: Text("\(count) new \(count == 1 ? "mail" : "mails")").font(.subheadline.weight(.medium)).foregroundStyle(.primary) // ✓ good
L451: Text("Review").font(.subheadline).foregroundStyle(Theme.gold) // ✓ good
L460: .font(.caption).foregroundStyle(.tertiary) // ✓ good
L460: .font(.caption).foregroundStyle(.tertiary) // ✓ good
L479: Text(text).font(.subheadline).foregroundStyle(.secondary) // ✓ good
L479: Text(text).font(.subheadline).foregroundStyle(.secondary) // ✓ good
L479: Text(text).font(.subheadline).foregroundStyle(.secondary) // ✓ good
L488: Text(text).font(.subheadline).foregroundStyle(.secondary) // ✓ good
L488: Text(text).font(.subheadline).foregroundStyle(.secondary) // ✓ good
L488: Text(text).font(.subheadline).foregroundStyle(.secondary) // ✓ good
L493: Text("No new mail.").font(.subheadline).foregroundStyle(.secondary) // ✓ good
L493: Text("No new mail.").font(.subheadline).foregroundStyle(.secondary) // ✓ good
L493: Text("No new mail.").font(.subheadline).foregroundStyle(.secondary) // ✓ good
// ... and 50 more matches
~~~

**Sources/CausabeePhone/MailFiles\.swift**
~~~swift
L104: .font(.caption).foregroundStyle(Theme.gold).padding(.horizontal, 4) // ✓ good
L150: Image(systemName: Self.icon(document)).font(.title3).foregroundStyle(.secondary).frame(width: 26) // ✓ good
L150: Image(systemName: Self.icon(document)).font(.title3).foregroundStyle(.secondary).frame(width: 26) // ✓ good
L150: Image(systemName: Self.icon(document)).font(.title3).foregroundStyle(.secondary).frame(width: 26) // ✓ good
L150: Image(systemName: Self.icon(document)).font(.title3).foregroundStyle(.secondary).frame(width: 26) // ⚠ concern
L152: Text(document.shownName).foregroundStyle(.primary).multilineTextAlignment(.leading).lineLimit(2) // ✓ good
L152: Text(document.shownName).foregroundStyle(.primary).multilineTextAlignment(.leading).lineLimit(2) // ✓ good
L162: .font(.caption).foregroundStyle(.secondary).lineLimit(2) // ✓ good
L162: .font(.caption).foregroundStyle(.secondary).lineLimit(2) // ✓ good
L162: .font(.caption).foregroundStyle(.secondary).lineLimit(2) // ✓ good
L164: Text(says).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading).lineLimit(3).padding(.top, 2) // ✓ good
L164: Text(says).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading).lineLimit(3).padding(.top, 2) // ✓ good
L164: Text(says).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.leading).lineLimit(3).padding(.top, 2) // ✓ good
L176: Image(systemName: "ellipsis").frame(width: 30, height: 26).contentShape(Rectangle()) // ⚠ concern
L178: .tint(.secondary) // ✓ good
// ... and 7 more matches
~~~

**Sources/CausabeePhone/AssistantSheet\.swift**
~~~swift
L104: .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40) // ✓ good
L104: .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 40) // ✓ good
L114: .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity) // ✓ good
L114: .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity) // ✓ good
L114: .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity) // ✓ good
L156: Image(systemName: newAnswer ? "arrow.down" : "chevron.down").font(.body.weight(.semibold)) // ⚠ concern
L159: .foregroundStyle(newAnswer ? .primary : .secondary) // ✓ good
L166: .accessibilityLabel(newAnswer ? "To the new answer" : "To the newest") // ✓ good
L204: Label(failure, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Theme.warning) // ✓ good
L215: Text("Causabee").font(.headline) // ✓ good
L216: Text(matter?.name ?? "All matters").font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L216: Text(matter?.name ?? "All matters").font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L216: Text(matter?.name ?? "All matters").font(.caption).foregroundStyle(.secondary).lineLimit(1) // ✓ good
L223: Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(.primary) // ✓ good
L223: Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(.primary) // ✓ good
// ... and 74 more matches
~~~

**Sources/CausabeePhone/History\.swift**
~~~swift
L15: Text(thread.subject.isEmpty ? "(no subject)" : thread.subject).font(.headline).lineLimit(2) // ✓ good
L19: .font(.caption).foregroundStyle(.secondary).fixedSize() // ✓ good
L19: .font(.caption).foregroundStyle(.secondary).fixedSize() // ✓ good
L19: .font(.caption).foregroundStyle(.secondary).fixedSize() // ✓ good
L48: .foregroundStyle(sent ? Theme.gold : Color.secondary) // ✓ good
L49: .accessibilityLabel(sent ? "sent" : "came in") // ✓ good
L87: Text(entry.date.map(Dates.short) ?? "—").font(.caption.monospacedDigit()).foregroundStyle(.secondary) // ✓ good
L87: Text(entry.date.map(Dates.short) ?? "—").font(.caption.monospacedDigit()).foregroundStyle(.secondary) // ✓ good
L90: Image(systemName: "ellipsis").frame(width: 30, height: 26).contentShape(Rectangle()) // ⚠ concern
L92: .tint(.secondary) // ✓ good
L93: .accessibilityLabel("More") // ✓ good
L98: Text(digest).font(.subheadline).foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true) // ✓ good
L98: Text(digest).font(.subheadline).foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true) // ✓ good
L98: Text(digest).font(.subheadline).foregroundStyle(.secondary).lineLimit(3).fixedSize(horizontal: false, vertical: true) // ✓ good
~~~

**Sources/CausabeePhone/AllMatters\.swift**
~~~swift
L43: Text("Quiet · \(quiet.count)\(Text("  nothing open, no date").font(.footnote).foregroundStyle(.secondary))") // ✓ good
L43: Text("Quiet · \(quiet.count)\(Text("  nothing open, no date").font(.footnote).foregroundStyle(.secondary))") // ✓ good
L43: Text("Quiet · \(quiet.count)\(Text("  nothing open, no date").font(.footnote).foregroundStyle(.secondary))") // ✓ good
L54: .tint(.primary) // ✓ good
L111: Text(matter.name).lineLimit(1).foregroundStyle(matter.isClosed ? .secondary : .primary) // ✓ good
L115: if new > 0 { Text("\(new) new \(new == 1 ? "mail" : "mails")").font(.caption).foregroundStyle(Theme.warning) } // ✓ good
L116: if late > 0 { Text("\(late) overdue").font(.caption).foregroundStyle(Theme.warning) } // ✓ good
L129: .font(.caption).foregroundStyle(.secondary) // ✓ good
L129: .font(.caption).foregroundStyle(.secondary) // ✓ good
L129: .font(.caption).foregroundStyle(.secondary) // ✓ good
~~~

**Sources/MatterCore/Screenshot/ScreenshotDoor\.swift**
~~~swift
L180: context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)) // ⚠ concern
L181: context.fill(CGRect(x: 0, y: 0, width: width, height: height)) // ⚠ concern
~~~

**scripts/og\-image\.html**
~~~html
L7: <html lang="en"> // ✓ good
L28: font-family: var(--sans); color: var(--ink); // ✓ good
L37: .eyebrow { display: flex; align-items: center; gap: 12px; margin-top: 30px; font-size: 20px; font-weight: 500; color: var(--ink-2); } // ✓ good
L38: .pill { display: inline-flex; align-items: center; height: 30px; padding: 0 12px; border-radius: 999px; background: var(--honey); color: var(--ink); font-size: 16px; font-weight: 600; } // ✓ good
L39: h1 { margin-top: 18px; font: 400 74px / 1.02 var(--serif); font-optical-sizing: none; letter-spacing: -0.025em; } // ✓ good
L40: .lead { margin-top: 22px; font-size: 23px; line-height: 1.4; color: var(--muted); } // ✓ good
L41: .private { position: absolute; left: 72px; bottom: 58px; display: flex; align-items: center; gap: 10px; font-size: 19px; color: var(--ink-2); } // ✓ good
L42: .private strong { color: var(--ink); font-weight: 600; } // ✓ good
L46: border-radius: 14px; overflow: hidden; box-shadow: var(--shadow-shot); background: #fff; // ✓ good
L52: padding: 6.4px; border-radius: 36px; background: var(--ink); // ✓ good
L53: box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.12), var(--shadow-shot); // ✓ good
L62: <h1>Be organized.<br>Be private.</h1> // ✓ good
L66: <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#7F5E00" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/></svg> // ✓ good
~~~

**scripts/film/web/film\.html**
~~~html
L2: <html lang="en"><head><meta charset="utf-8"><title>Causabee in 90 seconds</title> // ✓ good
L11: html, body { margin: 0; width: 1080px; height: 1920px; background: #fff; overflow: hidden; font-family: Inter, -apple-system, "SF Pro Text", system-ui, sans-serif; color: var(--ink); -webkit-font-smoothing: antialiased; } // ✓ good
L16: .head { position: absolute; left: 80px; top: 300px; width: 920px; text-align: center; font-family: "Source Serif 4", serif; font-size: 88px; line-height: 100px; font-weight: 400; opacity: 0; animation: head-in 0.5s var(--ease-out) both, head-out 0.35s var(--ease-in) forwards; animation-delay: calc(var(--in) - 0.25s), calc(var(--out) - 0.8s); } // ✓ good
L32: .mail .dot { position: absolute; left: -10px; top: 46px; width: 16px; height: 16px; border-radius: 50%; background: var(--honey); transform: scale(0); } // ✓ good
L33: .mail .avatar { flex: none; width: 70px; height: 70px; border-radius: 50%; background: var(--pale); color: var(--grey); font-weight: 500; font-size: 30px; display: grid; place-items: center; margin-left: 16px; } // ✓ good
L34: .mail .body { flex: 1; min-width: 0; padding-bottom: 20px; border-bottom: 2px solid var(--line); } // ✓ good
L37: .mail .date { color: var(--grey); font-size: 27px; } // ✓ good
L39: .mail .preview { color: var(--grey); font-size: 28px; line-height: 36px; margin-top: 4px; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; } // ✓ good
L40: .mail .file { display: inline-flex; align-items: center; gap: 8px; margin-top: 12px; padding: 6px 14px 6px 12px; background: var(--pale); border-radius: 12px; font-size: 25px; } // ✓ good
L43: .inbox { animation: inbox-up 0.6s var(--ease-out) both; animation-delay: calc(var(--v2) - 0.25s); } // ✓ good
L45: .mail:nth-child(1) { animation: mail-in 0.6s var(--ease-out) both; animation-delay: calc(var(--v1) + 0.2s); } // ✓ good
L46: .mail:nth-child(1) .dot { animation: pop 0.45s var(--ease-out) both; animation-delay: calc(var(--v1) + 1.2s); } // ✓ good
L47: .mail:nth-child(2) { animation: mail-in 0.55s var(--ease-out) both; animation-delay: calc(var(--v2) + 0.9s); } // ✓ good
L48: .mail:nth-child(2) .dot { animation: pop 0.4s var(--ease-out) both; animation-delay: calc(var(--v2) + 1.3s); } // ✓ good
L49: .mail:nth-child(3) { animation: mail-in 0.55s var(--ease-out) both; animation-delay: calc(var(--v2) + 1.6s); } // ✓ good
// ... and 221 more matches
~~~

**scripts/film/web/film\-web\.html**
~~~html
L2: <html lang="en"><head><meta charset="utf-8"><title>Causabee in 90 seconds</title> // ✓ good
L11: html, body { margin: 0; width: 100%; height: 100%; background: #fff; overflow: hidden; font-family: Inter, -apple-system, "SF Pro Text", system-ui, sans-serif; color: var(--ink); -webkit-font-smoothing: antialiased; } // ✓ good
L16: .head { position: absolute; left: 80px; top: 300px; width: 920px; text-align: center; font-family: "Source Serif 4", serif; font-size: 88px; line-height: 100px; font-weight: 400; opacity: 0; animation: head-in 0.5s var(--ease-out) both, head-out 0.35s var(--ease-in) forwards; animation-delay: calc(var(--in) - 0.25s), calc(var(--out) - 0.8s); } // ✓ good
L32: .mail .dot { position: absolute; left: -10px; top: 46px; width: 16px; height: 16px; border-radius: 50%; background: var(--honey); transform: scale(0); } // ✓ good
L33: .mail .avatar { flex: none; width: 70px; height: 70px; border-radius: 50%; background: var(--pale); color: var(--grey); font-weight: 500; font-size: 30px; display: grid; place-items: center; margin-left: 16px; } // ✓ good
L34: .mail .body { flex: 1; min-width: 0; padding-bottom: 20px; border-bottom: 2px solid var(--line); } // ✓ good
L37: .mail .date { color: var(--grey); font-size: 27px; } // ✓ good
L39: .mail .preview { color: var(--grey); font-size: 28px; line-height: 36px; margin-top: 4px; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; } // ✓ good
L40: .mail .file { display: inline-flex; align-items: center; gap: 8px; margin-top: 12px; padding: 6px 14px 6px 12px; background: var(--pale); border-radius: 12px; font-size: 25px; } // ✓ good
L43: .inbox { animation: inbox-up 0.6s var(--ease-out) both; animation-delay: calc(var(--v2) - 0.25s); } // ✓ good
L45: .mail:nth-child(1) { animation: mail-in 0.6s var(--ease-out) both; animation-delay: calc(var(--v1) + 0.2s); } // ✓ good
L46: .mail:nth-child(1) .dot { animation: pop 0.45s var(--ease-out) both; animation-delay: calc(var(--v1) + 1.2s); } // ✓ good
L47: .mail:nth-child(2) { animation: mail-in 0.55s var(--ease-out) both; animation-delay: calc(var(--v2) + 0.9s); } // ✓ good
L48: .mail:nth-child(2) .dot { animation: pop 0.4s var(--ease-out) both; animation-delay: calc(var(--v2) + 1.3s); } // ✓ good
L49: .mail:nth-child(3) { animation: mail-in 0.55s var(--ease-out) both; animation-delay: calc(var(--v2) + 1.6s); } // ✓ good
// ... and 221 more matches
~~~

**scripts/film/web/film\.src\.html**
~~~html
L2: <html lang="en"><head><meta charset="utf-8"><title>Causabee in 90 seconds</title> // ✓ good
L11: html, body { margin: 0; width: 1080px; height: 1920px; background: #fff; overflow: hidden; font-family: Inter, -apple-system, "SF Pro Text", system-ui, sans-serif; color: var(--ink); -webkit-font-smoothing: antialiased; } // ✓ good
L16: .head { position: absolute; left: 80px; top: 300px; width: 920px; text-align: center; font-family: "Source Serif 4", serif; font-size: 88px; line-height: 100px; font-weight: 400; opacity: 0; animation: head-in 0.5s var(--ease-out) both, head-out 0.35s var(--ease-in) forwards; animation-delay: calc(var(--in) - 0.25s), calc(var(--out) - 0.8s); } // ✓ good
L32: .mail .dot { position: absolute; left: -10px; top: 46px; width: 16px; height: 16px; border-radius: 50%; background: var(--honey); transform: scale(0); } // ✓ good
L33: .mail .avatar { flex: none; width: 70px; height: 70px; border-radius: 50%; background: var(--pale); color: var(--grey); font-weight: 500; font-size: 30px; display: grid; place-items: center; margin-left: 16px; } // ✓ good
L34: .mail .body { flex: 1; min-width: 0; padding-bottom: 20px; border-bottom: 2px solid var(--line); } // ✓ good
L37: .mail .date { color: var(--grey); font-size: 27px; } // ✓ good
L39: .mail .preview { color: var(--grey); font-size: 28px; line-height: 36px; margin-top: 4px; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; } // ✓ good
L40: .mail .file { display: inline-flex; align-items: center; gap: 8px; margin-top: 12px; padding: 6px 14px 6px 12px; background: var(--pale); border-radius: 12px; font-size: 25px; } // ✓ good
L43: .inbox { animation: inbox-up 0.6s var(--ease-out) both; animation-delay: calc(var(--v2) - 0.25s); } // ✓ good
L45: .mail:nth-child(1) { animation: mail-in 0.6s var(--ease-out) both; animation-delay: calc(var(--v1) + 0.2s); } // ✓ good
L46: .mail:nth-child(1) .dot { animation: pop 0.45s var(--ease-out) both; animation-delay: calc(var(--v1) + 1.2s); } // ✓ good
L47: .mail:nth-child(2) { animation: mail-in 0.55s var(--ease-out) both; animation-delay: calc(var(--v2) + 0.9s); } // ✓ good
L48: .mail:nth-child(2) .dot { animation: pop 0.4s var(--ease-out) both; animation-delay: calc(var(--v2) + 1.3s); } // ✓ good
L49: .mail:nth-child(3) { animation: mail-in 0.55s var(--ease-out) both; animation-delay: calc(var(--v2) + 1.6s); } // ✓ good
// ... and 228 more matches
~~~

**scripts/dmg/background\.html**
~~~html
L5: <html lang="en"> // ✓ good
L35: <svg class="arrow" width="660" height="400" viewBox="0 0 660 400" fill="none" aria-hidden="true"> // ✓ good
L44: <h1>Drag Causabee to Applications</h1> // ✓ good
~~~

### HIG Reference

1. **Prioritize content over chrome.** Reduce visual clutter. Use system-provided materials and subtle separators rather than heavy borders and backgrounds.

2. **Build in accessibility from the start.** Design for VoiceOver, Dynamic Type, Reduce Motion, Increase Contrast, and Switch Control from day one. Every interactive element needs an accessible label.

3. **Use system colors and materials.** System colors adapt to light/dark mode, increased contrast, and vibrancy. Prefer semantic colors (`label`, `secondaryLabel`, `systemBackground`) over hard-coded values.

4. **Use platform fonts and icons.** SF Pro, SF Compact, SF Mono by default. New York for serif. Follow the type hierarchy at recommended sizes. Use SF Symbols for iconography.

5. **Match platform conventions.** Align look and behavior with system standards. Provide direct, responsive manipulation and clear feedback for every action.

6. **Respect privacy.** Request permissions only when needed, explain why clearly, provide value before asking for data. Design for minimal data collection.

7. **Support internationalization.** Accommodate text expansion, right-to-left scripts, and varying date/number formats. Use Auto Layout for dynamic content sizing.

8. **Use motion purposefully.** Animation should communicate meaning and spatial relationships. Honor Reduce Motion by providing crossfade alternatives.

### Evaluate

- Color usage: system semantic colors vs hardcoded values
- Typography: Dynamic Type text styles vs fixed font sizes
- Accessibility: labels, hints, traits on interactive elements
- Dark mode: proper color adaptation, no hardcoded light/dark values
- Motion: Reduce Motion support for animations

## Category: Controls

*501 detections across 34 file(s) — 0 concern(s), 0 positive(s)*

### Code Excerpts

**Sources/CausabeeShare/ShareViewController\.swift**
~~~swift
L131: Button("Close") { model.cancel() }.foregroundStyle(Theme.gold)
L168: ToolbarItem(placement: .cancellationAction) { Button("Cancel") { model.cancel() } }
L169: ToolbarItem(placement: .confirmationAction) { Button("Add") { model.add() }.fontWeight(.semibold) }
L207: Button { model.chosen = key } label: {
~~~

**Sources/Causabee/PageFind\.swift**
~~~swift
L106: Button(action: start) {
L126: Button(action: find.previous) { Image(systemName: "chevron.up") }
L128: Button(action: find.next) { Image(systemName: "chevron.down") }
L131: Button(action: close) { Image(systemName: "xmark.circle.fill") }
L146: Button("", action: start).keyboardShortcut("f", modifiers: .command).hidden()
L205: Button("Add", action: add).filledButton().padding(.bottom, 4).accessibilityIdentifier("note.add")
L246: Button("Edit", systemImage: "pencil", action: edit)
L247: Button("Copy", systemImage: "doc.on.doc") { Self.copy(text) }
L250: Button("Delete", systemImage: "trash", role: .destructive) { withAnimation { delete(); try? context.save() } }
L263: Button("Cancel") { editing = nil; editingEarlier = false }.quietButton()
L264: Button("Save") {
L279: Button("Edit", systemImage: "pencil", action: edit)
L280: Button("Copy", systemImage: "doc.on.doc") { Self.copy(text) }
L282: Button("Delete", systemImage: "trash", role: .destructive) { withAnimation { delete(); try? context.save() } }
L370: ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
// ... and 22 more matches
~~~

**Sources/Causabee/Conversation\.swift**
~~~swift
L407: Button(action: unpin) { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
L427: Button("Task", systemImage: "checklist") { add(.task) }
L428: Button("Note", systemImage: "note.text") { add(.note) }
L432: Button(action.title, systemImage: action.symbol) {
L437: Button("Screenshot, Mail or PDF to Read …", systemImage: "doc.viewfinder", action: attach)
L447: Button(action: attach) {
L479: Button(action: stop ?? send) {
~~~

**Sources/Causabee/MailCheck\.swift**
~~~swift
L319: Button(matter.name) {
L328: Button("Not needed") {
L377: Button { check.state = .ready(look, door) } label: {
L415: Button { withAnimation(.easeOut(duration: 0.2)) { check.state = .idle } } label: {
L428: Button {
L460: Button { check.look(store: navigation.store, context: context) } label: {
L494: Button {
L521: Button("Later", action: later)
L523: Button(chosen.isEmpty ? "Leave out" : chosen.count == look.pending ? "Sort in" : "Sort in \(chosen.count)") { sortIn(chosen) }
L570: Button(chosen.isEmpty ? "Leave out" : chosen.count == offers.count ? "Take in" : "Take in \(chosen.count)") { take(chosen, moved, skipped) }
L588: Button { if on { chosen.remove(index) } else { chosen.insert(index) } } label: {
L603: Button("Later", action: later)
L604: Button(chosen.count == DemoData.newMail.count ? "Sort in" : "Sort in \(chosen.count)") { sortIn(chosen) }
L622: Button {
L637: Button(matter.name) {
~~~

**Sources/Causabee/OverviewWeek\.swift**
~~~swift
L50: Button { withAnimation(.smooth(duration: 0.25)) { showsEarlier.toggle() } } label: {
L107: return Button { withAnimation(.smooth(duration: 0.3)) { chosen = day } } label: {
L138: Button { navigation.open(thing.matter, showing: thing.todo?.persistentModelID) } label: {
L167: Button { showsOverdue = true } label: {
L186: Button {
L210: return Button {
L258: Button { navigation.open(matter) } label: {
L301: Button("Unpin") { matter.pinnedAt = nil; try? context.save() }
L303: Button("Pin to Top") {
L324: Button(pinned.name) {
L331: Button("Cancel", role: .cancel) { navigation.pinning = nil }
~~~

**Sources/Causabee/SetupAssistant\.swift**
~~~swift
L154: Button { step = item } label: {
L193: Button("Later") { if !SetupState.isFresh { later = true }; dismiss() }
L196: Button("Back") { step = Step(rawValue: step.rawValue - 1) ?? .you }
L200: Button("Close") { dismiss() }
L202: Button(SetupState.isFresh ? "Finish test" : "Get new mail") { dismiss(); if !SetupState.isFresh { getMail() } }
L207: Button(step == .calendar && !isDone(.calendar) ? "Skip" : "Next") { step = Step(rawValue: step.rawValue + 1) ?? .ready }
L226: Button { step = item } label: {
L360: Picker("AI", selection: Binding(get: { provider }, set: { choose($0) })) {
L373: Button(checking ? "Checking …" : "Check and save") { check() }
L504: Button(working ? "Logging in …" : "Log in") { logIn() }
L546: Button(working ? "Looking …" : label == nil ? "Look for the label" : "Check again") { lookForLabel(account) }
L550: Button("Use another account") {
L564: Button { signInWithGoogle() } label: {
L672: Button("Connect Calendar and Reminders") {
~~~

**Sources/Causabee/ModelChoice\.swift**
~~~swift
L50: Toggle("Fewer, real tasks", isOn: $strict)
L83: Picker(title, selection: selection) {
L116: Button("Save") {
L121: if stored { Button("Remove") { APIKeys.delete(name); stored = false } }
~~~

**Sources/Causabee/MatterStatusView\.swift**
~~~swift
L210: Button("Merge") {
L213: Button("Cancel", role: .cancel) { merging = nil }
L219: Button("Merge") {
L227: Button("Cancel", role: .cancel) { mergingMatter = nil }
L232: Button("OK") { exportFailure = nil }
L236: Button("Close") { close(markingOpenDone: false) }
L238: Button("Mark all done and close") { close(markingOpenDone: true) }
L239: Button("Leave them open and close") { close(markingOpenDone: false) }
L241: Button("Cancel", role: .cancel) {}
L278: Button("Update · \(cost)", action: writeSummary)
L283: Button("Write summary · \(cost)", action: writeSummary)
L367: Button((fresh ? "ask again · " : "Suggest better · ") + cost, action: askStep)
L385: Button("Write follow-up") {
L392: Button("Write message") {
L400: if !waiting { Button("Done") { withAnimation { toggle(todo) } }.fixedSize() }
// ... and 100 more matches
~~~

**Sources/Causabee/CalendarChip\.swift**
~~~swift
L40: Button { open(id) } label: {
L46: .contextMenu { Button("Open in \(where_)") { open(id) }; Button("Disconnect") { connect(nil) } }
L49: Button("Add again", action: add).buttonStyle(.gold).font(.caption)
L50: Button("Disconnect") { connect(nil) }.buttonStyle(.gold).font(.caption)
L56: Button("Connect") { connect(match.id) }.buttonStyle(.gold).font(.caption)
L59: Button(action: add) { Label("Add to \(where_)", systemImage: "plus") }
L151: Button("Connect") {
L178: Picker("Add appointments to", selection: $calendar) {
L186: Picker("Add tasks to", selection: $list) {
L204: Button("Connect") { Task { _ = await Calendars.shared.requestAccess(); tick += 1 } }
~~~

**Sources/Causabee/ShotView\.swift**
~~~swift
L107: if let id { Button("open ›") { open(id) }.buttonStyle(.plain).foregroundStyle(.secondary) }
L115: Button("Bring back", action: bringBack).buttonStyle(.gold).font(.caption)
L134: Button("Dismiss", action: dismiss)
L135: Button(primary, action: action).inkButton()
L244: Picker("Matter", selection: $choice) {
L332: Toggle(isOn: Binding(get: { !skipped.contains(id) }, set: { if $0 { skipped.remove(id) } else { skipped.insert(id) } })) {
~~~

**Sources/Causabee/CausabeeApp\.swift**
~~~swift
L125: Button("New Matter …") { NotificationCenter.default.post(name: .newMatter, object: nil) }
L131: Button("About Causabee") {
L138: Button("Set Up Causabee …") { NotificationCenter.default.post(name: .showSetup, object: nil) }
L139: Button(DemoData.isRequested ? "Leave the Demo" : "Try the Demo") { DemoData.restart(demo: !DemoData.isRequested) }
L142: Button("Introduction to Causabee") { NotificationCenter.default.post(name: .showIntro, object: nil) }
L576: Button("Rename …") { newName = matter.name; renaming = matter }
L580: Button(other.name) { merging = (matter, other) }
L676: Button("") {
L683: Button {
L779: Button("Merge") {
L787: Button("Cancel", role: .cancel) { merging = nil }
L793: Button("Create") {
L797: Button("Cancel", role: .cancel) { }
L803: Button("Save") {
L808: Button("Cancel", role: .cancel) { renaming = nil }
// ... and 1 more matches
~~~

**Sources/Causabee/Theme\.swift**
~~~swift
L315: Button { choose(icon.symbol) } label: {
L321: Button("Let Causabee choose", systemImage: "sparkles") { choose(nil) }
L354: Button { choose(icon.symbol) } label: {
L370: Button("Let Causabee choose") { choose(nil) }
L581: Button {
L624: Button { voice.cancel() } label: {
L651: Button { voice.finish() } label: {
L690: Button("Not now") { withAnimation(.snappy) { voice.asksModel = false } }.quietButton()
L691: Button("Load") { Task { await Transcriber.shared.download() } }.filledButton()
L855: Button {
L876: Button(matter.name) { moved[offer.id] = matter.persistentModelID }
L880: Button("As suggested") { moved[offer.id] = nil }
L893: Button {
~~~

**Sources/Causabee/CloudSync\.swift**
~~~swift
L189: Picker("iCloud", selection: Binding(get: { CloudSync.available.map(\.rawValue).contains(mode) ? mode : CloudSync.Mode.off.rawValue },
L200: Button("Quit Causabee") { NSApp.terminate(nil) }
~~~

**Sources/Causabee/FolderSaver\.swift**
~~~swift
L63: Button("Choose folder …", action: choose)
L64: if !chosen.isEmpty, MatterFolders.drive != nil { Button("Use iCloud Drive") { chosen = "" } }
L70: Button("Open") { try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true); FolderSaver.reveal(root) }
L76: Button("Save all files now") { saver.save(matters) }.disabled(saver.busy != nil)
~~~

**Sources/Causabee/IntroView\.swift**
~~~swift
L70: Button("Skip") { finish() }
L85: Button("Back") { withAnimation(.easeOut(duration: 0.2)) { index -= 1 } }
L90: Button("Try the demo") { seen = true; DemoData.restart(demo: true) }
L93: Button(index == Self.pages.count - 1 ? "Get started" : "Next") { next() }
~~~

**Sources/Causabee/CardActions\.swift**
~~~swift
L568: Button { open?() } label: {
L613: Button("Write mail", systemImage: "envelope") { write(first) }
L614: Button("Copy address", systemImage: "doc.on.doc") { copy(first) }
L618: Button { write(item) } label: { Text(item.address); Text(item.note) }
L623: Button { copy(item) } label: { Text(item.address); Text(item.note) }
L695: Button("Copy") { copy() }.buttonStyle(.gold).font(.footnote.weight(.medium))
~~~

**Sources/Causabee/AssistantView\.swift**
~~~swift
L113: Button { withAnimation(.snappy(duration: 0.25)) { navigation.closeAssistant() } } label: {
L139: Button("Show earlier · \(shown.count - turns.count) more") { showsNewest += Self.page }
L207: Button { placement.button(newestID, with: scroller) } label: { ToNewestLabel(newAnswer: newAnswer) }
L411: Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain)
L434: Button { search = ""; showsRecent = false; navigation.open(hit.matter) } label: {
L450: Button { start(query) } label: {
L473: Button("") { searching = true }.keyboardShortcut("f", modifiers: .command).hidden()
L492: Button { withAnimation(.snappy(duration: 0.25)) { navigation.openAssistant() } } label: {
L614: Button(action: again) { Label("Try again", systemImage: "arrow.clockwise") }
L653: Button {
L665: Button {
L677: Button(action: again) {
L684: Button {
L698: Button {
L799: Button("Show again") { setDismissed(false) }.buttonStyle(.gold).font(.caption).fixedSize()
// ... and 9 more matches
~~~

**Sources/Causabee/Components\.swift**
~~~swift
L39: Button {
L108: Button {
L135: Button {
L257: Button(label) { NSWorkspace.shared.open(file) }
L263: Button(label) { NSWorkspace.shared.open(url) }
~~~

**Sources/CausabeePhone/PeopleAndLinks\.swift**
~~~swift
L59: Button("Merge") { if let (party, other) = merging { confirmSame(party, as: other) } }
L60: Button("Cancel", role: .cancel) { merging = nil }
L149: Button("Edit", systemImage: "pencil") { editing = true }
L152: Button(other.name) { merge(other) }
L156: Button("Remove", systemImage: "person.badge.minus", role: .destructive, action: remove)
L187: Button("Remove from this matter", role: .destructive) { dismiss(); remove() }
L195: ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
L197: Button("Save") {
L231: Button("Not the same") { refuse(suggestion) }.buttonStyle(.phone(wide: true))
L232: Button("Merge") { accept(suggestion) }.buttonStyle(.phone(filled: true, wide: true))
L300: Button(matter.linksSearchedAt == nil ? "Look for links in the mails" : "Look in the mails again", action: search)
L386: Button { if let url = link.url { openURL(url) } } label: {
L419: Button("Edit", systemImage: "pencil") { editing = true }
L421: Button("Remove", systemImage: "trash", role: .destructive, action: remove)
L452: Picker("For task", selection: $todo) {
// ... and 5 more matches
~~~

**Sources/CausabeePhone/PhoneFolder\.swift**
~~~swift
L55: Button(name == nil ? "Choose a folder …" : "Choose another …") { picks = true }
L60: if name != nil { Button("Use none", role: .destructive) { PhoneFolder.forget(); name = nil } }
~~~

**Sources/CausabeePhone/Welcome\.swift**
~~~swift
L41: .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { finish() } } }
L85: Button("Add …") { opensSettings = true }.buttonStyle(.phone)
L89: Button("Add …") { addsAccount = true }.buttonStyle(.phone)
L115: Button("Start") { finish() }.buttonStyle(.phone(filled: true, wide: true))
L117: Button("Open my matters") { finish() }.buttonStyle(.phone(filled: true, wide: true))
L118: Button("Try the demo") { finish(); store.switchDemo(true) }.buttonStyle(.phone(wide: true))
L120: Button("Try the demo") { finish(); store.switchDemo(true) }.buttonStyle(.phone(filled: true, wide: true))
L121: Button("Start with my matters") { finish() }.buttonStyle(.phone(wide: true))
~~~

**Sources/CausabeePhone/SettingsSheet\.swift**
~~~swift
L29: Button(accounts.isEmpty ? "Add mail account …" : "Change …") { addsAccount = true }
L35: Picker("Sort mail", selection: $mail) {
L42: Toggle("Fewer, real tasks", isOn: $strict)
L44: Toggle("Auto: read mail and files at once", isOn: $auto)
L55: Picker("Assistant", selection: $assistant) {
L114: .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
~~~

**Sources/CausabeePhone/Pad\.swift**
~~~swift
L44: Button { navigation.go([]) } label: {
L66: Button { withAnimation(.snappy(duration: 0.2)) { showsClosed.toggle() } } label: {
L124: Button(action: action) {
L141: Button {
~~~

**Sources/CausabeePhone/MatterScreen\.swift**
~~~swift
L217: Button { choosingIcon = true } label: { MatterIconTile(matter: matter, size: 32) }
L241: Button { startFinding() } label: { Image(systemName: "magnifyingglass") }
L249: Button {
L264: Button("Export as RTF", systemImage: "square.and.arrow.up", action: export)
L267: Button("Open again", systemImage: "arrow.uturn.backward") { matter.reopen(); try? context.save() }
L269: Button("Close", systemImage: "archivebox") { asksToClose = true }
L279: Button("OK") { exportFailure = nil }
L284: Button("Close") { close(markingOpenDone: false) }
L286: Button("Mark all done and close") { close(markingOpenDone: true) }
L287: Button("Leave them open and close") { close(markingOpenDone: false) }
L289: Button("Cancel", role: .cancel) {}
L349: Button { choosingIcon = true } label: { MatterIconTile(matter: matter, size: 36) }
L386: Button(action: find.previous) { Image(systemName: "chevron.up") }
L388: Button(action: find.next) { Image(systemName: "chevron.down") }
L390: Button("Done") { stopFinding() }.fontWeight(.semibold)
// ... and 44 more matches
~~~

**Sources/CausabeePhone/Scans\.swift**
~~~swift
L46: Button(file == nil ? "Scan with the camera" : "Scan again", systemImage: "doc.viewfinder") { scanning = true }
L48: Button(file == nil ? "Choose a PDF or a photo" : "Choose another file", systemImage: "folder") { picking = true }
L64: ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
L66: Button("Add", action: add).disabled(file == nil)
~~~

**Sources/CausabeePhone/WeekStrip\.swift**
~~~swift
L51: Button { withAnimation(.snappy) { showsEarlier.toggle() } } label: {
L75: Button { withAnimation(.snappy) { showsOverdue.toggle() } } label: {
L95: Button {
L116: return Button { chosen = day } label: {
L149: Button { navigation.open(thing.matter, showing: thing.todo?.persistentModelID) } label: {
L176: Button { navigation.open(next.thing.matter, showing: next.thing.todo?.persistentModelID) } label: {
~~~

**Sources/CausabeePhone/OverviewScreen\.swift**
~~~swift
L200: Button { navigation.open(matter) } label: {
L213: Button("Leave the demo") { store.switchDemo(false) }
L237: Button("Settings", systemImage: "gearshape") { editsAccount = true }
L238: Button("Introduction", systemImage: "info.circle") { showsWelcome = true }
L239: Button(store.isDemo ? "Leave the demo" : "Try the demo", systemImage: store.isDemo ? "arrow.uturn.backward" : "sparkles") { store.switchDemo(!store.isDemo) }
L268: Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
L285: Button { searching = false; navigation.open(matter) } label: {
L306: Button { search = ""; navigation.open(hit.matter) } label: {
L319: Button { start(query) } label: {
L348: Button("Try the demo") { store.switchDemo(true) }.buttonStyle(.phoneFilled)
~~~

**Sources/CausabeePhone/Parts\.swift**
~~~swift
L40: Button(action: run) { Label(action, systemImage: symbol) }.buttonStyle(.phoneFilled)
L122: Button {
L175: Button(action: action) { Label { Text("Ask Causabee") } icon: { Self.bee } }
L200: Button { open(todo.persistentModelID) } label: {
~~~

**Sources/CausabeePhone/PhoneShots\.swift**
~~~swift
L238: Button("Not now") { shots.remove(shot.id) }.buttonStyle(.phone)
L239: Button("Sort in") { shots.classify(shot.id, context: context, owner: profiles.first?.names ?? []) }.buttonStyle(.phoneFilled)
L249: Button("Not needed") { shots.remove(shot.id) }.buttonStyle(.phone)
L250: Button("Take in") { take(judgement) }.buttonStyle(.phoneFilled)
L258: Button("Open") { navigation.open(matter) }.buttonStyle(.phone)
L264: Button("Remove") { shots.remove(shot.id) }.buttonStyle(.phone)
L301: Button {
L323: Picker("Into", selection: $target) {
L362: Button("Photo or screenshot", systemImage: "photo") { picksPhoto = true }
L363: Button("File", systemImage: "doc") { picksFile = true }
L381: Button(title, systemImage: symbol) {
L390: Button(recent.name) { navigation.chosen(recent, for: plus) }
L393: Button("Another matter …", systemImage: "magnifyingglass") { navigation.choose(for: plus) }
L509: .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
L516: Button { navigation.chosen(matter, for: plus) } label: {
~~~

**Sources/CausabeePhone/PhoneMailCheck\.swift**
~~~swift
L447: Button(action: open) {
L481: Button("Cancel") { check.cancel() }.buttonStyle(.phone)
L523: Button { withAnimation(.easeOut(duration: 0.2)) { check.state = .idle } } label: {
L536: Button {
L577: Button(matter.name) {
L585: Button("Not needed") {
L629: Button {
L653: Button("Later", action: later).buttonStyle(.phone)
L655: Button(chosen.isEmpty ? "Leave out" : chosen.count == look.pending ? "Sort in" : "Sort in \(chosen.count)") { sortIn(chosen) }
L697: Button(chosen.isEmpty ? "Leave out" : chosen.count == offers.count ? "Take in" : "Take in \(chosen.count)") { take(chosen, moved, skipped) }
L717: Button { if on { chosen.remove(index) } else { chosen.insert(index) } } label: {
L733: Button("Later", action: later).buttonStyle(.phone)
L734: Button(chosen.count == DemoData.newMail.count ? "Sort in" : "Sort in \(chosen.count)") { sortIn(chosen) }
L754: Button {
L770: Button(matter.name) {
~~~

**Sources/CausabeePhone/MailFiles\.swift**
~~~swift
L98: Button(showsHidden ? "Hide the hidden ones" : "\(hidden.count) hidden · show") { showsHidden.toggle() }
L101: Button(showsSmallImages ? "Hide small images" : "Show small images") { showsSmallImages.toggle() }
L113: Button("Delete", role: .destructive) {
L117: Button("Cancel", role: .cancel) { deleting = nil }
L121: Button("Save") {
L129: Button("Cancel", role: .cancel) { renaming = nil }
L148: Button { open(document) } label: {
L185: Button("Name it from its content") { nameFromContent(document) }
L213: if !document.isOwnFile || document.source.fileURL != nil || MatterFolders.kept(document) != nil { Button("Open", systemImage: "eye") { open(document) } }
L214: if document.isReadable, !document.isOwnFile, document.readAt == nil { Button("Scan", systemImage: "text.viewfinder") { read(document) } }
L216: Button("Rename", systemImage: "pencil") { newName = document.shownName; renaming = document }
L217: if isPDF(document), !document.isOwnFile { Button("Name from content", systemImage: "text.magnifyingglass") { nameFromContent(document) } }
L219: Button("Use file name", systemImage: "arrow.uturn.backward") { document.title = nil; try? context.save() }
L221: Button(document.isHidden ? "Show again" : "Hide", systemImage: document.isHidden ? "eye" : "eye.slash") {
L228: Button("Delete …", systemImage: "trash", role: .destructive) { deleting = document }
// ... and 3 more matches
~~~

**Sources/CausabeePhone/AssistantSheet\.swift**
~~~swift
L154: Button { placement.button(newestID.map { AnyHashable($0) }, with: scroller) } label: {
L206: Button(action: send) { Label("Try again", systemImage: "arrow.clockwise") }
L222: Button { navigation.closeAssistant() } label: {
L250: Button { navigation.pinned = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary) }
L290: Button { if asking == nil { send() } else { stop() } } label: {
L583: Button {
L596: Button {
L609: Button { withAnimation(.snappy) { showsSources.toggle() } } label: {
L726: Button("Show again") { navigation.mark(record, card: index, dismissed: false, context: context) }
L774: Button("Cancel") { step { editingDraft = false } }.buttonStyle(.phone)
L775: Button("Open in Mail") { take() }.buttonStyle(.phoneFilled)
L779: if undo != nil { Button("Undo", action: takeBack).buttonStyle(.phone) }
L781: Button("Dismiss") { Haptics.tap(); withAnimation { navigation.mark(record, card: index, dismissed: true, context: context) } }
L783: Button(verb) { take() }.buttonStyle(.phone(filled: true, wide: true))
L806: Button("Undo", action: takeBack).font(.footnote.weight(.medium)).foregroundStyle(Theme.gold).buttonStyle(.plain)
// ... and 1 more matches
~~~

**Sources/CausabeePhone/History\.swift**
~~~swift
L116: Button("Cancel", role: .cancel) {}
L117: Button("Move") {
L132: Button(label(entry.source.kind), systemImage: entry.source.kind == .mail ? "envelope" : "arrow.up.forward.app") { openURL(url) }
L184: Button(matter.name, systemImage: "checkmark") { }.disabled(true)
L186: Button(matter.name) { Self.move(entry, to: matter, in: context) }
L190: Button("A new matter", systemImage: "plus.circle", action: newMatter)
~~~

**Sources/CausabeePhone/AllMatters\.swift**
~~~swift
L76: Button { navigation.open(matter) } label: {
L146: Button("Unpin", systemImage: "pin.slash") { matter.pinnedAt = nil; try? context.save() }
L148: Button("Pin to top", systemImage: "pin") {
L153: Button("Rename", systemImage: "pencil") { navigation.renaming = matter }
L158: Button(other.name) { navigation.merging = (matter, other) }
L177: Button(pinned.name) {
L184: Button("Cancel", role: .cancel) { navigation.pinning = nil }
L190: Button("Merge") {
L201: Button("Cancel", role: .cancel) { navigation.merging = nil }
L207: Button("Save") {
L212: Button("Cancel", role: .cancel) { navigation.renaming = nil }
~~~

### HIG Reference

1. **Clear current state.** Users must always see what is selected. Toggles show on/off, segmented controls highlight the active segment, pickers display the current selection.

2. **Prefer standard system controls.** Built-in controls provide consistency and accessibility. Custom controls introduce a learning curve and may break assistive features.

3. **Toggles for binary states.** On or off. In Settings-style screens, changes take effect immediately. In modal forms, changes commit on confirmation.

4. **Segmented controls for mutually exclusive options.** 2-5 items, roughly equal importance, short labels.

5. **Sliders for continuous values.** When precise numeric input is not critical. Provide min/max labels or icons for range endpoints.

6. **Pickers for long option lists.** Too many options for a segmented control. Works well for dates, times, structured data.

7. **Steppers for small, precise adjustments.** Increment/decrement in fixed steps. Display current value next to the stepper with reasonable min/max bounds.

8. **Text fields for short, single-line input.** Text views for multi-line. Configure keyboard type to match expected input (email, URL, number).

9. **Combo boxes: text input + selection list.** macOS. Type a value or choose from a predefined list when custom values are valid.

10. **Token fields: discrete values as visual tokens.** macOS. For email recipients, tags, or collections of discrete items.

11. **Gauges and rating indicators display values.** Gauges show a value within a range. Rating indicators show ratings (often stars). Display-only; use interactive variants for input.

### Evaluate

- Standard control usage (Button, Toggle, Picker, etc.)
- Proper button styles and roles
- Clear action labels and consistent interaction patterns

## Category: Interaction Patterns

*189 detections across 27 file(s) — 0 concern(s), 84 positive(s)*

### Code Excerpts

**Sources/Causabee/PageFind\.swift**
~~~swift
L152: withAnimation(Self.move) { open = true } completion: {
L153: withAnimation(.easeIn(duration: 0.1)) { shown = true }
L163: withAnimation(Self.move) { open = false }
L250: Button("Delete", systemImage: "trash", role: .destructive) { withAnimation { delete(); try? context.save() } }
L265: withAnimation { save(edited.trimmingCharacters(in: .whitespacesAndNewlines)); try? context.save() }
L282: Button("Delete", systemImage: "trash", role: .destructive) { withAnimation { delete(); try? context.save() } }
L293: withAnimation { draft = "" }
L565: Button("Delete", systemImage: "trash", role: .destructive) { withAnimation { context.delete(detail); try? context.save() } }
~~~

**Sources/Causabee/MailCheck\.swift**
~~~swift
L415: Button { withAnimation(.easeOut(duration: 0.2)) { check.state = .idle } } label: {
~~~

**Sources/Causabee/OverviewWeek\.swift**
~~~swift
L50: Button { withAnimation(.smooth(duration: 0.25)) { showsEarlier.toggle() } } label: {
L107: return Button { withAnimation(.smooth(duration: 0.3)) { chosen = day } } label: {
~~~

**Sources/Causabee/MatterStatusView\.swift**
~~~swift
L146: withAnimation(.easeOut(duration: 0.15)) { scrolledUnder = under }
L155: .onChange(of: find.current) { if let at = find.current { withAnimation { scroller.scrollTo(at, anchor: .center) } } }
L188: withAnimation { scroller.scrollTo(section, anchor: .top) }
L400: if !waiting { Button("Done") { withAnimation { toggle(todo) } }.fixedSize() }
L591: withAnimation { link.isSuggestion = false }
L594: withAnimation { link.isSuggestion = false; link.isDismissed = true }
L694: withAnimation { context.delete(link) }
L704: withAnimation { document.title = title }
L714: withAnimation { document.isHidden = hidden }
L803: DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation { scroller.scrollTo(todo, anchor: .center) } }
L804: DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { if marked == todo { marked = nil }; if find.shown == todo { find.shown = nil } } }
L1007: withAnimation(.easeOut(duration: 0.15)) { partsUnder = under && scrolledUnder }
L1117: withAnimation { todo.isInfo = isInfo }
L1215: withAnimation { membership.remove(in: context, origin: origin) }
L1235: withAnimation { membership.remove(in: context, origin: origin) }
// ... and 6 more matches
~~~

**Sources/Causabee/CausabeeApp\.swift**
~~~swift
L677: withAnimation(.snappy(duration: 0.25)) { if showsAssistant { navigation.closeAssistant() } else { navigation.openAssistant() } }
L684: withAnimation(.snappy(duration: 0.25)) { navigation.openAssistant() }
~~~

**Sources/Causabee/Theme\.swift**
~~~swift
L437: withAnimation(.snappy) { asksModel = true }
L449: withAnimation(.snappy) { phase = .listening }
L469: withAnimation(.snappy) { phase = .idle }
L473: withAnimation(.snappy) { phase = .writing }
L481: withAnimation(.snappy) { phase = .idle }
L488: withAnimation(.snappy) { phase = .idle }
L498: UIImpactFeedbackGenerator(style: .light).impactOccurred() // ✓ good
L690: Button("Not now") { withAnimation(.snappy) { voice.asksModel = false } }.quietButton()
L698: .onChange(of: state) { if state == .ready { Task { try? await Task.sleep(for: .seconds(1.5)); withAnimation(.snappy) { voice.asksModel = false } } } }
~~~

**Sources/Causabee/IntroView\.swift**
~~~swift
L79: .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { index = dot } }
L85: Button("Back") { withAnimation(.easeOut(duration: 0.2)) { index -= 1 } }
L123: withAnimation(.easeOut(duration: 0.2)) { index += 1 }
~~~

**Sources/Causabee/ThreadPlacement\.swift**
~~~swift
L136: withAnimation(Self.glide) { scroller.scrollTo(newest, anchor: .bottom) }
L183: withAnimation(Self.glide) { scroller.scrollTo(newest, anchor: anchor) }
L238: DispatchQueue.main.async { withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { landed = true } }
L255: .onAppear { if fresh { withAnimation(.easeIn(duration: 0.25)) { shown = true } } }
~~~

**Sources/Causabee/CardActions\.swift**
~~~swift
L723: UIImpactFeedbackGenerator(style: .light).impactOccurred() // ✓ good
L728: withAnimation(.easeOut(duration: 0.15)) { copied = true }
L731: withAnimation(.easeIn(duration: 0.2)) { copied = false }
~~~

**Sources/Causabee/AssistantView\.swift**
~~~swift
L113: Button { withAnimation(.snappy(duration: 0.25)) { navigation.closeAssistant() } } label: {
L492: Button { withAnimation(.snappy(duration: 0.25)) { navigation.openAssistant() } } label: {
L685: withAnimation(.easeOut(duration: 0.15)) { showsSources.toggle() }
L699: withAnimation(.easeOut(duration: 0.15)) { showsSent.toggle() }
L759: if reduceMotion { withAnimation(.easeInOut(duration: 0.2)) { change() }; return }
L760: withAnimation(.easeOut(duration: 0.14)) { showsContent = false } completion: {
L761: withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) { change() } completion: {
L762: withAnimation(.easeIn(duration: 0.16)) { showsContent = true }
L845: Button("Dismiss") { withAnimation { setDismissed(true) } }
~~~

**Sources/Causabee/Components\.swift**
~~~swift
L41: withAnimation(.easeInOut(duration: 0.25)) { navigation.sidebarHidden.toggle() }
L78: if hovering { withAnimation(.easeOut(duration: 0.1)) { shows = true } }
L109: withAnimation(.easeInOut(duration: 0.2)) { auto.toggle() }
L136: withAnimation(.easeInOut(duration: 0.2)) { navigation.reading.toggle() }
~~~

**Sources/CausabeePhone/PeopleAndLinks\.swift**
~~~swift
L46: withAnimation { membership.remove(in: context, origin: origin) }
L264: withAnimation { context.delete(link) }
L280: withAnimation { link.isSuggestion = false }
L283: withAnimation { link.isSuggestion = false; link.isDismissed = true }
~~~

**Sources/CausabeePhone/Navigation\.swift**
~~~swift
L85: if isPad { withAnimation(.snappy(duration: 0.25)) { showsAssistant = true } } else { showsAssistant = true }
L89: if isPad { withAnimation(.snappy(duration: 0.25)) { showsAssistant = false } } else { showsAssistant = false }
~~~

**Sources/CausabeePhone/Pad\.swift**
~~~swift
L66: Button { withAnimation(.snappy(duration: 0.2)) { showsClosed.toggle() } } label: {
L105: withAnimation(.easeInOut(duration: 0.2)) { navigation.reading.toggle() }
L142: withAnimation(.snappy(duration: 0.25)) { navigation.showsSidebar.toggle() }
~~~

**Sources/CausabeePhone/MatterScreen\.swift**
~~~swift
L163: .onChange(of: find.current) { if let at = find.current { withAnimation { scroller.scrollTo(at, anchor: .center) } } }
L250: withAnimation(.easeInOut(duration: 0.2)) { navigation.reading.toggle() }
L327: withAnimation { scroller.scrollTo(id, anchor: .center) }
L331: DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { withAnimation { marked = nil; if find.shown == id { find.shown = nil } } }
L398: withAnimation(.easeOut(duration: 0.2)) { finding = true }
L405: withAnimation(.easeOut(duration: 0.2)) { finding = false }
L579: if !waiting { Button("Done") { withAnimation { toggle(todo) } }.buttonStyle(.phone) }
L715: withAnimation { todo.isInfo = false }
L749: PhoneTodoRow(todo: todo, today: status.today, showsOwner: showsOwner, reminders: reminders, calendarTick: calendarTick) { withAnimation { toggle(todo) } }
L961: withAnimation { context.delete(link) }
L1102: withAnimation { context.delete(todo) }
L1121: withAnimation { todo.isInfo = true }
L1128: withAnimation { _ = todo.wait(for: other) }
L1137: withAnimation { todo.waitsFor = nil }
L1156: withAnimation { todo.note = rest }
~~~

**Sources/CausabeePhone/WeekStrip\.swift**
~~~swift
L51: Button { withAnimation(.snappy) { showsEarlier.toggle() } } label: {
L75: Button { withAnimation(.snappy) { showsOverdue.toggle() } } label: {
~~~

**Sources/CausabeePhone/OverviewScreen\.swift**
~~~swift
L42: withAnimation(.snappy(duration: 0.25)) { navigation.showsSidebar = !narrow }
L224: .refreshable { PhoneMailCheck.shared.look(context: context) }
~~~

**Sources/CausabeePhone/Parts\.swift**
~~~swift
L129: withAnimation(.easeOut(duration: 0.2)) { says = words }
L132: if says == words { withAnimation(.easeIn(duration: 0.25)) { says = nil } }
~~~

**Sources/CausabeePhone/Haptics\.swift**
~~~swift
L8: static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() } // ✓ good
L10: static func stop() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() } // ✓ good
L12: static func held() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() } // ✓ good
L14: static func landed() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() } // ✓ good
L16: static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) } // ✓ good
L18: static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) } // ✓ good
~~~

**Sources/CausabeePhone/PhoneMailCheck\.swift**
~~~swift
L523: Button { withAnimation(.easeOut(duration: 0.2)) { check.state = .idle } } label: {
~~~

**Sources/CausabeePhone/MailFiles\.swift**
~~~swift
L114: if let document = deleting { withAnimation { _ = matter.forget(document, besides: PhoneCloud.storeLocation(), in: context); try? context.save() } }
L222: withAnimation { document.isHidden.toggle() }
L274: withAnimation { document.title = title }
~~~

**Sources/CausabeePhone/AssistantSheet\.swift**
~~~swift
L609: Button { withAnimation(.snappy) { showsSources.toggle() } } label: {
L692: if reduceMotion { withAnimation(.easeInOut(duration: 0.2), change); return }
L693: withAnimation(.easeOut(duration: 0.14)) { showsContent = false } completion: {
L694: withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) { change() } completion: {
L695: withAnimation(.easeIn(duration: 0.16)) { showsContent = true }
L781: Button("Dismiss") { Haptics.tap(); withAnimation { navigation.mark(record, card: index, dismissed: true, context: context) } }
~~~

**Sources/CausabeePhone/History\.swift**
~~~swift
L205: withAnimation { try? from.move([entry], into: matter, in: context) }
~~~

**scripts/film/web/film\.html**
~~~html
L17: @keyframes head-in { from { opacity: 0; transform: translateY(24px); } to { opacity: 1; transform: none; } } // ✓ good
L21: @keyframes rise-in { from { opacity: 0; transform: translateY(32px); } to { opacity: 1; transform: none; } } // ✓ good
L22: @keyframes drop-out { from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(48px); } } // ✓ good
L25: @keyframes mail-in { from { opacity: 0; transform: translateY(-70px); } 70% { opacity: 1; transform: translateY(6px); } to { opacity: 1; transform: none; } } // ✓ good
L27: @keyframes settle { 0%, 100% { transform: none; } 40% { transform: translateY(8px); } } // ✓ good
L44: @keyframes inbox-up { from { transform: translateY(0); } to { transform: translateY(-300px); } } // ✓ good
L62: @keyframes gather { from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(var(--to)) scale(0.55); } } // ✓ good
L76: @keyframes faint-out { from { opacity: 0.4; transform: scale(0.96); } to { opacity: 0; transform: scale(0.96) translateY(48px); } } // ✓ good
L96: @keyframes bee-sort { 0% { opacity: 0.14; transform: translateY(-160px); } 18%, 62% { opacity: 1; transform: none; } 85%, 100% { opacity: 0.14; transform: none; } } // ✓ good
L99: @keyframes bee-hover { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-90px); } } // ✓ good
L151: @keyframes settle-in { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } } // ✓ good
L167: @keyframes fly-in { from { opacity: 0; transform: translateY(-20px); } to { opacity: 1; transform: none; } } // ✓ good
L168: @keyframes fly-into { from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(var(--dy)) scale(0.55); } } // ✓ good
L197: @keyframes stage9-in { from { opacity: 0; transform: translate(166px, 190px) scale(2); } to { opacity: 1; transform: translate(166px, 190px) scale(2); } } // ✓ good
L198: @keyframes stage9-land { from { transform: translate(166px, 190px) scale(2); } to { transform: translate(0, 0) scale(1); } } // ✓ good
// ... and 10 more matches
~~~

**scripts/film/web/film\-web\.html**
~~~html
L17: @keyframes head-in { from { opacity: 0; transform: translateY(24px); } to { opacity: 1; transform: none; } } // ✓ good
L21: @keyframes rise-in { from { opacity: 0; transform: translateY(32px); } to { opacity: 1; transform: none; } } // ✓ good
L22: @keyframes drop-out { from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(48px); } } // ✓ good
L25: @keyframes mail-in { from { opacity: 0; transform: translateY(-70px); } 70% { opacity: 1; transform: translateY(6px); } to { opacity: 1; transform: none; } } // ✓ good
L27: @keyframes settle { 0%, 100% { transform: none; } 40% { transform: translateY(8px); } } // ✓ good
L44: @keyframes inbox-up { from { transform: translateY(0); } to { transform: translateY(-300px); } } // ✓ good
L62: @keyframes gather { from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(var(--to)) scale(0.55); } } // ✓ good
L76: @keyframes faint-out { from { opacity: 0.4; transform: scale(0.96); } to { opacity: 0; transform: scale(0.96) translateY(48px); } } // ✓ good
L96: @keyframes bee-sort { 0% { opacity: 0.14; transform: translateY(-160px); } 18%, 62% { opacity: 1; transform: none; } 85%, 100% { opacity: 0.14; transform: none; } } // ✓ good
L99: @keyframes bee-hover { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-90px); } } // ✓ good
L151: @keyframes settle-in { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } } // ✓ good
L167: @keyframes fly-in { from { opacity: 0; transform: translateY(-20px); } to { opacity: 1; transform: none; } } // ✓ good
L168: @keyframes fly-into { from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(var(--dy)) scale(0.55); } } // ✓ good
L197: @keyframes stage9-in { from { opacity: 0; transform: translate(166px, 190px) scale(2); } to { opacity: 1; transform: translate(166px, 190px) scale(2); } } // ✓ good
L198: @keyframes stage9-land { from { transform: translate(166px, 190px) scale(2); } to { transform: translate(0, 0) scale(1); } } // ✓ good
// ... and 10 more matches
~~~

**scripts/film/web/test\.html**
~~~html
L4: @keyframes move{from{transform:translateX(0)}to{transform:translateX(300px)}} // ✓ good
~~~

**scripts/film/web/film\.src\.html**
~~~html
L17: @keyframes head-in { from { opacity: 0; transform: translateY(24px); } to { opacity: 1; transform: none; } } // ✓ good
L21: @keyframes rise-in { from { opacity: 0; transform: translateY(32px); } to { opacity: 1; transform: none; } } // ✓ good
L22: @keyframes drop-out { from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(48px); } } // ✓ good
L25: @keyframes mail-in { from { opacity: 0; transform: translateY(-70px); } 70% { opacity: 1; transform: translateY(6px); } to { opacity: 1; transform: none; } } // ✓ good
L27: @keyframes settle { 0%, 100% { transform: none; } 40% { transform: translateY(8px); } } // ✓ good
L44: @keyframes inbox-up { from { transform: translateY(0); } to { transform: translateY(-300px); } } // ✓ good
L62: @keyframes gather { from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(var(--to)) scale(0.55); } } // ✓ good
L76: @keyframes faint-out { from { opacity: 0.4; transform: scale(0.96); } to { opacity: 0; transform: scale(0.96) translateY(48px); } } // ✓ good
L96: @keyframes bee-sort { 0% { opacity: 0.14; transform: translateY(-160px); } 18%, 62% { opacity: 1; transform: none; } 85%, 100% { opacity: 0.14; transform: none; } } // ✓ good
L99: @keyframes bee-hover { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-90px); } } // ✓ good
L151: @keyframes settle-in { from { opacity: 0; transform: translateY(10px); } to { opacity: 1; transform: none; } } // ✓ good
L167: @keyframes fly-in { from { opacity: 0; transform: translateY(-20px); } to { opacity: 1; transform: none; } } // ✓ good
L168: @keyframes fly-into { from { opacity: 1; transform: none; } to { opacity: 0; transform: translateY(var(--dy)) scale(0.55); } } // ✓ good
L197: @keyframes stage9-in { from { opacity: 0; transform: translate(166px, 190px) scale(2); } to { opacity: 1; transform: translate(166px, 190px) scale(2); } } // ✓ good
L198: @keyframes stage9-land { from { transform: translate(166px, 190px) scale(2); } to { transform: translate(0, 0) scale(1); } } // ✓ good
// ... and 10 more matches
~~~

### HIG Reference

1. **Minimize modality.** Use modality only when it is critical to get attention, a task must be completed or abandoned, or saving changes is essential. Prefer non-modal alternatives.

2. **Provide clear feedback.** Every action should produce visible, audible, or haptic response. Activity indicators for indeterminate waits, progress bars for determinate, haptics for physical confirmation.

3. **Support undo over confirmation dialogs.** Destructive actions should be reversible when possible. Undo is almost always better than "Are you sure?"

4. **Launch quickly.** Display a launch screen that transitions seamlessly into the first screen. No splash screens with logos. Restore previous state.

5. **Defer sign-in.** Let users explore before requiring account creation. Support Sign in with Apple and passkeys.

6. **Keep onboarding brief.** Three screens max. Let users skip. Teach through progressive disclosure and contextual hints.

7. **Use progressive disclosure.** Show essentials first, let users drill into details. Don't overwhelm with every option on one screen.

8. **Respect user attention.** Consolidate notifications, minimize interruptions, give users control over alerts. Never use notifications for marketing.

### Evaluate

- Drag and drop support where appropriate
- Pull-to-refresh for refreshable content
- Swipe actions follow HIG conventions
- Undo support for destructive actions

## Category: Dialogs & Presentations

*63 detections across 12 file(s) — 0 concern(s), 0 positive(s)*

### Code Excerpts

**Sources/Causabee/PageFind\.swift**
~~~swift
L536: .sheet(isPresented: $adding) { DetailEditor(matter: matter) }
L537: .sheet(item: $editing) { DetailEditor(matter: matter, detail: $0) }
~~~

**Sources/Causabee/OverviewWeek\.swift**
~~~swift
L183: .popover(isPresented: isShown ? $showsOverdue : .constant(false), arrowEdge: .bottom) {
L321: .confirmationDialog("Pin “\(navigation.pinning?.name ?? "")” instead of …",
~~~

**Sources/Causabee/MatterStatusView\.swift**
~~~swift
L202: .sheet(isPresented: $addingContact) { ContactEditor(matter: matter) }
L203: .sheet(isPresented: $addingDetail) { DetailEditor(matter: matter) }
L209: .confirmationDialog(mergeQuestion, isPresented: Binding(get: { merging != nil }, set: { if !$0 { merging = nil } })) {
L217: .confirmationDialog(mergingMatter.map { "Merge “\($0.0.name)” into “\($0.1.name)”?" } ?? "",
L231: .alert("The matter could not be exported", isPresented: Binding(get: { exportFailure != nil }, set: { if !$0 { exportFailure = nil } })) {
L234: .confirmationDialog(closeQuestion, isPresented: $asksToClose) {
L567: .popover(isPresented: $addingLink, arrowEdge: .bottom) {
L854: .popover(isPresented: $splitting, arrowEdge: .bottom) { splitForm(status) }
L907: .popover(isPresented: $choosingIcon, arrowEdge: .bottom) { MatterIconPicker(matter: matter) }
L1025: .popover(isPresented: Binding(get: { newTodo != nil }, set: { if !$0 { dropNewTodo() } }), arrowEdge: .bottom) {
L1595: .popover(isPresented: $editing, arrowEdge: .bottom) {
L1610: .confirmationDialog("Delete “\(todo.text)”?", isPresented: $deleting) {
L1989: .popover(isPresented: $editing, arrowEdge: .bottom) {
L1999: .confirmationDialog("Delete “\(item.what)”?", isPresented: $deleting) {
L2158: .popover(isPresented: $editing, arrowEdge: .bottom) {
// ... and 4 more matches
~~~

**Sources/Causabee/CausabeeApp\.swift**
~~~swift
L771: .sheet(isPresented: $showsIntro, onDismiss: {
L774: .sheet(isPresented: $showsSetup) {
L778: .confirmationDialog(mergeQuestion, isPresented: Binding(get: { merging != nil }, set: { if !$0 { merging = nil } })) {
L791: .alert("New matter", isPresented: $startsMatter) {
L801: .alert("Rename matter", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
~~~

**Sources/CausabeePhone/PeopleAndLinks\.swift**
~~~swift
L25: .sheet(isPresented: $adding) { ContactEditor(matter: matter) }
L57: .confirmationDialog(mergeQuestion, isPresented: Binding(get: { merging != nil }, set: { if !$0 { merging = nil } }),
L139: .sheet(isPresented: $editing) {
L310: .sheet(isPresented: $adding) {
L406: .sheet(isPresented: $editing) {
~~~

**Sources/CausabeePhone/Welcome\.swift**
~~~swift
L42: .sheet(isPresented: $addsAccount, onDismiss: { tick += 1 }) { MailAccountSheet() }
L43: .sheet(isPresented: $opensSettings, onDismiss: { tick += 1 }) { SettingsSheet() }
~~~

**Sources/CausabeePhone/SettingsSheet\.swift**
~~~swift
L115: .sheet(isPresented: $addsAccount, onDismiss: { accounts = Keychain.accounts().filter { !$0.usesGoogle } }) { MailAccountSheet() }
~~~

**Sources/CausabeePhone/MatterScreen\.swift**
~~~swift
L190: .sheet(isPresented: $addingScan, onDismiss: { part = .record; filter = .files }) { ScanSheet(matter: matter) }
L191: .sheet(isPresented: $addingContact, onDismiss: { part = .people }) { ContactEditor(matter: matter) }
L192: .sheet(isPresented: $addingDetail, onDismiss: { part = .record; filter = .details }) { DetailEditor(matter: matter) }
L193: .sheet(isPresented: $addingLink, onDismiss: { part = .record; filter = .links }) {
L278: .alert("The matter could not be exported", isPresented: Binding(get: { exportFailure != nil }, set: { if !$0 { exportFailure = nil } })) {
L281: .sheet(item: $newTodo, onDismiss: dropEmptyTodos) { todo in PhoneTodoEditor(todo: todo, isNew: true) }
L282: .confirmationDialog(closeQuestion, isPresented: $asksToClose, titleVisibility: .visible) {
L362: .sheet(isPresented: $choosingIcon) {
L428: .alert("A new matter with the \(status.mailsSinceClosed.count) new \(status.mailsSinceClosed.count == 1 ? "mail" : "mails")", isPresented: $splitting) {
L1097: .sheet(isPresented: $editing) { PhoneTodoEditor(todo: todo) }
L1098: .confirmationDialog("Delete “\(todo.text)”?", isPresented: $deleting, titleVisibility: .visible) {
L1403: .sheet(isPresented: $editing) { PhoneDateEditor(item: item) }
L1404: .confirmationDialog("Delete “\(item.what)”?", isPresented: $deleting, titleVisibility: .visible) {
~~~

**Sources/CausabeePhone/OverviewScreen\.swift**
~~~swift
L73: .sheet(item: $navigation.choosingInAssistant) { plus in MatterChooser(plus: plus) }
L111: .sheet(isPresented: Binding(get: { navigation.showsAssistant && !navigation.isPad }, set: { navigation.showsAssistant = $0 })) {
L117: .sheet(item: $navigation.choosingInAssistant) { plus in MatterChooser(plus: plus) }
L120: .sheet(item: $navigation.choosing) { plus in MatterChooser(plus: plus) }
L245: .sheet(isPresented: $editsAccount) { SettingsSheet() }
L247: .sheet(isPresented: $showsWelcome) { WelcomeSheet() }
~~~

**Sources/CausabeePhone/MailFiles\.swift**
~~~swift
L109: .sheet(isPresented: $addsAccount) { MailAccountSheet() }
L110: .sheet(isPresented: $addsScan) { ScanSheet(matter: matter) }
L111: .confirmationDialog(deleting.map { "Delete “\($0.shownName)”?" } ?? "", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
L119: .alert("Rename file", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
~~~

**Sources/CausabeePhone/History\.swift**
~~~swift
L114: .alert("Move to a new matter", isPresented: $naming) {
~~~

**Sources/CausabeePhone/AllMatters\.swift**
~~~swift
L174: .confirmationDialog("Pin “\(navigation.pinning?.name ?? "")” instead of …", isPresented: Binding(get: { navigation.pinning != nil }, set: { if !$0 { navigation.pinning = nil } }),
L188: .confirmationDialog(mergeQuestion, isPresented: Binding(get: { navigation.merging != nil }, set: { if !$0 { navigation.merging = nil } }),
L205: .alert("Rename matter", isPresented: Binding(get: { navigation.renaming != nil }, set: { if !$0 { navigation.renaming = nil } })) {
~~~

### HIG Reference

1. **Alerts: sparingly, for critical situations.** Errors needing attention, destructive action confirmations, or information requiring acknowledgment. They interrupt flow and demand a response.

2. **Sheets: focused tasks that maintain context.** Slides in from the edge (or attaches to a window on macOS). Use for creating items, editing settings, multi-step forms.

3. **Popovers: non-modal on iPad and Mac.** Appear next to the trigger element, dismissed by tapping outside. For additional information, options, or controls without taking over the screen.

4. **Action sheets: choosing among actions.** Present when picking from multiple actions, especially if one is destructive. iPhone: slide up from bottom. iPad: appear as popovers.

5. **Minimize interruptions.** Before reaching for a modal, consider inline presentation or making the action undoable instead.

6. **Concise, actionable alert text.** Short descriptive title. Brief message body if needed. Button labels should be specific verbs ("Delete", "Save"), not "OK".

7. **Mark destructive actions clearly.** Destructive button style (red text). Place destructive buttons where users are less likely to tap reflexively.

8. **Provide a cancel option** for alerts and action sheets with multiple actions. On action sheets, cancel appears at the bottom, separated.

9. **Digit entry: focused and accessible.** Appropriately sized input fields, automatic advancement between digits, support for paste and autofill.

10. **Adapt presentation to platform.** The same interaction may use different components on iPhone, iPad, Mac, and visionOS.

### Evaluate

- Alerts used sparingly for important decisions
- Sheets for focused tasks, popovers for contextual info
- Confirmation dialogs for destructive actions

## Category: Menus & Actions

*55 detections across 20 file(s) — 0 concern(s), 0 positive(s)*

### Code Excerpts

**Sources/CausabeeShare/ShareViewController\.swift**
~~~swift
L167: .toolbar {
~~~

**Sources/Causabee/PageFind\.swift**
~~~swift
L245: Menu {
L278: .contextMenu {
L369: .toolbar {
L441: .toolbar {
L557: .contextMenu {
~~~

**Sources/Causabee/Conversation\.swift**
~~~swift
L426: Menu {
~~~

**Sources/Causabee/OverviewWeek\.swift**
~~~swift
L267: .contextMenu { PinMenuItem(matter: matter, all: all) }
~~~

**Sources/Causabee/MatterStatusView\.swift**
~~~swift
L944: Menu {
L1225: .contextMenu {
L1308: Menu {
L1603: .contextMenu { moreItems }
L1727: Menu {
L1908: .contextMenu {
L1998: .contextMenu { moreItems }
L2357: .contextMenu { items }
L2458: .contextMenu { moreItems }
~~~

**Sources/Causabee/CalendarChip\.swift**
~~~swift
L46: .contextMenu { Button("Open in \(where_)") { open(id) }; Button("Disconnect") { connect(nil) } }
~~~

**Sources/Causabee/CausabeeApp\.swift**
~~~swift
L574: .contextMenu {
L987: NotificationCenter.default.addObserver(forName: NSMenu.didAddItemNotification, object: nil, queue: .main) { note in
L989: let added = (note.object as? NSMenu).map(ObjectIdentifier.init)
~~~

**Sources/Causabee/AssistantView\.swift**
~~~swift
L560: .contextMenu { PinMenuItem(matter: matter, all: matters) }
~~~

**Sources/Causabee/Components\.swift**
~~~swift
L223: Menu { items } label: { Image(systemName: "ellipsis") }
~~~

**Sources/CausabeePhone/PeopleAndLinks\.swift**
~~~swift
L126: Menu { items } label: {
L137: .contextMenu { items }
L194: .toolbar {
L394: Menu { items } label: {
L404: .contextMenu { items }
L462: .toolbar {
~~~

**Sources/CausabeePhone/Welcome\.swift**
~~~swift
L41: .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { finish() } } }
~~~

**Sources/CausabeePhone/SettingsSheet\.swift**
~~~swift
L114: .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
~~~

**Sources/CausabeePhone/MatterScreen\.swift**
~~~swift
L207: .toolbar {
L261: Menu {
L849: Menu {
L1086: Menu { moreItems } label: {
L1096: .contextMenu { moreItems }
L1257: .toolbar {
L1390: Menu { moreItems } label: {
L1402: .contextMenu { moreItems }
L1456: .toolbar {
~~~

**Sources/CausabeePhone/Scans\.swift**
~~~swift
L63: .toolbar {
~~~

**Sources/CausabeePhone/OverviewScreen\.swift**
~~~swift
L178: .contextMenu { MatterMenuItems(matter: matter, all: sidebarOrder(matters)) }
L234: .toolbar {
L236: Menu {
~~~

**Sources/CausabeePhone/Parts\.swift**
~~~swift
L86: Menu {
~~~

**Sources/CausabeePhone/PhoneShots\.swift**
~~~swift
L388: Menu {
L460: Menu {
L509: .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
~~~

**Sources/CausabeePhone/MailFiles\.swift**
~~~swift
L175: Menu { items(document) } label: {
L199: .contextMenu { items(document) }
L342: .toolbar {
~~~

**Sources/CausabeePhone/History\.swift**
~~~swift
L89: Menu { items(entry) } label: {
L113: .contextMenu { items(entry) }
L181: Menu {
~~~

**Sources/CausabeePhone/AllMatters\.swift**
~~~swift
L87: .contextMenu { MatterMenuItems(matter: matter, all: all) }
~~~

### HIG Reference

1. **Menus should be contextual and predictable.** Standard items in standard locations. Follow platform conventions for ordering and grouping.

2. **Use standard button styles.** System-defined styles communicate affordance and maintain visual consistency. Prefer them over custom designs.

3. **Toolbars for frequent actions.** Most commonly used commands in the toolbar. Rarely used actions belong in menus.

4. **Menu bar is the primary command interface on macOS.** Every command reachable from the menu bar. Toolbars and context menus supplement, not replace.

5. **Context menus for secondary actions.** Right-click or long-press, relevant to the item under the pointer. Never put a command only in a context menu.

6. **Pop-up buttons for mutually exclusive choices.** Select exactly one option from a set.

7. **Pull-down buttons for action lists.** No current selection; they offer a set of commands.

8. **Action buttons consolidate related actions** behind a single icon in toolbars or title bars.

9. **Disclosure controls for progressive disclosure.** Show or hide additional content.

10. **Dock menus: short and focused** on the most useful actions when the app is running.

### Evaluate

- Context menus provide relevant actions
- Menu organization follows HIG grouping conventions

## Category: Apple Technologies

*54 detections across 54 file(s) — 0 concern(s), 0 positive(s)*

### Code Excerpts

**Sources/MatterSpike/main\.swift**
~~~swift
L4: import SwiftData
~~~

**Sources/Causabee/PageFind\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/Causabee/Conversation\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/Causabee/MirrorRunner\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/Causabee/DemoData\.swift**
~~~swift
L6: import SwiftData
~~~

**Sources/Causabee/MailCheck\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/Causabee/IntroShot\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/Causabee/OverviewWeek\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/Causabee/SetupAssistant\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/Causabee/ModelChoice\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/Causabee/MatterStatusView\.swift**
~~~swift
L5: import SwiftData
~~~

**Sources/Causabee/NameListPublisher\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/Causabee/ShotView\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/Causabee/CausabeeApp\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/Causabee/Theme\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/Causabee/CloudSync\.swift**
~~~swift
L4: import SwiftData
~~~

**Sources/Causabee/FolderSaver\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/Causabee/CardActions\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/Causabee/AssistantView\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/CausabeePhone/PeopleAndLinks\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/Navigation\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/CausabeePhone/Welcome\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/SettingsSheet\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/Pad\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/MatterScreen\.swift**
~~~swift
L4: import SwiftData
~~~

**Sources/CausabeePhone/Scans\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/CausabeePhone/WeekStrip\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/OverviewScreen\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/PhoneApp\.swift**
~~~swift
L4: import SwiftData
~~~

**Sources/CausabeePhone/Parts\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/PhoneShots\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/CausabeePhone/PhoneMailCheck\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/MailFiles\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/CausabeePhone/AssistantSheet\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/PhoneFolderSaver\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/CausabeePhone/History\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/SharedIn\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/CausabeePhone/AllMatters\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/MatterBench/Bench\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/MatterBench/main\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/MatterCore/MatterFolders\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/MatterCore/Model/PartyBook\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/MatterCore/Model/VaultOffers\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/MatterCore/Model/MatterStatus\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/MatterCore/Model/MatterImport\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/MatterCore/Model/SortedMails\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/MatterCore/Model/NameLists\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/MatterCore/Model/Unplaced\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/MatterCore/Model/Models\.swift**
~~~swift
L2: import SwiftData
~~~

**Sources/MatterCore/Model/NextStep\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/MatterCore/Model/Assistant\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/MatterCore/Mirror\.swift**
~~~swift
L3: import SwiftData
~~~

**Sources/MatterCore/Digests\.swift**
~~~swift
L4: import SwiftData
~~~

**Sources/MatterCore/MailLinks\.swift**
~~~swift
L2: import SwiftData
~~~

### HIG Reference

1. **Apple technologies extend app capabilities through system integration.** Each technology has established user-facing patterns; deviating creates confusion and erodes trust.

2. **Privacy and user control are paramount.** Especially for health, payment, and identity technologies. Request only needed data, explain why, respect choices.

3. **Siri: natural, predictable, recoverable.** Clear conversational intent phrases that complete quickly and confirm results. Support App Shortcuts for proactive suggestions. Handle errors with clear fallbacks.

4. **Payments: transparent and frictionless.** Standard Apple Pay button styles. Never ask for card details when Apple Pay is available. Clearly describe what the user is buying, the price, and whether it's one-time or subscription.

5. **Health data is deeply personal.** Explain the health benefit before requesting access. CareKit tasks should be encouraging. ResearchKit consent flows must be thorough, readable, and respect autonomy.

6. **HomeKit: simple and reliable.** Immediate response when controlling devices. Clear device state. Graceful handling of connectivity issues.

7. **AR: genuine value, not gimmicks.** Use AR when spatial context improves understanding. Guide setup (surface, lighting, space). Provide clear exit back to standard interaction.

8. **ML and generative AI: enhance without surprising.** Smart suggestions, image recognition, text prediction. Clearly attribute AI-generated content. Controls to edit, regenerate, or dismiss. Let users correct mistakes.

9. **Sign in with Apple as top option.** Standard button styles. Respect email hiding preference. ID Verifier: guided flows, don't store sensitive data beyond what verification requires.

10. **iCloud: invisible and reliable sync.** Data appears on all devices without manual intervention. Handle conflicts gracefully. Never lose data.

11. **SharePlay: real-time participation.** Support multiple participants, show presence, handle latency. AirPlay: appropriate Now Playing metadata.

12. **CarPlay: driver safety first.** Minimize interaction complexity, large touch targets, no distracting content. Only permitted app types: audio, messaging, EV charging, navigation, parking, quick food ordering.

13. **Accessibility is a baseline requirement.** Every element has a meaningful VoiceOver label, trait, and action. Support Dynamic Type, Switch Control, and other assistive technologies. Test entirely with VoiceOver enabled.

### Evaluate

- Apple framework integration follows HIG for that technology
- Proper permission handling and progressive disclosure

## Category: Input Methods

*52 detections across 15 file(s) — 0 concern(s), 0 positive(s)*

### Code Excerpts

**Sources/Causabee/PageFind\.swift**
~~~swift
L96: @FocusState private var focused: Bool
L146: Button("", action: start).keyboardShortcut("f", modifiers: .command).hidden()
L179: @FocusState private var focused: Bool
L385: Button("Cancel") { dismiss() }.quietButton().keyboardShortcut(.cancelAction)
L386: Button("Add", action: add).filledButton().keyboardShortcut(.defaultAction).disabled(!canAdd)
L457: Button("Cancel") { dismiss() }.quietButton().keyboardShortcut(.cancelAction)
L458: Button(detail == nil ? "Add" : "Save", action: save).filledButton().keyboardShortcut(.defaultAction).disabled(!canSave)
~~~

**Sources/Causabee/Conversation\.swift**
~~~swift
L485: .keyboardShortcut(stop == nil ? KeyboardShortcut(.return, modifiers: .command) : KeyboardShortcut(".", modifiers: .command))
~~~

**Sources/Causabee/SetupAssistant\.swift**
~~~swift
L205: .keyboardShortcut(.defaultAction)
L209: .keyboardShortcut(.defaultAction)
~~~

**Sources/Causabee/MatterStatusView\.swift**
~~~swift
L56: @FocusState private var naming: Bool
L875: .keyboardShortcut(.defaultAction)
L926: Button("Save", action: rename).keyboardShortcut(.defaultAction)
L931: .onTapGesture(perform: startRenaming)
L1222: .onTapGesture { person = party.persistentModelID; filter = .all; part = .record }
L1701: @FocusState private var focus: Field?
L1754: Button("Cancel", action: cancel).keyboardShortcut(.cancelAction)
L1755: Button(isNew ? "Add" : "Save", action: save).keyboardShortcut(.defaultAction).inkButton()
L2058: .keyboardShortcut(.defaultAction)
L2182: .keyboardShortcut(.defaultAction)
L2454: .onTapGesture(perform: open)
L2505: Button("Save", action: saveName).keyboardShortcut(.defaultAction)
L2615: .keyboardShortcut(.defaultAction)
~~~

**Sources/Causabee/ShotView\.swift**
~~~swift
L74: .onTapGesture { NSWorkspace.shared.open(shot.file) }
L79: .onTapGesture { NSWorkspace.shared.open(shot.file) }
~~~

**Sources/Causabee/CausabeeApp\.swift**
~~~swift
L126: .keyboardShortcut("n", modifiers: .command)
L679: .keyboardShortcut("k", modifiers: .command).hidden()
L939: if action == .newTask { item(action.title, action).keyboardShortcut("t", modifiers: [.command, .shift]) } else { item(action.title, action) }
~~~

**Sources/Causabee/Theme\.swift**
~~~swift
L628: .keyboardShortcut(.cancelAction)
L656: .keyboardShortcut(.defaultAction)
~~~

**Sources/Causabee/IntroView\.swift**
~~~swift
L79: .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { index = dot } }
L86: .keyboardShortcut(.leftArrow, modifiers: [])
L95: .keyboardShortcut(.defaultAction)
~~~

**Sources/Causabee/AssistantView\.swift**
~~~swift
L44: @FocusState private var focused: Bool
L367: @FocusState private var searching: Bool
L419: .onTapGesture { searching = true; showsRecent = true }
L425: Color.clear.contentShape(Capsule()).onTapGesture { searching = true; showsRecent = true }
L473: Button("") { searching = true }.keyboardShortcut("f", modifiers: .command).hidden()
L532: .onTapGesture { navigation.open(matter) }
L883: .onTapGesture(perform: openTaken)
L942: .onTapGesture { apply(text, subject) }
L1067: .onTapGesture(perform: open)
~~~

**Sources/Causabee/Components\.swift**
~~~swift
L26: .onTapGesture(perform: open)
~~~

**Sources/CausabeePhone/PeopleAndLinks\.swift**
~~~swift
L51: .onTapGesture { choose?(party) }
~~~

**Sources/CausabeePhone/MatterScreen\.swift**
~~~swift
L26: @FocusState private var findFocused: Bool
L121: Color.clear.contentShape(Rectangle()).onTapGesture {
~~~

**Sources/CausabeePhone/OverviewScreen\.swift**
~~~swift
L142: @FocusState private var searching: Bool
~~~

**Sources/CausabeePhone/Parts\.swift**
~~~swift
L217: .onTapGesture { open(nil) }
~~~

**Sources/CausabeePhone/AssistantSheet\.swift**
~~~swift
L23: @FocusState private var typing: Bool
L26: @FocusState private var keepsKeyboard: Bool
L815: .onTapGesture(perform: openTaken)
L886: .onTapGesture { take() }
~~~

### HIG Reference

1. **Support multiple input methods.** Touch, pointer, keyboard, pencil, voice, eyes, hands, controllers. Design for the inputs available on each platform. On iPadOS, support both touch and pointer; on macOS, both pointer and keyboard.

2. **Consistent feedback for every input action.** Visible, audible, or haptic response.

3. **Standard gestures must behave consistently.** Tap to activate, swipe to scroll/navigate, pinch to zoom, long press for context menus, drag to move. Don't override system gestures (edge swipes for back, Home, notifications).

4. **Use standard recognizers; keep custom gestures discoverable.** Apple's built-in recognizers handle edge cases and accessibility. If you add non-standard gestures, provide hints or coaching to teach them.

5. **Apple Pencil: precision drawing, markup, and selection.** Support pressure, tilt, and hover. Distinguish finger from Pencil when appropriate (finger pans, Pencil draws).

6. **Support Scribble in text fields.** Users expect to write with Pencil in any text input.

7. **Keyboard shortcuts and full navigation.** Standard shortcuts (Cmd+C/V/Z) plus custom ones visible in the iPadOS Command key overlay. Logical tab order.

8. **Respect the software keyboard.** Adjust layout when keyboard appears. Use keyboard-avoidance APIs.

9. **Game controllers: MFi controllers with on-screen fallbacks.** Map to extended gamepad profile, sensible defaults, remappable. Always offer touch or keyboard alternatives.

10. **Pointer and trackpad: native feel.** Hover effects, pointer shape adaptation, standard cursor behaviors. Two-finger scroll, pinch to zoom, swipe to navigate.

11. **Digital Crown: primary scrolling and value-adjustment input on watchOS.** Scrolling lists, adjusting values, navigating views. Haptic feedback at detents.

12. **Eyes and spatial (visionOS): look and pinch.** Generous hit targets (eye tracking is less precise than touch). Avoid sustained gaze for activation. Direct hand manipulation in immersive experiences.

13. **Focus system: critical for tvOS and visionOS.** Predictable focus movement. Every interactive element focusable. Clear visual indicators (scale, highlight, elevation). Logical focus groups.

14. **Siri Remote: limited surface.** Touch area for swiping, clickpad for selection, few physical buttons. Keep interactions simple.

15. **Gyroscope, accelerometer, UWB: use judiciously.** Suits gaming, fitness, AR. Not for essential tasks. Provide calibration and reset. For UWB, communicate distance and direction with visual or haptic cues.

### Evaluate

- Text input uses appropriate field types
- Keyboard shortcuts for power users (macOS/iPad)
- Gesture usage follows platform conventions

## Category: Platform Adaptation

*44 detections across 11 file(s) — 0 concern(s), 44 positive(s)*

### Code Excerpts

**Sources/Causabee/PageFind\.swift**
~~~swift
L88: #if os(macOS) // ✓ good
L183: #if os(iOS) // ✓ good
L201: #if os(macOS) // ✓ good
L326: #if os(macOS) // ✓ good
L352: #if os(iOS) // ✓ good
L425: #if os(iOS) // ✓ good
L501: #if os(iOS) // ✓ good
L514: #if os(macOS) // ✓ good
L570: #if os(macOS) // ✓ good
~~~

**Sources/Causabee/DemoData\.swift**
~~~swift
L29: #if os(macOS) // ✓ good
~~~

**Sources/Causabee/TextSize\.swift**
~~~swift
L3: #if os(macOS) // ✓ good
~~~

**Sources/Causabee/AskSteps\.swift**
~~~swift
L12: #if os(iOS) // ✓ good
~~~

**Sources/Causabee/ModelChoice\.swift**
~~~swift
L28: #if os(iOS) // ✓ good
L38: #if os(macOS) // ✓ good
~~~

**Sources/Causabee/CalendarChip\.swift**
~~~swift
L142: #if os(iOS) // ✓ good
L165: #if os(iOS) // ✓ good
L195: #if os(iOS) // ✓ good
~~~

**Sources/Causabee/Theme\.swift**
~~~swift
L56: #if os(macOS) // ✓ good
L339: #if os(iOS) // ✓ good
L347: #if os(iOS) // ✓ good
L376: #if os(iOS) // ✓ good
L381: #if os(iOS) // ✓ good
L385: #if os(iOS) // ✓ good
L497: #if os(iOS) // ✓ good
L528: #if os(macOS) // ✓ good
L593: #if os(iOS) // ✓ good
L671: #if os(iOS) // ✓ good
L734: #if os(iOS) // ✓ good
L743: #if os(iOS) // ✓ good
L751: #if os(iOS) // ✓ good
L883: #if os(macOS) // ✓ good
L951: #if os(macOS) // ✓ good
~~~

**Sources/Causabee/CardActions\.swift**
~~~swift
L149: #if os(iOS) // ✓ good
L536: #if os(iOS) // ✓ good
L563: #if os(iOS) // ✓ good
L636: #if os(macOS) // ✓ good
L721: #if os(iOS) // ✓ good
~~~

**Sources/MatterCore/MatterFolders\.swift**
~~~swift
L11: #if os(iOS) // ✓ good
L45: #if os(macOS) // ✓ good
~~~

**Sources/MatterCore/Keychain\.swift**
~~~swift
L108: #if os(iOS) // ✓ good
L180: #if os(iOS) // ✓ good
L193: #if os(macOS) // ✓ good
~~~

**Sources/MatterCore/Voice/Voice\.swift**
~~~swift
L183: #if os(macOS) // ✓ good
L232: #if os(iOS) // ✓ good
~~~

### HIG Reference

1. **Each platform has a distinct identity.** Do not port designs between platforms. Respect each platform's conventions, interaction models, and user expectations.

2. **iOS: touch-first.** Direct manipulation on a handheld screen. Optimize for one-handed use. Navigation uses tab bars and push/pop stacks.

3. **iPadOS: expanded canvas.** Support Split View, Slide Over, and Stage Manager. Use sidebars and multi-column layouts. Support pointer and keyboard alongside touch.

4. **macOS: pointer and keyboard.** Dense information display is acceptable. Use menu bars, toolbars, and keyboard shortcuts extensively. Windows are resizable with precise control.

5. **tvOS: remote and focus.** Viewed from a distance. Design for the Siri Remote with focus-based navigation. Large text, simple layouts, linear navigation.

6. **visionOS: spatial interaction.** 3D environment using windows, volumes, and spaces. Eye tracking for targeting, indirect gestures for interaction. Respect ergonomic comfort zones.

7. **watchOS: glanceable and brief.** Information consumable at a glance. Brief interactions. Digital Crown, haptics, and complications for timely content.

8. **Games: own paradigm.** Free to define in-game interaction models, but still respect platform conventions for system interactions (notifications, accessibility, controllers).

### Evaluate

- UI adapts appropriately across target platforms
- Platform idioms respected (iPhone vs iPad vs Mac)

## Category: Layout & Navigation

*40 detections across 23 file(s) — 0 concern(s), 1 positive(s)*

### Code Excerpts

**scripts/film/render\.swift**
~~~swift
L19: let window = NSWindow(contentRect: web.frame, styleMask: .borderless, backing: .buffered, defer: false)
~~~

**Sources/CausabeeShare/ShareViewController\.swift**
~~~swift
L141: NavigationStack {
L142: ScrollView {
~~~

**Sources/Causabee/PageFind\.swift**
~~~swift
L353: NavigationStack {
L426: NavigationStack {
~~~

**Sources/Causabee/MailCheck\.swift**
~~~swift
L490: ScrollView {
L564: ScrollView { MailOffers(offers: offers, chosen: $chosen, moved: $moved, skipped: $skipped, small: true) }
~~~

**Sources/Causabee/IntroShot\.swift**
~~~swift
L95: let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
L142: let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
~~~

**Sources/Causabee/OverviewWeek\.swift**
~~~swift
L256: LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
L256: LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) { // ✓ good
~~~

**Sources/Causabee/SetupAssistant\.swift**
~~~swift
L115: ScrollView {
~~~

**Sources/Causabee/MatterStatusView\.swift**
~~~swift
L94: ScrollView {
~~~

**Sources/Causabee/ShotView\.swift**
~~~swift
L178: ScrollView {
~~~

**Sources/Causabee/CausabeeApp\.swift**
~~~swift
L590: List {
L635: GeometryReader { geometry in
~~~

**Sources/Causabee/Theme\.swift**
~~~swift
L352: LazyVGrid(columns: Array(repeating: GridItem(.fixed(tile), spacing: gap), count: 6), spacing: gap) {
~~~

**Sources/Causabee/AssistantView\.swift**
~~~swift
L128: ScrollView {
L480: ScrollView {
L557: LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
L717: ScrollView {
~~~

**Sources/Causabee/Components\.swift**
~~~swift
L175: let toolbar = NSToolbar(identifier: "causabee.window")
~~~

**Sources/CausabeePhone/PeopleAndLinks\.swift**
~~~swift
L174: NavigationStack {
L438: NavigationStack {
~~~

**Sources/CausabeePhone/Welcome\.swift**
~~~swift
L22: NavigationStack {
L23: ScrollView {
~~~

**Sources/CausabeePhone/SettingsSheet\.swift**
~~~swift
L24: NavigationStack {
~~~

**Sources/CausabeePhone/Pad\.swift**
~~~swift
L42: ScrollView {
~~~

**Sources/CausabeePhone/MatterScreen\.swift**
~~~swift
L69: ScrollView {
L1203: NavigationStack {
L1443: NavigationStack {
~~~

**Sources/CausabeePhone/Scans\.swift**
~~~swift
L38: NavigationStack {
~~~

**Sources/CausabeePhone/OverviewScreen\.swift**
~~~swift
L66: NavigationStack {
L81: return NavigationStack(path: $navigation.path) {
L155: ScrollView {
L174: LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: columns), alignment: .leading, spacing: 12) {
~~~

**Sources/CausabeePhone/PhoneShots\.swift**
~~~swift
L501: NavigationStack {
L502: List {
~~~

**Sources/CausabeePhone/MailFiles\.swift**
~~~swift
L304: NavigationStack {
~~~

**Sources/CausabeePhone/AssistantSheet\.swift**
~~~swift
L98: ScrollView {
~~~

### HIG Reference

1. **Organize hierarchically.** Structure information from broad categories to specific details. Sidebars for top-level sections, lists for browsable items, detail views for individual content.

2. **Use standard navigation patterns.** Tab bars for flat navigation between peer sections (iPhone). Sidebars for deep hierarchical navigation (iPad, Mac). Match the pattern to the information architecture and platform.

3. **Adapt to screen size.** Three-column on iPad collapses to single-column on iPhone. Use size classes and adaptive APIs (NavigationSplitView) for automatic adaptation.

4. **Support multitasking on iPad.** Respond gracefully to Split View, Slide Over, and Stage Manager. Test at every split ratio and size class transition.

5. **Maintain spatial consistency on visionOS.** Windows, volumes, and ornaments in shared space. Position predictably. Use ornaments for toolbars and controls without occluding content.

6. **Use scroll views for overflow content.** Enable paging for discrete content units. Support pull-to-refresh where appropriate. Respect safe areas.

7. **Keep navigation predictable.** Users should always know where they are, how they got there, and how to go back. Use back buttons, breadcrumbs, and clear section titles.

8. **Prefer system components.** UINavigationController, UISplitViewController, NavigationSplitView, and TabView provide built-in adaptivity, accessibility, and state restoration.

### Evaluate

- Navigation pattern matches app structure (tabs for flat, sidebar for deep)
- Adaptive layout: responds to size classes, multitasking
- Standard navigation components (NavigationSplitView, not deprecated NavigationView)
- Consistent back navigation and spatial hierarchy

## Category: Status & Progress

*11 detections across 7 file(s) — 0 concern(s), 0 positive(s)*

### Code Excerpts

**Sources/CausabeeShare/ShareViewController\.swift**
~~~swift
L123: ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
~~~

**Sources/Causabee/SetupAssistant\.swift**
~~~swift
L506: if working { ProgressView().controlSize(.small) }
L548: if working { ProgressView().controlSize(.small) }
~~~

**Sources/Causabee/MatterStatusView\.swift**
~~~swift
L607: if searchingLinks.hasSuffix("…") { ProgressView().controlSize(.small) }
~~~

**Sources/Causabee/Theme\.swift**
~~~swift
L587: ProgressView().controlSize(.small)
L601: if warming { ProgressView().controlSize(.mini).scaleEffect(0.7).offset(x: 7, y: -6).transition(.opacity) }
L680: ProgressView(value: done).tint(.primary)
L683: HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Getting it ready …").font(.caption).foregroundStyle(.secondary) }
~~~

**Sources/Causabee/FolderSaver\.swift**
~~~swift
L73: if let busy = saver.busy { ProgressView().controlSize(.small); Text(busy).font(.caption).foregroundStyle(.secondary) }
~~~

**Sources/CausabeePhone/PeopleAndLinks\.swift**
~~~swift
L296: if searching.hasSuffix("…") { ProgressView() }
~~~

**Sources/CausabeePhone/MailFiles\.swift**
~~~swift
L173: if state[id]?.hasPrefix("Getting") == true { ProgressView() }
~~~

### HIG Reference

1. **Show progress for operations longer than a second or two.**

2. **Determinate when duration/percentage is known.** A filling progress bar gives users a clear sense of remaining work. Use for downloads, uploads, or any measurable process.

3. **Indeterminate when duration is unknown.** A spinner communicates work is happening without promising a timeframe. Use for unpredictable network requests.

4. **Prefer progress bars over spinners.** Determinate progress feels faster and more trustworthy.

5. **Place indicators where content will appear.** Inline progress near the content area, not modal or distant.

6. **Don't stack multiple indicators.** Aggregate simultaneous operations into one representation or show the most relevant.

7. **Don't hide the status bar without good reason.** Reserve hiding for immersive experiences (full-screen media, games, AR).

8. **Match status bar style to your content.** Light or dark for adequate contrast.

9. **Respect safe areas.** No interactive content behind the status bar.

10. **Restore the status bar promptly** when exiting immersive contexts.

11. **Activity rings are for Move, Exercise, and Stand goals.** Don't repurpose the ring metaphor for unrelated data.

12. **Respect ring color conventions.** Red (Move), green (Exercise), blue (Stand) are strongly associated with Apple Fitness.

13. **Use HealthKit APIs** for activity data rather than manual tracking.

14. **Celebrate completions** with animation and haptics when rings close.

### Evaluate

- Progress indicators for long operations
- Appropriate use of determinate vs indeterminate progress

## Category: Search & Navigation

*1 detections across 1 file(s) — 0 concern(s), 0 positive(s)*

### Code Excerpts

**Sources/CausabeePhone/PhoneShots\.swift**
~~~swift
L506: .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Find a matter")
~~~

### HIG Reference

1. **Search: discoverable with instant feedback.** Place search fields where users expect them (top of list, toolbar/navigation bar). Show results as the user types.

2. **Page controls: position in a flat page sequence.** For discrete, equally weighted pages (onboarding, photo gallery). Show current page and total count.

3. **Path controls: file hierarchy navigation.** macOS path controls display location within a directory structure and allow jumping to any ancestor.

4. **Search scopes narrow large result sets.** Provide scope buttons so users can filter without complex queries.

5. **Clear empty states for search.** Helpful message suggesting corrections or alternatives, not a blank screen.

6. **Page controls are not for hierarchical navigation.** Flat, linear sequences only. Use navigation controllers, tab bars, or sidebars for hierarchy.

7. **Keep path controls concise.** Show meaningful segments only. Users can click any segment to navigate directly.

8. **Support keyboard for search.** Command-F and system search shortcuts should activate search.

### Evaluate

- Searchable modifier used for filterable content
- Search suggestions and scopes where appropriate

## Scoring Summary

| Category | Score (1-10) | Key Findings |
|----------|-------------|-------------|
| Foundations | | |
| Controls | | |
| Interaction Patterns | | |
| Dialogs & Presentations | | |
| Menus & Actions | | |
| Apple Technologies | | |
| Input Methods | | |
| Platform Adaptation | | |
| Layout & Navigation | | |
| Status & Progress | | |
| Search & Navigation | | |
| **Overall** | **/10** | |
