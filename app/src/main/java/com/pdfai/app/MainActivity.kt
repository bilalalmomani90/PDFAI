package com.pdfai.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.pdfai.app.ui.PdfAiRoot
import com.pdfai.app.ui.theme.PdfAiTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            PdfAiTheme {
                PdfAiRoot()
            }
        }
    }
}
