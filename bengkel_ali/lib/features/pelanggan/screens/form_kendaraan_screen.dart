import 'package:flutter/material.dart';
import '../services/pelanggan_service.dart';

class FormKendaraanScreen extends StatefulWidget {
  const FormKendaraanScreen({super.key});
  @override
  State<FormKendaraanScreen> createState() => _FormKendaraanScreenState();
}

class _FormKendaraanScreenState extends State<FormKendaraanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _merkCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _polisiCtrl = TextEditingController();
  final _warnaCtrl = TextEditingController();
  final _tahunCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    for (final c in [
      _merkCtrl,
      _modelCtrl,
      _polisiCtrl,
      _warnaCtrl,
      _tahunCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final res = await PelangganService.instance.tambahKendaraan({
      'merk': _merkCtrl.text.trim(),
      'model': _modelCtrl.text.trim(),
      'no_polisi': _polisiCtrl.text.trim().toUpperCase(),
      'warna': _warnaCtrl.text.trim(),
      'tahun': _tahunCtrl.text.trim().isNotEmpty
          ? int.tryParse(_tahunCtrl.text.trim())
          : null,
    });

    if (!mounted) return;
    setState(() => _submitting = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res['message'] as String? ?? ''),
      backgroundColor: res['success'] == true ? Colors.green : Colors.red,
    ));
    if (res['success'] == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Kendaraan'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _field(_merkCtrl, 'Merk', 'Honda / Yamaha / Suzuki', Icons.label,
                  req: true),
              const SizedBox(height: 14),
              _field(_modelCtrl, 'Model', 'Vario 125 / NMAX / Mio',
                  Icons.two_wheeler,
                  req: true),
              const SizedBox(height: 14),
              _field(_polisiCtrl, 'No Polisi', 'P 1234 AB', Icons.credit_card,
                  req: true, upper: true),
              const SizedBox(height: 14),
              _field(_warnaCtrl, 'Warna', 'Hitam / Putih / Merah',
                  Icons.color_lens),
              const SizedBox(height: 14),
              _field(_tahunCtrl, 'Tahun', '2020', Icons.date_range,
                  type: TextInputType.number, validator: (v) {
                if (v == null || v.isEmpty) return null;
                final y = int.tryParse(v);
                if (y == null || y < 1990 || y > DateTime.now().year) {
                  return 'Tahun tidak valid';
                }
                return null;
              }),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : const Text('Simpan Kendaraan',
                          style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    String hint,
    IconData icon, {
    bool req = false,
    bool upper = false,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      textCapitalization:
          upper ? TextCapitalization.characters : TextCapitalization.none,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue.shade700),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: validator ??
          (req
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label wajib diisi' : null
              : null),
    );
  }
}
