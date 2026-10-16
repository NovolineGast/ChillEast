import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/state/auth_state.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/electricity_model.dart';
import '../services/electricity_service.dart';

class DormitoryElectricityState {
  final List<SavedElectricityRoom?> rooms;
  final List<ElectricityBalanceInfo?> balances;
  final bool isLoading;
  final String? error;

  const DormitoryElectricityState({
    this.rooms = const [null, null],
    this.balances = const [null, null],
    this.isLoading = false,
    this.error,
  });

  SavedElectricityRoom? get room => rooms.isNotEmpty ? rooms[0] : null;
  ElectricityBalanceInfo? get balanceInfo => balances.isNotEmpty ? balances[0] : null;

  DormitoryElectricityState copyWith({
    List<SavedElectricityRoom?>? rooms,
    List<ElectricityBalanceInfo?>? balances,
    SavedElectricityRoom? room,
    bool clearRoom = false,
    ElectricityBalanceInfo? balanceInfo,
    bool clearBalanceInfo = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    List<SavedElectricityRoom?> nextRooms = rooms ?? List.from(this.rooms);
    if (room != null || clearRoom) {
      nextRooms = List.from(nextRooms);
      while (nextRooms.isEmpty) {
        nextRooms.add(null);
      }
      nextRooms[0] = clearRoom ? null : room;
    }

    List<ElectricityBalanceInfo?> nextBalances = balances ?? List.from(this.balances);
    if (balanceInfo != null || clearBalanceInfo) {
      nextBalances = List.from(nextBalances);
      while (nextBalances.isEmpty) {
        nextBalances.add(null);
      }
      nextBalances[0] = clearBalanceInfo ? null : balanceInfo;
    }

    return DormitoryElectricityState(
      rooms: nextRooms,
      balances: nextBalances,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final electricityCacheProvider = StateNotifierProvider<
    ElectricityCacheNotifier, DormitoryElectricityState>((ref) {
  return ElectricityCacheNotifier(ref);
});

class ElectricityCacheNotifier
    extends StateNotifier<DormitoryElectricityState> {
  final Ref _ref;
  final _logger = AppLogger.instance;

  ElectricityCacheNotifier(this._ref)
      : super(const DormitoryElectricityState(isLoading: true)) {
    _init();

    // 监听登录状态，登录成功后自动静默拉取电费
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status != AuthStatus.authenticated &&
          next.status == AuthStatus.authenticated) {
        _logger.i('🔐 Login success detected, auto-refreshing electricity...');
        _silentRefresh();
      }
    });
  }

  Future<void> _init() async {
    final service = _ref.read(electricityServiceProvider);
    final rooms = await service.getSavedRooms();
    final balances = await service.getSavedBalances();

    if (mounted) {
      state = DormitoryElectricityState(
        rooms: rooms,
        balances: balances,
        isLoading: false,
      );
    }

    final auth = _ref.read(authStateProvider);
    if (auth.status == AuthStatus.authenticated && rooms.any((r) => r != null)) {
      _silentRefresh();
    }
  }

  Future<void> _silentRefresh() async {
    final service = _ref.read(electricityServiceProvider);
    final savedRooms = await service.getSavedRooms();
    final rooms = List<SavedElectricityRoom?>.generate(
      2,
      (i) => (i < state.rooms.length ? state.rooms[i] : null) ?? (i < savedRooms.length ? savedRooms[i] : null),
    );

    if (rooms.every((r) => r == null)) {
      if (mounted && state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
      return;
    }

    if (mounted) {
      state = state.copyWith(rooms: rooms, isLoading: true, clearError: true);
    }

    final newBalances = List<ElectricityBalanceInfo?>.from(state.balances);
    while (newBalances.length < 2) {
      newBalances.add(null);
    }

    String? lastError;
    for (int i = 0; i < rooms.length; i++) {
      final room = rooms[i];
      if (room == null) continue;
      try {
        final info = await service.getBalance(
          areaName: room.areaName,
          buildingName: room.buildingName,
          roomId: room.roomId,
          mertype: room.mertype,
        );
        newBalances[i] = info;
        await service.saveSavedBalance(info, slot: i);
      } catch (e) {
        _logger.w('⚠️ Silent refresh electricity balance failed for slot $i: $e');
        lastError = e.toString();
      }
    }

    if (mounted) {
      state = state.copyWith(
        rooms: rooms,
        balances: newBalances,
        isLoading: false,
        error: lastError,
        clearError: lastError == null,
      );
    }
  }

  Future<void> refresh() async {
    final service = _ref.read(electricityServiceProvider);
    final savedRooms = await service.getSavedRooms();
    if (mounted) {
      state = state.copyWith(rooms: savedRooms);
    }
    await _silentRefresh();
  }

  void updateRoomAndBalance(
      SavedElectricityRoom room, ElectricityBalanceInfo? balanceInfo, {int slot = 0}) {
    if (mounted) {
      final newRooms = List<SavedElectricityRoom?>.from(state.rooms);
      while (newRooms.length <= slot) {
        newRooms.add(null);
      }
      newRooms[slot] = room;

      final newBalances = List<ElectricityBalanceInfo?>.from(state.balances);
      while (newBalances.length <= slot) {
        newBalances.add(null);
      }
      newBalances[slot] = balanceInfo;

      state = state.copyWith(
        rooms: newRooms,
        balances: newBalances,
        isLoading: false,
        clearError: true,
      );
    }
  }

  void updateBalance(ElectricityBalanceInfo balanceInfo, {int slot = 0}) {
    if (mounted) {
      final newBalances = List<ElectricityBalanceInfo?>.from(state.balances);
      while (newBalances.length <= slot) {
        newBalances.add(null);
      }
      newBalances[slot] = balanceInfo;

      state = state.copyWith(
        balances: newBalances,
        isLoading: false,
        clearError: true,
      );
    }
  }

  void clearRoom({int slot = 0}) {
    if (mounted) {
      final newRooms = List<SavedElectricityRoom?>.from(state.rooms);
      if (slot < newRooms.length) newRooms[slot] = null;

      final newBalances = List<ElectricityBalanceInfo?>.from(state.balances);
      if (slot < newBalances.length) newBalances[slot] = null;

      state = state.copyWith(
        rooms: newRooms,
        balances: newBalances,
        isLoading: false,
        clearError: true,
      );
    }
  }

  void clear() {
    if (mounted) {
      state = const DormitoryElectricityState();
    }
  }
}
