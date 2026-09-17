package com.example.tatislam_app

import com.ryanheise.audioservice.AudioServiceActivity

// Extends AudioServiceActivity (not plain FlutterActivity) so the app's
// FlutterEngine is shared with audio_service's background audio handler.
// This avoids a second engine and makes the media notification / lock screen
// controls talk to the exact same player the UI uses.
class MainActivity : AudioServiceActivity()
