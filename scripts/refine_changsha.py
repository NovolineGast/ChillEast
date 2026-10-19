#!/usr/bin/env python3
"""Refine Xiang Chinese (Changsha dialect / 湘语·长沙话) translations in lib/l10n/app_hsn.arb.

Requirements:
1. Ordinary Mandarin ratio <= 30.0% as measured by scripts/measure_dialect.py.
2. Complete all 929 keys in lib/l10n/app_zh.arb.
3. Strictly satisfy test/core/state/locale_provider_test.dart assertions:
   - appTitle: "自在东湖"
   - settings: "设置"
   - tabHome: "首页"
4. Authentic Changsha dialect vocabulary & grammar from 《长沙方言词典》.
5. All placeholders preserved verbatim.
"""

import json
import re
import sys
from pathlib import Path

ZH_PATH = Path("lib/l10n/app_zh.arb")
HSN_PATH = Path("lib/l10n/app_hsn.arb")

# Changsha dialect translations for remaining / newly added Mandarin keys
CHANGSHA_MAP = {
    # Test strict assertions (MUST NOT CHANGE)
    "appTitle": "自在东湖",
    "settings": "设置",
    "tabHome": "首页",

    # 小组件 / Widgets
    "funcInfoPortal": "还有的小门道",
    "feedAutoSort": "自个排先后",
    "feedAutoSortSubtitle": "开哒后不管自个排的前后跟显隐，按规矩自个动态排好",
    "widgetSettings": "桌面小挂件",
    "widgetQuickTitle": "灵泛用处（拣 4 个）",
    "widgetQuickHint": "小挂件的快捷口子跟首页分开的，做得单独调好",
    "widgetHowToAdd": "归到手机桌面，长按空处添上「今日日程」「灵泛用处」「日程 + 灵泛」小挂件",
    "widgetNeedFour": "请拣好 4 个用处",
    "widgetSaved": "存好哒，小挂件会自个刷新",
    "widgetRefreshed": "小挂件底细刷新好哒",
    "widgetRefresh": "连忙刷新小挂件",

    # 课表 / Timetable
    "timetableSettings": "堂课表",
    "notSet": "冒设置",
    "timetableAutoSync": "自个同步堂课表",
    "disableAutoSyncTitle": "关脱自动同步啵？",
    "disableAutoSyncMessage": "关脱后会删脱本地堂课表（调课、停课这些规矩还在），要是想望课表，做得戳堂课表页右上角刷新按钮自个同步。",
    "localTimetableDeleted": "本地堂课表删脱哒",
    "noLocalTimetable": "暂且冒得本地堂课表",
    "tapRefreshButtonToSync": "戳右上角刷新按钮自个同步",

    # 颜色
    "courseColor": "堂课颜色",
    "changeColor": "换只颜色",
    "selectCourseColor": "拣堂课颜色",
    "colorSwappedNotice": "已同「{course}」换好堂课颜色哒",
    "materialColorNotice": "只做得从高对比度 Material UI 色板里头拣",

    # 学工问卷 / 请假
    "studentWorkQuestionnaire": "学工问卷调查",
    "pleaseFillQuestion": "请填好: {title}",
    "pleaseEnterPhone": "请输电话号码",
    "pleaseEnter": "请输下子",
    "calculatingDuration": "（算紧…）",
    "emergencyContact": "要紧联系人",
    "emergencyContactPhone": "要紧联系人电话",
    "pleaseEnter11DigitPhone": "请输 11 位手机号",
    "optional": "随你填",
    "leaveCampus": "出学校",
    "detailedAddress": "底细地址",
    "leaveCity": "走出长沙市",
    "leaveProvince": "走出湖南省",
    "durationDays": "{days}天",
    "durationHours": "{hours}个钟头",
    "hoursCount": "{count}个钟头",
    "contactPhone": "联络电话",
    "practiceInstructor": "实践带路老师",
    "attachment": "附带物件",
    "auditStatus": "把关动静",
    "leaveTypeDetails": "{type}底细",
    "revokeApplication": "撤脱申请",
    "statusAuditing": "把关紧",

    # 图书馆与座位
    "libraryStatusInUse": "用紧",
    "checkInFailedWithReason": "签到冒搞成: {reason}",
    "confirmCheckOut": "扎实退位子",
    "checkOutFailedWithReason": "退座冒搞成: {reason}",
    "cancelReservationFailedWithReason": "算了冒搞成: {reason}",
    "readingRoomLabel": "阅览屋：{room}",
    "checkIn": "打卡签到",
    "checkOut": "退位子",
    "totalSeats": "座位总共：{capacity}",
    "seatOccupied": "有人哒/拣不得",
    "loadingSeatMap": "正在调出座位图...",
    "quickReserveTip": "系统会照你调的时间跟位子喜好自个对准空位，帮你飞快定好。",
    "startMatchingSeats": "开始对准空位子",
    "matchingSeats": "正在对准空位子...",
    "matchedSeatSuccess": "已经把你想好推荐位子哒",
    "changeAnotherSeat": "换只位子",
    "changeAnotherSeatWithCooldown": "换只位子 ({seconds}s)",
    "confirmQuickReserve": "定好",
    "allFloors": "通统楼层",
    "allRooms": "通统阅览屋",
    "locationPreference": "位子偏好",
    "optionalLabel": "随你拣",
    "floorLabel": "楼层数",
    "roomLabel": "阅览屋",
    "noMatchedSeatFound": "暂且冒得合心意的空位子，改哈时段或位子再试下子",
    "adjustFilters": "调整拣选条件",
    "homeworkReminderChannelName": "作业歇期提个醒",
    "seatNumberNotificationTitle": "{time} {seat}号位子",
    "liveClassStartingTime": "{time}上堂课",
    "liveSeatStartingTime": "{time}起头",
    "ruleModeCopy": "照样抄一份",

    # 报修平台 / Repairs
    "repairsTitle": "喊修台子",
    "repairsQuickReport": "我要喊修",
    "repairsQuickReportHint": "照毛病类别飞快进到填报页",
    "repairsMyOrders": "我的喊修单子",
    "repairsMyOrdersHint": "喊修底细会连到校园喊修台子",
    "repairsInProgress": "搞紧",
    "repairsCompleted": "搞好哒",
    "repairsHeroTitle": "校园杂事，一哈喊修",
    "repairsHeroSubtitle": "原生底子填写，单子动静即刻对齐；请拣好最合搞的服务类别。",
    "repairsNoCompleted": "暂且冒得办结的单子",
    "repairsNoOngoing": "暂且冒得搞紧的单子",
    "repairsUnnamedOrder": "冒起名字的单子",
    "repairsEnterValue": "请输或者粘上台子的选项值",
    "repairsRequiredField": "请填好{field}",
    "repairsSubmitSuccess": "报上去哒",
    "repairsSubmitSuccessMessage": "单子报上去哒，搞到哪一步可在“我的工单”里头望。",
    "repairsSelectValue": "请拣一哈",
    "repairsSubmit": "报单子上去",
    "repairsSubmitting": "正在报上去…",
    "repairsOrderDetail": "喊修单子底细",
    "repairsOrderNumber": "单子号数",
    "repairsOrderStatus": "现时动静",
    "repairsOrderType": "喊修类别",
    "repairsDepartment": "承办部门",
    "repairsCreatedAt": "建单时辰",
    "repairsDescription": "毛病说明",
    "repairsNoDescription": "暂且冒得讲究",
    "repairsDrafts": "草稿篓子",
    "repairsNoDrafts": "暂且冒得草稿",
    "repairsSaveDraft": "存进草稿",
    "repairsSavingDraft": "正在存进草稿…",
    "repairsSaveDraftSuccess": "存进草稿篓子哒",
    "repairsCancelOrder": "算哒不喊修",
    "repairsCancellingOrder": "正在算脱…",
    "repairsCancelConfirmTitle": "真格要取消喊修啵？",
    "repairsCancelConfirmMessage": "算脱后咯张喊修单就不搞哒，真格要算哒啵？",
    "repairsCancelSuccess": "喊修单子算脱哒",
    "repairsApplicant": "喊修的人",
    "repairsApplicantDepartment": "喊修部门",
    "repairsPhone": "联络电话",
    "repairsHandler": "经手师傅",
    "repairsHandleResult": "经手结果",
    "repairsUserFeedback": "评断反馈",
    "repairsRating": "评判打分",
    "repairsSupplement": "添些说明",
    "repairsPriority": "要紧程度",
    "repairsCurrentNode": "现下到哪步",
    "repairsCompletedAt": "搞结时辰",
    "repairsActivityTimeline": "经手底细",
    "repairsAttachments": "附带照片",
    "repairsNoActivity": "暂且冒得经手底细",
    "repairsUploadImage": "添张照片",
    "repairsUploading": "照片正在传上去…",
    "repairsUploadFailed": "照片传不上去",
    "repairsDeleteImage": "删脱照片",
    "repairsDeleteConfirm": "真格要删脱咯张照片啵？",
    "repairsSubmitTicket": "填写喊修单",
    "repairsSelectCategory": "拣喊修类别",

    # 备份与导出
    "dataSyncSettings": "底细数据",
    "dataBackup": "数据导出去",
    "backupSecurityTip": "备份不包登录暗号，包自设的 AI Key，请好生收好",
    "backupShareText": "自个的自在东湖备份底细",
    "backupExportSuccess": "备份导出来哒，做得存好或者发把别个",
    "backupExportFailed": "导出来冒搞成: {error}",
    "dataImport": "数据导进来",
    "dataImportConfirmTitle": "真格要导进来啵？",
    "dataImportConfirmMessage": "导进来会盖脱现时设置跟本地底细，还要往下搞啵？",
    "dataImportSuccess": "备份导进来哒",
    "dataImportFailed": "导进来冒搞成: {error}",
    "dataImportInvalidFile": "冒是正经的备份文件",
    "dataImportVersionTooNew": "备份版本太新哒，先升级 App 再导进来",
    "cloudBackupAutoSync": "自个同步",
    "cloudBackupAutoSyncSubtitle": "借学习通网盘",
    "cloudSyncPromptTitle": "开启自个同步",
    "cloudSyncPromptMessage": "自个把堂课表、作业这些本地底细同步到学习通网盘，换只手机也丢不脱，随手可在设置里头关掉。",
    "cloudSyncPromptEnable": "连忙开启",

    # 图书查询 / Book Search
    "bookSearch": "寻书本",
    "bookSearchSubtitle": "查馆里存书跟借出动静",
    "bookSearchHint": "寻书名、写书的人、主题或编码...",
    "bookSearchTotalCount": "一共寻到 {count} 本书",
    "bookSearchLoading": "正在调出来...",
    "bookSearchEmpty": "冒寻到沾边的图书",
    "bookDetailTitle": "图书底细",
    "holdingsTitle": "馆藏底细",
    "barcode": "条码号数",
    "callNumber": "寻书号数",
    "holdingLocation": "藏书地方",
    "holdingStatus": "现下状态",
    "holdingUnit": "藏书处所",
    "copyType": "单册样子",
    "accessionNo": "入库号数",
    "searchTypeTitle": "图书名字",
    "searchTypeAuthor": "写书的人",
    "searchTypeSubject": "主题讲究",
    "searchTypeIdentifier": "规矩编码",
    "statusInLibrary": "到馆里",
    "statusBorrowed": "借出克哒",
    "search": "寻下子",

    # 办事大厅 / Ehall
    "funcEhall": "线上办事大厅",
    "ehallSubtitle": "网里办事、批条子与杂务服务",
    "ehallHotServices": "抢手服务",
    "ehallAllServices": "通统服务",
    "ehallCategories": "服务门类",
    "ehallDepartments": "经管处所",
    "ehallMyOrders": "我办的件",
    "ehallSearchHint": "寻服务名字、处所或者说明...",
    "ehallNoServicesFound": "冒寻到对路的服务",
    "ehallApplyNow": "自个去办",
    "ehallViewDetail": "望哈底细",
    "ehallServiceType": "服务类别",
    "ehallDepartment": "经管处所",
    "ehallVisits": "望过的人数",
    "ehallExternalLink": "跳到外头系统",
    "ehallProcessWorkflow": "线上批条子流程",
    "ehallOpenInWeb": "网页版堂屋",
    "ehallOngoing": "搞紧",
    "ehallCompleted": "办结哒",
    "ehallNoOrders": "暂且冒得办事底细",
    "ehallFavorites": "我存下的好东西",
    "ehallAddToFavorites": "存进收藏",
    "ehallRemoveFromFavorites": "撤脱收藏",
    "ehallServiceUnavailable": "办事大厅现下不顶事，等一哈再试下子",
    "ehallSessionExpired": "办事大厅登进超时哒，请重新登进来",
    "ehallExternalJumpPrompt": "马上跳到外头服务",
    "ehallOpenNativeLeave": "到请假小程序里头办",
    "examTimePrefix": "考试时辰",

    # 缓存与 AI
    "clearWebViewCache": "扫脱缓存",
    "clearWebViewCacheSubtitle": "清脱应用里头的网页离线缓存跟杂碎底细",
    "clearWebViewCacheSuccess": "缓存扫干净哒",
    "clearWebViewCacheConfirmTitle": "真格要扫脱缓存啵？",
    "clearWebViewCacheConfirmMessage": "将清脱应用里网页的离线缓存与临时底细，不碍你的登录动静。",
    "aiFetchModels": "扯出模型单子",
    "aiSelectModel": "拣模型",
    "aiSearchModelHint": "寻模型名字…",
    "aiNoModelsFound": "冒寻到对路子的模型",
    "aiTestConnection": "测哈连得上不",
    "aiTestingConnection": "正在测哈连得上不…",
    "aiTestSuccess": "连上哒 (花了 {ms}ms)",
    "aiTestFailed": "连不上: {error}",
    "aiApiKeyRequired": "请先调置好 API Key",
    "aiModelSelected": "拣好模型哒: {model}",

    # 日历订阅
    "timetableSubscription": "堂课表订阅",
    "timetableSubscriptionSubtitle": "线上日历订阅跟云端自个同步",
    "timetableSubscriptionAutoUpload": "开启堂课表订阅",
    "timetableSubscriptionAutoUploadDesc": "开启后，从教务同步或调好堂课表，会自个把调停后的课表送上云端供订阅；关脱后云端课表一淘删脱",
    "timetableSubscriptionUrl": "日历订阅连结",
    "copySubscriptionUrl": "抄下连结",
    "subscriptionUrlCopied": "订阅连结抄进剪切板哒",
    "openInCalendar": "到日历里头订阅",
    "openInCalendarFailed": "喊不起系统日历，自个抄下连结去订阅",
    "syncToCloudNow": "连忙同步到云端",
    "syncSuccess": "云端同步好哒",
    "syncFailed": "云端同步搞砸哒: {error}",
    "resetSubscriptionUrl": "重新换只连结",
    "resetSubscriptionConfirmTitle": "换只订阅连结",
    "resetSubscriptionConfirmMessage": "换掉后旧的订阅连结即刻不中用，云端旧课表也会删脱，要到订阅的设备里重添新连结。还要往下搞啵？",
    "subscriptionTutorialTitle": "别个日历订阅指路",
    "subscriptionTutorialContent": "• Apple 日历 (iPhone / iPad / Mac)：\n戳上头「到日历里头订阅」，或者到日历里头选「添上订阅日历」，粘上连结就中。\n\n• Google 日历：\n在网页里戳「别个日历」旁边的「+」号，拣「通过网址」，粘上连结存好。\n\n• Outlook / 微软日历：\n拣「添上日历」-「从 Web 订阅」，输进连结存好。\n\n• 提个醒：\n订阅连结包哒调停后的通统堂课，要是课表有调动或教务更新，订阅源会自个对齐到最新。",

    # Existing translations polish for authentic Changsha dialect
    "gradeFailed": "冒及格",
    "loginRequiredTitle": "要登进来才望得见内容",
    "loginRequiredMessage": "登进来后就望得见你的堂课表、作业跟成绩信息",
    "noScoreData": "咯个学期冒得成绩数据",
    "courseReminder": "上课前提个醒",
    "courseReminderTime": "上课提个醒的时辰",
    "homeworkReminderTime": "作业提个醒的时辰",
    "libraryReminder": "图书馆预约提个醒",
    "libraryReminderTime": "图书馆预约提个醒的时辰",
}


