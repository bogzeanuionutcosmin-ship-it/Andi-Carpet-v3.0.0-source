part of '../main.dart';

class _Page extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final Widget child;
  const _Page({required this.title, required this.subtitle, this.actions = const [], required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (c, box) {
      final accent = sectionAccent(title);
      final mobile = box.maxWidth < 600;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(mobile ? 12 : 26, mobile ? 14 : 22, mobile ? 12 : 26, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: .90),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 6))],
              ),
              child: _activeAppSettingsForBranding == null
                  ? Image.asset('assets/logos/standard.jpg',height:mobile?80:112,width:mobile?250:360,fit:BoxFit.contain)
                  : appBrandLogo(_activeAppSettingsForBranding!,height:mobile?80:112,width:mobile?250:360),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent.withValues(alpha: .23), Theme.of(context).colorScheme.surface.withValues(alpha: .94)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: .40)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 16, offset: const Offset(0, 5))],
            ),
            child: mobile
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(width: 6, height: 42, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: accent))),
                    ]),
                    const SizedBox(height: 5),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: actions),
                    ],
                  ])
                : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Container(width: 6, height: 48, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(99))),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: accent)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    ])),
                    ...actions.map((x) => Padding(padding: const EdgeInsets.only(left: 8), child: x)),
                  ]),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(mobile ? 12 : 18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? .94 : .975),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .55)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .07), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: child,
          ),
        ]),
      );
    },
  );
}

