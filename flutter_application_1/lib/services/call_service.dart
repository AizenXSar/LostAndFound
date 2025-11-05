import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Get caller information from Firestore (users or admins collection)
  static Future<Map<String, String>> _getCallerInfo(String userId) async {
    String callerName = 'User';
    String callerAvatarUrl = '';
    
    try {
      // Try users collection first
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      if (userData != null) {
        final rawName = (userData['name'] as String?)?.trim() ?? '';
        callerName = rawName.isNotEmpty ? rawName : ((userData['fullName'] as String?)?.trim() ?? 'User');
        callerAvatarUrl = (userData['profileImageUrl'] as String?)?.trim() ?? '';
      }
      
      // If not found in users, try admins collection
      if (callerName == 'User' || callerAvatarUrl.isEmpty) {
        try {
          final adminDoc = await _firestore.collection('admins').doc(userId).get();
          final adminData = adminDoc.data();
          if (adminData != null) {
            if (callerName == 'User') {
              final rawName = (adminData['name'] as String?)?.trim() ?? '';
              callerName = rawName.isNotEmpty ? rawName : ((adminData['fullName'] as String?)?.trim() ?? 'User');
            }
            if (callerAvatarUrl.isEmpty) {
              callerAvatarUrl = (adminData['profileImageUrl'] as String?)?.trim() ?? '';
            }
          }
        } catch (_) {}
      }
    } catch (_) {
      // Fallback to Firebase Auth user info
      final currentUser = _auth.currentUser;
      if (currentUser != null && currentUser.uid == userId) {
        callerName = currentUser.displayName ?? currentUser.email ?? 'User';
        callerAvatarUrl = currentUser.photoURL ?? '';
      }
    }
    
    return {'name': callerName, 'avatarUrl': callerAvatarUrl};
  }

  /// Start an audio call - sends invitation to peer user
  static Future<Map<String, dynamic>> startAudioCall({
    required String peerUserId,
    required String peerName,
    String? peerAvatarUrl,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final callerId = currentUser.uid;
      
      // Get caller info from Firestore
      final callerInfo = await _getCallerInfo(callerId);
      final callerName = callerInfo['name'] ?? 'User';
      final callerAvatarUrl = callerInfo['avatarUrl'] ?? '';

      // Generate unique room name based on user IDs
      final roomName = _generateRoomName(callerId, peerUserId);

      // Create call invitation document
      final callDoc = _firestore.collection('calls').doc();
      final callId = callDoc.id;

      await callDoc.set({
        'callId': callId,
        'roomName': roomName,
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatarUrl': callerAvatarUrl,
        'peerId': peerUserId,
        'peerName': peerName,
        'peerAvatarUrl': peerAvatarUrl ?? '',
        'status': 'ringing', // ringing, accepted, rejected, ended
        'type': 'audio', // video or audio
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Call initiated',
        'callId': callId,
        'roomName': roomName,
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to start call: ${e.toString()}'};
    }
  }

  /// Start a video call - sends invitation to peer user
  static Future<Map<String, dynamic>> startVideoCall({
    required String peerUserId,
    required String peerName,
    String? peerAvatarUrl,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }

      final callerId = currentUser.uid;
      
      // Get caller info from Firestore
      final callerInfo = await _getCallerInfo(callerId);
      final callerName = callerInfo['name'] ?? 'User';
      final callerAvatarUrl = callerInfo['avatarUrl'] ?? '';

      // Generate unique room name based on user IDs
      final roomName = _generateRoomName(callerId, peerUserId);

      // Create call invitation document
      final callDoc = _firestore.collection('calls').doc();
      final callId = callDoc.id;

      await callDoc.set({
        'callId': callId,
        'roomName': roomName,
        'callerId': callerId,
        'callerName': callerName,
        'callerAvatarUrl': callerAvatarUrl,
        'peerId': peerUserId,
        'peerName': peerName,
        'peerAvatarUrl': peerAvatarUrl ?? '',
        'status': 'ringing', // ringing, accepted, rejected, ended
        'type': 'video', // video or audio
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Call initiated',
        'callId': callId,
        'roomName': roomName,
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to start call: ${e.toString()}'};
    }
  }

  /// Accept an incoming call
  static Future<Map<String, dynamic>> acceptCall(String callId) async {
    try {
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      if (!callDoc.exists) {
        return {'success': false, 'message': 'Call not found'};
      }

      final callData = callDoc.data()!;
      if (callData['status'] != 'ringing') {
        return {'success': false, 'message': 'Call is no longer available'};
      }

      await _firestore.collection('calls').doc(callId).update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {
        'success': true,
        'message': 'Call accepted',
        'roomName': callData['roomName'],
        'callerId': callData['callerId'],
        'callerName': callData['callerName'],
        'callerAvatarUrl': callData['callerAvatarUrl'],
      };
    } catch (e) {
      return {'success': false, 'message': 'Failed to accept call: ${e.toString()}'};
    }
  }

  /// Reject an incoming call
  static Future<Map<String, dynamic>> rejectCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'message': 'Call rejected'};
    } catch (e) {
      return {'success': false, 'message': 'Failed to reject call: ${e.toString()}'};
    }
  }

  /// End a call
  static Future<void> endCall(String callId) async {
    try {
      await _firestore.collection('calls').doc(callId).update({
        'status': 'ended',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error ending call: $e');
    }
  }

  /// Get active call for current user
  static Stream<QuerySnapshot<Map<String, dynamic>>>? getActiveCallStream(String userId) {
    try {
      return _firestore
          .collection('calls')
          .where('peerId', isEqualTo: userId)
          .where('status', isEqualTo: 'ringing')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots();
    } catch (e) {
      print('Error getting active call stream: $e');
      return null;
    }
  }

  /// Generate unique room name from two user IDs
  static String generateRoomName(String userId1, String userId2) {
    // Sort IDs to ensure consistent room name regardless of caller
    final sortedIds = [userId1, userId2]..sort();
    final combined = '${sortedIds[0]}_${sortedIds[1]}';
    // Remove special characters and make lowercase
    final roomName = combined.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
    return 'lostandfound_$roomName';
  }

  /// Generate unique room name from two user IDs (private method for internal use)
  static String _generateRoomName(String userId1, String userId2) {
    return generateRoomName(userId1, userId2);
  }
}

