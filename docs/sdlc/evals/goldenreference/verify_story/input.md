# Story

# 5.1.2 — Navigate a Leg Segment

**Epic:** Navigation Handoff
**Feature:** Launch Navigation
**Status:** WIP

## User Story

As a user, I want to tap a "Navigate" action on a leg and open a navigation app showing the route from the leg's origin to the leg's destination, so that I can navigate a specific segment of my trip rather than just to a single stop.

## Description

Each leg displayed between two stops on the trip detail screen gains a "Navigate" icon button. Tapping it opens the device's browser or a navigation app with a Google Maps directions URL that includes both the origin and destination coordinates for that leg, with the travel mode set to driving. This is distinct from story 5.1.1 (navigate to a single stop), which uses a `geo:` URI targeting a single point -- leg navigation shows a specific route segment with origin AND destination.

The action is available on every leg for which route data has been calculated (i.e. a `Leg` object exists with both `fromStopId` and `toStopId`). Legs without calculated route data are not displayed at all, so the navigate action is naturally absent.

The `LegSummary` composable currently shows distance and duration text. The navigate action is added alongside this existing content, keeping the display compact.

If no application capable of handling the directions URL is installed (unlikely since it is an `https://` URL, which virtually all Android devices can handle), the user sees a brief snackbar error message.

## Acceptance Criteria

1. **Navigate action visible** -- Every `LegSummary` row that is rendered (i.e. where a calculated `Leg` exists) displays a "Navigate" icon button.
2. **Navigate action disabled during loading** -- The navigate button is disabled when the screen is in a loading state (`isLoading = true`).
3. **Directions URL format** -- Tapping the button launches an `ACTION_VIEW` intent with the URL `https://www.google.com/maps/dir/?api=1&origin={fromLat},{fromLng}&destination={toLat},{toLng}&travelmode=driving`. This opens Google Maps (or the browser) showing the driving route for the specific leg.
4. **Both origin and destination included** -- The URL includes the origin stop's coordinates as the starting point and the destination stop's coordinates as the endpoint. This is the key difference from 5.1.1, which only targets a single point.
5. **Coordinates used directly** -- The intent uses the stops' persisted `latitude` and `longitude` values, not a text-based search query.
6. **No app available** -- If no installed application can handle the `https://` intent (edge case), the user sees a user-friendly error message (snackbar).
7. **No permissions required** -- Launching an implicit intent to another app does not require any runtime permission.
8. **Accessibility** -- The navigate button has an appropriate content description (e.g. "Navigate from {originName} to {destinationName}").
9. **No labels in URL** -- Unlike the `geo:` URI used in 5.1.1, the Google Maps directions URL does not support a label parameter. Place names are not included in the URL -- only coordinates.

## Fields and MVI Artefacts

### UiIntent (new entry)

| Intent | Data | Purpose |
|--------|------|---------|
| `OnNavigateLegClicked` | `fromStopId: String` | User taps Navigate on a leg row. The `fromStopId` uniquely identifies the leg (legs are keyed by `fromStopId` in the UI). |

### UiEffect (new entry)

| Effect | Data | Purpose |
|--------|------|---------|
| `LaunchLegNavigation` | `fromLatitude: Double, fromLongitude: Double, toLatitude: Double, toLongitude: Double` | Signals the composable/activity to fire the directions intent with both origin and destination |

Note: The existing `ShowNavigationError` effect can be reused for the error case.

### UiState

No new UiState fields are required. The navigate button visibility is derived from the presence of a `Leg` object (legs are only rendered when they exist). The `isLoading` flag already exists for disabling interactive elements.

## Intent URI

| URI scheme | Example | Behaviour |
|-----------|---------|-----------|
| `https://www.google.com/maps/dir/?api=1&origin={fromLat},{fromLng}&destination={toLat},{toLng}&travelmode=driving` | `https://www.google.com/maps/dir/?api=1&origin=41.9028,12.4964&destination=43.7696,11.2558&travelmode=driving` | Opens Google Maps (web or app) showing the driving route between the two points. On devices with Google Maps installed, the app intercepts the URL. On devices without it, the system browser handles it. |

