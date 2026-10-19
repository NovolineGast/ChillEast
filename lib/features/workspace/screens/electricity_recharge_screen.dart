import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/electricity_service.dart';
import '../services/campus_card_service.dart';
import '../models/electricity_model.dart';
import '../providers/electricity_cache_provider.dart';
import 'payment_result_screen.dart';
import 'campus_card_payment_sheet.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/l10n_extension.dart';

class ElectricityRechargeScreen extends ConsumerStatefulWidget {
  final int initialSlot;

  const ElectricityRechargeScreen({super.key, this.initialSlot = 0});

  @override
  ConsumerState<ElectricityRechargeScreen> createState() => _ElectricityRechargeScreenState();
}

class _CardSlotState {
  ElectricityArea? selectedArea;
  ElectricityBuilding? selectedBuilding;
  ElectricityRoom? selectedRoom;
  List<ElectricityBuilding> buildings = [];
  List<ElectricityRoom> rooms = [];
  ElectricityBalanceInfo? balanceInfo;
  bool isLoadingBalance = false;
  String? balanceError;
}

class _ElectricityRechargeScreenState extends ConsumerState<ElectricityRechargeScreen> {
  final _logger = AppLogger.instance;
  final TextEditingController _amountController = TextEditingController();

  bool _isLoading = true;
  String? _error;

  List<ElectricityArea> _areas = [];
  final List<_CardSlotState> _cardSlots = [
    _CardSlotState(),
    _CardSlotState(),
  ];
  late int _expandedIndex;

  double? _selectedAmount;
  final List<double> _presetAmounts = [10, 20, 50, 100];
  CampusCardInfo? _cardInfo;
  bool _isPaying = false;

