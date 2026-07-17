import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../app/app_colors.dart';
import '../app/user_session.dart';
import '../location/location_service.dart';
import 'address_repository.dart';
import 'delivery_address.dart';
import 'geoapify_address_service.dart';

class AddressBookPage extends StatefulWidget {
  final AppLocation currentLocation;
  final DeliveryAddress? selectedAddress;

  const AddressBookPage({
    super.key,
    required this.currentLocation,
    this.selectedAddress,
  });

  @override
  State<AddressBookPage> createState() => _AddressBookPageState();
}

class _AddressBookPageState extends State<AddressBookPage> {
  List<DeliveryAddress> _addresses = const [];
  DeliveryAddress? _selectedAddress;
  String _savedPhone = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final phone = await UserSession.getSavedPhone();
    final addresses = await AddressRepository.loadAddresses();
    final selected =
        widget.selectedAddress ??
        await AddressRepository.loadSelectedAddress() ??
        _currentAddress(phone);
    if (!mounted) return;
    setState(() {
      _addresses = addresses;
      _selectedAddress = selected;
      _savedPhone = phone ?? '';
      _loading = false;
    });
  }

  DeliveryAddress _currentAddress([String? phone]) {
    return DeliveryAddress(
      id: 'current-location',
      label: 'Nhà',
      receiverName: 'Người nhận',
      phone: phone ?? _savedPhone,
      address: widget.currentLocation.address,
      latitude: widget.currentLocation.latitude,
      longitude: widget.currentLocation.longitude,
    );
  }

  Future<void> _selectAddress(DeliveryAddress address) async {
    if (address.id != 'current-location') {
      await AddressRepository.select(address.id);
    }
    if (!mounted) return;
    Navigator.pop(context, address);
  }

  Future<void> _openAdd({DeliveryAddress? initial}) async {
    final result = await Navigator.push<DeliveryAddress>(
      context,
      MaterialPageRoute(
        builder: (_) => AddAddressPage(
          initial: initial,
          fallbackLocation: widget.currentLocation,
          fallbackPhone: _savedPhone,
        ),
      ),
    );
    if (result == null) return;
    final normalized = result.normalized();
    await AddressRepository.saveAndSelect(normalized);
    if (!mounted) return;
    Navigator.pop(context, normalized);
  }

  Future<void> _openMapThenAdd() async {
    final picked = await Navigator.push<AddressSuggestion>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddressMapPickerPage(currentLocation: widget.currentLocation),
      ),
    );
    if (picked == null || !mounted) return;
    await _openAdd(
      initial: DeliveryAddress(
        id: 'addr-${DateTime.now().microsecondsSinceEpoch}',
        label: 'Nhà',
        receiverName: '',
        phone: _savedPhone,
        address: picked.address,
        latitude: picked.latitude,
        longitude: picked.longitude,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedAddress ?? _currentAddress();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _AddressAppBar(
        title: 'Địa chỉ giao hàng',
        action: IconButton(
          onPressed: _openMapThenAdd,
          icon: const Icon(Icons.map_outlined, color: AppColors.primary),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: _SearchField(onTap: _openMapThenAdd),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _AddressCard(
                        icon: Icons.location_on_rounded,
                        title: selected.title,
                        address: selected.displayAddress,
                        receiver: selected.receiverName,
                        phone: selected.phone,
                        selected: true,
                        onTap: () => _selectAddress(selected),
                        onEdit: () => _openAdd(initial: selected),
                      ),
                      const _SectionLabel('Địa chỉ đã lưu'),
                      _ActionRow(
                        icon: Icons.business_center_outlined,
                        title: 'Thêm địa chỉ Công ty',
                        onTap: () => _openAdd(
                          initial: _currentAddress().copyWith(label: 'Công ty'),
                        ),
                      ),
                      for (final address in _addresses)
                        if (address.id != selected.id)
                          _AddressCard(
                            icon: Icons.bookmark_border_rounded,
                            title: address.title,
                            address: address.displayAddress,
                            receiver: address.receiverName,
                            phone: address.phone,
                            onTap: () => _selectAddress(address),
                            onEdit: () => _openAdd(initial: address),
                          ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => _openAdd(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'Thêm địa chỉ mới',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class AddAddressPage extends StatefulWidget {
  final DeliveryAddress? initial;
  final AppLocation fallbackLocation;
  final String fallbackPhone;

  const AddAddressPage({
    super.key,
    this.initial,
    required this.fallbackLocation,
    required this.fallbackPhone,
  });

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _detailController;
  late final TextEditingController _gateController;
  late final TextEditingController _noteController;
  late String _label;
  late AddressSuggestion _picked;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.receiverName ?? '');
    _phoneController = TextEditingController(
      text: initial?.phone.isNotEmpty == true
          ? initial!.phone
          : widget.fallbackPhone,
    );
    _detailController = TextEditingController(text: initial?.detail ?? '');
    _gateController = TextEditingController(text: initial?.gate ?? '');
    _noteController = TextEditingController(text: initial?.note ?? '');
    _label = initial?.title ?? 'Nhà';
    _picked = AddressSuggestion(
      title: 'Vị trí đã chọn',
      address: initial?.address ?? widget.fallbackLocation.address,
      latitude: initial?.latitude ?? widget.fallbackLocation.latitude,
      longitude: initial?.longitude ?? widget.fallbackLocation.longitude,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _detailController.dispose();
    _gateController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _picked.address.trim().isNotEmpty;

  Future<void> _chooseAddress() async {
    final picked = await Navigator.push<AddressSuggestion>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressMapPickerPage(
          currentLocation: widget.fallbackLocation,
          initialPoint: LatLng(_picked.latitude, _picked.longitude),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _picked = picked);
  }

  void _save() {
    if (!_canSave) return;
    final initial = widget.initial;
    final address = DeliveryAddress(
      id: initial?.id.startsWith('addr-') == true
          ? initial!.id
          : 'addr-${DateTime.now().microsecondsSinceEpoch}',
      label: _label,
      receiverName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _picked.address,
      detail: _detailController.text.trim(),
      gate: _gateController.text.trim(),
      note: _noteController.text.trim(),
      latitude: _picked.latitude,
      longitude: _picked.longitude,
    ).normalized();
    Navigator.pop(context, address);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const _AddressAppBar(title: 'Thêm địa chỉ mới'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _FormInput(
                  controller: _nameController,
                  hint: 'Tên người nhận',
                  icon: Icons.person_add_alt_outlined,
                  onChanged: (_) => setState(() {}),
                ),
                _FormInput(
                  controller: _phoneController,
                  hint: 'Số điện thoại',
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                ),
                _AddressChooser(
                  address: _picked.address,
                  onTap: _chooseAddress,
                ),
                _FormInput(
                  controller: _detailController,
                  hint: 'Tòa nhà, Số tầng (Không bắt buộc)',
                ),
                _FormInput(
                  controller: _gateController,
                  hint: 'Cổng (không bắt buộc)',
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      for (final label in ['Nhà', 'Công ty', 'Khác'])
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: _label == label,
                            onSelected: (_) => setState(() => _label = label),
                            selectedColor: AppColors.primaryBg,
                            labelStyle: TextStyle(
                              color: _label == label
                                  ? AppColors.primary
                                  : const Color(0xFF212121),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _FormInput(
                  controller: _noteController,
                  hint: 'Ghi chú cho Tài xế (không bắt buộc)',
                  maxLines: 4,
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _canSave ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFE0E0E0),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF9E9E9E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Lưu',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddressMapPickerPage extends StatefulWidget {
  final AppLocation currentLocation;
  final LatLng? initialPoint;

  const AddressMapPickerPage({
    super.key,
    required this.currentLocation,
    this.initialPoint,
  });

  @override
  State<AddressMapPickerPage> createState() => _AddressMapPickerPageState();
}

class _AddressMapPickerPageState extends State<AddressMapPickerPage> {
  final MapController _mapController = MapController();
  Timer? _mapMoveDebounce;
  late LatLng _currentPoint;
  late LatLng _selectedPoint;
  AddressSuggestion? _selectedAddress;
  List<AddressSuggestion> _suggestions = const [];
  bool _loadingAddress = true;
  bool _refreshingCurrentLocation = false;

  @override
  void initState() {
    super.initState();
    _currentPoint = LatLng(
      widget.currentLocation.latitude,
      widget.currentLocation.longitude,
    );
    _selectedPoint = widget.initialPoint ?? _currentPoint;
    _loadAddress(_selectedPoint);
    _loadSuggestions(_selectedPoint);
    _refreshCurrentLocation(moveToFreshPoint: widget.initialPoint == null);
  }

  @override
  void dispose() {
    _mapMoveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadAddress(LatLng point) async {
    setState(() => _loadingAddress = true);
    final address = await GeoapifyAddressService.reverse(
      point.latitude,
      point.longitude,
    );
    if (!mounted) return;
    setState(() {
      _selectedAddress = address;
      _loadingAddress = false;
    });
  }

  Future<void> _loadSuggestions(LatLng point) async {
    final suggestions = await GeoapifyAddressService.nearby(
      point.latitude,
      point.longitude,
      radiusMeters: 200,
    );
    if (!mounted) return;
    setState(() => _suggestions = suggestions);
  }

  void _selectPoint(LatLng point) {
    _mapMoveDebounce?.cancel();
    setState(() {
      _selectedPoint = point;
      _selectedAddress = null;
    });
    _loadAddress(point);
    _loadSuggestions(point);
  }

  void _scheduleCenterPick(LatLng point) {
    _mapMoveDebounce?.cancel();
    setState(() {
      _selectedPoint = point;
      _selectedAddress = null;
      _loadingAddress = true;
    });
    _mapMoveDebounce = Timer(const Duration(milliseconds: 450), () {
      _loadAddress(point);
      _loadSuggestions(point);
    });
  }

  void _useSuggestion(AddressSuggestion suggestion) {
    final point = LatLng(suggestion.latitude, suggestion.longitude);
    _mapController.move(point, 16);
    _mapMoveDebounce?.cancel();
    setState(() {
      _selectedPoint = point;
      _selectedAddress = suggestion;
      _suggestions = const [];
      _loadingAddress = false;
    });
    _loadSuggestions(point);
  }

  void _confirm() {
    final address = _selectedAddress;
    if (address == null) return;
    Navigator.pop(context, address);
  }

  Future<void> _refreshCurrentLocation({bool moveToFreshPoint = true}) async {
    if (_refreshingCurrentLocation) return;
    setState(() => _refreshingCurrentLocation = true);
    final location = await LocationService.getCurrentLocation();
    if (!mounted) return;

    final point = LatLng(location.latitude, location.longitude);
    setState(() {
      _currentPoint = point;
      _refreshingCurrentLocation = false;
    });

    if (!moveToFreshPoint || location.isFallback) return;
    _mapController.move(point, 16);
    _selectPoint(point);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const _AddressAppBar(title: 'Chọn địa chỉ'),
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.46,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _selectedPoint,
                    initialZoom: 15.5,
                    minZoom: 5,
                    maxZoom: 19,
                    onTap: (_, point) {
                      _mapController.move(point, _mapController.camera.zoom);
                      _selectPoint(point);
                    },
                    onPositionChanged: (camera, hasGesture) {
                      if (hasGesture) {
                        _scheduleCenterPick(camera.center);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.shopeefood',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _selectedPoint,
                          radius: 200,
                          useRadiusInMeter: true,
                          color: const Color(
                            0xFF2196F3,
                          ).withValues(alpha: 0.12),
                          borderColor: const Color(
                            0xFF2196F3,
                          ).withValues(alpha: 0.42),
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _currentPoint,
                          width: 36,
                          height: 36,
                          child: const _CurrentLocationDot(),
                        ),
                      ],
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Center(
                    child: Transform.translate(
                      offset: const Offset(0, -14),
                      child: const _SelectedPin(),
                    ),
                  ),
                ),
                Positioned(
                  right: 18,
                  bottom: 18,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter-map',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF212121),
                    onPressed: () {
                      _refreshCurrentLocation();
                    },
                    child: _refreshingCurrentLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const _SectionLabel('Địa chỉ gợi ý'),
                if (_selectedAddress != null || _loadingAddress)
                  _SuggestionTile(
                    title:
                        _selectedAddress?.title ??
                        'Đang xác định vị trí đã ghim',
                    address:
                        _selectedAddress?.address ??
                        'Chọn điểm trên bản đồ để ghim địa chỉ',
                    selected: true,
                    loading: _loadingAddress,
                    onTap: _selectedAddress == null
                        ? null
                        : () => _useSuggestion(_selectedAddress!),
                  ),
                for (final suggestion in _suggestions)
                  _SuggestionTile(
                    title: suggestion.title,
                    address: suggestion.address,
                    onTap: () => _useSuggestion(suggestion),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _selectedAddress == null ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFE0E0E0),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFF9E9E9E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text(
                    'Xác nhận vị trí',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? action;

  const _AddressAppBar({required this.title, this.action});

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      shadowColor: const Color(0x1A000000),
      leadingWidth: 72,
      leading: IconButton(
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(
          Icons.arrow_back_rounded,
          color: AppColors.primary,
          size: 32,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF212121),
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
      actions: [?action],
    );
  }
}

class _SearchField extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchField({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: const Color(0xFFF3F3F3),
        child: const Row(
          children: [
            Icon(Icons.search_rounded, color: Color(0xFF757575), size: 24),
            SizedBox(width: 8),
            Text(
              'Tìm vị trí',
              style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String address;
  final String receiver;
  final String phone;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _AddressCard({
    required this.icon,
    required this.title,
    required this.address,
    required this.receiver,
    required this.phone,
    required this.onTap,
    required this.onEdit,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: selected ? AppColors.primary : const Color(0xFF212121),
                size: 24,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      address,
                      style: const TextStyle(
                        color: Color(0xFF8A8A8A),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    if (receiver.isNotEmpty || phone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        [
                          receiver,
                          phone,
                        ].where((part) => part.isNotEmpty).join('  '),
                        style: const TextStyle(
                          color: Color(0xFF424242),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: onEdit,
                child: const Text('Sửa', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              Icon(icon, size: 26, color: const Color(0xFF212121)),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF757575),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FormInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  const _FormInput({
    required this.controller,
    required this.hint,
    this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 16),
          prefixIcon: icon == null
              ? null
              : Icon(icon, color: AppColors.primary, size: 24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
        ),
        style: const TextStyle(color: Color(0xFF212121), fontSize: 16),
      ),
    );
  }
}

class _AddressChooser extends StatelessWidget {
  final String address;
  final VoidCallback onTap;

  const _AddressChooser({required this.address, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.trim().isNotEmpty;
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 18, 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasAddress ? address : 'Chọn địa chỉ',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasAddress
                        ? const Color(0xFF212121)
                        : const Color(0xFFBDBDBD),
                    fontSize: 16,
                    height: 1.25,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String title;
  final String address;
  final bool selected;
  final bool loading;
  final VoidCallback? onTap;

  const _SuggestionTile({
    required this.title,
    required this.address,
    this.selected = false,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.location_on_outlined,
                      color: selected ? AppColors.primary : Colors.black54,
                    ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF212121),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8A8A8A),
                        fontSize: 14,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentLocationDot extends StatelessWidget {
  const _CurrentLocationDot();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withValues(alpha: 0.30),
              blurRadius: 12,
              spreadRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedPin extends StatelessWidget {
  const _SelectedPin();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.location_on_rounded, color: AppColors.primary, size: 48),
        SizedBox(height: 8),
      ],
    );
  }
}
