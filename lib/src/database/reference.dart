part of firebase_dart;

/// DatabaseReference represents a particular location in your Firebase
/// Database and can be used for reading or writing data to that location.
///
/// This class is the starting point for all Firebase Database operations.
/// After you’ve obtained your first DatabaseReference via
/// `FirebaseDatabase.reference()`, you can use it to read data
/// (ie. `onChildAdded`), write data (ie. `setValue`), and to create new
/// `DatabaseReference`s (ie. `child`).
abstract class DatabaseReference implements Query {
  /// Getter for onDisconnect.
  Disconnect get onDisconnect;

  /// Gets a DatabaseReference for the location at the specified relative path.
  ///
  /// The relative path can either be a simple child name, (e.g. 'fred') or a
  /// deeper slash separated path (e.g. 'fred/name/first').
  DatabaseReference child(String c);

  /// Gets a DatabaseReference for the parent location.
  ///
  /// If this instance refers to the root of your Firebase Database, it has no
  /// parent, and therefore parent() will return null.
  DatabaseReference parent();

  /// Gets a DatabaseReference for the root location.
  DatabaseReference root();

  /// Gets the last token in a Firebase Database location (e.g. ‘fred’ in
  /// https://SampleChat.firebaseIO-demo.com/users/fred)
  ///
  /// [key] on the root of a Firebase is `null`.
  String get key => url.pathSegments.isEmpty
      ? null
      : url.pathSegments.lastWhere((s) => s.isNotEmpty);

  /// Gets the absolute URL corresponding to this Firebase reference's location.
  Uri get url;

  /// Write `value` to the location with the specified `priority` if applicable.
  ///
  /// This will overwrite any data at this location and all child locations.
  ///
  /// Data types that are allowed are String, boolean, int, double, Map, List.
  ///
  /// The effect of the write will be visible immediately and the corresponding
  /// events ('onValue', 'onChildAdded', etc.) will be triggered.
  /// Synchronization of the data to the Firebase servers will also be started,
  /// and the Future returned by this method will complete after synchronization
  /// has finished.
  ///
  /// Passing null for the new value is equivalent to calling remove().
  ///
  /// A single set() will generate a single onValue event at the location where
  /// the set() was performed.
  Future<void> set(dynamic value, {dynamic priority});

  /// Write the enumerated children to this Firebase location. This will only
  /// overwrite the children enumerated in the 'value' parameter and will leave
  /// others untouched.
  ///
  /// The returned Future will be complete when the synchronization has
  /// completed with the Firebase servers.
  Future<void> update(Map<String, dynamic> value);

  /// Remove the data at this Firebase location. Any data at child locations
  /// will also be deleted.
  ///
  /// The effect of this delete will be visible immediately and the
  /// corresponding events (onValue, onChildAdded, etc.) will be triggered.
  /// Synchronization of the delete to the Firebase servers will also be
  /// started, and the Future returned by this method will complete after the
  /// synchronization has finished.
  Future<void> remove() => set(null);

  /// Push generates a new child location using a unique name and returns a
  /// Firebase reference to it. This is useful when the children of a Firebase
  /// location represent a list of items.
  ///
  /// The unique name generated by push() is prefixed with a client-generated
  /// timestamp so that the resulting list will be chronologically sorted.
  Future<DatabaseReference> push(dynamic value);

  /// Sets a priority for the data at this Firebase Database location.
  ///
  /// Priorities can be used to provide a custom ordering for the children at a
  /// location (if no priorities are specified, the children are ordered by
  /// key).
  ///
  /// You cannot set a priority on an empty location. For this reason
  /// set() should be used when setting initial data with a specific priority
  /// and setPriority() should be used when updating the priority of existing
  /// data.
  ///
  /// Children are sorted based on this priority using the following rules:
  ///
  /// Children with no priority come first. Children with a number as their
  /// priority come next. They are sorted numerically by priority (small to
  /// large). Children with a string as their priority come last. They are
  /// sorted lexicographically by priority. Whenever two children have the same
  /// priority (including no priority), they are sorted by key. Numeric keys
  /// come first (sorted numerically), followed by the remaining keys (sorted
  /// lexicographically).
  ///
  /// Note that priorities are parsed and ordered as IEEE 754 double-precision
  /// floating-point numbers. Keys are always stored as strings and are treated
  /// as numbers only when they can be parsed as a 32-bit integer.
  Future<void> setPriority(dynamic priority);

  /// Atomically modify the data at this location. Unlike a normal set(), which
  /// just overwrites the data regardless of its previous value, transaction()
  /// is used to modify the existing value to a new value, ensuring there are
  /// no conflicts with other clients writing to the same location at the same
  /// time.
  ///
  /// To accomplish this, you pass [transaction] an update function which is
  /// used to transform the current value into a new value. If another client
  /// writes to the location before your new value is successfully written,
  /// your update function will be called again with the new current value, and
  /// the write will be retried. This will happen repeatedly until your write
  /// succeeds without conflict or you abort the transaction by not returning
  /// a value from your update function.
  ///
  /// The returned [Future] will be completed after the transaction has
  /// finished.
  Future<DataSnapshot> transaction(dynamic Function(dynamic currentVal) update,
      {bool applyLocally = true});
}