Notes:
- No API key, SDK dependency, or network call is needed -- this is purely an intent launch.
- The URL is a standard `https://` link, so it is handled by virtually all Android devices. No `<queries>` manifest entry is needed for `https://` scheme (the existing `geo:` query entry in the manifest remains for 5.1.1).
- Unlike `geo:` URIs, Google Maps directions URLs do not support a label parameter. The user confirms origin/destination visually in Google Maps.
- No `Intent.createChooser()` wrapping -- the standard `ACTION_VIEW` intent relies on the system's default app resolution.

## Files to Modify

| File (intent) | Change description |
|---------------|-------------------|
| `TripDetailUiIntent.kt` | Add `OnNavigateLegClicked` intent |
| `TripDetailUiEffect.kt` | Add `LaunchLegNavigation` effect carrying origin and destination coordinates |
| `TripDetailViewModel.kt` | Handle the new intent: look up the leg and its origin/destination stops, emit analytics, emit the appropriate effect |
| `NavigationUriBuilder.kt` | Add a function to build the Google Maps directions URL from origin and destination coordinates |
| `LegSummary.kt` | Add a "Navigate" icon button alongside the existing distance/duration text, controlled by an `onNavigate` lambda parameter |
| `TripDetailScreen.kt` | Wire the `onNavigate` lambda per leg, passing the intent with the leg's `fromStopId`; consume the new effect to launch the intent and show errors |
| `MainScreen.kt` | Handle the new `LaunchLegNavigation` effect: build the URL, create and fire the ACTION_VIEW intent, handle the "no app" error case |
| `strings.xml` (all locales: EN, IT, ES) | Add strings for the navigate-leg content description and any leg-specific error message |
| Compose UI tests | Add test cases for navigate button presence on LegSummary, click behaviour |
| ViewModel unit tests | Add tests for intent handling, effect emission, and edge cases |
| `NavigationUriBuilder` unit tests | Add tests for the new directions URL builder function |

## Unit Testing Strategy

### ViewModel Tests
- GIVEN a trip with a calculated leg WHEN `OnNavigateLegClicked` is dispatched with that leg's `fromStopId` THEN `LaunchLegNavigation` effect is emitted with the correct origin and destination coordinates
- GIVEN a trip with a calculated leg WHEN `OnNavigateLegClicked` is dispatched with that leg's `fromStopId` THEN `navigation_launched` analytics event is emitted with stop_type of the origin stop and the origin stop's position
- GIVEN a trip WHEN `OnNavigateLegClicked` is dispatched with a non-existent `fromStopId` THEN no effect is emitted and no crash occurs

### NavigationUriBuilder Tests
- GIVEN valid origin and destination coordinates WHEN `buildDirectionsUrl` is called THEN the returned URL matches the expected format with correct coordinates and `travelmode=driving`
- GIVEN coordinates with negative values WHEN `buildDirectionsUrl` is called THEN negative signs are preserved correctly in the URL

### Composable / UI Tests
- GIVEN a LegSummary with an `onNavigate` lambda WHEN the composable is rendered THEN the navigate button is visible with the correct content description
- GIVEN a LegSummary without an `onNavigate` lambda (null) WHEN the composable is rendered THEN the navigate button is NOT visible
- GIVEN a LegSummary with an `onNavigate` lambda WHEN the navigate button is tapped THEN the `onNavigate` callback is invoked
- GIVEN a LegSummary with `isLoading = true` and an `onNavigate` lambda WHEN the composable is rendered THEN the navigate button is disabled

## Documentation Updates

- Update `CLAUDE.md` / `AGENTS.md` "Current Status" section to include story 5.1.2 as completed (once done)
- Update `docs/userstories/index.md` when the file is renamed to `-DONE` suffix

## Security Considerations

| Concern | Risk | Mitigation |
|---------|------|------------|
| URL injection | An attacker could theoretically craft a stop with malicious coordinates to produce an unintended URL | Coordinates are `Double` values (cannot contain arbitrary strings). The URL is constructed programmatically with only numeric coordinate values -- no user-provided strings are embedded in the URL (unlike the `geo:` URI in 5.1.1, which includes the place name). |
| Data leakage to third-party app | The directions intent exposes two sets of coordinates to the receiving app (Google Maps or browser) | This is the explicit, expected behaviour. The user is actively choosing to navigate. Only coordinates are shared -- no trip name, stop names, user account info, or other personal data. Coordinates alone, without labels, are less identifying than the `geo:` URI used in 5.1.1. |
| Denial of service | Rapid repeated taps could launch multiple intents | Standard Android behaviour; the external app will handle or ignore duplicate launches. No rate-limiting needed. |
| HTTPS URL opens browser | The URL could open in a browser rather than Google Maps, potentially exposing coordinates in browser history | Browser history is a device-local concern under the user's control. The coordinates are the user's own trip data, not sensitive third-party data. |

