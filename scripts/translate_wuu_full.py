import json
import re

with open("lib/l10n/app_zh.arb", "r", encoding="utf-8") as f:
    zh = json.load(f)

with open("lib/l10n/app_wuu.arb", "r", encoding="utf-8") as f:
    wuu_current = json.load(f)

# Extra Suzhou translations for the missing keys
EXTRA_WUU = {
    "funcInfoPortal": "还有小程序",
    "feedBalance": "剩底铜钿",
    "noSavedDormitory": "朆存好宿舍房间屋子",
    "clickToSelectDormitory": "按一记去挑房间或者充铜钿",
    "addExam": "添一只考试",
    "inputExamTitleHint": "输入考试名字（譬如期末大考）",
    "examCourse": "所属功课",
    "inputExamCourseHint": "输入功课名字（随喜）",
    "examTime": "考试辰光",
    "selectExamTimeHint": "挑选考试日脚搭辰光",
    "inputExamLocationHint": "输入考场或者上课间（随喜）",
    "examRemarks": "顺便交代",
    "inputExamRemarksHint": "输入交代或准备事体（随喜）",
    "noCurrentSemesterExams": "该学期暂时呒不考试排期",
    "manualExamTag": "自家添加",
    "delete": "删脱",
    "deleteExamConfirm": "真正要拿该场考试删脱伐？",
    "examDeleted": "已经删脱考试",
    "examAdded": "添好考试哉",
    "examStatusPending": "等牢考",
    "examStatusEnded": "考好哉",
    "examDetails": "考试细底",
    "openInChaoXing": "在学习通里向望望",
    "feedAutoSortSubtitle": "开牢后勿管手动排次序搭显隐，按灵巧规矩动态排次序",
    "widgetQuickTitle": "便捷用场（挑 4 只）",
    "widgetQuickHint": "小组件个便捷入口同头一页独立，好单独配好",
    "widgetHowToAdd": "回到手机台面，长按空档地方添「今日日脚行程」「便捷用场」「行程 + 便捷」小组件",
    "widgetNeedFour": "请挑选 4 只用场",
    "widgetSaved": "存好哉，小组件会得自家翻新",
    "widgetRefreshed": "小组件数据已经翻新哉",
    "widgetRefresh": "立即翻新小组件",
    "timetableSettings": "课程表",
    "notSet": "朆设定",
    "disableAutoSyncTitle": "关脱自动同步伐？",
    "disableAutoSyncMessage": "关脱后会拿本地课程表删脱（调堂、停课规矩会留牢），假使要看，好按课程表页右上角刷新按钮自家手动同步。",
    "localTimetableDeleted": "本地课程表已经删脱哉",
    "noLocalTimetable": "暂时呒不本地课程表",
    "tapRefreshButtonToSync": "按右上角刷新按钮手动同步",
    "changeColor": "换个颜色",
    "selectCourseColor": "挑选课程颜色",
    "colorSwappedNotice": "已经跟「{course}」互换课程颜色哉",
    "materialColorNotice": "仅支持从高对比度 Material UI 色板里向挑选",
    "quickReserveTip": "系统会照唔俚设定个辰光搭地段偏好自家配对空位子，帮唔俚快当锁牢。",
    "startMatchingSeats": "开始配对空位子",
    "deleteSelected": "拿挑好个删脱",
    "totalSelectedHours": "拢共挑好 {hours} 钟头",
    "autoSelectFailed": "自家匹配位子失败：{error}",
    "bookSearch": "寻书本",
    "searchBookHint": "书名字 / 写书人 / ISBN / 索书号头",
    "bookDetail": "书本细底",
    "clearHistory": "扫脱老早记录",
    "clearHistoryConfirm": "确定要扫脱所有寻书记录伐？",
    "searchFailed": "寻书失败：{error}",
    "noSearchResults": "呒不寻着搭界个书本",
    "emptySearchTip": "好试着搜搜书名、作者或索书号",
    "searchHistory": "老早寻过个",
    "hotSearches": "大家寻得多个",
    "callNumberPrefix": "索书号：{callNumber}",
    "holdingSummary": "在馆 {available} / 馆藏 {total}",
    "holdingStatusAvailable": "勒馆里",
    "holdingStatusLoaned": "借出紧",
    "holdingStatusReserved": "预留紧",
    "holdingStatusLost": "遗失哉",
    "filterCondition": "筛选门类",
    "filterDepartment": "开课科室",
    "filterDayOfWeek": "星期日脚",
    "courseDetail": "课程细底",
    "allColleges": "全部学堂",
    "roomType": "教室门类",
    "capacity": "容纳人数",
    "emptyClassroomDisclaimer": "数据仅供参考，若有变动请以实际教学安排为准。",
    "todaySchedule": "今日日脚行程",
    "tomorrowSchedule": "听日日脚行程",
    "scheduleCard": "日脚行程卡片",
    "noScheduleToday": "今日呒不日脚行程",
    "noScheduleTomorrow": "听日呒不日脚行程",
    "freeClassroomsTitle": "空上课间",
    "searchHistoryClearSuccess": "寻书记录扫干净哉",
    "loadFailed": "加载失败：{error}",
    "saveSuccess": "存好哉",
    "edit": "改动",
    "batchDelete": "批量删脱",
    "clearAll": "通通清脱",
    "selectAll": "通通挑好",
    "invertSelection": "反过来挑",
    "action": "操作",
    "detail": "细底",
    "status": "现下情形",
    "remark": "交代",
    "download": "下载到本地",
    "upload": "传上去",
    "search": "寻一寻",
    "history": "老早记录",
    "empty": "空空无物",
    "warning": "提醒警示",
    "success": "做好哉",
    "failed": "搞砸哉",
    "info": "通告消息",
    "send": "发出去",
    "reset": "重新恢复",
    "close": "关脱",
    "confirm": "定牢",
    "cancel": "算数",
    "open": "开开",
    "manage": "管好",
    "operationSuccess": "操作做好哉",
    "operationFailed": "操作搞砸哉：{error}",
    "pleaseInput": "请填入{field}",
    "pleaseSelect": "请挑选{field}",
    "noMoreData": "后头呒不数据哉",
    "networkError": "网络连线勿好，请检查网络",
    "serverError": "服务机响应有毛病",
    "timeout": "连线超时哉，请再试一趟",
    "unknownError": "勿晓得啥毛病",
    "clickToRetry": "按一记重新试一趟",
    "refreshSuccess": "刷新做好哉",
    "copySuccess": "抄好哉",
    "saveFailed": "存脱失败：{error}",
    "deleteSuccess": "删脱做好哉",
    "deleteFailed": "删脱失败：{error}",
    "updateSuccess": "更新做好哉",
    "updateFailed": "更新失败：{error}",
    "applySuccess": "申请递交好哉",
    "applyFailed": "申请递交失败：{error}",
    "shareSuccess": "分享做好哉",
    "shareFailed": "分享失败：{error}",

    "dormitoryBuilding": "宿舍楼面",
    "dormitoryRoom": "宿舍房间",
    "dormitoryUnit": "单元门号",
    "dormitoryAcademicYear": "学年纪",
    "dormitoryTerm": "学期程",
    "newChat": "新闲话",
    "matchingSeats": "勒配对空位子紧...",
    "matchedSeatSuccess": "已经帮唔俚挑好推荐位子哉",
    "changeAnotherSeatWithCooldown": "换一只 ({seconds}s)",
    "cancelSeatCooldown": "换位子冷却紧 ({seconds}s)",
    "matchingFailed": "配对位子搞砸哉",
    "matchingTimeout": "配对位子超时哉",
    "autoSelectTitle": "智能配对空位子",
    "autoSelectDesc": "照喜好自家挑位子",
    "emptyClassroom": "空上课间",
    "campusBus": "学校公交班车",
    "electricFee": "电钿",
    "dormitoryFloor": "几楼",
    "dormitoryBed": "榻号头",
    "leaveType": "告假门类",
    "leaveReason": "告假缘故",
    "leaveStartTime": "开头辰光",
    "leaveEndTime": "结束辰光",
    "leaveDays": "告假天数",
    "groupMiniApps": "小软件",
    "districtCounty": "区县地段",
    "funcCampusCard": "校园一卡通",
    "funcSunshine": "阳光热线服务",
    "sunshineService": "阳光热线服务",
    "cardBalance": "卡里剩底铜钿",
    "transactionRecord": "用铜钿流水账",
    "payRecords": "付钱记录",
    "rechargeRecords": "充钱记录",
    "dormitoryDetail": "宿舍细底",
    "roomNumber": "房间号头",
    "buildingNumber": "楼栋号头",

}

