import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_app/app/travel_agent_app.dart';
import 'package:flutter_app/features/auth/data/account_auth_service.dart';
import 'package:flutter/material.dart';
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

  group('ChatPoll', () {
    test('parses valid poll data and rejects incomplete polls', () {
      final poll = ChatPoll.fromMap({
        'question': 'Where should we eat?',
        'options': ['Night market', 'Cafe'],
      });

      expect(poll?.question, 'Where should we eat?');
      expect(poll?.options, ['Night market', 'Cafe']);
      expect(
        ChatPoll.fromMap({
          'question': 'Only one option',
          'options': ['Cafe'],
        }),
        isNull,
      );
    });

    testWidgets('poll card reports the selected option', (tester) async {
      int? selectedOption;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatPollCard(
              poll: const ChatPoll(
                question: 'Pick a day',
                options: ['Friday', 'Saturday'],
              ),
              currentUserId: 'user-1',
              votes: Stream.value(const {'user-2': 1}),
              foregroundColor: Colors.black,
              onVote: (optionIndex) async {
                selectedOption = optionIndex;
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Friday'));
      await tester.pump();

      expect(selectedOption, 0);
      expect(find.text('1 vote'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('chat composer options appear above the bar and wrap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupChatRoomScreen(
            chat: const GroupChat(
              id: 'chat-1',
              title: 'Test chat',
              ownerId: 'user-1',
              memberIds: ['user-1'],
              roles: {'user-1': 'owner'},
            ),
            membership: const GroupChatMembership(
              chatId: 'chat-1',
              role: 'owner',
              status: 'active',
              titleSnapshot: 'Test chat',
            ),
            account: const AuthenticatedAccount(
              uid: 'user-1',
              displayName: 'Taylor',
            ),
            user: const UserProfile(
              name: 'Taylor',
              email: 'taylor@example.com',
              interests: [],
            ),
            repository: _FakeGroupChatRepository(),
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Attach'));
    await tester.pump();

    final options = find.byKey(const ValueKey('chat-composer-options'));
    final messageField = find.byType(TextField);
    expect(options, findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
    expect(find.text('Poll'), findsOneWidget);
    expect(
      tester.getTopLeft(options).dy,
      lessThan(tester.getTopLeft(messageField).dy),
    );
    expect(
      tester.getTopLeft(find.text('Camera')).dy,
      tester.getTopLeft(find.text('Photos')).dy,
    );
    expect(
      tester.getTopLeft(find.text('Poll')).dy,
      greaterThan(tester.getTopLeft(find.text('Camera')).dy),
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(options, findsNothing);
  });

  test('GroupChatJoinResult parses callable response data', () {
    final result = GroupChatJoinResult.fromMap({
      'chatId': 'chat-123',
      'title': 'Taipei plans',
      'role': 'member',
      'alreadyMember': true,
    });

    expect(result.chatId, 'chat-123');
    expect(result.title, 'Taipei plans');
    expect(result.role, GroupChatRole.member.name);
    expect(result.alreadyMember, isTrue);
  });
}

class _FakeGroupChatRepository extends Fake implements GroupChatRepository {
  @override
  Stream<List<GroupChatMessage>> watchMessages(String chatId) {
    return Stream.value(const []);
  }
}
