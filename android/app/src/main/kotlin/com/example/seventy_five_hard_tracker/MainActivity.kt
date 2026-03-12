package com.example.seventy_five_hard_tracker

import io.flutter.embedding.android.FlutterActivity
import android.os.Bundle
import android.os.Build
import androidx.core.view.WindowCompat

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Enable edge-to-edge display
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
    }
}
