import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chat_app/service/user_service.dart';
import 'package:chat_app/shared/constants/navigation/screen_params.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChatMainScreen extends StatefulWidget {
  final ChatMainScreenArgs params;
  // final String idd;
  const ChatMainScreen({super.key, required this.params});

  @override
  State<ChatMainScreen> createState() => _ChatMainScreenState();
}

class _ChatMainScreenState extends State<ChatMainScreen> {
  final msjController = TextEditingController();
  bool isInitial = true;
  late RecorderController recorderController;
  late PlayerController playerController;
  TextEditingController messageCont = TextEditingController();
  ValueNotifier<bool> isRecording = ValueNotifier(false);
  List<dynamic> messageList = [];
  DocumentSnapshot? lastDocument;
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((val) {
      recorderController = RecorderController();
      playerController = PlayerController();
      getMessagesStream();
      scrollController.addListener(onScroll);
    });
  }

  void onScroll() {
    if (scrollController.position.pixels <=
        scrollController.position.minScrollExtent + 50) {
      fetchMessages();
    }
  }

  Future<void> fetchMessages() async {
    List<DocumentSnapshot> paginatedMessages = await UserService.instance
        .getMessagesPaginated(
            FirebaseAuth.instance.currentUser!.uid, widget.params.id,
            lastDocument: lastDocument);

    if (paginatedMessages.isNotEmpty) {
      setState(() {
        messageList = paginatedMessages
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        lastDocument = paginatedMessages.last;
      });
    }
  }

  void getMessagesStream() {
    Stream<List<Map<String, dynamic>>> messagesStream = UserService.instance
        .getMessages(FirebaseAuth.instance.currentUser!.uid, widget.params.id);

    messagesStream.listen((messages) {
      if (messages.isNotEmpty) {
        setState(() {
          messageList.addAll(messages);
        });
        if (isInitial) {
          isInitial = false;
          fetchMessages();
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    recorderController.dispose();
    playerController.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: getOnlineStatus(),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
          padding: const EdgeInsets.all(10),
          child: messageList.isEmpty
              ? const SizedBox()
              : ListView.builder(
                  controller: scrollController,
                  reverse: true,
                  //  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: messageList.length,
                  itemBuilder: (context, index) {
                    final item = messageList[index];
                    final previousItem =
                        index == 0 ? null : messageList[index - 1];
                    final data = item;
                    final readByList = data['readBy'] ?? [];
                    if (!readByList
                        .contains(FirebaseAuth.instance.currentUser!.uid)) {
                      UserService.instance.markMessagesAsRead(widget.params.id,
                          FirebaseAuth.instance.currentUser!.uid);
                    }

                    DateTime? messageTime;
                    if (data['time'] != null) {
                      messageTime = (data['time']).toDate();
                    }
                    final time = messageTime != null
                        ? DateFormat.jm().format(messageTime)
                        : '';
                    DateTime? msgDate =
                        item['time']?.toDate() ?? DateTime.now();
                    String msgDateS = UserService.formatDateTime(msgDate);
                    String? previousDateS;

                    if (previousItem != null) {
                      DateTime previousDate = previousItem['time'].toDate();
                      previousDateS = UserService.formatDateTime(previousDate);
                    }

                    bool isSeen =
                        data['readBy']?.contains(widget.params.id) ?? false;

                    return Column(
                      children: [
                        if (msgDateS != previousDateS)
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 10),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                msgDateS,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                            ),
                          ),
                        Align(
                          alignment: data['senderId'] ==
                                  FirebaseAuth.instance.currentUser!.uid
                              ? Alignment.bottomRight
                              : Alignment.bottomLeft,
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: () async {
                                  if (data['voiceUrl'] != null) {
                                    await playerController.preparePlayer(
                                      path: data['voiceUrl'],
                                      shouldExtractWaveform: true,
                                    );
                                    playerController.startPlayer();
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: data['senderId'] ==
                                            FirebaseAuth
                                                .instance.currentUser!.uid
                                        ? Colors.green
                                        : Colors.blue,
                                  ),
                                  child: (data['isVoiceMessage'] == true)
                                      ? AudioFileWaveforms(
                                          playerController: playerController,
                                          size: const Size(100, 40.0),
                                          playerWaveStyle:
                                              const PlayerWaveStyle(
                                            fixedWaveColor: Colors.red,
                                            liveWaveColor: Colors.white,
                                            spacing: 6,
                                          ),
                                        )
                                      : Text(data['message'] ?? ''),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    time,
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  if (data['senderId'] ==
                                      FirebaseAuth.instance.currentUser!.uid)
                                    Icon(
                                      isSeen
                                          ? Icons.check_circle
                                          : Icons.check_circle_outline,
                                      color: isSeen ? Colors.blue : Colors.grey,
                                      size: 16,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  })),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(10.0),
        child: ValueListenableBuilder(
            valueListenable: isRecording,
            builder: (context, value, child) {
              return Row(
                children: [
                  isRecording.value
                      ? Expanded(
                          child: AudioWaveforms(
                            recorderController: recorderController,
                            size: Size(MediaQuery.of(context).size.width, 26.0),
                            enableGesture: true,
                            waveStyle: const WaveStyle(
                              waveColor: Colors.black,
                              showDurationLabel: false,
                              spacing: 8.0,
                              showBottom: false,
                              extendWaveform: true,
                              showMiddleLine: false,
                            ),
                          ),
                        )
                      : Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewInsets.bottom,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: msjController,
                                      decoration: const InputDecoration(
                                        hintText: 'Enter message',
                                        hintStyle: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      UserService.instance.sendMessage(
                                        msjController.text,
                                        FirebaseAuth.instance.currentUser!.uid,
                                        widget.params.id,
                                      );
                                      msjController.clear();
                                    },
                                    icon: Icon(
                                      Icons.send,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      if (isRecording.value) {
                        // Stop recording and send voice message
                        String? recordedFilePath =
                            await recorderController.stop();
                        if (recordedFilePath != null) {
                          // Call the function to send the voice message
                          await UserService.instance.sendVoiceMessage(
                            recordedFilePath,
                            FirebaseAuth.instance.currentUser!.uid,
                            widget.params.id,
                          );
                        }
                      } else {
                        // Start recording
                        recorderController.record();
                      }

                      // Toggle recording state
                      isRecording.value = !isRecording.value;
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRecording.value ? Icons.stop : Icons.mic,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            }),
      ),
    );
  }

  Widget getOnlineStatus() {
    return StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.params.id)
            .snapshots(),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox();
          }
          String? lastSeen;
          bool isOnline = snapshot.data?['isOnline'];
          Timestamp time = snapshot.data?['timeStamp'];

          if (isOnline) {
            lastSeen = 'Online';
          } else {
            DateTime lastSeendt = time.toDate();
            DateTime now = DateTime.now();

            String formattedTime = DateFormat('HH:mm a').format(lastSeendt);
            if (now.difference(lastSeendt).inDays == 0) {
              lastSeen = 'Last seen today at $formattedTime';
            } else {
              String formattedDate = DateFormat('yMd').format(lastSeendt);
              lastSeen = 'Last seen $formattedDate at $formattedTime';
            }
          }
          return Text(
            lastSeen,
            style: const TextStyle(fontSize: 13),
          );
        });
  }
}
