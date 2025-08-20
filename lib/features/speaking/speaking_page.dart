import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpeakingPage extends StatelessWidget {
  final dynamic examples; // optional: API response
  const SpeakingPage({super.key, this.examples});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final double cardWidth = math.min(520.0, screenW - 40);
    final double cardHeight = 380.0;

    final double shadowOffsetY = cardWidth * 0.045;
    final double shadowBlur = cardWidth * 0.08;
    final double shadowSpread = -cardWidth * 0.01;
    const double cardRadius = 24.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('스피킹 연습')),
      // Slightly above vertical center
      body: Align(
        alignment: const Alignment(0, -0.2),
        child: SizedBox(
          width: cardWidth,
          height: cardHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(
                color: const Color(0xFF0F172A).withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  offset: Offset(0, shadowOffsetY),
                  blurRadius: shadowBlur,
                  spreadRadius: shadowSpread,
                  color: const Color(0xFF0F172A).withOpacity(0.12),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "This is my first time traveling here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                      height: 1.3,
                      letterSpacing: -0.01,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '이 곳을 여행하는 건 처음이에요.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF475569),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
