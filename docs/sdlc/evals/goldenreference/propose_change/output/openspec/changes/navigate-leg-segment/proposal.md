## Why

Users can navigate to a single stop (story 5.1.1) but cannot navigate a specific segment of the trip. When a route is calculated, each leg is shown between two stops; the user wants to open a navigation app showing the route from that leg's origin to its destination, rather than from their current position to one stop.

## What Changes

- Add a Navigate icon button to every rendered `LegSummary` row, disabled while `isLoading = true`.
- Add `TripDetailUiIntent.OnNavigateLegClicked(fromStopId)` and `TripDetailUiEffect.LaunchLegNavigation(fromLatitude, fromLongitude, toLatitude, toLongitude)`.
- Add `NavigationUriBuilder.buildDirectionsUrl(...)` producing `https://www.google.com/maps/dir/?api=1&origin={fromLatitude},{fromLongitude}&destination={toLatitude},{toLongitude}&travelmode=driving` (coordinates only, no labels).
- Add `legNavigateContentDescriptions: Map<String, String>` to `TripDetailUiState`, precomputed by the ViewModel ("Navigate from {originName} to {destinationName}"), keyed by `fromStopId`.
- `MainScreen` effect handler launches `ACTION_VIEW` using `startActivity` in a try/catch for `ActivityNotFoundException` (no `resolveActivity`, no manifest `<queries>` change); failure reuses `ShowNavigationError` snackbar. Shared intent-launch helper extracted.
- Emit existing `navigation_launched` analytics event with the origin stop's `stop_type` and `stop_position`; no tracking-plan change.
- Strings in en, it, es-rES.
- Leg navigation stays enabled for VISITED stops; it is disabled only while loading.

## Capabilities

### New Capabilities
- `leg-navigation`: Navigate button on leg rows, directions URL construction, ViewModel resolution of leg endpoints, launch and error handling, accessibility description, analytics.

### Modified Capabilities

## Impact

- Code: `NavigationUriBuilder`, `LegSummary`, `TripDetailScreen`, `TripDetailUiIntent`, `TripDetailUiEffect`, `TripDetailUiState`, `TripDetailViewModel`, `MainScreen`, `strings.xml` (3 locales).
- Tests: `NavigationUriBuilderTest`, `TripDetailViewModelTest`, `LegSummaryTest` (existing `legSummary_exposesNoClickableSemantics` must be replaced), `TripDetailScreenTest`, `MainScreenTest`.
- No new dependencies, no permissions, no manifest change, no tracking-plan change.
