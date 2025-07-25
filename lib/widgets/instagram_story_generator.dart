import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import '../models/bite_model.dart';

class InstagramStoryGenerator extends StatelessWidget {
  final BiteModel bite;
  final String personalComment;
  final int snippetDuration;
  final ScreenshotController screenshotController;

  const InstagramStoryGenerator({
    Key? key,
    required this.bite,
    required this.personalComment,
    required this.snippetDuration,
    required this.screenshotController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Screenshot(
      controller: screenshotController,
      child: AspectRatio(
        aspectRatio: 9.0 / 16.0, // Instagram Story aspect ratio
        child: Container(
          width: 1080, // Instagram story width
          height: 1920, // Instagram story height
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF56500), // Pumpkin orange
                const Color(0xFFFF8C42), // Lighter orange
                const Color(0xFFFFB366), // Even lighter
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top section - App branding
                  _buildTopSection(),
                  
                  // Middle section - Bite content
                  Expanded(
                    child: _buildMiddleSection(),
                  ),
                  
                  // Bottom section - Call to action
                  _buildBottomSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Column(
      children: [
        // App logo/icon placeholder
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.headphones,
            size: 40,
            color: Color(0xFFF56500),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'PUMPKIN BITES',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildMiddleSection() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bite title
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                bite.title,
                style: const TextStyle(
                  color: Color(0xFF2C2C2C),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF56500),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'DAY ${bite.dayNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.play_circle_filled,
                    color: Color(0xFFF56500),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${snippetDuration}s snippet',
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Personal comment if provided
        if (personalComment.isNotEmpty) ...[
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.format_quote,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Personal Note',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  personalComment,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        // Category badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.category,
                color: Color(0xFFF56500),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                bite.category,
                style: const TextStyle(
                  color: Color(0xFF2C2C2C),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Call to action
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Listen to the full bite',
                style: TextStyle(
                  color: Color(0xFF2C2C2C),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Download Pumpkin Bites App',
                style: TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF56500),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'pumpkinbites.app',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}