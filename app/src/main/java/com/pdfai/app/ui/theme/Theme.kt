package com.pdfai.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val PdfAiLightColors = lightColorScheme(
    primary = PdfAiColors.Blue,
    onPrimary = PdfAiColors.White, // about 5.6:1
    primaryContainer = PdfAiColors.LightBlue,
    onPrimaryContainer = PdfAiColors.Navy,
    secondary = PdfAiColors.Navy,
    onSecondary = PdfAiColors.White,
    secondaryContainer = PdfAiDerivedColors.NavyTint,
    onSecondaryContainer = PdfAiColors.Navy,
    // White text on turquoise fails contrast (about 2.9:1), so text on it is navy.
    tertiary = PdfAiColors.Teal,
    onTertiary = PdfAiColors.Navy,
    tertiaryContainer = PdfAiDerivedColors.TealTint,
    onTertiaryContainer = PdfAiColors.Navy,
    background = PdfAiColors.Background,
    onBackground = PdfAiColors.TextPrimary,
    surface = PdfAiColors.Card,
    onSurface = PdfAiColors.TextPrimary,
    surfaceVariant = PdfAiColors.LightBlue,
    onSurfaceVariant = PdfAiDerivedColors.TextSecondarySmall,
    outline = PdfAiColors.Border,
    outlineVariant = PdfAiColors.Border,
    error = PdfAiDerivedColors.Error,
    onError = PdfAiColors.White,
    errorContainer = PdfAiDerivedColors.ErrorTint,
    onErrorContainer = PdfAiDerivedColors.Error,
)

/**
 * App theme. Light only: the approved palette has no dark variant.
 * TODO: add a dark theme only if it is requested and its palette is approved.
 */
@Composable
fun PdfAiTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = PdfAiLightColors,
        typography = PdfAiTypography,
        shapes = PdfAiShapes,
        content = content,
    )
}
