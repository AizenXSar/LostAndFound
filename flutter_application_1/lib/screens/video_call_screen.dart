import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';

class VideoCallScreen extends StatefulWidget {
  final String roomName;
  final String? peerName;
  final String? peerAvatarUrl;
  final bool isVideoCall;

  const VideoCallScreen({
    super.key,
    required this.roomName,
    this.peerName,
    this.peerAvatarUrl,
    this.isVideoCall = true,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  InAppWebViewController? _webViewController;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isVideoEnabled = true;
  bool _isFrontCamera = true;

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndInitialize();
  }

  Future<void> _requestPermissionsAndInitialize() async {
    // Request camera and microphone permissions before initializing WebView
    // This works for BOTH caller and receiver - they both use the same VideoCallScreen
    if (widget.isVideoCall) {
      print('[VideoCall] Requesting camera and microphone permissions...');
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();
      
      print('[VideoCall] Camera permission: ${cameraStatus.isGranted}, Microphone permission: ${microphoneStatus.isGranted}');
      
      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        print('[VideoCall] Permissions granted - camera and mic ready for BOTH caller and receiver');
        setState(() {
          _isLoading = false;
        });
      } else {
        print('[VideoCall] Permissions denied');
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Camera and microphone permissions are required for video calls. Please grant permissions in settings.';
        });
      }
    } else {
      // For audio-only calls, just request microphone
      final microphoneStatus = await Permission.microphone.request();
      if (microphoneStatus.isGranted) {
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Microphone permission is required. Please grant permission in settings.';
        });
      }
    }
  }

  Future<void> _initializeJavaScript() async {
    if (_webViewController == null) return;
    
    // Inject code to prevent external navigation and auto-click join button
    await _webViewController!.evaluateJavascript(source: '''
      (function() {
        // Prevent window.open() from opening external browsers
        const originalOpen = window.open;
        window.open = function(url, target, features) {
          console.log('[VideoCall] Blocking window.open() call:', url);
          // Only allow opening within the same origin
          if (url && (url.includes('meet.jit.si') || url.includes('jitsi.net') || url.includes('8x8.vc'))) {
            return originalOpen.call(this, url, target, features);
          }
          return null; // Block external navigation
        };
        
        // Prevent location changes to external sites
        const originalAssign = window.location.assign;
        window.location.assign = function(url) {
          if (!url) return false;
          
          // Block intent:// URLs
          if (url.startsWith('intent://')) {
            console.log('[VideoCall] Blocking intent:// location.assign() - staying in app');
            return false;
          }
          
          if (url.includes('meet.jit.si') || url.includes('jitsi.net') || url.includes('8x8.vc')) {
            return originalAssign.call(this, url);
          }
          console.log('[VideoCall] Blocking location.assign() to:', url);
          return false;
        };
        
        // Override window.location.href to block intent:// URLs
        let currentHref = window.location.href;
        Object.defineProperty(window.location, 'href', {
          get: function() {
            return currentHref;
          },
          set: function(url) {
            if (url && url.startsWith('intent://')) {
              console.log('[VideoCall] Blocking intent:// location.href - staying in app');
              return; // Block intent://
            }
            currentHref = url;
            originalAssign.call(this, url);
          }
        });
        
        // Function to auto-click join button
        function autoJoin() {
          // Try multiple selectors for join button
          const selectors = [
            'button[aria-label*="join" i]',
            'button[data-tooltip*="join" i]',
            'button[title*="join" i]',
            '[role="button"][aria-label*="join" i]',
            'button[class*="join"]',
            'button[id*="join"]',
          ];
          
          for (const selector of selectors) {
            try {
              const btn = document.querySelector(selector);
              if (btn && btn.offsetParent !== null && !btn.disabled) {
                const text = (btn.textContent || btn.innerText || '').toLowerCase().trim();
                const ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
                if ((text.includes('join') || ariaLabel.includes('join')) && 
                    !text.includes('download') && 
                    !text.includes('app store') &&
                    !text.includes('browser')) {
                  console.log('[VideoCall] Found join button, auto-clicking:', selector);
                  btn.click();
                  return true;
                }
              }
            } catch (e) {
              continue;
            }
          }
          
          // Find button by text content
          const allButtons = document.querySelectorAll('button, [role="button"], a[role="button"]');
          for (const btn of allButtons) {
            const text = (btn.textContent || btn.innerText || '').toLowerCase().trim();
            const ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
            if ((text.includes('join') || ariaLabel.includes('join')) && 
                !text.includes('download') && 
                !text.includes('app store') &&
                !text.includes('browser') &&
                btn.offsetParent !== null &&
                !btn.disabled) {
              console.log('[VideoCall] Found join button by text, auto-clicking:', text);
              btn.click();
              return true;
            }
          }
          
          return false;
        }
        
        // Try to auto-join immediately
        if (autoJoin()) {
          console.log('[VideoCall] Auto-joined successfully');
        } else {
          // If not found, try periodically
          let attempts = 0;
          const maxAttempts = 20;
          const joinInterval = setInterval(function() {
            attempts++;
            if (autoJoin() || attempts >= maxAttempts) {
              clearInterval(joinInterval);
              if (attempts >= maxAttempts) {
                console.log('[VideoCall] Auto-join timeout after 10 seconds');
              }
            }
          }, 500);
        }
        
        // Also watch for join button to appear
        const observer = new MutationObserver(function(mutations) {
          if (autoJoin()) {
            observer.disconnect();
            console.log('[VideoCall] Join button appeared and was auto-clicked');
          }
        });
        
        observer.observe(document.body, {
          childList: true,
          subtree: true,
          attributes: false,
        });
        
        // Stop observing after 10 seconds
        setTimeout(function() {
          observer.disconnect();
        }, 10000);
        
        console.log('[VideoCall] External navigation blocked - staying in app');
      })();
    ''');
  }

  Future<void> _toggleCamera() async {
    try {
      setState(() {
        _isVideoEnabled = !_isVideoEnabled;
      });

      await _webViewController?.evaluateJavascript(source: '''
        (function() {
          try {
            if (window.APP && window.APP.conference && window.APP.conference.toggleVideo) {
              window.APP.conference.toggleVideo();
            } else {
              const cameraBtn = document.querySelector('[aria-label*="camera" i], [aria-label*="video" i]');
              if (cameraBtn) cameraBtn.click();
            }
          } catch (e) {
            console.error('Error toggling camera:', e);
          }
        })();
      ''');
    } catch (e) {
      print('Error toggling camera: $e');
      setState(() {
        _isVideoEnabled = !_isVideoEnabled;
      });
    }
  }

  Future<void> _flipCamera() async {
    try {
      setState(() {
        _isFrontCamera = !_isFrontCamera;
      });

      await _webViewController?.evaluateJavascript(source: '''
        (function() {
          try {
            if (window.APP && window.APP.conference) {
              if (window.APP.conference.switchCamera) {
                window.APP.conference.switchCamera();
              } else if (window.APP.conference._switchCamera) {
                window.APP.conference._switchCamera();
              }
            }
          } catch (e) {
            console.error('Error flipping camera:', e);
          }
        })();
      ''');
    } catch (e) {
      print('Error flipping camera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Video Call Error'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                  if (_errorMessage?.contains('permission') ?? false) ...[
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await openAppSettings();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email ?? 'User';
    final userEmail = user?.email ?? '';

    // Build direct URL with hash parameters that force auto-join and skip prejoin page
    // The hash parameters are critical - they must be set correctly to bypass prejoin
    final displayName = Uri.encodeComponent(userName);
    final email = Uri.encodeComponent(userEmail);
    
    // Use direct URL with hash parameters that force direct join
    // Hash params come after # and are separated by &, query params come before #
    final jitsiUrl = 'https://meet.jit.si/${widget.roomName}'
        '#config.prejoinPageEnabled=false'
        '&config.enableWelcomePage=false'
        '&config.enableClosePage=false'
        '&config.requireDisplayName=false'
        '&config.startWithVideoMuted=${!widget.isVideoCall}'
        '&config.startWithAudioMuted=false'
        '&config.disableDeepLinking=true'
        '&config.disableInviteFunctions=true'
        '&config.disableThirdPartyRequests=true'
        '&config.disableRemoteControl=true'
        '&config.defaultLocalVideoMuted=${!widget.isVideoCall}'
        '&config.defaultRemoteVideoMuted=false'
        '&config.defaultLocalAudioMuted=false'
        '&config.defaultRemoteAudioMuted=false'
        '&config.enableLayerSuspension=false'
        '&config.enableNoAudioDetection=false'
        '&config.enableNoisyMicDetection=false'
        '&interfaceConfig.TOOLBAR_BUTTONS=["microphone","camera","hangup","settings","tileview","fullscreen"]'
        '&interfaceConfig.SHOW_JITSI_WATERMARK=false'
        '&interfaceConfig.SHOW_WATERMARK_FOR_GUESTS=false'
        '&interfaceConfig.SHOW_BRAND_WATERMARK=false'
        '&interfaceConfig.SHOW_POWERED_BY=false'
        '&interfaceConfig.SHOW_PROMOTIONAL_CLOSE_PAGE=false'
        '&interfaceConfig.DISPLAY_WELCOME_PAGE_CONTENT=false'
        '&interfaceConfig.DISPLAY_WELCOME_FOOTER=false'
        '&interfaceConfig.DISPLAY_WELCOME_PAGE_TOOLBAR_ADDITIONAL_CONTENT=false'
        '&interfaceConfig.APP_NAME=Lost%20and%20Found'
        '&interfaceConfig.NATIVE_APP_NAME=Lost%20and%20Found'
        '&interfaceConfig.PROVIDER_NAME=Lost%20and%20Found'
        '&userInfo.displayName=$displayName'
        '&userInfo.email=$email';

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('End Video Call?'),
            content: const Text('Are you sure you want to leave the video call?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (shouldPop == true && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // InAppWebView with proper permission handling
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(jitsiUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  useHybridComposition: true,
                  // Enable camera and microphone access
                  allowsBackForwardNavigationGestures: false,
                  // Prevent opening external browsers
                  javaScriptCanOpenWindowsAutomatically: false,
                  // Keep everything in app
                  supportMultipleWindows: false,
                  // Block navigation to external sites
                  allowsLinkPreview: false,
                  // Set user agent to prevent Android intent detection
                  userAgent: 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
                  // Prevent opening external apps
                  useOnDownloadStart: false,
                  // Block file downloads that might open external apps
                  useOnLoadResource: false,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                  
                  // Register JavaScript handlers before page loads
                  controller.addJavaScriptHandler(
                    handlerName: 'onJoined',
                    callback: (args) {
                      print('[VideoCall] Successfully joined conference');
                      setState(() {
                        _isLoading = false;
                      });
                    },
                  );
                  
                  controller.addJavaScriptHandler(
                    handlerName: 'onLeft',
                    callback: (args) {
                      print('[VideoCall] Left conference');
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                  
                  controller.addJavaScriptHandler(
                    handlerName: 'onReadyToClose',
                    callback: (args) {
                      print('[VideoCall] Ready to close');
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  );
                  
                  controller.addJavaScriptHandler(
                    handlerName: 'onError',
                    callback: (args) {
                      print('[VideoCall] Error occurred: $args');
                      setState(() {
                        _hasError = true;
                        _errorMessage = 'Error occurred in video call';
                        _isLoading = false;
                      });
                    },
                  );
                  
                  // Immediately inject code to prevent external navigation
                  Future.delayed(const Duration(milliseconds: 100), () async {
                    await _initializeJavaScript();
                  });
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading = true;
                  });
                  // Inject blocking code on every page load
                  Future.delayed(const Duration(milliseconds: 100), () async {
                    await _initializeJavaScript();
                  });
                },
                onLoadStop: (controller, url) async {
                  setState(() {
                    _isLoading = false;
                  });
                  print('[VideoCall] Page loaded - attempting to auto-join');
                  
                  // Initialize JavaScript to prevent external navigation and auto-join
                  await _initializeJavaScript();
                  
                  // Also try to auto-join after a delay to ensure page is fully loaded
                  Future.delayed(const Duration(milliseconds: 1000), () async {
                    if (_webViewController == null || !mounted) return;
                    await _webViewController!.evaluateJavascript(source: '''
                      (function() {
                        // Try to find and click join button again
                        const joinBtn = document.querySelector('button[aria-label*="join" i], button[class*="join"], button[id*="join"]');
                        if (joinBtn && !joinBtn.disabled) {
                          const text = (joinBtn.textContent || joinBtn.innerText || '').toLowerCase().trim();
                          const ariaLabel = (joinBtn.getAttribute('aria-label') || '').toLowerCase();
                          if ((text.includes('join') || ariaLabel.includes('join')) && 
                              !text.includes('download') && 
                              !text.includes('app store') &&
                              !text.includes('browser')) {
                            console.log('[VideoCall] Retry: Clicking join button');
                            joinBtn.click();
                          }
                        }
                        
                        // Also try using Jitsi API if available
                        if (window.APP && window.APP.conference) {
                          try {
                            // Try to join directly via API
                            if (window.APP.conference.join) {
                              window.APP.conference.join();
                              console.log('[VideoCall] Joined via API');
                            }
                          } catch (e) {
                            console.log('[VideoCall] Error joining via API:', e);
                          }
                        }
                      })();
                    ''');
                  });
                },
                onConsoleMessage: (controller, consoleMessage) {
                  print('WebView Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}');
                },
                androidOnPermissionRequest: (controller, origin, resources) async {
                  // Automatically grant camera and microphone permissions if we have them
                  // IMPORTANT: This works for BOTH caller and receiver - they both use the same VideoCallScreen
                  print('[WebView] Permission request from: $origin');
                  print('[WebView] Requested resources: $resources');
                  
                  final cameraGranted = await Permission.camera.isGranted;
                  final microphoneGranted = await Permission.microphone.isGranted;
                  
                  print('[WebView] App permissions - Camera: $cameraGranted, Microphone: $microphoneGranted');
                  
                  if (cameraGranted && microphoneGranted) {
                    print('[WebView] ✓ Granting camera and microphone permissions to WebView for BOTH caller and receiver');
                    return PermissionRequestResponse(
                      resources: resources,
                      action: PermissionRequestResponseAction.GRANT,
                    );
                  } else {
                    print('[WebView] ✗ Permissions not granted - requesting now...');
                    // Request permissions if not granted (works for both caller and receiver)
                    if (!cameraGranted) {
                      final status = await Permission.camera.request();
                      print('[WebView] Camera permission request result: $status');
                    }
                    if (!microphoneGranted) {
                      final status = await Permission.microphone.request();
                      print('[WebView] Microphone permission request result: $status');
                    }
                    
                    // Check again after requesting
                    final cameraNowGranted = await Permission.camera.isGranted;
                    final micNowGranted = await Permission.microphone.isGranted;
                    
                    if (cameraNowGranted && micNowGranted) {
                      print('[WebView] ✓ Permissions granted after request - granting to WebView');
                      return PermissionRequestResponse(
                        resources: resources,
                        action: PermissionRequestResponseAction.GRANT,
                      );
                    } else {
                      print('[WebView] ✗ Permissions still not granted - denying WebView access');
                    }
                  }
                  
                  return PermissionRequestResponse(
                    resources: resources,
                    action: PermissionRequestResponseAction.DENY,
                  );
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                    _errorMessage = 'Failed to load video call: ${errorResponse.statusCode}';
                  });
                },
                onReceivedError: (controller, request, error) {
                  // Handle ERR_UNKNOWN_URL_SCHEME for intent:// URLs - just ignore them
                  if (error.description.contains('ERR_UNKNOWN_URL_SCHEME') || 
                      error.description.contains('intent://')) {
                    print('[VideoCall] Ignoring intent:// URL error - staying in app');
                    return;
                  }
                  
                  // Handle other errors normally
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                    _errorMessage = 'Failed to load video call: ${error.description}';
                  });
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final uri = navigationAction.request.url;
                  if (uri == null) {
                    return NavigationActionPolicy.CANCEL;
                  }
                  
                  final urlString = uri.toString();
                  
                  // Block intent:// URLs completely
                  if (urlString.startsWith('intent://')) {
                    print('[VideoCall] Blocking intent:// URL - staying in app');
                    return NavigationActionPolicy.CANCEL;
                  }
                  
                  // Allow only Jitsi Meet domains and related resources
                  final host = uri.host.toLowerCase();
                  final isJitsiDomain = host.contains('meet.jit.si') || 
                                       host.contains('jitsi.net') || 
                                       host.contains('8x8.vc') ||
                                       host.contains('jitsi.org') ||
                                       host.contains('jitsi.com') ||
                                       host.isEmpty; // Allow data URIs
                  
                  // Allow same-origin navigation and Jitsi domains
                  if (isJitsiDomain) {
                    print('[VideoCall] Allowing navigation to Jitsi domain: ${host.isEmpty ? 'data URI' : host}');
                    return NavigationActionPolicy.ALLOW;
                  }
                  
                  // Block all external navigation - keep everything in app
                  print('[VideoCall] Blocking external navigation to: $uri');
                  return NavigationActionPolicy.CANCEL;
                },
                onCreateWindow: (controller, createWindowAction) async {
                  // Prevent popup windows from opening external browser
                  print('[VideoCall] Blocking popup window creation');
                  return false;
                },
                onWindowFocus: (controller) {
                  // Keep focus within the app
                  print('[VideoCall] Window focused - staying in app');
                },
                onWindowBlur: (controller) {
                  // Prevent losing focus to external apps
                  print('[VideoCall] Window blurred');
                },
              ),
              // Loading indicator
              if (_isLoading)
                Container(
                  color: Colors.black,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        SizedBox(height: 24),
                        Text(
                          'Joining video call...',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              // Back button overlay
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () async {
                      final shouldPop = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('End Video Call?'),
                          content: const Text('Are you sure you want to leave the video call?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Leave'),
                            ),
                          ],
                        ),
                      );
                      if (shouldPop == true && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ),
              ),
              // Camera controls overlay at the bottom
              if (!_isLoading && widget.isVideoCall)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Toggle Camera On/Off Button
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isVideoEnabled ? Colors.white.withOpacity(0.2) : Colors.red.withOpacity(0.8),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: _toggleCamera,
                            tooltip: _isVideoEnabled ? 'Turn off camera' : 'Turn on camera',
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Flip Camera Button
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.2),
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.flip_camera_ios,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: _flipCamera,
                            tooltip: 'Switch camera',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
