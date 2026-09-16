import "package:flutter/material.dart";
import "../config/theme.dart";
import "admin_scaffold.dart";

class ApprovalGate extends StatelessWidget {
  const ApprovalGate({
    super.key,
    required this.stepLabel,
    required this.details,
    required this.onApprove,
    this.onBack,
    this.busy = false,
    this.approveLabel = "Haan, aage badho",
    this.canApprove = true,
  });

  final String stepLabel;
  final Widget details;
  final VoidCallback onApprove;
  final VoidCallback? onBack;
  final bool busy;
  final String approveLabel;
  final bool canApprove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          stepLabel,
          style: const TextStyle(
            color: AdminTheme.accent,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: details),
        const SizedBox(height: 12),
        Row(
          children: [
            if (onBack != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onBack,
                  child: const Text("Peeche"),
                ),
              ),
            if (onBack != null) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: PrimaryBtn(
                label: approveLabel,
                onTap: canApprove ? onApprove : null,
                busy: busy,
                color: AdminTheme.ok,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
