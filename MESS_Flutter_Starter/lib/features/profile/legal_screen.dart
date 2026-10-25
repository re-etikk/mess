import 'package:flutter/material.dart';
import '../../core/theme/mess_theme.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.isPrivacy});
  final bool isPrivacy;
  @override
  Widget build(BuildContext context) {
    final title = isPrivacy ? 'Privacy policy' : 'Terms and conditions';
    final sections = isPrivacy
        ? const [
            ('Information handled', 'In production, MESS may process account details, chosen location, plan records, meal redemptions, payment references and support requests needed to provide the service.'),
            ('How information is used', 'Use information to manage subscriptions, verify meal eligibility, prevent duplicate redemptions, handle payments and support customer requests.'),
            ('Permissions', 'Camera permission is requested only for scanning the QR displayed by a participating mess. Location access should be optional and used only for nearby discovery when enabled.'),
            ('Sharing and retention', 'Provider, payment and delivery information should be shared only where necessary to fulfil the requested service. Retention, deletion and access controls must be configured before launch.'),
            ('Your choices', 'Production release must provide a contact channel, account deletion process, and a way to ask privacy questions.'),
          ]
        : const [
            ('Plans and meal limits', 'Each provider defines eligible meal slots, portions, included items, add-on prices, opening hours and plan-specific rules. The checkout summary must show these terms before purchase.'),
            ('Fixed-period plans', 'A fixed-period plan provides access during its start and end dates, subject to the provider’s published daily slot limits. Meal attendance may be recorded, but meal credits are not deducted.'),
            ('Meal-tracker plans', 'Meal credits are deducted only after successful redemption. Credits and validity are both enforced; the limit reached first ends eligibility. Unused credit treatment must be shown at purchase.'),
            ('Daily meals and extras', 'A daily meal is eligible only after confirmed payment. Optional dishes and extra portions are charged according to the displayed price and quantity.'),
            ('QR redemption', 'Only current, provider-bound QR tokens verified by the production server can redeem meals. A successful camera read alone does not confirm a redemption.'),
            ('Refunds and support', 'Cancellation, refund, provider closure and dispute policies must be published for the applicable plan and reviewed before production launch.'),
          ];
    return Scaffold(appBar: AppBar(leading: IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded)), title: Text(title)), body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
      Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFFFE8BF), borderRadius: BorderRadius.circular(13)), child: Text('Draft for product review. This is not the final legal text. Have the production policy reviewed and update it to match the actual business and applicable laws.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
      const SizedBox(height: 20),
      for (final section in sections) Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(section.$1, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6), Text(section.$2, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: MessColors.muted, height: 1.55))])),
      Text('Last reviewed: Not yet reviewed', style: Theme.of(context).textTheme.bodySmall),
    ]));
  }
}
