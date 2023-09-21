import 'package:flutter/material.dart';

class UsageCard extends StatelessWidget {
  final double usageGB;
  final double capacityGB;

  const UsageCard({
    Key? key,
    required this.usageGB,
    required this.capacityGB,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate the percentage of usage
    double percentage = (usageGB / capacityGB) * 100.0;

    // Determine the theme brightness
    Brightness themeBrightness = Theme.of(context).brightness;

    // Define the colors based on usage and theme brightness
    Color progressBarColor = percentage > 100 ? Colors.red : Colors.blue;
    Color textColor = percentage > 100
        ? Colors.red
        : themeBrightness == Brightness.dark
            ? Colors.white
            : Colors.black;

    return Card(
      elevation: 4.0,
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Storage Usage',
              style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            LinearProgressIndicator(
              value: percentage > 100 ? 1.0 : percentage / 100.0,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(progressBarColor),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Usage: $usageGB GB / $capacityGB GB',
              style: TextStyle(
                fontSize: 16.0,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
