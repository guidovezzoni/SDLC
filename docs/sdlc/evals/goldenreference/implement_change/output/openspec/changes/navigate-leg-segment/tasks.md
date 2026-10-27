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
