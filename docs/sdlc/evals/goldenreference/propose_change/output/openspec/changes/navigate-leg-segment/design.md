## Context

Legs (`Leg`) carry only `fromStopId`/`toStopId`, no coordinates. Stops carry persisted latitude/longitude and place name. `TripDetailViewModel.navigateToStop` already resolves a stop, computes its position and emits `LaunchNavigation`. `MainScreen.TripDetailEffectHandler` launches a `geo:` intent guarded by `resolveActivity`. `LegSummary` is purely presentational with no click behaviour and is rendered at three call sites in `TripDetailScreen`, always inside `legByFromStopId[stop.id]?.let`.

## Goals / Non-Goals

**Goals:**
- Navigate a leg from origin to destination using persisted coordinates via a Google Maps directions URL.
- Keep composables presentational: content description precomputed in the ViewModel.
- Reuse analytics event and error effect.

**Non-Goals:**
- Waypoints, polyline-based navigation, or multi-leg navigation.
- Disabling navigation for VISITED stops.
- New analytics events, parameters or manifest changes.

## Decisions

1. **HTTPS directions URL via `ACTION_VIEW`.** Required by the story; works with Google Maps and browsers. Alternative (`google.navigation:` or `geo:`) cannot express origin and destination.
2. **`buildDirectionsUrl(fromLatitude, fromLongitude, toLatitude, toLongitude)` in `NavigationUriBuilder`.** Coordinates only, no labels, `travelmode=driving`. Pure, unit-testable.
3. **try/catch `ActivityNotFoundException` instead of `resolveActivity`.** On API 30+ `resolveActivity` for https needs a `<queries>` entry; try/catch avoids manifest changes. Extract a shared helper in `MainScreen` that both `LaunchNavigation` and `LaunchLegNavigation` use (the existing geo branch may keep its behaviour; the helper takes an `Intent` and returns success/failure so each branch shows `ShowNavigationError` on failure). Existing tests injecting `resolveActivity`/`startActivity` must remain valid for the geo branch.
4. **ViewModel resolves endpoints.** `navigateLeg(fromStopId)` finds the leg by `fromStopId` in `legs`, looks up both stops in the ordered stop list, computes the origin stop's position and `StopTypeParam`, logs `NavigationLaunched`, emits `LaunchLegNavigation`. If leg or stops are missing it does nothing. The "build ordered stop list" logic is extracted into a private helper shared with `navigateToStop`.
5. **`legNavigateContentDescriptions: Map<String, String>` in UiState**, keyed by `fromStopId`, derived alongside `formattedLegDistances`, using a new string resource `leg_action_navigate_content_description` ("Navigate from %1$s to %2$s"). `TripDetailScreen` passes `uiState.legNavigateContentDescriptions[leg.fromStopId]`.
6. **`LegSummary` API:** `onNavigate: (() -> Unit)? = null`, `isLoading: Boolean = false`, `navigateContentDescription: String = ""`; modifier remains first. An `IconButton(enabled = !isLoading)` with `Icons.Filled.Navigation` is shown when `onNavigate` is non-null. Defaults keep existing previews valid.
7. **Analytics:** reuse `NavigationLaunched(stopType, stopPosition)` of the origin stop. Tracking plan already covers it ("An external navigation app is launched for a stop").

## Risks / Trade-offs

- [Origin stop name or leg missing from state while loading] → map entries only built when both stops exist; the screen passes an empty description otherwise and the ViewModel ignores intents with unresolvable legs.
- [No browser or maps app installed] → `ActivityNotFoundException` caught, snackbar shown.
- [`navigation_launched` cannot distinguish stop vs leg navigation] → accepted; keeps taxonomy unchanged.
- [Existing `legSummary_exposesNoClickableSemantics` test breaks] → replaced by tests for the new behaviour.
