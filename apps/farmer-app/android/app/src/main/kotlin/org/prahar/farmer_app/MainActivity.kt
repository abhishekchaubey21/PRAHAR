package org.prahar.farmer_app

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

class MainActivity : FlutterActivity() {

    private val VOICE_CHANNEL = "org.prahar.farmer_app/voice"

    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingMethodResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize TTS eagerly so it's ready when the user first taps the mic
        tts = TextToSpeech(this) { status ->
            ttsReady = (status == TextToSpeech.SUCCESS)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {

                    "isTtsAvailable" -> {
                        result.success(ttsReady)
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
                            override fun onStart(utteranceId: String?) {}
                            override fun onDone(utteranceId: String?) {}
                            @Deprecated("Deprecated in Java")
                            override fun onError(utteranceId: String?) {}
                        })
                        val utteranceId = "prahar_${System.currentTimeMillis()}"
                        tts!!.speak(text, TextToSpeech.QUEUE_FLUSH, null, utteranceId)
                        result.success(true)
                    }

                    "stopSpeaking" -> {
                        tts?.stop()
                        result.success(true)
                    }

                    "isSttAvailable" -> {
                        val available = SpeechRecognizer.isRecognitionAvailable(this)
                        result.success(available)
                    }

                    "startListening" -> {
                        val lang = call.argument<String>("lang") ?: "en"
                        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                            result.success(mapOf("success" to false, "error" to "STT_NOT_AVAILABLE"))
                            return@setMethodCallHandler
                        }

                        // Cancel any existing in-progress recognition
                        speechRecognizer?.cancel()
                        speechRecognizer?.destroy()
                        pendingMethodResult = null

                        speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
                        pendingMethodResult = result

                        speechRecognizer!!.setRecognitionListener(object : RecognitionListener {
                            override fun onReadyForSpeech(params: Bundle?) {}
                            override fun onBeginningOfSpeech() {}
                            override fun onRmsChanged(rmsdB: Float) {}
                            override fun onBufferReceived(buffer: ByteArray?) {}
                            override fun onEndOfSpeech() {}
                            override fun onPartialResults(partialResults: Bundle?) {}
                            override fun onEvent(eventType: Int, params: Bundle?) {}

                            override fun onResults(bundle: Bundle?) {
                                val matches = bundle?.getStringArrayList(
                                    SpeechRecognizer.RESULTS_RECOGNITION
                                )
                                val transcript = matches?.firstOrNull() ?: ""
                                pendingMethodResult?.success(
                                    mapOf("success" to true, "transcript" to transcript)
                                )
                                pendingMethodResult = null
                            }

                            override fun onError(error: Int) {
                                val msg = when (error) {
                                    SpeechRecognizer.ERROR_NO_MATCH -> "NO_MATCH"
                                    SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "TIMEOUT"
                                    SpeechRecognizer.ERROR_AUDIO -> "AUDIO_ERROR"
                                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "RECOGNIZER_BUSY"
                                    SpeechRecognizer.ERROR_CLIENT -> "CLIENT_ERROR"
                                    SpeechRecognizer.ERROR_NETWORK -> "NETWORK_ERROR"
                                    else -> "ERROR_$error"
                                }
                                pendingMethodResult?.success(
                                    mapOf("success" to false, "error" to msg)
                                )
                                pendingMethodResult = null
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
                            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                        }
                        speechRecognizer!!.startListening(intent)
                    }

                    "stopListening" -> {
                        speechRecognizer?.stopListening()
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        tts?.shutdown()
        speechRecognizer?.destroy()
        super.onDestroy()
    }
}
