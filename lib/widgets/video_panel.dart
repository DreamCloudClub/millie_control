import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import '../config/robot_config.dart';
import '../utils/constants.dart';

class VideoPanel extends StatelessWidget {
  const VideoPanel({super.key});

  // Video stream from robot's web_video_server
  static String get _streamUrl => RobotConfig.videoStreamUrl();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video stream
          Mjpeg(
            stream: _streamUrl,
            isLive: true,
            fit: BoxFit.contain,
            error: (context, error, stack) {
              return _buildErrorState();
            },
          ),
          
          // Status overlay (top)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: AppColors.accent, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  const Text(
                    'OAK-D Lite',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Text(
                    'LIVE',
                    style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off,
              color: AppColors.textMuted,
              size: 48,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Video stream unavailable',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _streamUrl,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
