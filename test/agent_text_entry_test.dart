import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sehatmate_ai/features/agent/copilot/agent_text_entry.dart';

void main() {
  testWidgets('progressive real field updates keep selection and final authoritative value', (tester) async {
    final c=TextEditingController();
    final typing=AgentTextEntry(c);
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:TextField(controller:c))));
    typing.fill('naya pakistan');await tester.pump(const Duration(milliseconds:90));
    expect(c.text,'nay');expect(c.selection.baseOffset,3);
    await tester.pump(const Duration(milliseconds:400));expect(c.text,'naya pakistan');expect(c.selection.baseOffset,13);expect(typing.isAnimating,false);
    await tester.pumpWidget(const SizedBox());typing.dispose();c.dispose();
  });
  testWidgets('new user text wins and stale timer never writes over it', (tester) async {
    final c=TextEditingController();
    final entry=AgentTextEntry(c);entry.fill('old agent title');await tester.pump(const Duration(milliseconds:70));
    c.value=const TextEditingValue(text:'My chosen title',selection:TextSelection.collapsed(offset:3));
    await tester.pump(const Duration(seconds:1));expect(c.text,'My chosen title');expect(c.selection.baseOffset,3);expect(entry.isAnimating,false);
    entry.dispose();c.dispose();
  });
  testWidgets('new Agent fill supersedes previous timer without old suffix', (tester) async {
    final c=TextEditingController();
    final typing=AgentTextEntry(c);typing.fill('Old value');await tester.pump(const Duration(milliseconds:60));typing.fill('New value');
    await tester.pump(const Duration(milliseconds:500));expect(c.text,'New value');expect(typing.isAnimating,false);typing.dispose();c.dispose();
  });
  testWidgets('long Unicode text completes within cap without splitting graphemes', (tester) async {
    final c=TextEditingController();final typing=AgentTextEntry(c);
    final text=List.filled(100,'e\u0301👩‍⚕️').join();typing.fill(text);
    await tester.pump(const Duration(milliseconds:35));expect(c.text.characters.every((g)=>g=='e\u0301'||g=='👩‍⚕️'),true);
    await tester.pump(const Duration(milliseconds:420));expect(c.text,text);expect(c.selection.baseOffset,text.length);expect(typing.isAnimating,false);
    typing.dispose();c.dispose();
  });
  testWidgets('cancel and disposal stop writes; reduced motion fills once exactly', (tester) async {
    final c=TextEditingController();final typing=AgentTextEntry(c);
    typing.fill('First');await tester.pump(const Duration(milliseconds:50));typing.cancel();final partial=c.text;
    await tester.pump(const Duration(seconds:1));expect(c.text,partial);
    typing.fill('Exact text',animate:false);expect(c.text,'Exact text');expect(typing.isAnimating,false);
    typing.fill('Disposed');typing.dispose();await tester.pump(const Duration(seconds:1));expect(c.text,'Exact text');c.dispose();
  });
}
