import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/route_utils.dart';
import 'ai_memory_screen.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  late TextEditingController _apiUrlController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;
  bool _obscureApiKey = true;
  bool _isSaving = false;
  bool _isFetchingModels = false;
  bool _isTestingConnection = false;
  List<String> _availableModels = [];

  @override
  void initState() {
    super.initState();
    final aiState = ref.read(aiAssistantProvider);
    _apiUrlController = TextEditingController(text: aiState.resolvedApiUrl);
    _modelController = TextEditingController(text: aiState.resolvedModel);
    _apiKeyController = TextEditingController(text: aiState.apiKey ?? '');
    _apiUrlController.addListener(_onFieldChanged);
    _modelController.addListener(_onFieldChanged);
    _apiKeyController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {});
  }

  bool get _isDefaultConfig {
    final apiUrl = _apiUrlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final isDefaultUrl = apiUrl.isEmpty || apiUrl == AiAssistantService.defaultApiUrl;
    final isDefaultModel = model.isEmpty || model == AiAssistantService.defaultModel;
    final isDefaultKey = apiKey.isEmpty;
    return isDefaultUrl && isDefaultModel && isDefaultKey;
  }

  @override
  void dispose() {
    _apiUrlController.removeListener(_onFieldChanged);
    _modelController.removeListener(_onFieldChanged);
    _apiKeyController.removeListener(_onFieldChanged);
    _apiUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    final apiUrl = _apiUrlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    // 留空表示跟随默认（Worker 中转），由 saveFullSettings 落盘为“清除”。
    await ref.read(aiAssistantProvider.notifier).saveFullSettings(
      apiUrl: apiUrl,
      model: model,
      apiKey: apiKey,
    );

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiSettingsSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _resetDefaults() async {
    await ref.read(aiAssistantProvider.notifier).resetToDefaults();
    setState(() {
      _apiUrlController.text = AiAssistantService.defaultApiUrl;
      _modelController.text = AiAssistantService.defaultModel;
      _apiKeyController.clear();
      _availableModels.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiSettingsResetDefaults),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    final aiState = ref.read(aiAssistantProvider);
    if (apiKey.isEmpty && !aiState.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiApiKeyRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isTestingConnection = true;
    });

    try {
      final apiUrl = _apiUrlController.text.trim();
      final model = _modelController.text.trim();
      final latency =
          await ref.read(aiAssistantProvider.notifier).testConnection(
                apiUrl: apiUrl,
                model: model,
                apiKey: apiKey,
              );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ ${context.l10n.aiTestSuccess(latency.inMilliseconds)}'),
            backgroundColor: const Color(0xFF09C489),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${context.l10n.aiTestFailed(errorMsg)}'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTestingConnection = false;
        });
      }
    }
  }

  Future<void> _downloadModels({bool openDropdownAfter = false}) async {
    final apiKey = _apiKeyController.text.trim();
    final aiState = ref.read(aiAssistantProvider);
    if (apiKey.isEmpty && !aiState.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.aiApiKeyRequired),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isFetchingModels = true;
    });

    try {
      final apiUrl = _apiUrlController.text.trim();
      final models = await ref.read(aiAssistantProvider.notifier).fetchModels(
            apiUrl: apiUrl,
            apiKey: apiKey,
          );

      setState(() {
        _availableModels = models;
        if (models.isNotEmpty) {
          _modelController.text = models.first;
        }
      });

      if (mounted) {
        if (openDropdownAfter) {
          _showModelSelectionSheet();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                models.isNotEmpty
                    ? '获取成功，共 ${models.length} 个模型，已默认选择第 1 个'
                    : context.l10n.aiNoModelsFound,
              ),
              backgroundColor: const Color(0xFF09C489),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingModels = false;
        });
      }
    }
  }

  void _openModelDropdown() {
    if (_availableModels.isEmpty) {
      _downloadModels(openDropdownAfter: true);
    } else {
      _showModelSelectionSheet();
    }
  }

  void _showModelSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _ModelSelectionModal(
          initialModels: _availableModels,
          selectedModel: _modelController.text.trim(),
          onModelSelected: (model) {
            setState(() {
              _modelController.text = model;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.aiModelSelected(model)),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          onRefresh: () async {
            Navigator.pop(sheetContext);
            await _downloadModels(openDropdownAfter: true);
          },
        );
      },
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      setState(() {
        _apiKeyController.text = data.text!.trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF09C489);
    final aiState = ref.watch(aiAssistantProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.agentSettings,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF202124),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // API 接口地址 (Base URL) - 校园卡充值同款 Outlined 样式
            TextField(
              controller: _apiUrlController,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
              decoration: InputDecoration(
                labelText: context.l10n.aiApiUrl,
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                hintText: context.l10n.aiApiUrlHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                filled: isDark,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
                prefixIcon: Icon(
                  Icons.link_rounded,
                  size: 20,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // 模型名称 (Model Name)
            TextField(
              controller: _modelController,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
              decoration: InputDecoration(
                labelText: context.l10n.aiModelName,
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                hintText: context.l10n.aiModelNameHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                filled: isDark,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
                prefixIcon: Icon(
                  Icons.memory_outlined,
                  size: 20,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isFetchingModels)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else ...[
                      IconButton(
                        icon: const Icon(Icons.download_rounded, size: 20),
                        tooltip: context.l10n.aiFetchModels,
                        onPressed: _downloadModels,
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_drop_down_rounded, size: 24),
                        tooltip: context.l10n.aiSelectModel,
                        onPressed: _openModelDropdown,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // API Key
            TextField(
              controller: _apiKeyController,
              obscureText: _obscureApiKey,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : const Color(0xFF202124),
              ),
              decoration: InputDecoration(
                labelText: aiState.hasCustomApiKey ? context.l10n.aiApiKeyCustom : context.l10n.aiApiKeyDefault,
                labelStyle: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 14,
                ),
                hintText: context.l10n.aiApiKeyHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                filled: isDark,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
                prefixIcon: Icon(
                  Icons.vpn_key_outlined,
                  size: 20,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureApiKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureApiKey = !_obscureApiKey;
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.paste_rounded,
                        size: 20,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                      tooltip: context.l10n.paste,
                      onPressed: _pasteFromClipboard,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 记忆管理入口
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                Navigator.push(
                  context,
                  createSlideUpRoute(const AiMemoryScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '记忆管理',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF202124),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white54 : Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            if (!_isDefaultConfig) ...[
              // 测试连接按钮
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isTestingConnection ? null : _testConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded, size: 20),
                  label: Text(
                    _isTestingConnection
                        ? context.l10n.aiTestingConnection
                        : context.l10n.aiTestConnection,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: const BorderSide(color: primaryColor, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 保存按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        context.l10n.saveSettings,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // 恢复默认配置按钮
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _resetDefaults,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(context.l10n.resetDefaults),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.grey[700],
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey[300]!,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelSelectionModal extends StatefulWidget {
  final List<String> initialModels;
  final String selectedModel;
  final ValueChanged<String> onModelSelected;
  final Future<void> Function() onRefresh;

  const _ModelSelectionModal({
    required this.initialModels,
    required this.selectedModel,
    required this.onModelSelected,
    required this.onRefresh,
  });

  @override
  State<_ModelSelectionModal> createState() => _ModelSelectionModalState();
}

class _ModelSelectionModalState extends State<_ModelSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  late List<String> _filteredModels;

  @override
  void initState() {
    super.initState();
    _filteredModels = List.from(widget.initialModels);
    _searchController.addListener(_filter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredModels = List.from(widget.initialModels);
      } else {
        _filteredModels = widget.initialModels
            .where((m) => m.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF09C489);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.aiSelectModel,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '共 ${widget.initialModels.length} 个模型',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: context.l10n.aiFetchModels,
                  onPressed: widget.onRefresh,
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.l10n.aiSearchModelHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                filled: isDark,
                fillColor:
                    isDark ? Colors.white.withOpacity(0.06) : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          // Models list
          Expanded(
            child: _filteredModels.isEmpty
                ? Center(
                    child: Text(
                      context.l10n.aiNoModelsFound,
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredModels.length,
                    itemBuilder: (context, index) {
                      final model = _filteredModels[index];
                      final isSelected = model == widget.selectedModel;
                      return ListTile(
                        leading: Icon(
                          Icons.memory_outlined,
                          size: 20,
                          color: isSelected
                              ? primaryColor
                              : (isDark ? Colors.white60 : Colors.grey[600]),
                        ),
                        title: Text(
                          model,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? primaryColor
                                : (isDark
                                    ? Colors.white
                                    : const Color(0xFF202124)),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: primaryColor, size: 20)
                            : null,
                        onTap: () {
                          widget.onModelSelected(model);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
