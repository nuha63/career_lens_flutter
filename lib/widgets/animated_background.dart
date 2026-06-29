import 'dart:async';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  final bool isSlideshow;
  final String? staticImage;

  const AnimatedBackground({
    super.key,
    required this.child,
    this.isSlideshow = false,
    this.staticImage,
  });

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground> {
  final List<String> _slideshowImages = [
    'assets/images/image1.jpg',
    'assets/images/image2.jpg',
    'assets/images/image3.avif',
  ];
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isSlideshow) {
      // Precache first few images if possible (optional)
      _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % _slideshowImages.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget backgroundLayer;

    if (widget.isSlideshow) {
      backgroundLayer = AnimatedSwitcher(
        duration: const Duration(milliseconds: 1500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Container(
          key: ValueKey<int>(_currentIndex),
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_slideshowImages[_currentIndex]),
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    } else if (widget.staticImage != null) {
      backgroundLayer = Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(widget.staticImage!),
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      // Fallback simple background if no image is used
      backgroundLayer = Container(
        color: Theme.of(context).scaffoldBackgroundColor,
      );
    }

    return Stack(
      children: [
        backgroundLayer,
        // Add a dark overlay so that the UI text remains readable on top of images
        Container(
          color: Colors.black.withOpacity(0.4),
        ),
        widget.child,
      ],
    );
  }
}
