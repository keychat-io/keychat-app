import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:keychat/constants/legal_links.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalConsentWidget extends StatelessWidget {
  const LegalConsentWidget({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: value,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              onChanged: (checked) => onChanged(checked ?? false),
            ),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('I agree to the ', style: textStyle),
                _LegalLinkButton(
                  label: 'Terms & Conditions',
                  url: LegalLinks.termsConditions,
                  style: textStyle,
                ),
                Text(' and ', style: textStyle),
                _LegalLinkButton(
                  label: 'Privacy Policy',
                  url: LegalLinks.privacyPolicy,
                  style: textStyle,
                ),
                Text('.', style: textStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalLinkButton extends StatelessWidget {
  const _LegalLinkButton({
    required this.label,
    required this.url,
    required this.style,
  });

  final String label;
  final String url;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final linkColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () async {
        final launched = await launchUrl(Uri.parse(url));
        if (!launched) {
          await EasyLoading.showError('Unable to open link');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: style?.copyWith(
            color: linkColor,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
