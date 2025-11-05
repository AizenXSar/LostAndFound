import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/call_service.dart';
import 'video_call_screen.dart';

class CallingScreen extends StatefulWidget {
  final String callId;
  final String roomName;
  final String peerName;
  final String? peerAvatarUrl;
  final bool isVideoCall;

  const CallingScreen({
    super.key,
    required this.callId,
    required this.roomName,
    required this.peerName,
    this.peerAvatarUrl,
    this.isVideoCall = true,
  });

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ringController1;
  late AnimationController _ringController2;
  late AnimationController _ringController3;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSubscription;
  bool _isEnding = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  List<CameraDescription>? _cameras;
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Create multiple ring animations for cascading effect
    _ringController1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _ringController2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _ringController3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Delay each ring animation to create cascading effect
    Future.delayed(const Duration(milliseconds: 0), () => _ringController1.forward());
    Future.delayed(const Duration(milliseconds: 400), () => _ringController2.forward());
    Future.delayed(const Duration(milliseconds: 800), () => _ringController3.forward());

    _playRingtone();
    _listenForCallAcceptance();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (!widget.isVideoCall) return;
    
    try {
      // Request camera permission
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        print('[Calling] Camera permission denied');
        return;
      }

      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        print('[Calling] No cameras available');
        return;
      }

      // Initialize camera (use front camera if available)
      final frontCameraIndex = _cameras!.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      
      _currentCameraIndex = frontCameraIndex >= 0 ? frontCameraIndex : 0;
      final selectedCamera = _cameras![_currentCameraIndex];

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false, // We'll use WebView audio
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        print('[Calling] Camera initialized successfully');
      }
    } catch (e) {
      print('[Calling] Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _playRingtone() async {
    try {
      // Use custom ringtone from assets
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sounds/marimba_soft.mp3'));
      print('[RINGTONE] Started playing custom ringtone: marimba_soft.mp3');
    } catch (e) {
      print('[RINGTONE] Error playing custom ringtone: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _audioPlayer.stop();
      print('[RINGTONE] Stopped audio player');
    } catch (e) {
      print('[RINGTONE] Error stopping audio player: $e');
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras == null || _cameras!.isEmpty || _cameraController == null) return;
    
    try {
      // Get current camera direction
      final currentCamera = _cameras![_currentCameraIndex];
      final isCurrentlyFront = currentCamera.lensDirection == CameraLensDirection.front;
      
      // Find target camera (back if currently front, front if currently back)
      final targetDirection = isCurrentlyFront 
          ? CameraLensDirection.back 
          : CameraLensDirection.front;
      
      final targetCameraIndex = _cameras!.indexWhere(
        (camera) => camera.lensDirection == targetDirection,
      );
      
      // If target camera not found, just switch to next available camera
      if (targetCameraIndex < 0) {
        _currentCameraIndex = (_currentCameraIndex + 1) % _cameras!.length;
      } else {
        _currentCameraIndex = targetCameraIndex;
      }
      
      final newCamera = _cameras![_currentCameraIndex];
      
      // Dispose current controller
      await _cameraController!.dispose();
      
      // Initialize new camera
      _cameraController = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      
      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        final cameraType = newCamera.lensDirection == CameraLensDirection.back ? 'back' : 'front';
        print('[Calling] Camera switched to $cameraType camera successfully');
      }
    } catch (e) {
      print('[Calling] Error flipping camera: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  void _listenForCallAcceptance() {
    final callDocRef = FirebaseFirestore.instance.collection('calls').doc(widget.callId);
    _callSubscription = callDocRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) {
        if (mounted && !_isEnding) {
          await _stopRingtone();
          Navigator.of(context).pop();
        }
        return;
      }

      final callData = snapshot.data()!;
      final status = callData['status'] as String?;

      if (status == 'accepted' && mounted && !_isEnding) {
        await _stopRingtone();
        // Navigate to video call screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              roomName: widget.roomName,
              peerName: widget.peerName,
              peerAvatarUrl: widget.peerAvatarUrl,
              isVideoCall: widget.isVideoCall,
            ),
          ),
        );
      } else if (status == 'rejected' || status == 'ended') {
        await _stopRingtone();
        if (mounted && !_isEnding) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    setState(() => _isEnding = true);

    await _stopRingtone();
    await CallService.endCall(widget.callId);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _stopRingtone();
    _audioPlayer.dispose();
    _cameraController?.dispose();
    _pulseController.dispose();
    _ringController1.dispose();
    _ringController2.dispose();
    _ringController3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Camera preview for caller (if available) - shows while calling
              if (_isCameraInitialized && _cameraController != null && widget.isVideoCall)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Stack(
                    children: [
                      // Camera preview without border/outline
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 130,
                          height: 173, // 16:9 aspect ratio
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                      // Flip camera button overlay
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withOpacity(0.6),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1.5,
                            ),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.flip_camera_ios,
                              color: Colors.white,
                              size: 22,
                            ),
                            onPressed: _flipCamera,
                            tooltip: 'Switch camera',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    // Profile image with name directly below
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ring effects with avatar
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Expanding ring 1
                            AnimatedBuilder(
                              animation: _ringController1,
                              builder: (context, child) {
                                return Container(
                                  width: 140 + (_ringController1.value * 120),
                                  height: 140 + (_ringController1.value * 120),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.6 * (1 - _ringController1.value)),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Expanding ring 2
                            AnimatedBuilder(
                              animation: _ringController2,
                              builder: (context, child) {
                                return Container(
                                  width: 140 + (_ringController2.value * 120),
                                  height: 140 + (_ringController2.value * 120),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.6 * (1 - _ringController2.value)),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Expanding ring 3
                            AnimatedBuilder(
                              animation: _ringController3,
                              builder: (context, child) {
                                return Container(
                                  width: 140 + (_ringController3.value * 120),
                                  height: 140 + (_ringController3.value * 120),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.6 * (1 - _ringController3.value)),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Peer Avatar with pulse animation
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Container(
                                  width: 140 + (_pulseController.value * 15),
                                  height: 140 + (_pulseController.value * 15),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.blue.withOpacity(0.5 - (_pulseController.value * 0.3)),
                                      width: 2.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 70,
                                    backgroundColor: Colors.grey[800],
                                    backgroundImage: widget.peerAvatarUrl != null && widget.peerAvatarUrl!.isNotEmpty
                                        ? NetworkImage(widget.peerAvatarUrl!)
                                        : null,
                                    child: widget.peerAvatarUrl == null || widget.peerAvatarUrl!.isEmpty
                                        ? Text(
                                            widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : 'U',
                                            style: const TextStyle(
                                              fontSize: 56,
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Peer Name
                        Text(
                          widget.peerName,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Call Status
                        Text(
                          'Calling...',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                // End Call Button
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: _isEnding
                      ? const Padding(
                          padding: EdgeInsets.all(22),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeWidth: 3,
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.call_end, color: Colors.white, size: 34),
                          onPressed: _endCall,
                        ),
                ),
                const SizedBox(height: 50),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

