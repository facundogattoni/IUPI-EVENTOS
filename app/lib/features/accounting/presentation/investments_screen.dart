import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../data/accounting_repository.dart';
import '../domain/capital_asset.dart';

/// Inversiones / bienes de capital: total invertido, amortización mensual y
/// progreso de amortización de cada bien.
class InvestmentsScreen extends ConsumerWidget {
  const InvestmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(assetsProvider);
    return assetsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text('Solo administradores.\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted))),
      data: (assets) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(assetsProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FilledButton.icon(
              onPressed: () => _showEdit(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar inversión'),
            ),
            const SizedBox(height: 16),
            _Summary(assets: assets),
            const SizedBox(height: 16),
            if (assets.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'Cargá lo que invertiste: inflable, hornos, aires, juegos, mobiliario...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              for (final a in assets) _AssetTile(asset: a, ref: ref),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.assets});
  final List<CapitalAsset> assets;

  @override
  Widget build(BuildContext context) {
    final totalArs = assets.fold<double>(0, (s, a) => s + a.costArs);
    final totalUsd =
        assets.fold<double>(0, (s, a) => s + (a.costUsd ?? 0));
    final monthly =
        assets.where((a) => !a.fullyAmortized).fold<double>(
            0, (s, a) => s + a.monthlyDepreciation);
    final pending =
        assets.fold<double>(0, (s, a) => s + a.bookValue);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total invertido',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(Fmt.money(totalArs),
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brand)),
          if (totalUsd > 0)
            Text(Fmt.usd(totalUsd),
                style: const TextStyle(
                    fontSize: 14, color: AppColors.income)),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(
                child: _mini('Amortización / mes', Fmt.money(monthly),
                    AppColors.expense),
              ),
              Expanded(
                child: _mini('Falta amortizar', Fmt.money(pending),
                    AppColors.info),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        ],
      );
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset, required this.ref});
  final CapitalAsset asset;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => _showEdit(context, ref, existing: asset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(asset.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(
                        '${asset.category ?? 'otro'} · ${Fmt.date(asset.purchaseDate)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Fmt.money(asset.costArs),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (asset.costUsd != null)
                      Text(Fmt.usd(asset.costUsd!),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.income)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: asset.progress.clamp(0, 1),
                minHeight: 7,
                backgroundColor: AppColors.surfaceAlt,
                color: asset.fullyAmortized
                    ? AppColors.income
                    : AppColors.brand,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              asset.fullyAmortized
                  ? '✅ Amortizado (ya se recuperó contablemente)'
                  : 'Amortizado ${(asset.progress * 100).round()}% · '
                      'faltan ${asset.remainingMonths} meses · '
                      '${Fmt.money(asset.monthlyDepreciation)}/mes',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showEdit(BuildContext context, WidgetRef ref,
    {CapitalAsset? existing}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AssetSheet(existing: existing),
  );
}

class _AssetSheet extends ConsumerStatefulWidget {
  const _AssetSheet({this.existing});
  final CapitalAsset? existing;

  @override
  ConsumerState<_AssetSheet> createState() => _AssetSheetState();
}

class _AssetSheetState extends ConsumerState<_AssetSheet> {
  late final TextEditingController _name;
  late final TextEditingController _cost;
  late final TextEditingController _life;
  late final TextEditingController _rate;
  String? _category;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _cost = TextEditingController(
        text: e == null ? '' : e.costArs.toStringAsFixed(0));
    _life = TextEditingController(text: (e?.usefulLifeMonths ?? 60).toString());
    // Dólar de la compra: el guardado (si edita) o la última cotización (si es nuevo).
    final initialRate =
        e?.usdRate ?? ref.read(latestRateProvider).valueOrNull?.usdArs;
    _rate = TextEditingController(
        text: initialRate == null ? '' : initialRate.toStringAsFixed(0));
    _category = e?.category;
    _date = e?.purchaseDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _life.dispose();
    _rate.dispose();
    super.dispose();
  }

  double _toDouble(String s) =>
      double.tryParse(s.trim().replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    final cost = _toDouble(_cost.text);
    if (_name.text.trim().isEmpty || cost <= 0) return;
    setState(() => _saving = true);

    // Dólar de la compra (lo que cargó el usuario, editable).
    final rateVal = _toDouble(_rate.text);
    final usdRate = rateVal > 0 ? rateVal : null;

    final asset = CapitalAsset(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      category: _category,
      purchaseDate: _date,
      costArs: cost,
      usdRate: usdRate,
      usefulLifeMonths: int.tryParse(_life.text.trim()) ?? 60,
    );
    try {
      await ref
          .read(accountingRepositoryProvider)
          .upsertAsset(asset, id: widget.existing?.id);
      ref.invalidate(assetsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rate = ref.watch(latestRateProvider).valueOrNull;
    final cost = _toDouble(_cost.text);
    final usdPreview = _toDouble(_rate.text) > 0 ? _toDouble(_rate.text) : null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Nueva inversión' : 'Editar inversión',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Qué es (ej: Horno industrial)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: [
                for (final c in kAssetCategories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cost,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'Costo', prefixText: r'$ '),
            ),
            if (cost > 0 && usdPreview != null && usdPreview > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text('≈ ${Fmt.usd(cost / usdPreview)} (dólar $usdPreview)',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.income)),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _rate,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Dólar de la compra (\$ por USD)',
                helperText: 'Cuánto valía el dólar cuando lo compraste',
                prefixText: r'$ ',
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _life,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Vida útil (meses)',
                      helperText: 'Ej: 60 = 5 años'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2010),
                      lastDate: DateTime(2035),
                      locale: const Locale('es', 'AR'),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: InputDecorator(
                    decoration:
                        const InputDecoration(labelText: 'Fecha de compra'),
                    child: Text(Fmt.date(_date)),
                  ),
                ),
              ),
            ]),
            if (rate == null && widget.existing == null)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '💡 Cargá primero el dólar en Finanzas → Dólar para guardar el valor en USD.',
                  style: TextStyle(fontSize: 12, color: AppColors.expense),
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
            if (widget.existing != null)
              TextButton.icon(
                onPressed: () async {
                  await ref
                      .read(accountingRepositoryProvider)
                      .deleteAsset(widget.existing!.id);
                  ref.invalidate(assetsProvider);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                label: const Text('Eliminar',
                    style: TextStyle(color: AppColors.danger)),
              ),
          ],
        ),
      ),
    );
  }
}
