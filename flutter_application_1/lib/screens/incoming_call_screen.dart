import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/call_service.dart';
import 'video_call_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String roomName;
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final bool isVideoCall;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.roomName,
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl,
    this.isVideoCall = true,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _ringController1;
  late AnimationController _ringController2;
  late AnimationController _ringController3;
  bool _isProcessing = false;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
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
    // Auto-reject if call is not accepted within 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted && !_isProcessing) {
        _rejectCall();
      }
    });
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

  @override
  void dispose() {
    _stopRingtone();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _ringController1.dispose();
    _ringController2.dispose();
    _ringController3.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    await _stopRingtone();
    final result = await CallService.acceptCall(widget.callId);
    if (!mounted) return;

    if (result['success'] == true) {
      // Navigate to video call screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => VideoCallScreen(
            roomName: widget.roomName,
            peerName: widget.callerName,
            peerAvatarUrl: widget.callerAvatarUrl,
            isVideoCall: widget.isVideoCall,
          ),
        ),
      );
    } else {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to accept call')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _rejectCall() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    await _stopRingtone();
    await CallService.rejectCall(widget.callId);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _rejectCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Ring effects with avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Expanding ring 1
                    AnimatedBuilder(
                      animation: _ringController1,
                      builder: (context, child) {
                        return Container(
                          width: 200 + (_ringController1.value * 150),
                          height: 200 + (_ringController1.value * 150),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green.withOpacity(0.6 * (1 - _ringController1.value)),
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
                          width: 200 + (_ringController2.value * 150),
                          height: 200 + (_ringController2.value * 150),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green.withOpacity(0.6 * (1 - _ringController2.value)),
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
                          width: 200 + (_ringController3.value * 150),
                          height: 200 + (_ringController3.value * 150),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green.withOpacity(0.6 * (1 - _ringController3.value)),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                    // Caller Avatar with pulse animation
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Container(
                          width: 200 + (_pulseController.value * 20),
                          height: 200 + (_pulseController.value * 20),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.green.withOpacity(0.5 - (_pulseController.value * 0.3)),
                              width: 3,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 100,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: widget.callerAvatarUrl != null && widget.callerAvatarUrl!.isNotEmpty
                                ? NetworkImage(widget.callerAvatarUrl!)
                                : null,
                            child: widget.callerAvatarUrl == null || widget.callerAvatarUrl!.isEmpty
                                ? Text(
                                    widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : 'U',
                                    style: const TextStyle(fontSize: 80, color: Colors.white),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Caller Name
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                // Call Type
                Text(
                  widget.isVideoCall ? 'Incoming Video Call' : 'Incoming Voice Call',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const Spacer(),
                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Reject Button
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.call_end, color: Colors.white, size: 32),
                        onPressed: _isProcessing ? null : _rejectCall,
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Accept Button
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                      child: _isProcessing
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 3,
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.call, color: Colors.white, size: 32),
                              onPressed: _acceptCall,
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

