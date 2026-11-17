package com.pdfai.app.ui.theme

import androidx.compose.ui.graphics.Color

/** Approved PDFAI palette. Do not change these values without explicit approval. */
object PdfAiColors {
    val Background = Color(0xFFF6F8FB)
    val Card = Color(0xFFFFFFFF)
    val Blue = Color(0xFF356B9A)
    val Navy = Color(0xFF203D5A)
    val Teal = Color(0xFF35A6A0)
    val LightBlue = Color(0xFFEAF2F9)
    val Green = Color(0xFF65A987)
    val TextPrimary = Color(0xFF293747)
    val TextSecondary = Color(0xFF8491A0) // Large text / icons only (contrast about 3.2:1 on white).
    val Border = Color(0xFFE5EAF0)
    val White = Color(0xFFFFFFFF)
}

/**
 * Derived colors, approved together with the design concept.
 * They exist only because the approved palette has no value for these roles.
 */
object PdfAiDerivedColors {
    /** Small secondary text (about 4.6:1 or better on the approved backgrounds). */
    val TextSecondarySmall = Color(0xFF637184)
    val Purple = Color(0xFF7B6BB5)
    val PurpleTint = Color(0xFFEFECF8)
    val Orange = Color(0xFFC26A22)
    val OrangeTint = Color(0xFFFBF0E5)
    val Error = Color(0xFFB5524A)
    val ErrorTint = Color(0xFFF9ECEA)
    val TealDeep = Color(0xFF26807B)
    val TealTint = Color(0xFFE4F4F3)
    val GreenDeep = Color(0xFF4A8A69)
    val GreenTint = Color(0xFFE9F4EE)
    val NavyTint = Color(0xFFE6EBF1)
}

/** Glyph color + soft background used by an inner tool tile. Contrast of glyph on tint is 3:1 or better. */
data class ToolAccent(val glyph: Color, val tint: Color)

object PdfAiToolAccents {
    val Blue = ToolAccent(PdfAiColors.Blue, PdfAiColors.LightBlue)
    val Navy = ToolAccent(PdfAiColors.Navy, PdfAiDerivedColors.NavyTint)
    val Teal = ToolAccent(PdfAiDerivedColors.TealDeep, PdfAiDerivedColors.TealTint)
    val Green = ToolAccent(PdfAiDerivedColors.GreenDeep, PdfAiDerivedColors.GreenTint)
    val Purple = ToolAccent(PdfAiDerivedColors.Purple, PdfAiDerivedColors.PurpleTint)
    val Orange = ToolAccent(PdfAiDerivedColors.Orange, PdfAiDerivedColors.OrangeTint)
}
