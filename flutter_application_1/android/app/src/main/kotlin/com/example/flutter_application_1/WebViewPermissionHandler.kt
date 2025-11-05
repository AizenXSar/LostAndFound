package com.example.flutter_application_1

import android.Manifest
import android.content.pm.PackageManager
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebView
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.reflect.Field
import java.lang.reflect.Method

object WebViewPermissionHandler {
    private var activity: android.app.Activity? = null
    
    fun setActivity(activity: android.app.Activity) {
        this.activity = activity
    }
    
    fun configureWebViewPermissions(webView: WebView) {
        activity?.let { act ->
            val webChromeClient = object : WebChromeClient() {
                override fun onPermissionRequest(request: PermissionRequest) {
                    // Check if we have the necessary permissions
                    val cameraGranted = ContextCompat.checkSelfPermission(
                        act,
                        Manifest.permission.CAMERA
                    ) == PackageManager.PERMISSION_GRANTED
                    
                    val audioGranted = ContextCompat.checkSelfPermission(
                        act,
                        Manifest.permission.RECORD_AUDIO
                    ) == PackageManager.PERMISSION_GRANTED

                    // Grant permissions if we have them
                    if (cameraGranted && audioGranted) {
                        // Grant all requested resources
                        val resources = request.resources
                        request.grant(resources)
                    } else {
                        // Deny if we don't have permissions
                        request.deny()
                    }
                }
            }
            
            // Set the WebChromeClient
            webView.webChromeClient = webChromeClient
        }
    }
    
    fun tryConfigureWebViewFromPlatformView(platformViewId: Int) {
        activity?.let { act ->
            try {
                // Try to access the WebView through reflection
                // This is a workaround since webview_flutter doesn't expose WebView directly
                val webView = findWebViewById(platformViewId)
                webView?.let { 
                    configureWebViewPermissions(it)
                }
            } catch (e: Exception) {
                android.util.Log.e("WebViewPermissionHandler", "Failed to configure WebView: ${e.message}")
            }
        }
    }
    
    private fun findWebViewById(id: Int): WebView? {
        // This is a workaround - we try to find the WebView through the view hierarchy
        // Note: This might not work with all versions of webview_flutter
        return null // Return null for now, we'll use a different approach
    }
}

