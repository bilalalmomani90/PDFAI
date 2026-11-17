package com.pdfai.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

// TODO: bundle the approved Arabic + Latin font family (check its license first).
// Until then the system font is used, with generous line height for Arabic.
private val AppFont = FontFamily.Default

val PdfAiTypography = Typography(
    displaySmall = TextStyle(
        fontFamily = AppFont, fontWeight = FontWeight.SemiBold,
        fontSize = 36.sp, lineHeight = 48.sp, letterSpacing = 0.sp,
    ),
    headlineSmall = TextStyle(
        fontFamily = AppFont, fontWeight = FontWeight.SemiBold,
        fontSize = 24.sp, lineHeight = 34.sp, letterSpacing = 0.sp,
    ),
    titleLarge = TextStyle(
        fontFamily = AppFont, fontWeight = FontWeight.SemiBold,
        fontSize = 20.sp, lineHeight = 30.sp, letterSpacing = 0.sp,
    ),
    titleMedium = TextStyle(
        fontFamily = AppFont, fontWeight = FontWeight.Medium,
        fontSize = 16.sp, lineHeight = 26.sp, letterSpacing = 0.sp,
    ),
    bodyLarge = TextStyle(
        fontFamily = AppFont, fontWeight = FontWeight.Normal,
        fontSize = 16.sp, lineHeight = 28.sp, letterSpacing = 0.sp,
    ),
    bodyMedium = TextStyle(
        fontFamily = AppFont, fontWeight = FontWeight.Normal,
        fontSize = 14.sp, lineHeight = 24.sp, letterSpacing = 0.sp,
    ),
    labelLarge = TextStyle(
        fontFamily = AppFont, fontWeight = FontWeight.Medium,
        fontSize = 14.sp, lineHeight = 20.sp, letterSpacing = 0.sp,
    ),
    labelMedium = TextStyle(
        fontFamily = AppFont, fontWeight = FontWeight.Medium,
        fontSize = 12.sp, lineHeight = 18.sp, letterSpacing = 0.sp,
    ),
)
