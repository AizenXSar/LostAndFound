package com.example.flutter_application_1

import android.Manifest
import android.content.pm.PackageManager
import android.webkit.PermissionRequest
import android.webkit.WebChromeClient
import android.webkit.WebView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flutter_application_1/webview_permissions"
    private var pendingPermissionRequest: PermissionRequest? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        
        // Set up method channel to handle WebView permission requests
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "grantWebViewPermissions" -> {
                    pendingPermissionRequest?.grant(pendingPermissionRequest?.resources ?: arrayOf())
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        
        // Initialize WebView permission handler
        WebViewPermissionHandler.setActivity(this)
    }

    // Custom WebChromeClient that handles permission requests
    fun createWebChromeClient(): WebChromeClient {
        return object : WebChromeClient() {
            override fun onPermissionRequest(request: PermissionRequest) {
                // Check if we have the necessary permissions
                val cameraGranted = ContextCompat.checkSelfPermission(
                    this@MainActivity,
                    Manifest.permission.CAMERA
                ) == PackageManager.PERMISSION_GRANTED
                
                val audioGranted = ContextCompat.checkSelfPermission(
                    this@MainActivity,
                    Manifest.permission.RECORD_AUDIO
                ) == PackageManager.PERMISSION_GRANTED

                // Grant permissions if we have them
                if (cameraGranted && audioGranted) {
                    // Grant all requested resources (camera and microphone)
                    request.grant(request.resources)
                } else {
                    // Store the request and request permissions
                    pendingPermissionRequest = request
                    val permissions = mutableListOf<String>()
                    if (!cameraGranted) permissions.add(Manifest.permission.CAMERA)
                    if (!audioGranted) permissions.add(Manifest.permission.RECORD_AUDIO)
                    
                    if (permissions.isNotEmpty()) {
                        ActivityCompat.requestPermissions(
                            this@MainActivity,
                            permissions.toTypedArray(),
                            100
                        )
                    } else {
                        request.deny()
                    }
                }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == 100) {
            val allGranted = grantResults.isNotEmpty() && 
                           grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            
            if (allGranted && pendingPermissionRequest != null) {
                // Grant permissions to WebView
                pendingPermissionRequest?.grant(pendingPermissionRequest?.resources ?: arrayOf())
            } else {
                // Deny permissions to WebView
                pendingPermissionRequest?.deny()
            }
            pendingPermissionRequest = null
        }
    }
}
