package com.guidovezzoni.venice.ui.screens.tripdetail

import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.guidovezzoni.venice.ui.theme.HeadingToVeniceTheme
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class LegSummaryTest {

    @get:Rule
    val composeTestRule = createComposeRule()

    private fun setContent(
        formattedDistance: String,
        formattedDuration: String = "",
        onNavigate: (() -> Unit)? = null,
        isLoading: Boolean = false,
        navigateContentDescription: String = "",
    ) {
        composeTestRule.setContent {
            HeadingToVeniceTheme {
                LegSummary(
                    formattedDistance = formattedDistance,
                    formattedDuration = formattedDuration,
                    onNavigate = onNavigate,
                    isLoading = isLoading,
                    navigateContentDescription = navigateContentDescription,
                )
            }
        }
    }

    // region Distance display

    @Test
    fun legSummary_withShortDistance_showsDistanceTextBetweenStops() {
        setContent(formattedDistance = "750 m", formattedDuration = "9 min")

        composeTestRule
            .onNodeWithText("750 m · 9 min", substring = true)
            .assertIsDisplayed()
    }

    // endregion

    // region Duration display

    @Test
    fun legSummary_withFormattedDuration_showsDurationTextAlongsideDistance() {
        composeTestRule.setContent {
            HeadingToVeniceTheme {
                LegSummary(
                    formattedDistance = "750 m",
                    formattedDuration = "9 min",
                )
            }
        }

        composeTestRule
            .onNodeWithText("750 m · 9 min", substring = true)
            .assertIsDisplayed()
    }

    // endregion

    // region Navigate button

    @Test
    fun givenOnNavigate_whenRendered_thenNavigateButtonWithContentDescriptionIsDisplayed() {
        setContent(
            formattedDistance = "750 m",
            formattedDuration = "9 min",
            onNavigate = {},
            navigateContentDescription = "Navigate from Rome to Florence",
        )

        composeTestRule
            .onNodeWithContentDescription("Navigate from Rome to Florence")
            .assertIsDisplayed()
    }

    @Test
    fun givenNavigateButton_whenClicked_thenOnNavigateIsInvoked() {
        var navigateClicked = false
        setContent(
            formattedDistance = "750 m",
            formattedDuration = "9 min",
            onNavigate = { navigateClicked = true },
            navigateContentDescription = "Navigate from Rome to Florence",
        )

        composeTestRule
            .onNodeWithContentDescription("Navigate from Rome to Florence")
            .performClick()

        assertTrue(navigateClicked)
    }

    @Test
    fun givenIsLoading_whenRendered_thenNavigateButtonIsDisabled() {
        setContent(
            formattedDistance = "750 m",
            formattedDuration = "9 min",
            onNavigate = {},
            isLoading = true,
            navigateContentDescription = "Navigate from Rome to Florence",
        )

        composeTestRule
            .onNodeWithContentDescription("Navigate from Rome to Florence")
            .assertIsNotEnabled()
    }

    @Test
    fun givenNoOnNavigate_whenRendered_thenNoNavigateButton() {
        setContent(formattedDistance = "750 m", formattedDuration = "9 min")

        composeTestRule
            .onAllNodes(hasClickAction())
            .assertCountEquals(0)
    }

    // endregion
}
