package com.guidovezzoni.venice.ui.util

import java.net.URLEncoder

private const val URL_ENCODER_CHARSET = "UTF-8"
private const val PLUS_SIGN = "+"
private const val PERCENT_ENCODED_SPACE = "%20"
private const val DIRECTIONS_BASE_URL = "https://www.google.com/maps/dir/?api=1"
private const val PARAM_ORIGIN = "&origin="
private const val PARAM_DESTINATION = "&destination="
private const val PARAM_TRAVELMODE = "&travelmode=driving"

internal fun buildGeoUri(latitude: Double, longitude: Double, placeName: String): String {
    val encodedPlaceName = URLEncoder.encode(placeName, URL_ENCODER_CHARSET)
        .replace(PLUS_SIGN, PERCENT_ENCODED_SPACE)
    return "geo:$latitude,$longitude?q=$latitude,$longitude($encodedPlaceName)"
}

internal fun buildDirectionsUrl(
    fromLatitude: Double,
    fromLongitude: Double,
    toLatitude: Double,
    toLongitude: Double,
): String = "$DIRECTIONS_BASE_URL" +
    "$PARAM_ORIGIN$fromLatitude,$fromLongitude" +
    "$PARAM_DESTINATION$toLatitude,$toLongitude" +
    PARAM_TRAVELMODE
