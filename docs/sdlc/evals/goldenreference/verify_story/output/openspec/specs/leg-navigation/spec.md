# Leg Navigation Spec

## Purpose

Enables the user to navigate a specific route leg (from one stop to the next) by launching an external navigation app with a Google Maps directions URL built from the leg's persisted coordinates.

## Requirements

### Requirement: Navigate action on every leg row
Every rendered `LegSummary` row SHALL display a Navigate icon button when an `onNavigate` handler is supplied. The button SHALL be disabled when `isLoading = true` and enabled otherwise, regardless of the status of the leg's stops.

#### Scenario: Leg row shows Navigate button
- **WHEN** a `LegSummary` is rendered with an `onNavigate` handler
- **THEN** a Navigate icon button SHALL be visible

#### Scenario: Button disabled while loading
- **WHEN** a `LegSummary` is rendered with `isLoading = true`
- **THEN** the Navigate button SHALL be disabled

#### Scenario: Button enabled for visited stops
- **WHEN** a `LegSummary` is rendered with `isLoading = false` for a leg whose origin stop is VISITED
- **THEN** the Navigate button SHALL be enabled

### Requirement: Accessible content description
The Navigate button SHALL expose the content description "Navigate from {originName} to {destinationName}", precomputed by the ViewModel in `TripDetailUiState.legNavigateContentDescriptions` keyed by `fromStopId`, and localised in en, it and es-rES.

#### Scenario: ViewModel precomputes description
- **WHEN** a leg from stop "Milan" to stop "Turin" exists
- **THEN** `legNavigateContentDescriptions[fromStopId]` SHALL equal "Navigate from Milan to Turin"

#### Scenario: Button exposes description
- **WHEN** a `LegSummary` is rendered with `navigateContentDescription = "Navigate from Milan to Turin"`
- **THEN** a node with that content description SHALL exist

### Requirement: Tapping Navigate dispatches an intent resolved by the ViewModel
Tapping the button SHALL dispatch `TripDetailUiIntent.OnNavigateLegClicked(fromStopId)`. The ViewModel SHALL resolve the leg and both stops and emit `TripDetailUiEffect.LaunchLegNavigation(fromLatitude, fromLongitude, toLatitude, toLongitude)` using persisted coordinates.

#### Scenario: Tap dispatches intent
- **WHEN** the user taps Navigate on the leg whose origin stop id is "stop-1"
- **THEN** `OnNavigateLegClicked("stop-1")` SHALL be dispatched

#### Scenario: ViewModel emits effect with persisted coordinates
- **WHEN** the ViewModel receives `OnNavigateLegClicked` for a leg from (45.4642, 9.1900) to (45.0703, 7.6869)
- **THEN** `LaunchLegNavigation(45.4642, 9.1900, 45.0703, 7.6869)` SHALL be emitted

#### Scenario: Unresolvable leg is ignored
- **WHEN** the ViewModel receives `OnNavigateLegClicked` for a `fromStopId` with no matching leg or stops
- **THEN** no effect and no analytics event SHALL be emitted

### Requirement: Directions URL format
`NavigationUriBuilder.buildDirectionsUrl` SHALL return `https://www.google.com/maps/dir/?api=1&origin={fromLatitude},{fromLongitude}&destination={toLatitude},{toLongitude}&travelmode=driving`, using coordinates only and no place-name labels or text search.

#### Scenario: URL built from coordinates
- **WHEN** called with (45.4642, 9.1900, 45.0703, 7.6869)
- **THEN** it SHALL return `https://www.google.com/maps/dir/?api=1&origin=45.4642,9.19&destination=45.0703,7.6869&travelmode=driving`

#### Scenario: Negative coordinates preserved
- **WHEN** called with negative latitudes or longitudes
- **THEN** the minus signs SHALL appear unchanged in the URL

### Requirement: Launch and error handling
On `LaunchLegNavigation`, the UI layer SHALL start an `Intent(Intent.ACTION_VIEW, url)` using `startActivity` and catching `ActivityNotFoundException`, without `resolveActivity`, permissions or manifest `<queries>` changes. If no app can handle it, a snackbar with the existing `ShowNavigationError` message SHALL be shown.

#### Scenario: Intent launched
- **WHEN** `MainScreen` collects `LaunchLegNavigation`
- **THEN** it SHALL start an `ACTION_VIEW` intent whose data is the directions URL

#### Scenario: No app available
- **WHEN** starting the activity throws `ActivityNotFoundException`
- **THEN** the navigation error snackbar SHALL be shown and the app SHALL NOT crash

### Requirement: Leg navigation analytics
Launching leg navigation SHALL log `navigation_launched` with the origin stop's `stop_type` and `stop_position`, with no coordinates or names.

#### Scenario: Event logged for origin stop
- **WHEN** the ViewModel handles `OnNavigateLegClicked` for a leg whose origin is the starting point at position 0
- **THEN** `NavigationLaunched(STARTING_POINT, 0)` SHALL be logged exactly once
