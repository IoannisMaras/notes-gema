import 'package:flutter/material.dart';
import '../models/pending_change.dart';

/// Renders a GitHub-style diff review card for an AI-proposed note change.
class PendingChangeCard extends StatefulWidget {
  final PendingChange change;
  final void Function(PendingChange change) onAccept;
  final VoidCallback onReject;

  const PendingChangeCard({
    super.key,
    required this.change,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<PendingChangeCard> createState() => _PendingChangeCardState();
}

class _PendingChangeCardState extends State<PendingChangeCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.change;
    final String formattedOld = item.isAppend
        ? ''
        : item.oldText.split('\n').map((e) => '- $e').join('\n');
    final String formattedNew =
        item.newText.split('\n').map((e) => '+ $e').join('\n');
    final String diffRaw = item.isAppend
        ? '@@ APPEND @@\n$formattedNew'
        : '@@ REPLACE @@\n$formattedOld\n$formattedNew';

    return Container(
      color: Colors.black45,
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '> AI PROPOSED CHANGES:',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...diffRaw.split('\n').map((line) {
            Color c = Colors.white70;
            if (line.startsWith('+')) c = Colors.greenAccent;
            if (line.startsWith('-')) c = Colors.redAccent;
            if (line.startsWith('@@')) c = Colors.blueAccent;
            return Text(
              line,
              style: TextStyle(color: c, fontFamily: 'Courier', fontSize: 13),
            );
          }),
          const SizedBox(height: 12),
          if (!item.isResolved)
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.2),
                    foregroundColor: Colors.greenAccent,
                  ),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('ACCEPT'),
                  onPressed: () {
                    setState(() => item.isResolved = item.isAccepted = true);
                    widget.onAccept(item);
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('REJECT'),
                  onPressed: () {
                    setState(() {
                      item.isResolved = true;
                      item.isAccepted = false;
                    });
                    widget.onReject();
                  },
                ),
              ],
            )
          else
            Text(
              item.isAccepted ? '[MERGED]' : '[REJECTED]',
              style: TextStyle(
                color: item.isAccepted ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}
