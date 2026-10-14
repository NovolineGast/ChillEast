import 'package:ChillEast/features/repairs/utils/repair_log_parse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain submit log stays single text segment', () {
    const raw = '张三在“开始”节点，提交了该工单!';
    final segs = parseRepairLogDescription(raw);
    expect(segs.length, 1);
    expect(segs.first.isFile, isFalse);
    expect(segs.first.text, raw);
  });

  test('app-style upload with straight quotes becomes tappable file', () {
    const raw =
        '张三在“开始“节点，上传附件\$\$"photo_sample.jpg"\$\$<<rpc?method=/v2/file/download&id=00000000-0000-0000-0000-000000000001>>';
    final segs = parseRepairLogDescription(raw);
    expect(segs.length, 2);
    expect(segs[0].text, '张三在“开始“节点，上传附件');
    expect(segs[1].isFile, isTrue);
    expect(segs[1].text, '“photo_sample.jpg”');
    expect(segs[1].fileId, '00000000-0000-0000-0000-000000000001');
  });

  test('web-style upload with curly quotes becomes tappable file', () {
    const raw =
        '张三在“开始“节点，上传附件\$\$“sample_image.png“\$\$<<rpc?method=/v2/file/download&id=00000000-0000-0000-0000-000000000002>>';
    final segs = parseRepairLogDescription(raw);
    expect(segs.length, 2);
    expect(segs[1].isFile, isTrue);
    expect(segs[1].text, '“sample_image.png”');
    expect(
        segs[1].fileId, '00000000-0000-0000-0000-000000000002');
  });

  test('delete log drops raw link but keeps filename', () {
    const raw =
        '张三在“开始“节点，删除附件“photo.jpg”**rpc?method=/v2/file/download&id=abc123**';
    final segs = parseRepairLogDescription(raw);
    expect(segs.length, 1);
    expect(segs.first.isFile, isFalse);
    expect(segs.first.text, '张三在“开始“节点，删除附件“photo.jpg”');
    expect(segs.first.text.contains('rpc?method'), isFalse);
  });

  test('plain comment and processing logs are untouched', () {
    for (final raw in [
      '张三在“报修人确认”节点，评价了该工单!',
      '付阿妮在“管理员处理”节点，完成了该工单!',
      '李四发表了评论，评论内容：已收到',
    ]) {
      final segs = parseRepairLogDescription(raw);
      expect(segs.length, 1, reason: raw);
      expect(segs.first.text, raw, reason: raw);
    }
  });

  test('empty input yields no segments', () {
    expect(parseRepairLogDescription(''), isEmpty);
  });

  test('extractRepairFileId handles full urls', () {
    expect(
      extractRepairFileId(
          'https://bxpt.hunau.edu.cn/relax/mobile/rpc?method=/v2/file/download&id=file-1'),
      'file-1',
    );
    expect(extractRepairFileId('not a link'), isNull);
  });
}