**Verdict:** Low risk. No mitigation beyond programmatic URL construction with typed coordinates is required. The URL carries less identifying information than the `geo:` URI in 5.1.1 (no place names).

## Performance Considerations

| Concern | Risk | Mitigation |
|---------|------|------------|
| Intent resolution latency | Checking if an app can handle the HTTPS intent could theoretically be slow | `PackageManager.resolveActivity()` is a synchronous system call that executes in microseconds. No async wrapper needed. |
| No network call | This feature does not make any API call or database query | N/A -- performance impact is negligible |
| Stop lookup | The ViewModel needs to look up two stops (origin and destination) by ID | The stops are already in memory in `UiState`. The lookup is O(n) over a small list (max ~10 stops). Negligible. |

**Verdict:** No performance concerns. The feature is a single-line intent launch with no I/O.

## GDPR and Sensitive Information

| Concern | Risk | Mitigation |
|---------|------|------------|
| Location data shared with third-party | Two sets of coordinates (origin and destination) are passed to Google Maps or the browser via an HTTPS URL | This is user-initiated (the user explicitly taps "Navigate"). The data shared consists of coordinates the user themselves entered/selected as trip stops. No user's current GPS location is shared. No consent prompt is needed beyond the user's tap action. |
| No PII in the URL | Only numeric coordinates are shared | No place names, email, phone, account ID, or device identifiers are included in the URL. This is actually less identifying than the 5.1.1 `geo:` URI which includes the place name. |
| Browser history | The HTTPS URL with coordinates may be stored in the device's browser history if handled by the browser | This is device-local data under the user's control. The coordinates are not personal data in themselves (they are stop locations chosen by the user, not the user's location). |
| Analytics event | The `navigation_launched` event records `stop_type` and `stop_position` (both bounded enums/integers) | No coordinates, place names, or identifiers are included in the analytics event. Compliant with the tracking plan's privacy floor. |

**Verdict:** No GDPR concern. The shared data is minimal (coordinates only), user-initiated, and does not constitute personal data processing beyond what the user explicitly requested.

## Analytics

This feature reuses the existing `navigation_launched` event from the tracking plan. No new event is needed.

| Event | Parameters | Trigger | Answers |
|-------|-----------|---------|---------|
| `navigation_launched` | `stop_type`, `stop_position` | User taps Navigate on a leg | Q1 (activation funnel), Q2 (feature adoption) |

**Rationale:** The existing `navigation_launched` event already answers the relevant product questions: "Do users navigate their trip?" (Q1) and "Which features get used?" (Q2). The event records the `stop_type` and `stop_position` of the origin stop, which is sufficient to understand usage patterns.

Distinguishing leg navigation from stop navigation in analytics is unnecessary at this stage: both are navigation launches, and the existing parameters provide enough segmentation. If future analysis reveals a need to distinguish the two, a `navigation_target` parameter (values: `stop`, `leg`) can be added to the existing event at that time -- this is a low-cost addition that does not require a new event.

No new `operation` value is needed for `operation_failed` because launching an intent cannot fail in a way that would be tracked -- the only failure mode is "no app available," which is a UI concern, not a tracked operation failure.

## Other Non-Functional Requirements

| Concern | Detail |
|---------|--------|
| Offline behaviour | The navigate button should be visible regardless of network state. The HTTPS URL will be handled by Google Maps (which has its own offline support) or a browser. If the device is offline, Google Maps will show whatever cached data it has -- this is outside Venice's control. |
| Internationalisation | The content description for the navigate button must be extracted to `strings.xml` and translated to all existing locales (English, Italian, Spanish). The content description should include both origin and destination place names for screen reader users. |
| Accessibility | The navigate button must have a content description that includes both the origin and destination stop names for screen reader users (e.g. "Navigate from Rome, Italy to Florence, Italy"). |
| Device compatibility | The `https://` URL scheme is universally supported on all Android devices. On devices with Google Maps installed, the URL is intercepted by the Google Maps app. On devices without it (e.g. Huawei without Google Play Services), the system browser handles the URL. This is broader compatibility than the `geo:` URI used in 5.1.1. |
| Backward compatibility | `ACTION_VIEW` intents with `https://` URIs are supported on all Android API levels. No version gating needed (min SDK 24). |
| Consistency with 5.1.1 | The navigate icon should use the same `Icons.Filled.Navigation` icon used for stop navigation in 5.1.1, providing a consistent visual language. The placement differs (on the LegSummary row vs. on the stop card) to match the different context. |

## Definition of Done

- [ ] `OnNavigateLegClicked` intent added to `TripDetailUiIntent`
- [ ] `LaunchLegNavigation` effect added to `TripDetailUiEffect` with origin and destination coordinates
- [ ] ViewModel handles the intent: looks up the leg's origin and destination stops, emits analytics event, emits the correct effect
- [ ] Directions URL builder function added to `NavigationUriBuilder`
- [ ] "Navigate" icon button appears on every rendered `LegSummary` row
- [ ] Navigate button is disabled during loading state
- [ ] Navigate button has accessible content description including both origin and destination place names
- [ ] Tapping the button launches an `ACTION_VIEW` intent with the Google Maps directions URL
- [ ] If no app can handle the intent, a user-friendly error message is shown (snackbar)
- [ ] Strings added to `strings.xml` for all existing locales (EN, IT, ES)
- [ ] ViewModel unit tests pass (intent handling, effect emission, analytics, edge cases)
- [ ] NavigationUriBuilder unit tests pass for the new directions URL function
- [ ] Compose UI tests pass (button visibility, click callback, disabled state)
- [ ] Compose previews updated to show the navigate action on LegSummary in relevant states
- [ ] `./gradlew check` passes
- [ ] `./gradlew test` passes
- [ ] On-device manual verification: tapping Navigate on a leg opens Google Maps (or browser) showing the driving route between the correct origin and destination

---

## Original user story

### 5.1.2 — Open Google Maps Navigation for a Leg Segment

**Epic:** Navigation Handoff
**Feature:** Launch Navigation

### User Story

As a user, I want to tap a leg and open Google Maps navigation for that segment so that I can navigate specifically from one stop to the next.

### Description

Each leg in the trip overview has a "Navigate" action. Tapping it opens Google Maps with the leg's origin as the starting point and the leg's destination as the endpoint. This is useful when the user wants to navigate a specific segment rather than just "to a stop."

### Acceptance Criteria

- Each leg between two stops has a "Navigate" action.
- Tapping it opens Google Maps with both origin and destination for the leg.
- If Google Maps is not installed, the app falls back to a generic geo intent.

### Technical Notes

- **Implementation:** Use a Google Maps directions intent:
  ```
  https://www.google.com/maps/dir/?api=1&origin={fromLat},{fromLng}&destination={toLat},{toLng}&travelmode=driving
  ```
  This opens Google Maps showing the route for the specific leg.
- Alternatively, the simpler `google.navigation:q={toLat},{toLng}` intent (same as 5.1.1) navigates from current GPS position to the destination, which may be more practical in a driving scenario. Consider offering both or defaulting to the simpler one.

---

# Tasks

## 1. Prerequisites

- [x] 1.1 Add `OnNavigateLegClicked(fromStopId: String)` to `TripDetailUiIntent`
- [x] 1.2 Add `LaunchLegNavigation(fromLatitude, fromLongitude, toLatitude, toLongitude)` to `TripDetailUiEffect`
- [x] 1.3 Add `legNavigateContentDescriptions: Map<String, String> = emptyMap()` to `TripDetailUiState`
- [x] 1.4 Add string `leg_action_navigate_content_description` ("Navigate from %1$s to %2$s") in en, `values-it` ("Naviga da %1$s a %2$s"), `values-es-rES` ("Navegar de %1$s a %2$s"); check `ls app/src/main/res/` first

## 2. Directions URL builder (BDD)

- [x] 2.1 Write test: `GIVEN origin and destination coordinates WHEN buildDirectionsUrl is called THEN the Google Maps directions URL with origin, destination and travelmode=driving is returned` in NavigationUriBuilderTest
- [x] 2.2 Write test: `GIVEN negative coordinates WHEN buildDirectionsUrl is called THEN minus signs are preserved and no labels appear` in NavigationUriBuilderTest
- [x] 2.3 Implement: `NavigationUriBuilder.buildDirectionsUrl(fromLatitude, fromLongitude, toLatitude, toLongitude)` with private constants

## 3. ViewModel leg navigation (BDD)

- [x] 3.1 Write test: `GIVEN a leg between two stops WHEN OnNavigateLegClicked is sent THEN LaunchLegNavigation is emitted with both stops' persisted coordinates` in TripDetailViewModelTest
- [x] 3.2 Write test: `GIVEN a leg with unknown fromStopId WHEN OnNavigateLegClicked is sent THEN no effect and no analytics event are emitted` in TripDetailViewModelTest
- [x] 3.3 Write test: `GIVEN a leg whose origin is the starting point WHEN OnNavigateLegClicked is sent THEN NavigationLaunched with origin stop type and position is logged once` in TripDetailViewModelTest
- [x] 3.4 Write test: `GIVEN a VISITED origin stop WHEN OnNavigateLegClicked is sent THEN LaunchLegNavigation is still emitted` in TripDetailViewModelTest
- [x] 3.5 Write test: `GIVEN legs and stops WHEN state is observed THEN legNavigateContentDescriptions maps each fromStopId to "Navigate from origin to destination"` in TripDetailViewModelTest
- [x] 3.6 Implement: extract shared ordered-stop-list helper from `navigateToStop`; add `navigateLeg(fromStopId)` handler wired in `onIntent`; compute `legNavigateContentDescriptions` next to `formattedLegDistances` using the new string resource

## 4. LegSummary navigate button (BDD)

- [x] 4.1 Write test: `givenOnNavigate_whenRendered_thenNavigateButtonWithContentDescriptionIsDisplayed` in LegSummaryTest (replace `legSummary_exposesNoClickableSemantics`)
- [x] 4.2 Write test: `givenNavigateButton_whenClicked_thenOnNavigateIsInvoked` in LegSummaryTest
- [x] 4.3 Write test: `givenIsLoading_whenRendered_thenNavigateButtonIsDisabled` in LegSummaryTest
- [x] 4.4 Write test: `givenNoOnNavigate_whenRendered_thenNoNavigateButton` in LegSummaryTest
- [x] 4.5 Implement: add `onNavigate: (() -> Unit)? = null`, `isLoading`, `navigateContentDescription` to `LegSummary` (modifier first) with `IconButton(enabled = !isLoading)`; update previews (default, loading, no navigate)

## 5. Screen wiring (BDD)

- [x] 5.1 Write test: `givenLegsAndDescriptions_whenScreenDisplayed_thenEachLegRowHasNavigateButton` in TripDetailScreenTest
- [x] 5.2 Write test: `givenNavigateButton_whenClicked_thenOnNavigateLegClickedIsDispatchedWithFromStopId` in TripDetailScreenTest
- [x] 5.3 Write test: `givenIsLoading_whenScreenDisplayed_thenLegNavigateButtonsAreDisabled` in TripDetailScreenTest
- [x] 5.4 Implement: wire `onNavigate`, `isLoading` and `legNavigateContentDescriptions[leg.fromStopId]` into all three `LegSummary` call sites in `TripDetailScreen`; update preview covering `legNavigateContentDescriptions`

## 6. Effect handler launch (BDD)

- [x] 6.1 Write test: `GIVEN LaunchLegNavigation WHEN collected THEN ACTION_VIEW intent with the directions URL is started` in MainScreenTest
- [x] 6.2 Write test: `GIVEN startActivity throws ActivityNotFoundException WHEN LaunchLegNavigation is collected THEN the navigation error snackbar is shown` in MainScreenTest
- [x] 6.3 Implement: add `LaunchLegNavigation` branch in `TripDetailEffectHandler` using try/catch around `startActivity`; extract a shared intent-launch helper keeping existing `LaunchNavigation` tests green

## 7. Verification

- [x] 7.1 Run `./gradlew detektDebug` and `./gradlew test`; keep coverage at or above 95%
- [x] 7.2 Run `./gradlew connectedDebugAndroidTest` for Compose UI tests
- [x] 7.3 On-device: tap Navigate on a leg, confirm the maps app opens with origin and destination; check `adb logcat -s Analytics` shows one `navigation_launched` with no coordinates or names
- [x] 7.4 Update AGENTS.md "Current Status" with story 5.1.2 and `openspec/specs` sync at archive
