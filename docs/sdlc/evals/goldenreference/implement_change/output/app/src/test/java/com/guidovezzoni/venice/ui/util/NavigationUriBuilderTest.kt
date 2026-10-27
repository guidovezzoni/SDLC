package com.guidovezzoni.venice.ui.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test
import java.net.URLEncoder

private const val SIMPLE_PLACE_NAME = "Colosseum"
private const val SPECIAL_PLACE_NAME = "Sant'Angelo (Old Town)"
private const val TEST_LATITUDE = 41.9028
private const val TEST_LONGITUDE = 12.4964
private const val TEST_FROM_LATITUDE = 41.9028
private const val TEST_FROM_LONGITUDE = 12.4964
private const val TEST_TO_LATITUDE = 48.8584
private const val TEST_TO_LONGITUDE = 2.2945
private const val NEGATIVE_LATITUDE = -33.8688
private const val NEGATIVE_LONGITUDE = -70.6693
private const val URL_ENCODER_CHARSET = "UTF-8"
private const val PLUS_SIGN = "+"
private const val PERCENT_ENCODED_SPACE = "%20"

class NavigationUriBuilderTest {

    @Test
    fun `GIVEN origin and destination coordinates WHEN buildDirectionsUrl is called THEN the Google Maps directions URL with origin, destination and travelmode=driving is returned`() {
        val result = buildDirectionsUrl(
            fromLatitude = TEST_FROM_LATITUDE,
            fromLongitude = TEST_FROM_LONGITUDE,
            toLatitude = TEST_TO_LATITUDE,
            toLongitude = TEST_TO_LONGITUDE,
        )

        val expected = "https://www.google.com/maps/dir/?api=1" +
            "&origin=$TEST_FROM_LATITUDE,$TEST_FROM_LONGITUDE" +
            "&destination=$TEST_TO_LATITUDE,$TEST_TO_LONGITUDE" +
            "&travelmode=driving"
        assertEquals(expected, result)
    }

    @Test
    fun `GIVEN negative coordinates WHEN buildDirectionsUrl is called THEN minus signs are preserved and no labels appear`() {
        val result = buildDirectionsUrl(
            fromLatitude = NEGATIVE_LATITUDE,
            fromLongitude = NEGATIVE_LONGITUDE,
            toLatitude = TEST_TO_LATITUDE,
            toLongitude = TEST_TO_LONGITUDE,
        )

        val expected = "https://www.google.com/maps/dir/?api=1" +
            "&origin=$NEGATIVE_LATITUDE,$NEGATIVE_LONGITUDE" +
            "&destination=$TEST_TO_LATITUDE,$TEST_TO_LONGITUDE" +
            "&travelmode=driving"
        assertEquals(expected, result)
        assertFalse("URL must not contain place labels", result.contains("("))
        assertFalse("URL must not contain place labels", result.contains(")"))
    }

    @Test
    fun `GIVEN valid latitude longitude and a simple place name WHEN buildGeoUri is called THEN the result matches the geo URI format exactly`() {
        val placeName = SIMPLE_PLACE_NAME

        val result = buildGeoUri(TEST_LATITUDE, TEST_LONGITUDE, placeName)

        val expected = "geo:$TEST_LATITUDE,$TEST_LONGITUDE?q=$TEST_LATITUDE,$TEST_LONGITUDE($placeName)"
        assertEquals(expected, result)
    }

    @Test
    fun `GIVEN a place name containing spaces and parentheses WHEN buildGeoUri is called THEN the place name segment is percent-encoded and the overall URI remains well-formed`() {
        val placeName = SPECIAL_PLACE_NAME

        val result = buildGeoUri(TEST_LATITUDE, TEST_LONGITUDE, placeName)

        val encodedPlaceName = URLEncoder.encode(placeName, URL_ENCODER_CHARSET)
            .replace(PLUS_SIGN, PERCENT_ENCODED_SPACE)
        val expected = "geo:$TEST_LATITUDE,$TEST_LONGITUDE?q=$TEST_LATITUDE,$TEST_LONGITUDE($encodedPlaceName)"
        assertEquals(expected, result)
        assertFalse("URI must not contain unencoded spaces", result.contains(" "))
    }
}
