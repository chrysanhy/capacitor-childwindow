package us.hyph.capchildwindow

import android.content.pm.ActivityInfo
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.view.MotionEvent
import android.view.ViewGroup
import android.view.WindowManager
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AlertDialog
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import kotlin.math.abs

@CapacitorPlugin(name = "ChildWindow")
class ChildWindowPlugin : Plugin() {
    private var webView: WebView? = null
    private var dialog: AlertDialog? = null

    // Variables for swipe detection
    private var touchStartX = 0f
    private var touchStartTime = 0L

    // Flags for navigation control
    private var isProgrammaticNavigation = false
    private var isInitialLoadSequence = false

    @PluginMethod
    fun open(call: PluginCall) {
        val url = call.getString("url") ?: run {
            call.reject("Must provide a URL")
            return
        }

        activity.runOnUiThread {
            try {
                // Optionally force portrait orientation
                activity.requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT

                // Create or reuse WebView
                if (webView == null) {
                    webView = WebView(activity).apply {
                        setBackgroundColor(Color.WHITE)
                    }

                    // Configure WebView settings
                    webView?.settings?.apply {
                        javaScriptEnabled = true

                        // Disable zoom controls
                        builtInZoomControls = false
                        displayZoomControls = false
                        setSupportZoom(false)

                        // Set text size settings to simulate a standard browser.
                        // Adjust textZoom if needed (e.g., 110 or 125 if 100 appears small).
                        textZoom = 100  
                        defaultFontSize = 16
                        defaultFixedFontSize = 16

                        // Do not force overview mode or wide viewport:
                        // loadWithOverviewMode = true  // removed
                        // useWideViewPort = true         // removed

                        // Use the standard layout algorithm
                        layoutAlgorithm = WebSettings.LayoutAlgorithm.NORMAL
                    }

                    // Disable overscroll and horizontal scrolling
                    webView?.overScrollMode = WebView.OVER_SCROLL_NEVER
                    webView?.isHorizontalScrollBarEnabled = false

                    // Set WebViewClient for navigation control
                    webView?.webViewClient = object : WebViewClient() {
                        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                            if (isProgrammaticNavigation || isInitialLoadSequence) {
                                return false
                            }
                            val newUrl = request.url.toString()
                            val data = JSObject().apply { put("url", newUrl) }
                            notifyListeners("navigate", data)
                            return true
                        }

                        override fun onPageFinished(view: WebView, url: String) {
                            super.onPageFinished(view, url)
                            isProgrammaticNavigation = false
                            isInitialLoadSequence = false
                        }

                        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                            val data = JSObject().apply {
                                put("url", request.url.toString())
                                put("errorCode", error.errorCode)
                                put("errorDescription", error.description?.toString() ?: "Unknown error")
                            }
                            notifyListeners("loaderror", data)
                        }
                    }

                    // Simple custom swipe detection to close the browser
                    webView?.setOnTouchListener { _, event ->
                        when (event.action) {
                            MotionEvent.ACTION_DOWN -> {
                                touchStartX = event.x
                                touchStartTime = System.currentTimeMillis()
                                false
                            }
                            MotionEvent.ACTION_UP -> {
                                val distanceX = event.x - touchStartX
                                val elapsedTime = System.currentTimeMillis() - touchStartTime
                                if (distanceX > 100 && abs(distanceX) / elapsedTime * 1000 > 100) {
                                    notifyListeners("exit", JSObject())
                                    closeInternalBrowser()
                                    true
                                } else {
                                    false
                                }
                            }
                            else -> false
                        }
                    }
                }

                // Create or show dialog
                if (dialog == null) {
                    // Ensure the WebView fills the available space
                    webView?.layoutParams = ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )

                    // Build the dialog without extra margins
                    val builder = AlertDialog.Builder(activity)
                    builder.setView(webView)
                    builder.setCancelable(false)

                    dialog = builder.create()

                    // Set a solid background so no underlying page is visible
                    dialog?.window?.setBackgroundDrawable(ColorDrawable(Color.WHITE))
                    dialog?.show()

                    // Remove any default padding and force full-screen size (excluding system bars)
                    dialog?.window?.decorView?.setPadding(0, 0, 0, 0)
                    dialog?.window?.setLayout(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                }

                // Set flags for navigation
                isProgrammaticNavigation = true
                isInitialLoadSequence = true

                // Load the URL
                webView?.loadUrl(url)
                call.resolve()
            } catch (e: Exception) {
                call.reject("Failed to open browser: ${e.message}", e)
            }
        }
    }

    private fun closeInternalBrowser() {
        activity.runOnUiThread {
            try {
                dialog?.dismiss()
                dialog = null
                webView = null
            } catch (e: Exception) {
                // Handle exception as needed
            }
        }
    }

    @PluginMethod
    fun close(call: PluginCall) {
        closeInternalBrowser()
        call.resolve()
    }

    override fun handleOnDestroy() {
        closeInternalBrowser()
        super.handleOnDestroy()
    }
}