import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupChatMembership mute state', () {
    GroupChatMembership membership({
      Timestamp? mutedUntil,
      bool mutedForever = false,
    }) {
      return GroupChatMembership(
        chatId: 'chat-1',
        role: GroupChatRole.member.name,
        status: GroupChatMemberStatus.active.name,
        titleSnapshot: 'Test chat',
        mutedUntil: mutedUntil,
        mutedForever: mutedForever,
      );
    }

    test('recognizes temporary, expired, and permanent mute choices', () {
      expect(
        membership(
          mutedUntil: Timestamp.fromDate(
            DateTime.now().add(const Duration(minutes: 30)),
          ),
        ).isMuted,
        isTrue,
      );
      expect(
        membership(
          mutedUntil: Timestamp.fromDate(
            DateTime.now().subtract(const Duration(minutes: 1)),
          ),
        ).isMuted,
        isFalse,
      );
      expect(membership(mutedForever: true).isMuted, isTrue);
    });
  });
}