  @override
  void initState() {
    super.initState();
    _expandedIndex = widget.initialSlot.clamp(0, 1);
    _initData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = ref.read(electricityServiceProvider);
      _areas = await service.getAreas();

      for (int slot = 0; slot < 2; slot++) {
        final savedRoom = await service.getSavedRoom(slot: slot);
        final card = _cardSlots[slot];

        if (_areas.isNotEmpty) {
          ElectricityArea? targetArea;
          if (savedRoom != null && savedRoom.areaName.isNotEmpty) {
            targetArea = _areas.where((e) => e.name == savedRoom.areaName).firstOrNull;
          } else if (slot == 0) {
            targetArea = _areas.first;
          }
          card.selectedArea = targetArea;

          if (card.selectedArea != null) {
            card.buildings = await service.getBuildings(card.selectedArea!.name);
            ElectricityBuilding? targetBuilding;
            if (savedRoom != null && savedRoom.buildingName.isNotEmpty) {
              targetBuilding = card.buildings.where((e) => e.name == savedRoom.buildingName).firstOrNull;
            } else if (slot == 0) {
              targetBuilding = card.buildings.isNotEmpty ? card.buildings.first : null;
            }
            card.selectedBuilding = targetBuilding;

            if (card.selectedBuilding != null) {
              card.rooms = await service.getRooms(card.selectedArea!.name, card.selectedBuilding!.name);
              ElectricityRoom? targetRoom;
              if (savedRoom != null && savedRoom.roomId.isNotEmpty) {
                targetRoom = card.rooms.where((e) => e.id == savedRoom.roomId || e.name == savedRoom.roomName).firstOrNull;
              } else if (slot == 0) {
                targetRoom = card.rooms.isNotEmpty ? card.rooms.first : null;
              }
              card.selectedRoom = targetRoom;
            }
          }

          if (card.selectedRoom != null) {
            final savedBalance = await service.getSavedBalance(slot: slot);
            if (savedBalance != null) {
              card.balanceInfo = savedBalance;
            }
            _saveSlotSelection(slot);
          }
        }
      }

      // 静默后台预加载校园卡信息
      ref.read(campusCardServiceProvider).fetchRechargeInfo().then((info) {
        if (mounted) setState(() => _cardInfo = info);
      }).catchError((e) {
        _logger.w('Pre-fetching campus card info error: $e');
      });

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        for (int slot = 0; slot < 2; slot++) {
          if (_cardSlots[slot].selectedRoom != null) {
            _loadBalance(slot);
          }
        }
      }
    } catch (e) {
      _logger.e('Failed to init electricity data: $e');
      if (mounted) {
        setState(() {
          _error = context.l10n.loadListFailedRetry;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBalance(int slot) async {
    final card = _cardSlots[slot];
    if (card.selectedArea == null || card.selectedBuilding == null || card.selectedRoom == null) {
      if (mounted) {
        setState(() {
          card.balanceInfo = null;
          card.balanceError = null;
          card.isLoadingBalance = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        card.isLoadingBalance = true;
        card.balanceError = null;
      });
    }

    try {
      final service = ref.read(electricityServiceProvider);
      final info = await service.getBalance(
        areaName: card.selectedArea!.name,
        buildingName: card.selectedBuilding!.name,
        roomId: card.selectedRoom!.id,
        mertype: card.selectedRoom!.mertype,
        slot: slot,
      );
      if (mounted) {
        setState(() {
          card.balanceInfo = info;
          card.isLoadingBalance = false;
        });
      }
      ref.read(electricityCacheProvider.notifier).updateBalance(info, slot: slot);
      await service.saveSavedBalance(info, slot: slot);
    } catch (e) {
      _logger.w('Failed to load electricity balance for slot $slot: $e');
      if (mounted) {
        setState(() {
          card.balanceError = e.toString();
          card.isLoadingBalance = false;
        });
      }
    }
  }

  void _saveSlotSelection(int slot) {
    final card = _cardSlots[slot];
    if (card.selectedArea != null && card.selectedBuilding != null && card.selectedRoom != null) {
      final room = SavedElectricityRoom(
        areaName: card.selectedArea!.name,
        buildingName: card.selectedBuilding!.name,
        roomId: card.selectedRoom!.id,
        roomName: card.selectedRoom!.name,
        mertype: card.selectedRoom!.mertype,
      );
      ref.read(electricityServiceProvider).saveSavedRoom(room, slot: slot);
      ref
          .read(electricityCacheProvider.notifier)
          .updateRoomAndBalance(room, card.balanceInfo, slot: slot);
    }
  }

  Future<void> _onAreaChanged(int slot, String? areaName) async {
    if (areaName == null) return;
    final area = _areas.firstWhere((e) => e.name == areaName);
    setState(() {
      final card = _cardSlots[slot];
      card.selectedArea = area;
      card.selectedBuilding = null;
      card.selectedRoom = null;
      card.buildings = [];
      card.rooms = [];
      card.balanceInfo = null;
      card.balanceError = null;
    });
    try {
      final service = ref.read(electricityServiceProvider);
      final buildings = await service.getBuildings(area.name);
      if (mounted) {
        setState(() {
          final card = _cardSlots[slot];
          card.buildings = buildings;
          card.selectedBuilding = buildings.isNotEmpty ? buildings.first : null;
        });
        final selectedBuilding = _cardSlots[slot].selectedBuilding;
        if (selectedBuilding != null) {
          await _onBuildingChanged(slot, selectedBuilding.name);
        }
      }
    } catch (e) {
      _logger.w('Failed to load buildings for slot $slot: $e');
    }
  }

  Future<void> _onBuildingChanged(int slot, String? buildingName) async {
    if (buildingName == null) return;
    final card = _cardSlots[slot];
    final building = card.buildings.firstWhere((e) => e.name == buildingName);
    setState(() {
      card.selectedBuilding = building;
      card.selectedRoom = null;
      card.rooms = [];
      card.balanceInfo = null;
      card.balanceError = null;
    });
    if (card.selectedArea != null) {
      try {
        final service = ref.read(electricityServiceProvider);
        final rooms = await service.getRooms(card.selectedArea!.name, building.name);
        if (mounted) {
          setState(() {
            card.rooms = rooms;
            card.selectedRoom = rooms.isNotEmpty ? rooms.first : null;
          });
          _saveSlotSelection(slot);
          if (card.selectedRoom != null) {
            _loadBalance(slot);
          }
        }
      } catch (e) {
        _logger.w('Failed to load rooms for slot $slot: $e');
      }
    }
  }

  void _onRoomChanged(int slot, String? roomName) {
    if (roomName == null) return;
    final card = _cardSlots[slot];
    final room = card.rooms.firstWhere((e) => e.name == roomName);
    setState(() {
      card.selectedRoom = room;
    });
    _saveSlotSelection(slot);
    _loadBalance(slot);
  }

  Future<void> _handleClearCard(int slot) async {
    final service = ref.read(electricityServiceProvider);
    await service.clearSavedRoom(slot: slot);
    await service.clearSavedBalance(slot: slot);
    ref.read(electricityCacheProvider.notifier).clearRoom(slot: slot);

    if (mounted) {
      setState(() {
        final card = _cardSlots[slot];
        card.selectedArea = null;
        card.selectedBuilding = null;
        card.selectedRoom = null;
        card.buildings = [];
        card.rooms = [];
        card.balanceInfo = null;
        card.balanceError = null;
        card.isLoadingBalance = false;
      });
    }
  }

  void _handlePresetAmountSelect(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toStringAsFixed(0);
    });
  }

  Future<void> _handleCampusCardRecharge() async {
    final card = _cardSlots[_expandedIndex];
    if (card.selectedArea == null || card.selectedBuilding == null || card.selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseSelectCompleteRoom)),
      );
      return;
    }

    final amountText = _amountController.text;
    final amount = int.tryParse(amountText);
    
    if (amount == null || amount < 1 || amount > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseEnterValidAmountRange)),
      );
      return;
    }

    // 弹出确认卡片
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PaymentResultSheet(
        type: PaymentResultType.confirm,
        merchantName: context.l10n.payElectricityCampusCard,
        amount: amountText,
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPaying = true);

    try {
      final service = ref.read(electricityServiceProvider);
      final success = await service.recharge(
        areaName: card.selectedArea!.name,
        buildingName: card.selectedBuilding!.name,
        roomId: card.selectedRoom!.id,
        roomName: card.selectedRoom!.name,
        mertype: card.selectedRoom!.mertype,
        amount: amount.toDouble(),
        slot: _expandedIndex,
      );

      if (mounted) {
        setState(() => _isPaying = false);
        if (success) {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => PaymentResultSheet(
              type: PaymentResultType.success,
              merchantName: context.l10n.payElectricity,
              amount: amountText,
            ),
          );
          ref.read(campusCardServiceProvider).fetchRechargeInfo();
          _loadBalance(_expandedIndex);
        } else {
          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => PaymentResultSheet(
              type: PaymentResultType.failure,
              merchantName: context.l10n.payElectricityCampusCard,
              message: context.l10n.rechargeFailedRetry,
            ),
          );
        }
      }
    } catch (e) {
      _logger.e('Recharge failed: $e');
      if (mounted) {
        setState(() => _isPaying = false);
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => PaymentResultSheet(
            type: PaymentResultType.failure,
            merchantName: context.l10n.payElectricityCampusCard,
            message: context.l10n.rechargeFailedWithReason(e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _handleThirdPartyRecharge(PaymentMethod method) async {
    final card = _cardSlots[_expandedIndex];
    if (card.selectedArea == null || card.selectedBuilding == null || card.selectedRoom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseSelectCompleteRoom)),
      );
      return;
    }

    final amountText = _amountController.text;
    final amount = int.tryParse(amountText);

    if (amount == null || amount < 1 || amount > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pleaseEnterValidAmountRange)),
      );
      return;
    }

    final CampusCardInfo cardInfo;
    final cached = _cardInfo ?? ref.read(campusCardServiceProvider).cachedInfo;
    if (cached != null) {
      cardInfo = cached;
    } else {
      setState(() => _isPaying = true);
      try {
        cardInfo = await ref.read(campusCardServiceProvider).fetchRechargeInfo();
        _cardInfo = cardInfo;
      } catch (e) {
        _logger.e('Failed to fetch card info: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.fetchCardInfoFailed(e.toString()))),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _isPaying = false);
      }
    }

    if (!mounted) return;

    final roomDesc = '${card.selectedArea!.name} ${card.selectedBuilding!.name} ${card.selectedRoom!.name}';
    final rechargeFailedMsg = context.l10n.electricityRechargeFailed;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => CampusCardPaymentSheet(
        amount: amountText,
        merchantName: context.l10n.payElectricityWithRoom(roomDesc),
        info: cardInfo,
        paymentMethod: method,
        successTitle: context.l10n.electricityRechargeSuccess,
        onCardRechargeSuccess: () async {
          final service = ref.read(electricityServiceProvider);
          final success = await service.recharge(
            areaName: card.selectedArea!.name,
            buildingName: card.selectedBuilding!.name,
            roomId: card.selectedRoom!.id,
            roomName: card.selectedRoom!.name,
            mertype: card.selectedRoom!.mertype,
            amount: amount.toDouble(),
            slot: _expandedIndex,
          );
          if (!success) {
            throw Exception(rechargeFailedMsg);
          }
        },
      ),
    ).then((_) {
      if (mounted) {
        ref.read(campusCardServiceProvider).fetchRechargeInfo();
        _loadBalance(_expandedIndex);
      }
    });
  }

  Widget _buildDormitoryCard(int slot, bool isDark, Color themeColor, Color amberColor) {
    final isExpanded = _expandedIndex == slot;
    final card = _cardSlots[slot];

    final String roomDesc;
    final String? balanceVal;
    if (card.selectedRoom != null) {
      roomDesc = '${card.selectedArea?.name} - ${card.selectedBuilding?.name} - ${card.selectedRoom?.name}';
      balanceVal = card.balanceInfo != null
          ? '${card.balanceInfo!.balance}元'
          : (card.isLoadingBalance ? '...元' : '--元');
    } else {
      roomDesc = '宿舍 ${slot + 1} (${context.l10n.noRoomSelectedYet})';
      balanceVal = null;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? themeColor.withValues(alpha: isExpanded ? 0.1 : 0.08) : amberColor.withValues(alpha: isExpanded ? 0.05 : 0.04),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? themeColor.withValues(alpha: 0.2) : amberColor.withValues(alpha: 0.2),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOutCubic,
          switchOutCurve: Curves.easeInOutCubic,
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(
                sizeFactor: animation,
                alignment: Alignment.topCenter,
                child: child,
              ),
            );
          },
          child: isExpanded
              ? _buildExpandedCardContent(slot, isDark, card)
              : _buildCollapsedCardContent(slot, isDark, roomDesc, balanceVal),
        ),
      ),
    );
  }

  Widget _buildCollapsedCardContent(int slot, bool isDark, String roomDesc, String? balanceVal) {
    return InkWell(
      key: ValueKey('collapsed_inkwell_$slot'),
      onTap: () {
        setState(() {
          _expandedIndex = slot;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(
              child: Text(
                roomDesc,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (balanceVal != null) ...[
              const SizedBox(width: 8),
              Text(
                balanceVal,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
            const SizedBox(width: 8),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedCardContent(int slot, bool isDark, _CardSlotState card) {
    return Container(
      key: ValueKey('expanded_content_$slot'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.currentRechargeRoom,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 清空按钮
                  InkWell(
                    onTap: () => _handleClearCard(slot),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 13,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            context.l10n.clear,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (card.selectedRoom != null) ...[
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: card.isLoadingBalance ? null : () => _loadBalance(slot),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (card.isLoadingBalance)
                              SizedBox(
                                width: 11,
                                height: 11,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              )
                            else
                              Icon(
                                Icons.refresh,
                                size: 13,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            const SizedBox(width: 3),
                            Text(
                              card.isLoadingBalance ? context.l10n.refreshing : context.l10n.refreshBalance,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            card.selectedRoom != null 
              ? '${card.selectedArea?.name} - ${card.selectedBuilding?.name} - ${card.selectedRoom?.name}'
              : context.l10n.noRoomSelectedYet,
            style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.electricityBalance,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          if (card.balanceError != null && card.balanceInfo == null)
            InkWell(
              onTap: () => _loadBalance(slot),
              child: Row(
                children: [
                  Text(
                    context.l10n.fetchFailedClickRetry,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.refresh, size: 13, color: Colors.red.shade400),
                ],
              ),
            )
          else
            Text(
              card.balanceInfo != null
                  ? context.l10n.amountYuan(card.balanceInfo!.balance)
                  : (card.isLoadingBalance ? context.l10n.checkingPaymentStatus : context.l10n.amountYuan('0.00')),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 16),
          // 3 Dropdown boxes inside card
          _buildRoomSelectionBox(
            slot,
            context.l10n.campusArea,
            _areas.map((e) => e.name).toList(),
            card.selectedArea?.name,
            (val) => _onAreaChanged(slot, val),
          ),
          const SizedBox(height: 12),
          _buildRoomSelectionBox(
            slot,
            context.l10n.dormBuilding,
            card.buildings.map((e) => e.name).toList(),
            card.selectedBuilding?.name,
            (val) => _onBuildingChanged(slot, val),
          ),
          const SizedBox(height: 12),
          _buildRoomSelectionBox(
            slot,
            context.l10n.dormRoom,
            card.rooms.map((e) => e.name).toList(),
            card.selectedRoom?.name,
            (val) => _onRoomChanged(slot, val),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const themeColor = Color(AppConstants.primaryColorValue);
    const amberColor = Color(0xFFFFC107);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.electricityRechargeTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: themeColor))
        : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initData, 
                    style: ElevatedButton.styleFrom(backgroundColor: themeColor),
                    child: Text(context.l10n.retry, style: const TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 宿舍卡片 1
                  _buildDormitoryCard(0, isDark, themeColor, amberColor),
                  
                  const SizedBox(height: 12),
                  
                  // 宿舍卡片 2
                  _buildDormitoryCard(1, isDark, themeColor, amberColor),
                  
                  const SizedBox(height: 24),
                  
                  Text(context.l10n.selectRechargeAmount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black54)),
                  const SizedBox(height: 12),
                  
                  // Grid (No Shadow)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.8,
                    ),
                    itemCount: _presetAmounts.length,
                    itemBuilder: (context, index) {
                      final amount = _presetAmounts[index];
                      final isSelected = _selectedAmount == amount;
                      return InkWell(
                        onTap: () => _handlePresetAmountSelect(amount),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? themeColor : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSelected ? themeColor : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.3))),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            context.l10n.amountYuan(amount.toStringAsFixed(0)),
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black54),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Custom Input (No Fill Color)
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: context.l10n.customAmount,
                      labelStyle: TextStyle(color: isDark ? themeColor.withValues(alpha: 0.8) : themeColor),
                      prefixText: '¥ ',
                      filled: isDark,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: themeColor.withValues(alpha: 0.3))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: themeColor.withValues(alpha: 0.4))),
                      focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(6)), borderSide: BorderSide(color: themeColor, width: 1.5)),
                    ),
                    onChanged: (value) => setState(() => _selectedAmount = double.tryParse(value)),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // 底部支付操作按钮 (校园卡支付、微信支付、支付宝支付)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 校园卡支付
                          SizedBox(
                            width: 125,
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isPaying ? null : _handleCampusCardRecharge,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: _isPaying 
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.credit_card, size: 18),
                                      const SizedBox(width: 6),
                                      Text(context.l10n.campusCardPayment, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 微信支付
                          SizedBox(
                            width: 125,
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isPaying ? null : () => _handleThirdPartyRecharge(PaymentMethod.wechat),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF07C160),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.string(
                                    kWechatSvg,
                                    width: 18,
                                    height: 18,
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(context.l10n.wechatPay, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // 支付宝支付
                          SizedBox(
                            width: 125,
                            height: 42,
                            child: ElevatedButton(
                              onPressed: _isPaying ? null : () => _handleThirdPartyRecharge(PaymentMethod.alipay),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1677FF),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.string(
                                    kAlipaySvg,
                                    width: 18,
                                    height: 18,
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(context.l10n.alipayPayment, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildRoomSelectionBox(int slot, String label, List<String> items, String? current, Function(String?) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      key: ValueKey('${slot}_${label}_$current'),
      initialValue: items.contains(current) ? current : null,
      decoration: InputDecoration(
        labelText: label,
        filled: isDark,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.3)),
        ),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down, size: 20),
    );
  }
}
