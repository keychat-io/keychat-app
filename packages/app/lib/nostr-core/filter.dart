/// filter is a JSON object that determines what events will be sent in that subscription
class Filter {
  /// a list of event ids or prefixes
  List<String>? ids;

  /// a list of pubkeys or prefixes, the pubkey of an event must be one of these
  List<String>? authors;

  /// a list of a kind numbers
  List<int>? kinds;

  /// a list of event ids that are referenced in an "e" tag
  List<String>? e;

  /// a list of pubkeys that are referenced in a "p" tag
  List<String>? p;

  List<String>? r;

  List<String>? t;

  List<String>? h; // mls group

  /// a timestamp, events must be newer than this to pass
  int? since;

  /// a timestamp, events must be older than this to pass
  int? until;

  /// maximum number of events to be returned in the initial query
  int? limit;

  /// Default constructor
  Filter(
      {this.ids,
      this.authors,
      this.kinds,
      this.e,
      this.p,
      this.r,
      this.t,
      this.h,
      this.since,
      this.until,
      this.limit});

  /// Deserialize a filter from a JSON
  Filter.fromJson(Map<String, dynamic> json) {
    ids = json['ids'] == null ? null : List<String>.from(json['ids']);
    authors =
        json['authors'] == null ? null : List<String>.from(json['authors']);
    kinds = json['kinds'] == null ? null : List<int>.from(json['kinds']);
    e = json['#e'] == null ? null : List<String>.from(json['#e']);
    p = json['#p'] == null ? null : List<String>.from(json['#p']);
    r = json['#r'] == null ? null : List<String>.from(json['#r']);
    t = json['#t'] == null ? null : List<String>.from(json['#t']);
    h = json['#h'] == null ? null : List<String>.from(json['#h']);
    since = json['since'];
    until = json['until'];
    limit = json['limit'];
  }

  /// Serialize a filter in JSON
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (ids != null) {
      data['ids'] = ids;
    }
    if (authors != null) {
      data['authors'] = authors;
    }
    if (kinds != null) {
      data['kinds'] = kinds;
    }
    if (e != null) {
      data['#e'] = e;
    }
    if (p != null) {
      data['#p'] = p;
    }
    if (r != null) {
      data['#r'] = r;
    }
    if (t != null) {
      data['#t'] = t;
    }
    if (h != null) {
      data['#h'] = h;
    }
    if (since != null) {
      data['since'] = since;
    }
    if (until != null) {
      data['until'] = until;
    }
    if (limit != null) {
      data['limit'] = limit;
    }
    return data;
  }
}
