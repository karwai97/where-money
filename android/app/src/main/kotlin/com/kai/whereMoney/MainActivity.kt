package com.kai.whereMoney

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity

// local_auth shows the platform's BiometricPrompt, which is a fragment and
// needs a FragmentActivity to be shown in.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // The recents thumbnail is the last thing that was on screen, and a
        // lock that leaves it readable is cosmetic. This hides only that
        // thumbnail; the user can still screenshot their own charts, which
        // FLAG_SECURE would have taken away.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
    }
}
