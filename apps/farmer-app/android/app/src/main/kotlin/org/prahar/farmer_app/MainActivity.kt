package org.prahar.farmer_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {

    private val VOICE_CHANNEL = "org.prahar.farmer_app/voice"
    private val PERMISSION_REQUEST_RECORD_AUDIO = 2001

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingMethodResult: MethodChannel.Result? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    private var voiceChannel: MethodChannel? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize TTS eagerly so it's ready when the user first taps the mic
        tts = TextToSpeech(this) { status ->
            ttsReady = (status == TextToSpeech.SUCCESS)
            if (ttsReady) {
                mainHandler.post {
                    voiceChannel?.invokeMethod("onTtsReady", mapOf("ready" to true))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        voiceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
        voiceChannel!!.setMethodCallHandler { call, result ->
            when (call.method) {

                "isTtsAvailable" -> {
                    result.success(ttsReady)
                }

                "isLanguageAvailable" -> {
                    val lang = call.argument<String>("lang") ?: "en"
                    if (!ttsReady || tts == null) {
                        result.success(mapOf("available" to false, "reason" to "NOT_READY"))
                        return@setMethodCallHandler
                    }
                    val locale = when (lang) {
                        "hi" -> Locale("hi", "IN")
                        "mr" -> Locale("mr", "IN")
                        "pa" -> Locale("pa", "IN")
                        else -> Locale("en", "IN")
                    }
                    val res = tts!!.isLanguageAvailable(locale)
                    val isAvail = res >= TextToSpeech.LANG_AVAILABLE
                    result.success(mapOf("available" to isAvail, "status" to res))
                }

                "isSpeaking" -> {
                    result.success(tts?.isSpeaking ?: false)
                }

                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val lang = call.argument<String>("lang") ?: "en"
                    if (!ttsReady || tts == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    val locale = when (lang) {
                        "hi" -> Locale("hi", "IN")
                        "mr" -> Locale("mr", "IN")
                        "pa" -> Locale("pa", "IN")
                        else -> Locale("en", "IN")
                    }
                    val langResult = tts!!.setLanguage(locale)
                    if (langResult == TextToSpeech.LANG_MISSING_DATA
                        || langResult == TextToSpeech.LANG_NOT_SUPPORTED
                    ) {
                        // Fallback to English if the requested language voice is not available
                        tts!!.setLanguage(Locale("en", "IN"))
                    }
                    tts!!.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                        override fun onStart(utteranceId: String?) {
                            mainHandler.post {
                                voiceChannel?.invokeMethod("onTtsStart", mapOf("utteranceId" to (utteranceId ?: "")))
                            }
                        }
                        override fun onDone(utteranceId: String?) {
                            mainHandler.post {
                                voiceChannel?.invokeMethod("onTtsDone", mapOf("utteranceId" to (utteranceId ?: "")))
                            }
                        }
                        @Deprecated("Deprecated in Java")
                        override fun onError(utteranceId: String?) {
                            mainHandler.post {
                                voiceChannel?.invokeMethod("onTtsError", mapOf("utteranceId" to (utteranceId ?: "")))
                            }
                        }
                    })
                    val utteranceId = "prahar_${System.currentTimeMillis()}"
                    tts!!.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
                    result.success(true)
                }

                "stopSpeaking" -> {
                    tts?.stop()
                    result.success(true)
                }

                "checkPermission" -> {
                    val hasPermission = ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(hasPermission)
                }

                "requestPermission" -> {
                    if (ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECORD_AUDIO
                        ) == PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(true)
                    } else {
                        pendingPermissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.RECORD_AUDIO),
                            PERMISSION_REQUEST_RECORD_AUDIO
                        )
                    }
                }

                "isSttAvailable" -> {
                    val available = SpeechRecognizer.isRecognitionAvailable(this)
                    result.success(available)
                }

                "startListening" -> {
                    val lang = call.argument<String>("lang") ?: "en"

                    // Check runtime microphone permission first
                    if (ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECORD_AUDIO
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        result.success(mapOf("success" to false, "error" to "PERMISSION_DENIED"))
                        return@setMethodCallHandler
                    }

                    if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                        result.success(mapOf("success" to false, "error" to "STT_NOT_AVAILABLE"))
                        return@setMethodCallHandler
                    }

                    mainHandler.post {
                        try {
                            // Cancel and clean up previous recognizer
                            speechRecognizer?.cancel()
                            speechRecognizer?.destroy()
                            speechRecognizer = null
                            pendingMethodResult = null

                            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this@MainActivity)
                            if (speechRecognizer == null) {
                                result.success(mapOf("success" to false, "error" to "STT_INITIALIZATION_ERROR"))
                                return@post
                            }

                            pendingMethodResult = result

                            speechRecognizer!!.setRecognitionListener(object : RecognitionListener {
                                override fun onReadyForSpeech(params: Bundle?) {
                                    mainHandler.post {
                                        voiceChannel?.invokeMethod("onSttReady", null)
                                    }
                                }

                                override fun onBeginningOfSpeech() {
                                    mainHandler.post {
                                        voiceChannel?.invokeMethod("onSttListening", null)
                                    }
                                }

                                override fun onRmsChanged(rmsdB: Float) {
                                    mainHandler.post {
                                        voiceChannel?.invokeMethod("onSttRmsChanged", mapOf("rms" to rmsdB))
                                    }
                                }

                                override fun onBufferReceived(buffer: ByteArray?) {}

                                override fun onEndOfSpeech() {
                                    mainHandler.post {
                                        voiceChannel?.invokeMethod("onSttProcessing", null)
                                    }
                                }

                                override fun onPartialResults(partialResults: Bundle?) {
                                    val matches = partialResults?.getStringArrayList(
                                        SpeechRecognizer.RESULTS_RECOGNITION
                                    )
                                    val partial = matches?.firstOrNull() ?: ""
                                    if (partial.isNotEmpty()) {
                                        mainHandler.post {
                                            voiceChannel?.invokeMethod("onSttPartial", mapOf("partial" to partial))
                                        }
                                    }
                                }

                                override fun onEvent(eventType: Int, params: Bundle?) {}

                                override fun onResults(bundle: Bundle?) {
                                    val matches = bundle?.getStringArrayList(
                                        SpeechRecognizer.RESULTS_RECOGNITION
                                    )
                                    val transcript = matches?.firstOrNull() ?: ""
                                    mainHandler.post {
                                        pendingMethodResult?.success(
                                            mapOf("success" to true, "transcript" to transcript)
                                        )
                                        pendingMethodResult = null
                                    }
                                }

                                override fun onError(error: Int) {
                                    val msg = when (error) {
                                        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "PERMISSION_DENIED"
                                        SpeechRecognizer.ERROR_NO_MATCH -> "NO_MATCH"
                                        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "TIMEOUT"
                                        SpeechRecognizer.ERROR_AUDIO -> "AUDIO_ERROR"
                                        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "RECOGNIZER_BUSY"
                                        SpeechRecognizer.ERROR_CLIENT -> "CLIENT_ERROR"
                                        SpeechRecognizer.ERROR_NETWORK -> "NETWORK_ERROR"
                                        SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "NETWORK_TIMEOUT"
                                        SpeechRecognizer.ERROR_SERVER -> "SERVER_ERROR"
                                        SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "SERVER_DISCONNECTED"
                                        SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "TOO_MANY_REQUESTS"
                                        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "LANGUAGE_NOT_SUPPORTED"
                                        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "LANGUAGE_UNAVAILABLE"
                                        else -> "ERROR_$error"
                                    }
                                    mainHandler.post {
                                        pendingMethodResult?.success(
                                            mapOf("success" to false, "error" to msg)
                                        )
                                        pendingMethodResult = null
                                    }
                                }
                            })

                            val locale = when (lang) {
                                "hi" -> "hi-IN"
                                "mr" -> "mr-IN"
                                "pa" -> "pa-IN"
                                else -> "en-IN"
                            }
                            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                                putExtra(
                                    RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                                    RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                                )
                                putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                                putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
                                putExtra(RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE, locale)
                                putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
                                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                            }
                            speechRecognizer!!.startListening(intent)
                        } catch (e: Exception) {
                            result.success(mapOf("success" to false, "error" to (e.message ?: "START_ERROR")))
                        }
                    }
                }

                "stopListening" -> {
                    mainHandler.post {
                        try {
                            speechRecognizer?.stopListening()
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }

                "cancelListening" -> {
                    mainHandler.post {
                        try {
                            speechRecognizer?.cancel()
                            speechRecognizer?.destroy()
                            speechRecognizer = null
                            pendingMethodResult = null
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_RECORD_AUDIO) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    override fun onDestroy() {
        tts?.shutdown()
        speechRecognizer?.destroy()
        super.onDestroy()
    }
}
