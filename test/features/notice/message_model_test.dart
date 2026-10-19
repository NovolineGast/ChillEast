import 'package:flutter_test/flutter_test.dart';
import 'package:ChillEast/features/notice/models/message_model.dart';

void main() {
  group('MessageModel Tests', () {
    test('fromJson parses Fusion Portal format correctly', () {
      final json = {
        'idCode': 'MSG001',
        'title': '放假通知',
        'content': '国庆节放假安排通知',
        'createrName': '教务处',
        'sendTime': '2026-09-30 10:00',
        'isRead': '1',
        'redDot': '0',
        'countAll': 500,
        'countRead': 450,
      };

      final msg = MessageModel.fromJson(json);
      expect(msg.idCode, 'MSG001');
      expect(msg.title, '放假通知');
      expect(msg.content, '国庆节放假安排通知');
      expect(msg.createrName, '教务处');
      expect(msg.sendTime, '2026-09-30 10:00');
      expect(msg.isRead, isTrue);
      expect(msg.hasRedDot, isTrue); // redDot == '0' means unread / has red dot
      expect(msg.countAll, 500);
      expect(msg.countRead, 450);

      final outJson = msg.toJson();
      expect(outJson['idCode'], 'MSG001');
      expect(outJson['isRead'], '1');
      expect(outJson['redDot'], '0');
    });

    test('fromChaoxingJson parses insertTime and attachment title', () {
      // 2026-10-19 12:30:00 UTC
      final timestamp = DateTime(2026, 10, 19, 12, 30).millisecondsSinceEpoch;
      final json = {
        'idCode': 'CX001',
        'content': '正文内容',
        'createrName': '学工部',
        'insertTime': timestamp,
        'isread': 1,
        'count_all': 200,
        'count_read': 180,
        'uuid': 'uuid-12345',
        'attachment': '[{"att_web":{"title":"助学金申请通知"}}]',
      };

      final msg = MessageModel.fromChaoxingJson(json);
      expect(msg.idCode, 'CX001');
      expect(msg.title, '助学金申请通知');
      expect(msg.isRead, isTrue);
      expect(msg.hasRedDot, isFalse);
      expect(msg.uuid, 'uuid-12345');
      expect(msg.sendTime, contains('2026-10-19 12:30'));
      expect(msg.countAll, 200);
      expect(msg.countRead, 180);
    });

    test('fromChaoxingJson title extraction fallbacks', () {
      // 1. Content first line (short)
      final jsonShort = {
        'content': '关于英语四六级报名的通知\r\n请大家抓紧时间报名',
        'isread': 0,
        'count_all': '150',
        'count_read': '10',
      };
      final msg1 = MessageModel.fromChaoxingJson(jsonShort);
      expect(msg1.title, '关于英语四六级报名的通知');
      expect(msg1.isRead, isFalse);
      expect(msg1.hasRedDot, isTrue);
      expect(msg1.countAll, 150);
      expect(msg1.countRead, 10);

      // 2. Content first line (>50 chars truncated)
      final longLine = 'A' * 60;
      final jsonLong = {'content': '$longLine\r\n第二行'};
      final msg2 = MessageModel.fromChaoxingJson(jsonLong);
      expect(msg2.title.length, 53); // 50 + '...'
      expect(msg2.title.endsWith('...'), isTrue);

      // 3. Empty content fallback
      final jsonEmpty = {'content': ''};
      final msg3 = MessageModel.fromChaoxingJson(jsonEmpty);
      expect(msg3.title, '无标题');
    });

    test('toString formatting', () {
      const msg = MessageModel(
        idCode: '1',
        title: '测试',
        content: '内容',
        createrName: '发送者',
        sendTime: '2026-10-19',
        isRead: true,
        hasRedDot: false,
        countAll: 10,
        countRead: 5,
      );
      expect(msg.toString(), contains('MessageModel(title: 测试, sender: 发送者, time: 2026-10-19, read: true)'));
    });
  });

  group('NoticeResult Tests', () {
    test('NoticeResult retains pagination fields', () {
      final result = NoticeResult(
        messages: [],
        nextLastValue: 'next_page_token',
        hasMore: true,
      );
      expect(result.messages, isEmpty);
      expect(result.nextLastValue, 'next_page_token');
      expect(result.hasMore, isTrue);
    });
  });
}
