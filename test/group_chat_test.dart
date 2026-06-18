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

    const messages = [
      GroupChatMessage(
        id: 'message-1',
        senderId: 'user-2',
        senderNameSnapshot: 'Morgan',
        text: 'Visible message',
        type: 'text',
      ),
    ];

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
            repository: _FakeGroupChatRepository(messages: messages),
            onBack: () {},
            onOpenTrip: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final messageList = find.byType(ListView);
    final listRectBefore = tester.getRect(messageList);
    final messageField = find.byType(TextField);
    final messageFieldRectBefore = tester.getRect(messageField);

    await tester.tap(find.byTooltip('Attach'));
    await tester.pump();

    final options = find.byKey(const ValueKey('chat-composer-options'));
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
    final optionsRect = tester.getRect(options);
    expect(
      optionsRect.bottom,
      lessThanOrEqualTo(messageFieldRectBefore.top - 4),
    );
    expect(optionsRect.height, lessThan(260));
    expect(tester.getRect(messageList), listRectBefore);
    expect(tester.getRect(messageField), messageFieldRectBefore);

    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    expect(options, findsNothing);
    expect(tester.getRect(messageList), listRectBefore);
  });

  testWidgets('chat opens at the latest message without animated scrolling', (
    tester,
  ) async {
    final messages = List<GroupChatMessage>.generate(
      30,
      (index) => GroupChatMessage(
        id: 'message-$index',
        senderId: index.isEven ? 'user-1' : 'user-2',
        senderNameSnapshot: index.isEven ? 'Taylor' : 'Morgan',
        text: index == 29 ? 'Latest message' : 'Older message $index',
        type: 'text',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupChatRoomScreen(
            chat: const GroupChat(
              id: 'chat-1',
              title: 'Test chat',
              ownerId: 'user-1',
              memberIds: ['user-1', 'user-2'],
              roles: {'user-1': 'owner', 'user-2': 'member'},
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
            repository: _FakeGroupChatRepository(messages: messages),
            onBack: () {},
            onOpenTrip: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final messageList = tester.widget<ListView>(find.byType(ListView));
    expect(messageList.reverse, isTrue);
    expect(find.text('Latest message'), findsOneWidget);
    expect(find.text('Older message 0'), findsNothing);
  });

  testWidgets('chat separates messages by today, yesterday, and date', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final yesterday = today.subtract(const Duration(days: 1));
    final older = today.subtract(const Duration(days: 3));
    final messages = [
      GroupChatMessage(
        id: 'older',
        senderId: 'user-2',
        senderNameSnapshot: 'Morgan',
        text: 'Older message',
        type: 'text',
        createdAt: Timestamp.fromDate(older),
      ),
      GroupChatMessage(
        id: 'yesterday',
        senderId: 'user-2',
        senderNameSnapshot: 'Morgan',
        text: 'Yesterday message',
        type: 'text',
        createdAt: Timestamp.fromDate(yesterday),
      ),
      GroupChatMessage(
        id: 'today',
        senderId: 'user-1',
        senderNameSnapshot: 'Taylor',
        text: 'Today message',
        type: 'text',
        createdAt: Timestamp.fromDate(today),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroupChatRoomScreen(
            chat: const GroupChat(
              id: 'chat-1',
              title: 'Test chat',
              ownerId: 'user-1',
              memberIds: ['user-1', 'user-2'],
              roles: {'user-1': 'owner', 'user-2': 'member'},
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
            repository: _FakeGroupChatRepository(messages: messages),
            onBack: () {},
            onOpenTrip: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(GroupChatRoomScreen)),
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text(localizations.formatMediumDate(older)), findsOneWidget);
  });

  testWidgets('short text message bubble fits its content', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: GroupMessageBubble(
              message: GroupChatMessage(
                id: 'short-message',
                senderId: 'user-1',
                senderNameSnapshot: 'Taylor',
                text: 'Hi',
                type: 'text',
              ),
              isMine: true,
              currentUserId: 'user-1',
            ),
          ),
        ),
      ),
    );

    final bubble = find.byKey(
      const ValueKey('chat-message-bubble-short-message'),
    );
    expect(bubble, findsOneWidget);
    expect(tester.getSize(bubble).width, lessThan(90));
  });

  testWidgets('group owner can attach a trip from Group info', (tester) async {
    const chat = GroupChat(
      id: 'chat-1',
      title: 'Taipei group',
      ownerId: 'owner-1',
      memberIds: ['owner-1'],
      roles: {'owner-1': 'owner'},
    );
    final repository = _FakeGroupChatRepository(chat: chat);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: GroupChatInfoPanel(
              chatId: chat.id,
              accountId: 'owner-1',
              repository: repository,
              onAddMembers: () {},
              onOpenMedia: () {},
              onOpenTrip: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No trip attached'), findsOneWidget);
    expect(find.text('Attach trip'), findsOneWidget);
  });

  testWidgets('unjoined group member sees Join trip', (tester) async {
    const chat = GroupChat(
      id: 'chat-1',
      title: 'Taipei group',
      ownerId: 'owner-1',
      memberIds: ['owner-1', 'member-1'],
      roles: {'owner-1': 'owner', 'member-1': 'member'},
      linkedTripId: 'trip-1',
      linkedTripTitle: 'Taipei week',
      linkedTripDestination: 'Taipei',
    );
    final repository = _FakeGroupChatRepository(chat: chat);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 700,
            child: GroupChatInfoPanel(
              chatId: chat.id,
              accountId: 'member-1',
              repository: repository,
              onAddMembers: () {},
              onOpenMedia: () {},
              onOpenTrip: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Attached trip'), findsOneWidget);
    expect(find.text('Join trip'), findsOneWidget);
    expect(find.text('Replace trip'), findsNothing);
    expect(find.text('Detach trip'), findsNothing);
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
  _FakeGroupChatRepository({
    this.messages = const <GroupChatMessage>[],
    this.chat,
  });

  final List<GroupChatMessage> messages;
  final GroupChat? chat;

  @override
  Stream<List<GroupChatMessage>> watchMessages(String chatId) {
    return Stream.value(messages);
  }

  @override
  Stream<GroupChat?> watchChat(String chatId) {
    return Stream.value(chat);
  }

  @override
  Stream<List<GroupChatMember>> watchMembers(String chatId) {
    return Stream.value(const []);
  }

  @override
  Stream<bool> watchTripMembership({
    required String accountId,
    required String tripId,
  }) {
    return Stream.value(false);
  }
}