import sys; sys.path.insert(0, "."); from scripts.restore_wuu import translations as RESTORE_TRANS

# Compose final wuu dictionary
wuu_final = {}
wuu_final["@@locale"] = "wuu"

# Start from zh template to ensure exact key order and all metadata keys
for k, zv in zh.items():
    if k == "@@locale":
        continue
    if k.startswith("@"):
        wuu_final[k] = zv
        continue
    
    # Priority 1: Unit test strict keys
    if k == "appTitle":
        wuu_final[k] = "自在东湖"
        continue
    elif k == "settings":
        wuu_final[k] = "设定"
        continue
    elif k == "tabHome":
        wuu_final[k] = "头一页"
        continue

    # Priority 2: Extra translations
    if k in EXTRA_WUU:
        wuu_final[k] = EXTRA_WUU[k]
        continue

    # Priority 3: Restore translations
    if k in RESTORE_TRANS:
        wuu_final[k] = RESTORE_TRANS[k]
        continue

    # Priority 4: Existing wuu translation
    if k in wuu_current and wuu_current[k] != zv:
        wuu_final[k] = wuu_current[k]
        continue

    # Fallback: start with zv, apply rules
    val = zv
    ph_re = re.compile(r"(\{[a-zA-Z0-9_]+\})")
    parts = ph_re.split(val)
    new_parts = []
    for p in parts:
        if ph_re.match(p):
            new_parts.append(p)
        else:
            p = p.replace("侬", "唔俚")
            p = p.replace("你", "唔俚")
            p = p.replace("弗", "勿")
            p = p.replace("不", "勿")
            p = p.replace("没有", "呒不")
            p = p.replace("暂无", "暂时呒不")
            p = p.replace("查看", "望望")
            p = p.replace("设置", "设定")
            p = p.replace("搿搭", "格块")
            p = p.replace("这里", "格块")
            p = p.replace("这", "格")
            p = p.replace("什么", "啥物事")
            p = p.replace("怎么", "哪亨")
            p = p.replace("如何", "哪亨")
            p = p.replace("谁", "啥人")
            p = p.replace("为什么", "啥体")
            p = p.replace("哪里", "哪块")
            p = p.replace("哪儿", "哪块")
            p = p.replace("了", "哉")
            new_parts.append(p)
    wuu_final[k] = "".join(new_parts)

# Apply global safe cleanups
for k, v in list(wuu_final.items()):
    if k.startswith("@") or not isinstance(v, str):
        continue
    if k in ["appTitle", "settings", "tabHome"]:
        continue
    # safe dialect polish
    v = v.replace("勿要", "覅")
    v = v.replace("不要", "覅")
    v = v.replace("呒有", "呒不")
    wuu_final[k] = v

with open("lib/l10n/app_wuu.arb", "w", encoding="utf-8") as f:
    json.dump(wuu_final, f, ensure_ascii=False, indent=2)

print("Saved complete app_wuu.arb with all keys!")
