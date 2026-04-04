class PendingChange {
  final String oldText;
  final String newText;
  final bool isAppend;
  bool isResolved;
  bool isAccepted;

  PendingChange({
    required this.oldText,
    required this.newText,
    required this.isAppend,
    this.isResolved = false,
    this.isAccepted = false,
  });
}