def main():
    with open(ZH_PATH, "r", encoding="utf-8") as f:
        zh = json.load(f)
    with open(HSN_PATH, "r", encoding="utf-8") as f:
        hsn = json.load(f)

    # Placeholders check regex
    ph_re = re.compile(r"\{[a-zA-Z0-9_]+\}")

    output_data = {}
    output_data["@@locale"] = "hsn"

    missing_keys = []
    placeholder_errors = []

    for k, v in zh.items():
        if k == "@@locale":
            continue
        if k.startswith("@"):
            output_data[k] = v
            continue

        # Translation key
        if k in CHANGSHA_MAP:
            translated_val = CHANGSHA_MAP[k]
        elif k in hsn:
            translated_val = hsn[k]
        else:
            missing_keys.append(k)
            translated_val = v  # fallback

        # Strict checks
        if k == "appTitle":
            translated_val = "自在东湖"
        elif k == "settings":
            translated_val = "设置"
        elif k == "tabHome":
            translated_val = "首页"

        # Check placeholders
        zh_phs = sorted(ph_re.findall(v))
        hsn_phs = sorted(ph_re.findall(translated_val))
        if zh_phs != hsn_phs:
            placeholder_errors.append((k, zh_phs, hsn_phs))

        output_data[k] = translated_val

    if missing_keys:
        print(f"Warning: {len(missing_keys)} missing keys fell back to Mandarin: {missing_keys[:10]}")

    if placeholder_errors:
        print(f"ERROR: Placeholder errors detected in {len(placeholder_errors)} keys:")
        for err in placeholder_errors:
            print("  ", err)
        sys.exit(1)

    with open(HSN_PATH, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2)
        f.write("\n")

    print(f"Successfully refined {HSN_PATH} with {len([k for k in output_data if not k.startswith('@')])} keys.")


if __name__ == "__main__":
    main()
