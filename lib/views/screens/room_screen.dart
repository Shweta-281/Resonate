import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:resonate/controllers/single_room_controller.dart';
import 'package:resonate/models/appwrite_room.dart';
import 'package:resonate/utils/ui_sizes.dart';
import 'package:resonate/views/widgets/participant_block.dart';
import 'package:resonate/views/widgets/room_app_bar.dart';
import 'package:resonate/views/widgets/room_header.dart';

class RoomScreen extends StatefulWidget {
  final AppwriteRoom room;

  const RoomScreen({
    Key? key,
    required this.room,
  }) : super(key: key);

  @override
  RoomScreenState createState() => RoomScreenState();
}

class RoomScreenState extends State<RoomScreen> {
  late final SingleRoomController controller;

  @override
  void initState() {
    super.initState();
    Get.put(SingleRoomController(appwriteRoom: widget.room));
  }

  Future<dynamic> _deleteRoomDialog(String text, Function() onTap) async {
    return await Get.defaultDialog(
      title: "Are you sure?",
      buttonColor: Theme.of(context).colorScheme.primary,
      middleText: "To $text the room",
      cancelTextColor: Theme.of(context).colorScheme.primary,
      onConfirm: onTap,
      onCancel: () => log("canceled"),
    );
  }

  String _getTags() {
    if (widget.room.tags.isEmpty) {
      return "";
    }
    String tagString = widget.room.tags[0] ?? "";
    for (var tag in widget.room.tags.sublist(1)) {
      tagString += " · $tag";
    }
    return tagString;
  }

  @override
  Widget build(BuildContext context) {
    SingleRoomController controller = Get.find<SingleRoomController>();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RoomAppBar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: RoomHeader(
              roomName: widget.room.name,
              roomDescription: widget.room.description,
              roomTags: _getTags(),
            ),
          ),
          SizedBox(height: UiSizes.height_7),
          Expanded(child: _buildParticipantsList(controller)),
        ],
      ),
    );
  }

  Widget _buildParticipantsList(SingleRoomController controller) {
    return Obx(() {
      if (controller.isLoading.value) {
        return Center(
          child: LoadingAnimationWidget.threeRotatingDots(
            color: Theme.of(context).colorScheme.primary,
            size: Get.pixelRatio * 20,
          ),
        );
      } else {
        return Stack(children: [
          Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context)
                    .colorScheme
                    .onSecondary
                    .withAlpha((255 * 0.15).round())),
          ),
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildParticipantsSection(
                  title: "Participants",
                  controller: controller,
                ),
              ],
            ),
          ),
          _buildFooter(),
        ]);
      }
    });
  }

  Widget _buildParticipantsSection({
    required String title,
    required SingleRoomController controller,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: UiSizes.size_18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Obx(() {
            return SizedBox(
              height: double.maxFinite,
              width: 400,
              child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: UiSizes.width_20,
                    mainAxisSpacing: UiSizes.height_5,
                    childAspectRatio: 2.5 / 3,
                  ),
                  itemCount: controller.participants.length,
                  itemBuilder: (ctx, index) {
                    return GetBuilder<SingleRoomController>(
                        builder: (controller) => ParticipantBlock(
                              participant: controller.participants[index].value,
                              controller: controller,
                            ));
                  }),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.07,
        width: double.infinity,
        decoration: BoxDecoration(
            borderRadius: BorderRadiusDirectional.circular(24),
            color: Theme.of(context).colorScheme.surface),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildLeaveButton(),
            _buildMicButton(),
            _buildRaiseHandButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveButton() {
    return GetBuilder<SingleRoomController>(builder: (controller) {
      return ElevatedButton.icon(
        onPressed: () async {
          await _deleteRoomDialog(
            controller.appwriteRoom.isUserAdmin ? "delete" : "leave",
            () async {
              if (controller.appwriteRoom.isUserAdmin) {
                await controller.deleteRoom();
              } else {
                await controller.leaveRoom();
              }
            },
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 241, 108, 98),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        icon: const Icon(Icons.exit_to_app),
        label: const Text("Leave"),
      );
    });
  }

  Widget _buildRaiseHandButton() {
    return GetBuilder<SingleRoomController>(builder: (controller) {
      final bool hasRequestedToBeSpeaker =
          controller.me.value.hasRequestedToBeSpeaker;

      return FloatingActionButton(
        onPressed: () {
          if (hasRequestedToBeSpeaker) {
            controller.unRaiseHand();
          } else {
            controller.raiseHand();
          }
        },
        backgroundColor: hasRequestedToBeSpeaker
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.black54,
        child: Icon(
          hasRequestedToBeSpeaker ? Icons.back_hand : Icons.back_hand_outlined,
          color: hasRequestedToBeSpeaker
              ? Colors.black
              : Theme.of(context).brightness == Brightness.light
                  ? Colors.black
                  : Colors.white54,
        ),
      );
    });
  }

  Widget _buildMicButton() {
    return GetBuilder<SingleRoomController>(builder: (controller) {
      final bool isMicOn = controller.me.value.isMicOn;
      final bool isSpeaker = controller.me.value.isSpeaker;

      return FloatingActionButton(
        onPressed: () {
          if (isSpeaker) {
            if (isMicOn) {
              controller.turnOffMic();
            } else {
              controller.turnOnMic();
            }
          }
        },
        backgroundColor: isMicOn ? Colors.lightGreen : Colors.redAccent,
        child: Icon(
          isMicOn ? Icons.mic : Icons.mic_off,
          color: Colors.black,
        ),
      );
    });
  }
}
