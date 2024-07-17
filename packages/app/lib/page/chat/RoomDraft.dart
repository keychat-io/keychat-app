// save draft in room texfield
class RoomDraft {
  static RoomDraft? _instance;
  // Avoid self instance
  RoomDraft._();
  static RoomDraft get instance => _instance ??= RoomDraft._();
  static Map<int, String> drafts = {};

  void setDraft(int roomId, String draft) {
    if (draft.isEmpty) {
      drafts.remove(roomId);
      return;
    }
    drafts[roomId] = draft;
  }

  String? getDraft(int roomId) {
    return drafts[roomId];
  }

  void clear(int roomId) {
    drafts.remove(roomId);
  }
}
