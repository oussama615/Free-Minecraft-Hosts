package com.strawio.voicechat.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val StrawGold = Color(0xFFE3B64F)
val StrawGoldDark = Color(0xFF9C7530)
val StrawSilver = Color(0xFFE9E9EA)
val StrawCyan = Color(0xFF72F4F2)
val Charcoal = Color(0xFF111315)
val BlackPearl = Color(0xFF050607)
val MutedText = Color(0xFFC4C1BC)
val CardFill = Color(0xCC121416)

private val Scheme = darkColorScheme(
    primary = StrawGold,
    secondary = StrawCyan,
    background = BlackPearl,
    surface = Charcoal,
    onPrimary = Color(0xFF1C1405),
    onSecondary = Color(0xFF032322),
    onBackground = StrawSilver,
    onSurface = StrawSilver,
)

@Composable
fun StrawIoTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = Scheme, typography = StrawTypography, content = content)
}
